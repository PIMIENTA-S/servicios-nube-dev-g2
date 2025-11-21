################################################################################
# VARIABLES GLOBALES
#
# Este archivo define todas las variables de entrada para el proyecto.
################################################################################

variable "aws_region" {
  type        = string
  description = "Región de AWS"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "Perfil de AWS"
  default     = "terraform-prod"
}

variable "project" {
  type    = string
  default = "servicios-nube"
}

variable "environment" {
  type    = string
  default = "dev"
}

# -------- VPC --------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "database_subnets" {
  type    = list(string)
  default = ["10.0.201.0/24", "10.0.202.0/24"]
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

# -------- RDS --------
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

variable "db_allowed_cidrs" {
  description = "CIDRs permitidos a RDS si rds_public_access=true"
  type        = list(string)
  default     = []
}

variable "rds_multi_az" {
  type    = bool
  default = false
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

# -------- COMPUTE (ALB/ASG/Lambda) --------
variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "asg_desired" {
  type    = number
  default = 2
}

variable "asg_max" {
  type    = number
  default = 5
}

variable "alb_health_check_path" {
  type    = string
  default = "/"
}

variable "lambda_runtime" {
  type        = string
  default     = "python3.12"
  description = "Runtime de las Lambdas"
}

variable "lambda_architectures" {
  type    = list(string)
  default = ["x86_64"]
}

variable "lambda_timeout" {
  type    = number
  default = 30
}

variable "lambda_memory" {
  type    = number
  default = 256
}

variable "log_retention_in_days" {
  type    = number
  default = 14
}

variable "enable_lambda_tags" {
  type    = bool
  default = true
}

variable "use_docker_packaging" {
  type        = bool
  default     = false
  description = "Instala requirements.txt usando Docker"
}

variable "lambda_exec_role_arn" {
  type        = string
  default     = ""
  description = "ARN de un IAM Role existente para Lambda"
}

variable "images_env" {
  type    = map(string)
  default = {}
}

variable "students_env" {
  type    = map(string)
  default = {}
}

variable "db_init_env" {
  type    = map(string)
  default = {}
}

variable "lambda_tags_extra" {
  type    = map(string)
  default = {}
}

# -------- Observability --------
variable "alert_email" {
  type        = string
  description = "Email para suscripción SNS (alarmas)"
  default     = "marhernandezpa@unal.edu.co"
}

# -------- General --------
variable "tags_extra" {
  type    = map(string)
  default = {}
}
