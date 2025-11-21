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

variable "rds_endpoint" {
  type        = string
  description = "Endpoint de RDS"
}

variable "rds_port" {
  type        = number
  description = "Puerto de RDS"
}

variable "rds_db_name" {
  type        = string
  description = "Nombre de la base de datos"
}

variable "rds_username" {
  type        = string
  description = "Usuario de la base de datos"
}

variable "api_id" {
  type        = string
  description = "ID del API Gateway"
}

variable "stage_name" {
  type        = string
  description = "Stage del API Gateway"
}

variable "api_key_value" {
  type        = string
  description = "Valor de la API Key"
  sensitive   = true
}

variable "alb_dns_name" {
  type        = string
  description = "DNS Name del ALB"
}
