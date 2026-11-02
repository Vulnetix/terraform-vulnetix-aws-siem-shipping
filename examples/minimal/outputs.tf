output "stream_names" {
  description = "The Firehose streams delivering to Guardian."
  value       = module.vulnetix_siem.stream_names
}
