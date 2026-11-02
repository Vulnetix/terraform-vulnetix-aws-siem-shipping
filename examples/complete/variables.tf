variable "guardian_ingest_token_secret_id" {
  description = "The Secrets Manager secret holding the Guardian ingest token."
  type        = string
  default     = "vulnetix/guardian-ingest-token"
}
