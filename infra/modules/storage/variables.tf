variable "project" {
  type        = string
  description = "Nombre del proyecto"
}

variable "environment" {
  type        = string
  description = "Entorno de despliegue"
}

variable "rds_engine" {
  type    = string
  default = "postgres"
}

variable "rds_engine_version" {
  type    = string
  default = "16.3"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "rds_db_name" {
  type    = string
  default = "appdb"
}

variable "rds_username" {
  type    = string
  default = "appuser"
}

variable "rds_port" {
  type    = number
  default = 5432
}

variable "rds_public_access" {
  type    = bool
  default = false
}

variable "rds_multi_az" {
  type    = bool
  default = false
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = "IDs de los Security Groups para RDS"
}

variable "database_subnets" {
  type        = list(string)
  description = "IDs de las subredes de base de datos"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "rds_max_allocated_storage" {
  type    = number
  default = 100
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
