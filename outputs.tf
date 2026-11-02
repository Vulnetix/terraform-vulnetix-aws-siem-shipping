output "stream_names" {
  description = "The Firehose delivery stream names, by kind: flow, dns and cloudtrail."
  value       = { for k, s in aws_kinesis_firehose_delivery_stream.this : k => s.name }
}

output "stream_arns" {
  description = "The Firehose delivery stream ARNs, by kind: flow, dns and cloudtrail."
  value       = { for k, s in aws_kinesis_firehose_delivery_stream.this : k => s.arn }
}

output "error_bucket" {
  description = "The bucket holding batches Guardian refused after five minutes of retries."
  value       = aws_s3_bucket.errors.bucket
}

output "flow_log_ids" {
  description = "The VPC flow log ids, by VPC id."
  value       = { for k, f in aws_flow_log.vpc : k => f.id }
}

output "resolver_query_log_config_id" {
  description = "The Route 53 Resolver query logging config id, or null when resolver logs are off."
  value       = one(aws_route53_resolver_query_log_config.this[*].id)
}

output "cloudtrail_rule_arn" {
  description = "The EventBridge rule sending CloudTrail events, or null when CloudTrail is off."
  value       = one(aws_cloudwatch_event_rule.cloudtrail[*].arn)
}
