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
