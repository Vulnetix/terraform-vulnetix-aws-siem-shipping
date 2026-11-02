# CloudTrail only: the one required input is the Guardian ingest token. From
# the registry, use source = "Vulnetix/aws-siem-shipping/vulnetix" with a
# version.

variable "guardian_ingest_token" {
  description = "The Guardian ingest token (gdn_...) from the Guardian Sources page."
  type        = string
  sensitive   = true
}

provider "aws" {
  region = "us-east-1"
}

module "vulnetix_siem" {
  source = "../.."

  ingest_token = var.guardian_ingest_token
}

output "stream_names" {
  description = "The Firehose streams delivering to Guardian."
  value       = module.vulnetix_siem.stream_names
}
