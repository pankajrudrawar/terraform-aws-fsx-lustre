terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS Region. EFA-enabled FSx for Lustre is not available in every Region, so check the AWS documentation"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC that will host the file system"
  type        = string
}

variable "subnet_id" {
  description = "Subnet for the file system. EFA clients should run in the same Availability Zone"
  type        = string
}

variable "storage_capacity" {
  description = "Storage capacity in GiB. EFA-enabled file systems have their own capacity increments, so check the AWS documentation"
  type        = number
}

variable "per_unit_storage_throughput" {
  description = "Throughput in MB/s per TiB. Check the AWS documentation for the values supported with EFA"
  type        = number
}

variable "metadata_iops" {
  description = "Provisioned metadata IOPS"
  type        = number
}

module "fsx_lustre_efa" {
  source = "../.."

  name             = "example-lustre-efa"
  storage_capacity = var.storage_capacity
  subnet_ids       = [var.subnet_id]

  deployment_type             = "PERSISTENT_2"
  per_unit_storage_throughput = var.per_unit_storage_throughput
  efa_enabled                 = true

  metadata_configuration = {
    mode = "USER_PROVISIONED"
    iops = var.metadata_iops
  }

  # The module adds the self-referencing rules that EFA needs.
  # Attach this same security group to the EFA-capable client instances.
  create_security_group = true
  vpc_id                = var.vpc_id

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "security_group_id" {
  description = "Attach this security group to EFA-capable clients"
  value       = module.fsx_lustre_efa.security_group_id
}

output "mount_command" {
  description = "Command to mount the file system on a client"
  value       = "sudo mount -t lustre ${module.fsx_lustre_efa.dns_name}@tcp:/${module.fsx_lustre_efa.mount_name} /mnt/fsx"
}
