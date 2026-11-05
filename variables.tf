variable "create" {
  description = "Controls whether any resources are created by this module"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the file system, used for the Name tag and the security group name"
  type        = string
}

variable "storage_capacity" {
  description = "Storage capacity in GiB. Valid increments depend on `deployment_type` and `storage_type`, for example 1200 or multiples of 2400 for SSD"
  type        = number
}

variable "subnet_ids" {
  description = "List containing exactly one subnet ID. Lustre file systems are single-AZ"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) == 1
    error_message = "FSx for Lustre requires exactly one subnet ID."
  }
}

variable "deployment_type" {
  description = "Deployment type: `SCRATCH_1`, `SCRATCH_2`, `PERSISTENT_1` or `PERSISTENT_2`"
  type        = string
  default     = "PERSISTENT_2"

  validation {
    condition     = contains(["SCRATCH_1", "SCRATCH_2", "PERSISTENT_1", "PERSISTENT_2"], var.deployment_type)
    error_message = "deployment_type must be SCRATCH_1, SCRATCH_2, PERSISTENT_1 or PERSISTENT_2."
  }
}

variable "per_unit_storage_throughput" {
  description = "Throughput in MB/s per TiB of storage. Required for persistent deployment types and ignored for scratch ones. Example values are 125, 250, 500 and 1000 for PERSISTENT_2 SSD"
  type        = number
  default     = 125
}

variable "storage_type" {
  description = "Storage type: `SSD` or `HDD`. HDD is only valid for PERSISTENT_1"
  type        = string
  default     = "SSD"
}

variable "drive_cache_type" {
  description = "Read cache for HDD file systems: `READ` or `NONE`. Ignored for SSD"
  type        = string
  default     = null
}

variable "data_compression_type" {
  description = "Data compression: `LZ4` or `NONE`"
  type        = string
  default     = "LZ4"
}

variable "file_system_type_version" {
  description = "Lustre version, for example `2.15`. Uses the service default when null"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "ARN of the KMS key for encryption at rest. Only applies to persistent deployment types"
  type        = string
  default     = null
}

variable "import_path" {
  description = "S3 URI that is linked as the data repository, for example `s3://my-bucket/prefix`"
  type        = string
  default     = null
}

variable "export_path" {
  description = "S3 URI to which changes are exported. Defaults to `import_path` when null"
  type        = string
  default     = null
}

variable "imported_file_chunk_size" {
  description = "Stripe size in MiB for files imported from S3"
  type        = number
  default     = null
}

variable "auto_import_policy" {
  description = "How the file system keeps in sync with the S3 bucket: `NEW`, `NEW_CHANGED` or `NEW_CHANGED_DELETED`. Requires `import_path`"
  type        = string
  default     = null
}

variable "weekly_maintenance_start_time" {
  description = "Preferred weekly maintenance window start in `d:HH:MM` UTC, where d is 1 (Monday) to 7 (Sunday)"
  type        = string
  default     = null
}

variable "automatic_backup_retention_days" {
  description = "Days to retain automatic backups, 0 to 90. Only applies to persistent deployment types. Use 0 to disable"
  type        = number
  default     = 7
}

variable "daily_automatic_backup_start_time" {
  description = "Daily backup start time in `HH:MM` UTC. Only used when backups are enabled"
  type        = string
  default     = null
}

variable "copy_tags_to_backups" {
  description = "Whether to copy tags to backups. Only applies to persistent deployment types"
  type        = bool
  default     = true
}

variable "skip_final_backup" {
  description = "Whether to skip the final backup when the file system is destroyed"
  type        = bool
  default     = true
}

variable "final_backup_tags" {
  description = "Tags applied to the final backup. Only used when `skip_final_backup` is false"
  type        = map(string)
  default     = {}
}

variable "log_configuration" {
  description = "Data repository event logging. `level` is one of `WARN_ONLY`, `FAILURE_ONLY`, `ERROR_ONLY`, `WARN_ERROR` or `DISABLED`; `destination` is a CloudWatch Logs log group ARN"
  type = object({
    level       = string
    destination = optional(string)
  })
  default = null
}

variable "root_squash_configuration" {
  description = "Root squash settings. `root_squash` is `UID:GID`, and `no_squash_nids` lists client NIDs that are exempt"
  type = object({
    root_squash    = optional(string)
    no_squash_nids = optional(list(string))
  })
  default = null
}

################################################################################
# Security group
################################################################################

variable "create_security_group" {
  description = "Whether to create a security group that allows Lustre traffic (TCP 988 and 1018-1023)"
  type        = bool
  default     = true
}

variable "security_group_name" {
  description = "Name of the security group. Defaults to `name`"
  type        = string
  default     = null
}

variable "security_group_description" {
  description = "Description of the security group"
  type        = string
  default     = "Security group for the FSx for Lustre file system"
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the security group. Required when `create_security_group` is true"
  type        = string
  default     = null
}

variable "security_group_allow_self_traffic" {
  description = "Whether members of the created security group may reach each other on the Lustre ports"
  type        = bool
  default     = true
}

variable "security_group_allowed_cidr_blocks" {
  description = "IPv4 CIDR blocks that may reach the file system on the Lustre ports"
  type        = list(string)
  default     = []
}

variable "security_group_allowed_security_group_ids" {
  description = "Security group IDs of Lustre clients that may reach the file system on the Lustre ports"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Additional existing security group IDs to attach to the file system"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
