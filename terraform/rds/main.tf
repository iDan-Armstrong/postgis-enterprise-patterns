# Terraform module: PostgreSQL + PostGIS on RDS, sized for an enterprise GIS backend.
#
# module "gis_db" {
#   source            = "./terraform/rds"
#   name              = "gisdb-prod"
#   vpc_id            = var.vpc_id
#   subnet_ids        = var.private_subnet_ids
#   allowed_sg_ids    = [module.app.security_group_id]
#   instance_class    = "db.r6g.large"
#   multi_az          = true
# }

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  vpc_id      = var.vpc_id
  description = "PostgreSQL access for ${var.name}"

  lifecycle {
    create_before_destroy = true
  }
}

# One rule per allowed SG: no CIDR ingress, ever. The database is reachable
# only from workloads that present the right security group.
resource "aws_vpc_security_group_ingress_rule" "from_apps" {
  for_each                     = toset(var.allowed_sg_ids)
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = each.value
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# GIS workloads hold connections open (ArcGIS SDE, map services), and spatial
# queries benefit from more work_mem than the engine default.
resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-pg16-"
  family      = "postgres16"

  parameter {
    name  = "work_mem"
    value = var.work_mem_kb
  }
  parameter {
    name  = "random_page_cost"
    value = "1.1" # SSD storage; default 4.0 biases the planner away from indexes
  }
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username
  # master password lives in Secrets Manager, never in state or variables
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  backup_retention_period   = var.backup_retention_days
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name}-final"

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = var.monitoring_role_arn

  apply_immediately = false

  tags = var.tags
}
