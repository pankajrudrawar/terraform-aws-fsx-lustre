output "id" {
  description = "ID of the file system"
  value       = try(aws_fsx_lustre_file_system.this[0].id, null)
}

output "arn" {
  description = "ARN of the file system"
  value       = try(aws_fsx_lustre_file_system.this[0].arn, null)
}

output "dns_name" {
  description = "DNS name of the file system, for example `fs-0123456789abcdef0.fsx.us-east-1.amazonaws.com`"
  value       = try(aws_fsx_lustre_file_system.this[0].dns_name, null)
}

output "mount_name" {
  description = "Mount name used by clients: `mount -t lustre <dns_name>@tcp:/<mount_name> /mnt/fsx`"
  value       = try(aws_fsx_lustre_file_system.this[0].mount_name, null)
}

output "network_interface_ids" {
  description = "IDs of the network interfaces created for the file system"
  value       = try(aws_fsx_lustre_file_system.this[0].network_interface_ids, [])
}

output "vpc_id" {
  description = "VPC that the file system lives in"
  value       = try(aws_fsx_lustre_file_system.this[0].vpc_id, null)
}

output "security_group_id" {
  description = "ID of the security group created by this module"
  value       = try(aws_security_group.this[0].id, null)
}
