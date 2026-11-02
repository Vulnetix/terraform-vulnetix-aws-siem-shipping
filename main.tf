# Vulnetix Guardian log delivery: the Terraform form of the CloudFormation
# template the Guardian Sources page launches (Vulnetix/siem
# aws/vulnetix-siem.yaml). The resource names are the template's, so the
# two are interchangeable, and an account runs one or the other per region.
#
# Three Firehose streams deliver to ingest.vulnetix.com over HTTPS with the
# Guardian ingest token: VPC flow logs, Route 53 Resolver query logs and
# CloudTrail. Nothing here grants Vulnetix any access to the account.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # Each stream posts to its own ingest path: /v1/ingest/aws/<kind>.
  stream_kinds = toset(["flow", "dns", "cloudtrail"])

  flow_on       = var.send_flow_logs && length(var.vpc_ids) > 0
  resolver_on   = var.send_resolver_logs && length(var.vpc_ids) > 0
  cloudtrail_on = var.send_cloudtrail

  # The format Guardian's flow normaliser reads (worker/src/normalise/aws.ts
  # FLOW_FORMAT). Changing it breaks parsing.
  flow_log_format = "$${version} $${account-id} $${region} $${vpc-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${tcp-flags} $${flow-direction} $${log-status}"

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

# Batches Guardian could not take after five minutes of retries land here.
resource "aws_s3_bucket" "errors" {
  bucket        = "vulnetix-siem-errors-${local.account_id}-${local.region}"
  force_destroy = var.force_destroy_error_bucket
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "errors" {
  bucket                  = aws_s3_bucket.errors.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "errors" {
  bucket = aws_s3_bucket.errors.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "errors" {
  bucket = aws_s3_bucket.errors.id

  rule {
    id     = "expire-failed-batches"
    status = "Enabled"

    filter {}

    expiration {
      days = var.error_retention_days
    }
  }
}

data "aws_iam_policy_document" "firehose_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "firehose" {
  name               = "vulnetix-siem-firehose-${local.region}"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "firehose_failed_batches" {
  statement {
    actions   = ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:ListBucket", "s3:PutObject"]
    resources = [aws_s3_bucket.errors.arn, "${aws_s3_bucket.errors.arn}/*"]
  }
}

resource "aws_iam_role_policy" "firehose_failed_batches" {
  name   = "failed-batches"
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose_failed_batches.json
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  for_each = local.stream_kinds

  name        = "vulnetix-siem-${each.key}"
  destination = "http_endpoint"

  http_endpoint_configuration {
    name               = "Vulnetix Guardian"
    url                = "https://${var.ingest_host}/v1/ingest/aws/${each.key}"
    access_key         = var.ingest_token
    buffering_interval = 0
    buffering_size     = 1
    retry_duration     = 300
    role_arn           = aws_iam_role.firehose.arn
    s3_backup_mode     = "FailedDataOnly"

    request_configuration {
      content_encoding = "GZIP"
    }

    s3_configuration {
      role_arn   = aws_iam_role.firehose.arn
      bucket_arn = aws_s3_bucket.errors.arn
      prefix     = "${each.key}/"
    }
  }

  tags = local.tags

  depends_on = [aws_iam_role_policy.firehose_failed_batches]
}

resource "aws_flow_log" "vpc" {
  for_each = local.flow_on ? toset(var.vpc_ids) : toset([])

  vpc_id                   = each.key
  traffic_type             = "ALL"
  max_aggregation_interval = 60
  log_destination_type     = "kinesis-data-firehose"
  log_destination          = aws_kinesis_firehose_delivery_stream.this["flow"].arn
  log_format               = local.flow_log_format
  tags                     = local.tags
}

resource "aws_route53_resolver_query_log_config" "this" {
  count = local.resolver_on ? 1 : 0

  name            = "vulnetix-siem"
  destination_arn = aws_kinesis_firehose_delivery_stream.this["dns"].arn
  tags            = local.tags
}

resource "aws_route53_resolver_query_log_config_association" "vpc" {
  for_each = local.resolver_on ? toset(var.vpc_ids) : toset([])

  resolver_query_log_config_id = aws_route53_resolver_query_log_config.this[0].id
  resource_id                  = each.key
}

# CloudTrail reaches EventBridge only while a trail logs management events
# (the Vulnetix onboarding pipeline's trail does). Read-only calls never
# reach it.
data "aws_iam_policy_document" "events_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events" {
  count = local.cloudtrail_on ? 1 : 0

  name_prefix        = "vulnetix-siem-events-"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "events_put_records" {
  statement {
    actions   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
    resources = [aws_kinesis_firehose_delivery_stream.this["cloudtrail"].arn]
  }
}

resource "aws_iam_role_policy" "events_put_records" {
  count = local.cloudtrail_on ? 1 : 0

  name   = "put-records"
  role   = aws_iam_role.events[0].id
  policy = data.aws_iam_policy_document.events_put_records.json
}

resource "aws_cloudwatch_event_rule" "cloudtrail" {
  count = local.cloudtrail_on ? 1 : 0

  name        = "vulnetix-siem-cloudtrail"
  description = "CloudTrail management write events and console sign-ins to Vulnetix Guardian"
  event_pattern = jsonencode({
    "detail-type" = [
      "AWS API Call via CloudTrail",
      "AWS Console Sign In via CloudTrail",
    ]
  })
  tags = local.tags
}

resource "aws_cloudwatch_event_target" "cloudtrail" {
  count = local.cloudtrail_on ? 1 : 0

  rule      = aws_cloudwatch_event_rule.cloudtrail[0].name
  target_id = "guardian"
  arn       = aws_kinesis_firehose_delivery_stream.this["cloudtrail"].arn
  role_arn  = aws_iam_role.events[0].arn
}
