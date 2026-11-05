# terraform-aws-fsx-lustre

Terraform module for Amazon FSx for Lustre: scratch or persistent file systems, EFA support, optional S3 data repository link, backups and a Lustre-aware security group.

[![Validate](https://github.com/pankajrudrawar/terraform-aws-fsx-lustre/actions/workflows/validate.yml/badge.svg)](https://github.com/pankajrudrawar/terraform-aws-fsx-lustre/actions/workflows/validate.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
![Terraform](https://img.shields.io/badge/terraform-%E2%89%A5%201.5.7-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-module-FF9900)

## Features

- Scratch and persistent deployment types, with persistent-only settings ignored for scratch
- Elastic Fabric Adapter (EFA) and GPUDirect Storage support, with the self-referencing security group rules EFA needs
- Provisioned metadata performance for PERSISTENT_2 file systems
- Plan-time checks that reject unsupported combinations, such as EFA without PERSISTENT_2
- Optional S3 import and export paths with auto-import policy
- Automatic backups with retention and start time
- Security group preconfigured for Lustre ports (TCP 988 and 1018-1023) with CIDR and security-group sources
- Root squash and data repository event logging

## Usage

```hcl
module "fsx_lustre" {
  source = "github.com/pankajrudrawar/terraform-aws-fsx-lustre"

  name             = "example-lustre"
  storage_capacity = 2400
  subnet_ids       = [var.subnet_id]

  deployment_type             = "PERSISTENT_2"
  per_unit_storage_throughput = 250

  create_security_group              = true
  vpc_id                             = var.vpc_id
  security_group_allowed_cidr_blocks = var.client_cidr_blocks

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
```

A complete, runnable configuration is in [`examples/basic`](examples/basic). More examples: EFA and GPUDirect Storage in [`examples/efa`](examples/efa).

## Notes

- Lustre file systems are single-AZ, so `subnet_ids` takes exactly one subnet.
- Mount from a client: `sudo mount -t lustre <dns_name>@tcp:/<mount_name> /mnt/fsx`. Both values are module outputs.
- Valid `storage_capacity` and `per_unit_storage_throughput` values depend on the deployment and storage type. See the AWS FSx for Lustre documentation.
- EFA is chosen when the file system is created and cannot be changed later. Clients must run on EFA-capable instances and use the file system's security group. Supported Regions, instance types and capacity increments are listed in the AWS FSx for Lustre EFA documentation.
- This module needs AWS provider 6.0 or later. The other AWS modules in this collection work with 5.40 and later.

## Module reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.7 |
| aws | >= 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| create | Controls whether any resources are created by this module | `bool` | `true` | no |
| name | Name of the file system, used for the Name tag and the security group name | `string` | n/a | yes |
| storage_capacity | Storage capacity in GiB. Valid increments depend on `deployment_type` and `storage_type`, for example 1200 or multiples of 2400 for SSD | `number` | n/a | yes |
| subnet_ids | List containing exactly one subnet ID. Lustre file systems are single-AZ | `list(string)` | n/a | yes |
| deployment_type | Deployment type: `SCRATCH_1`, `SCRATCH_2`, `PERSISTENT_1` or `PERSISTENT_2` | `string` | `"PERSISTENT_2"` | no |
| per_unit_storage_throughput | Throughput in MB/s per TiB of storage. Required for persistent deployment types and ignored for scratch ones. Example values are 125, 250, 500 and 1000 for PERSISTENT_2 SSD | `number` | `125` | no |
| storage_type | Storage type: `SSD` or `HDD`. HDD is only valid for PERSISTENT_1 | `string` | `"SSD"` | no |
| drive_cache_type | Read cache for HDD file systems: `READ` or `NONE`. Ignored for SSD | `string` | `null` | no |
| data_compression_type | Data compression: `LZ4` or `NONE` | `string` | `"LZ4"` | no |
| file_system_type_version | Lustre version, for example `2.15`. Uses the service default when null | `string` | `null` | no |
| kms_key_id | ARN of the KMS key for encryption at rest. Only applies to persistent deployment types | `string` | `null` | no |
| import_path | S3 URI that is linked as the data repository, for example `s3://my-bucket/prefix` | `string` | `null` | no |
| export_path | S3 URI to which changes are exported. Defaults to `import_path` when null | `string` | `null` | no |
| imported_file_chunk_size | Stripe size in MiB for files imported from S3 | `number` | `null` | no |
| auto_import_policy | How the file system keeps in sync with the S3 bucket: `NEW`, `NEW_CHANGED` or `NEW_CHANGED_DELETED`. Requires `import_path` | `string` | `null` | no |
| weekly_maintenance_start_time | Preferred weekly maintenance window start in `d:HH:MM` UTC, where d is 1 (Monday) to 7 (Sunday) | `string` | `null` | no |
| automatic_backup_retention_days | Days to retain automatic backups, 0 to 90. Only applies to persistent deployment types. Use 0 to disable | `number` | `7` | no |
| daily_automatic_backup_start_time | Daily backup start time in `HH:MM` UTC. Only used when backups are enabled | `string` | `null` | no |
| copy_tags_to_backups | Whether to copy tags to backups. Only applies to persistent deployment types | `bool` | `true` | no |
| skip_final_backup | Whether to skip the final backup when the file system is destroyed | `bool` | `true` | no |
| final_backup_tags | Tags applied to the final backup. Only used when `skip_final_backup` is false | `map(string)` | `{}` | no |
| efa_enabled | Whether the file system supports Elastic Fabric Adapter (EFA) and GPUDirect Storage. Requires `deployment_type = "PERSISTENT_2"` and `metadata_configuration`, and can only be set when the file system is created | `bool` | `false` | no |
| metadata_configuration | Metadata performance settings for PERSISTENT_2 file systems. `mode` is `AUTOMATIC` or `USER_PROVISIONED`; `iops` only applies to `USER_PROVISIONED` | `object` | `null` | no |
| log_configuration | Data repository event logging. `level` is one of `WARN_ONLY`, `FAILURE_ONLY`, `ERROR_ONLY`, `WARN_ERROR` or `DISABLED`; `destination` is a CloudWatch Logs log group ARN | `object` | `null` | no |
| root_squash_configuration | Root squash settings. `root_squash` is `UID:GID`, and `no_squash_nids` lists client NIDs that are exempt | `object` | `null` | no |
| create_security_group | Whether to create a security group that allows Lustre traffic (TCP 988 and 1018-1023) | `bool` | `true` | no |
| security_group_name | Name of the security group. Defaults to `name` | `string` | `null` | no |
| security_group_description | Description of the security group | `string` | see `variables.tf` | no |
| vpc_id | ID of the VPC in which to create the security group. Required when `create_security_group` is true | `string` | `null` | no |
| security_group_allow_self_traffic | Whether members of the created security group may reach each other on the Lustre ports | `bool` | `true` | no |
| security_group_allowed_cidr_blocks | IPv4 CIDR blocks that may reach the file system on the Lustre ports | `list(string)` | `[]` | no |
| security_group_allowed_security_group_ids | Security group IDs of Lustre clients that may reach the file system on the Lustre ports | `list(string)` | `[]` | no |
| security_group_ids | Additional existing security group IDs to attach to the file system | `list(string)` | `[]` | no |
| tags | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| id | ID of the file system |
| arn | ARN of the file system |
| dns_name | DNS name of the file system, for example `fs-0123456789abcdef0.fsx.us-east-1.amazonaws.com` |
| mount_name | Mount name used by clients: `mount -t lustre <dns_name>@tcp:/<mount_name> /mnt/fsx` |
| network_interface_ids | IDs of the network interfaces created for the file system |
| vpc_id | VPC that the file system lives in |
| security_group_id | ID of the security group created by this module |
<!-- END_TF_DOCS -->

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first, and ask questions in [Discussions](https://github.com/pankajrudrawar/terraform-aws-fsx-lustre/discussions). Run `pre-commit run -a` before opening a pull request. It formats the code, validates it, runs TFLint and refreshes the reference tables above with terraform-docs.

Security problems should be reported privately. See [SECURITY.md](SECURITY.md).

## License

Apache 2.0. See [LICENSE](LICENSE).
