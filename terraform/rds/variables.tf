variable "name" {
  description = "Instance identifier and name prefix for related resources"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets for the DB subnet group (2+ AZs)"
  type        = list(string)
}

variable "allowed_sg_ids" {
  description = "Security groups allowed to reach PostgreSQL (no CIDR ingress)"
  type        = list(string)
  default     = []
}

variable "engine_version" {
  type    = string
  default = "16.4"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.large"
}

variable "database_name" {
  type    = string
  default = "gisdb"
}

variable "master_username" {
  type    = string
  default = "gis_admin"
}

variable "allocated_storage_gb" {
  type    = number
  default = 100
}

variable "max_allocated_storage_gb" {
  description = "Storage autoscaling ceiling; 0 disables"
  type        = number
  default     = 500
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 14
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "work_mem_kb" {
  description = "work_mem in kB; spatial joins and sorts are memory-hungry"
  type        = string
  default     = "65536"
}

variable "monitoring_role_arn" {
  description = "IAM role for enhanced monitoring"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
