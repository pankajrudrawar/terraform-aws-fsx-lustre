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
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC that will host the file system"
  type        = string
}

variable "subnet_id" {
  description = "Subnet for the file system"
  type        = string
}

variable "client_cidr_blocks" {
  description = "CIDR blocks of Lustre clients"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

module "fsx_lustre" {
  source = "../.."

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

output "mount_command" {
  description = "Command to mount the file system on a client"
  value       = "sudo mount -t lustre ${module.fsx_lustre.dns_name}@tcp:/${module.fsx_lustre.mount_name} /mnt/fsx"
}
