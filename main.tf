locals {
  create_security_group = var.create && var.create_security_group
  security_group_name   = coalesce(var.security_group_name, var.name)
  is_persistent         = startswith(var.deployment_type, "PERSISTENT")
  backups_enabled       = local.is_persistent && try(var.automatic_backup_retention_days > 0, false)

  security_group_ids = concat(
    local.create_security_group ? [aws_security_group.this[0].id] : [],
    var.security_group_ids,
  )

  # Ports used by Lustre clients and servers
  lustre_ports = {
    gateway = { from = 988, to = 988 }
    osts    = { from = 1018, to = 1023 }
  }

  cidr_ingress_rules = local.create_security_group ? merge([
    for ci, cidr in var.security_group_allowed_cidr_blocks : {
      for pk, pr in local.lustre_ports : "cidr${ci}-${pk}" => {
        cidr = cidr
        from = pr.from
        to   = pr.to
      }
    }
  ]...) : {}

  sg_ingress_rules = local.create_security_group ? merge([
    for si, sg_id in var.security_group_allowed_security_group_ids : {
      for pk, pr in local.lustre_ports : "sg${si}-${pk}" => {
        sg_id = sg_id
        from  = pr.from
        to    = pr.to
      }
    }
  ]...) : {}
}

################################################################################
# File system
################################################################################

resource "aws_fsx_lustre_file_system" "this" {
  count = var.create ? 1 : 0

  storage_capacity            = var.storage_capacity
  subnet_ids                  = var.subnet_ids
  deployment_type             = var.deployment_type
  per_unit_storage_throughput = local.is_persistent ? var.per_unit_storage_throughput : null
  storage_type                = var.storage_type
  drive_cache_type            = var.storage_type == "HDD" ? var.drive_cache_type : null
  data_compression_type       = var.data_compression_type
  file_system_type_version    = var.file_system_type_version
  efa_enabled                 = var.efa_enabled
  kms_key_id                  = local.is_persistent ? var.kms_key_id : null
  security_group_ids          = local.security_group_ids

  import_path              = var.import_path
  export_path              = var.export_path
  imported_file_chunk_size = var.imported_file_chunk_size
  auto_import_policy       = var.auto_import_policy

  weekly_maintenance_start_time     = var.weekly_maintenance_start_time
  automatic_backup_retention_days   = local.is_persistent ? var.automatic_backup_retention_days : null
  daily_automatic_backup_start_time = local.backups_enabled ? var.daily_automatic_backup_start_time : null
  copy_tags_to_backups              = local.is_persistent ? var.copy_tags_to_backups : null
  skip_final_backup                 = var.skip_final_backup
  final_backup_tags                 = var.skip_final_backup ? null : var.final_backup_tags

  dynamic "log_configuration" {
    for_each = var.log_configuration != null ? [var.log_configuration] : []

    content {
      level       = log_configuration.value.level
      destination = log_configuration.value.destination
    }
  }

  dynamic "metadata_configuration" {
    for_each = var.metadata_configuration != null ? [var.metadata_configuration] : []

    content {
      mode = metadata_configuration.value.mode
      iops = metadata_configuration.value.iops
    }
  }

  dynamic "root_squash_configuration" {
    for_each = var.root_squash_configuration != null ? [var.root_squash_configuration] : []

    content {
      root_squash    = root_squash_configuration.value.root_squash
      no_squash_nids = root_squash_configuration.value.no_squash_nids
    }
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = !var.efa_enabled || var.deployment_type == "PERSISTENT_2"
      error_message = "efa_enabled requires deployment_type = \"PERSISTENT_2\"."
    }

    precondition {
      condition     = !var.efa_enabled || var.metadata_configuration != null
      error_message = "efa_enabled requires metadata_configuration to be set."
    }

    precondition {
      condition     = var.metadata_configuration == null || var.deployment_type == "PERSISTENT_2"
      error_message = "metadata_configuration is only supported with deployment_type = \"PERSISTENT_2\"."
    }
  }
}

################################################################################
# Security group
################################################################################

resource "aws_security_group" "this" {
  count = local.create_security_group ? 1 : 0

  name        = local.security_group_name
  description = var.security_group_description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = local.security_group_name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "self" {
  for_each = local.create_security_group && var.security_group_allow_self_traffic ? local.lustre_ports : {}

  security_group_id            = aws_security_group.this[0].id
  description                  = "Lustre ${each.key} from members of this security group"
  ip_protocol                  = "tcp"
  from_port                    = each.value.from
  to_port                      = each.value.to
  referenced_security_group_id = aws_security_group.this[0].id

  tags = merge(var.tags, { Name = "${local.security_group_name}-self-${each.key}" })
}

resource "aws_vpc_security_group_ingress_rule" "cidr" {
  for_each = local.cidr_ingress_rules

  security_group_id = aws_security_group.this[0].id
  description       = "Lustre from ${each.value.cidr}"
  ip_protocol       = "tcp"
  from_port         = each.value.from
  to_port           = each.value.to
  cidr_ipv4         = each.value.cidr

  tags = merge(var.tags, { Name = "${local.security_group_name}-${each.key}" })
}

resource "aws_vpc_security_group_ingress_rule" "sg" {
  for_each = local.sg_ingress_rules

  security_group_id            = aws_security_group.this[0].id
  description                  = "Lustre from client security group"
  ip_protocol                  = "tcp"
  from_port                    = each.value.from
  to_port                      = each.value.to
  referenced_security_group_id = each.value.sg_id

  tags = merge(var.tags, { Name = "${local.security_group_name}-${each.key}" })
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  count = local.create_security_group ? 1 : 0

  security_group_id = aws_security_group.this[0].id
  description       = "Allow all outbound IPv4 traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "${local.security_group_name}-all-ipv4" })
}

# EFA traffic is not routed, so the security group must allow all traffic to and from itself
resource "aws_vpc_security_group_ingress_rule" "efa_self" {
  count = local.create_security_group && var.efa_enabled ? 1 : 0

  security_group_id            = aws_security_group.this[0].id
  description                  = "EFA: all inbound traffic from members of this security group"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.this[0].id

  tags = merge(var.tags, { Name = "${local.security_group_name}-efa-self-in" })
}

resource "aws_vpc_security_group_egress_rule" "efa_self" {
  count = local.create_security_group && var.efa_enabled ? 1 : 0

  security_group_id            = aws_security_group.this[0].id
  description                  = "EFA: all outbound traffic to members of this security group"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.this[0].id

  tags = merge(var.tags, { Name = "${local.security_group_name}-efa-self-out" })
}
