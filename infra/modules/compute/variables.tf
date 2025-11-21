variable "project" {
  type        = string
  description = "Nombre del proyecto"
}

variable "environment" {
  type        = string
  description = "Entorno de despliegue"
}

variable "aws_region" {
  type        = string
  description = "Región de AWS"
}

variable "vpc_id" {
  type        = string
  description = "ID de la VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "IDs de subredes públicas (para ALB)"
}

variable "private_subnets" {
  type        = list(string)
  description = "IDs de subredes privadas (para Lambdas y EC2)"
}

variable "alb_sg_id" {
  type        = string
  description = "ID del Security Group del ALB"
}

variable "web_sg_id" {
  type        = string
  description = "ID del Security Group de Web"
}

variable "lambda_sg_id" {
  type        = string
  description = "ID del Security Group de Lambdas"
}

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
  type    = string
  default = "python3.12"
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
  type    = bool
  default = false
}

variable "lambda_exec_role_arn" {
  type    = string
  default = ""
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

variable "images_bucket" {
  type        = string
  description = "Nombre del bucket de imágenes"
}
