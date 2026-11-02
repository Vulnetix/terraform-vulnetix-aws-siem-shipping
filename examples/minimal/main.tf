# CloudTrail only: the one required input is the Guardian ingest token. From
# the registry, use source = "Vulnetix/aws-siem-shipping/vulnetix" with a
# version.

provider "aws" {
  region = "us-east-1"
}

module "vulnetix_siem" {
  source = "../.."

  ingest_token = var.guardian_ingest_token
}
