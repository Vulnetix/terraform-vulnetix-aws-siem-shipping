# Every input: flow logs and DNS query logs for the production VPCs,
# CloudTrail, a longer error retention and tags, with the token read from
# Secrets Manager. From the registry, use
# source = "Vulnetix/aws-siem-shipping/vulnetix" with a version.

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
