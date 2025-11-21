############################################
# Variables específicas de RDS
############################################

variable "rds_engine" {
  type        = string
  default     = "postgres"
}

variable "rds_engine_version" {
  type        = string
  default     = "16.3"
}

variable "rds_instance_class" {
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_db_name" {
  type        = string
  default     = "appdb"
}

variable "rds_username" {
  type        = string
  default     = "appuser"
}

variable "rds_allocated_storage" {
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  type        = number
  default     = 100
}

variable "rds_backup_retention_days" {
  type    = number
  default = 7
}

variable "rds_deletion_protection" {
  type    = bool
  default = false
}

variable "rds_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "rds_port" {
  type    = number
  default = 9876
}

# 🚫 VARIABLES ELIMINADAS:
# - rds_subnet_ids
# - rds_vpc_security_group_ids
