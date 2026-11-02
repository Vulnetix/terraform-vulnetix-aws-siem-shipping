# terraform-vulnetix-aws-siem-shipping

Ships an AWS account's logs to Vulnetix Guardian, the Vulnetix SIEM. This is the Terraform form of the CloudFormation stack the Guardian Sources page launches, with the same resource names, so use one or the other in each region.

It creates three Firehose delivery streams that post to `ingest.vulnetix.com` over HTTPS with your Guardian ingest token:

- `vulnetix-siem-flow`: VPC flow logs for the VPCs you name, in the format Guardian parses.
- `vulnetix-siem-dns`: Route 53 Resolver query logs for the same VPCs.
- `vulnetix-siem-cloudtrail`: CloudTrail management write events and console sign-ins, through an EventBridge rule.

Batches Guardian refuses after five minutes of retries land in `vulnetix-siem-errors-<account>-<region>`, kept for 14 days by default. Nothing here grants Vulnetix any access to the account.

## Usage

```hcl
module "vulnetix_siem" {
  source  = "Vulnetix/aws-siem-shipping/vulnetix"
  version = "~> 1.0"

  ingest_token = var.guardian_ingest_token # gdn_..., from the Guardian Sources page
  vpc_ids      = ["vpc-0abc1234def567890"]
}
```

With no `vpc_ids`, only CloudTrail is sent. CloudTrail events reach EventBridge only while a trail logs management events. The trail from [terraform-vulnetix-aws-onboarding](https://github.com/Vulnetix/terraform-vulnetix-aws-onboarding) does, and so does any organisation trail.

- [examples/minimal](examples/minimal): CloudTrail only, the token from a variable.
- [examples/complete](examples/complete): every input, VPCs found by tag and the token read from Secrets Manager.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `ingest_token` | The Guardian ingest token (`gdn_...`) from the Guardian Sources page. Sensitive. | `string` | n/a | yes |
| `ingest_host` | The Guardian ingest host. | `string` | `"ingest.vulnetix.com"` | no |
| `vpc_ids` | VPCs to send flow logs and DNS query logs for. Empty sends CloudTrail only. | `list(string)` | `[]` | no |
| `send_flow_logs` | Send VPC flow logs for `vpc_ids`. | `bool` | `true` | no |
| `send_resolver_logs` | Send Route 53 Resolver query logs for `vpc_ids`. | `bool` | `true` | no |
| `send_cloudtrail` | Send CloudTrail management write events and console sign-ins. | `bool` | `true` | no |
| `error_retention_days` | Days to keep refused batches. | `number` | `14` | no |
| `force_destroy_error_bucket` | Let `terraform destroy` delete the error bucket while it holds batches. | `bool` | `false` | no |
| `tags` | Tags for every resource that takes them. `ManagedBy = "terraform"` is always added. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `stream_names` | The delivery stream names, by kind (`flow`, `dns`, `cloudtrail`). |
| `stream_arns` | The delivery stream ARNs, by kind. |
| `error_bucket` | The bucket holding refused batches. |
| `flow_log_ids` | The VPC flow log ids, by VPC id. |
| `resolver_query_log_config_id` | The Resolver query logging config, or null when resolver logs are off. |
| `cloudtrail_rule_arn` | The EventBridge rule, or null when CloudTrail is off. |

## Requirements

| Name | Version |
|------|---------|
| terraform or OpenTofu | >= 1.5.0 |
| hashicorp/aws | >= 6.0 |

## The ingest token

Firehose sends the token as the access key on every delivery, and the AWS provider keeps a Firehose access key in the Terraform state. Pass the token from a secret store, as the complete example does, and keep the state encrypted. To rotate it, issue a new token on the Guardian Sources page and apply with the new value.

## Development

CI runs `terraform fmt -check`, `terraform validate` and `tflint` (with the AWS ruleset) on the module and both examples.

## License

[MPL-2.0](LICENSE)
