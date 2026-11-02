variable "ingest_token" {
  description = "The Guardian ingest token (gdn_...) from the Guardian Sources page, shown once there. Firehose sends it as the access key on every delivery. Pass it from a secret store; it is kept in the Terraform state like any Firehose access key, so keep the state encrypted."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^gdn_[A-Za-z0-9_-]{20,64}$", var.ingest_token))
    error_message = "The ingest_token must be a Guardian ingest token: gdn_ followed by 20 to 64 letters, digits, underscores or hyphens."
  }
}

variable "ingest_host" {
  description = "The Guardian ingest host. Change it only when Vulnetix support asks you to."
  type        = string
  default     = "ingest.vulnetix.com"
}

variable "vpc_ids" {
  description = "The VPCs to send flow logs and DNS query logs for (vpc-...). Leave empty to send CloudTrail only."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for v in var.vpc_ids : can(regex("^vpc-[0-9a-f]+$", v))])
    error_message = "Each vpc_ids entry must be a VPC id, such as vpc-0abc123."
  }
}

variable "send_flow_logs" {
  description = "Whether to send VPC flow logs for vpc_ids."
  type        = bool
  default     = true
}

variable "send_resolver_logs" {
  description = "Whether to send Route 53 Resolver query logs for vpc_ids."
  type        = bool
  default     = true
}

variable "send_cloudtrail" {
  description = "Whether to send CloudTrail management write events and console sign-ins. They reach EventBridge only while a trail logs management events, such as the Vulnetix onboarding pipeline's."
  type        = bool
  default     = true
}

variable "error_retention_days" {
  description = "How many days to keep batches Guardian refused after five minutes of retries."
  type        = number
  default     = 14

  validation {
    condition     = var.error_retention_days >= 1
    error_message = "The error_retention_days must be at least 1."
  }
}

variable "force_destroy_error_bucket" {
  description = "Whether terraform destroy may delete the error bucket while it still holds failed batches."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags for every resource that takes them. ManagedBy = terraform is always added."
  type        = map(string)
  default     = {}
}
