# Every input: flow logs and DNS query logs for two VPCs, CloudTrail, a
# longer error retention and tags, with the token from a secret store. From
# the registry, use source = "Vulnetix/aws-siem-shipping/vulnetix" with a
# version.

variable "guardian_ingest_token_secret_id" {
  description = "The Secrets Manager secret holding the Guardian ingest token."
  type        = string
  default     = "vulnetix/guardian-ingest-token"
}

provider "aws" {
  region = "eu-west-1"
}

data "aws_secretsmanager_secret_version" "guardian" {
  secret_id = var.guardian_ingest_token_secret_id
}

data "aws_vpcs" "production" {
  tags = {
    Environment = "production"
  }
}

module "vulnetix_siem" {
  source = "../.."

  ingest_token = data.aws_secretsmanager_secret_version.guardian.secret_string
  ingest_host  = "ingest.vulnetix.com"
  vpc_ids      = data.aws_vpcs.production.ids

  send_flow_logs     = true
  send_resolver_logs = true
  send_cloudtrail    = true

  error_retention_days       = 30
  force_destroy_error_bucket = false

  tags = {
    Owner       = "security-platform"
    Environment = "production"
  }
}

output "stream_arns" {
  description = "The Firehose streams delivering to Guardian, by kind."
  value       = module.vulnetix_siem.stream_arns
}

output "error_bucket" {
  description = "Where refused batches land."
  value       = module.vulnetix_siem.error_bucket
}

output "flow_log_ids" {
  description = "One flow log per VPC."
  value       = module.vulnetix_siem.flow_log_ids
}

output "resolver_query_log_config_id" {
  description = "The DNS query logging config."
  value       = module.vulnetix_siem.resolver_query_log_config_id
}

output "cloudtrail_rule_arn" {
  description = "The EventBridge rule sending CloudTrail events."
  value       = module.vulnetix_siem.cloudtrail_rule_arn
}
