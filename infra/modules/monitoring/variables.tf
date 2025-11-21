variable "project" {
  type        = string
  description = "Nombre del proyecto"
}

variable "environment" {
  type        = string
  description = "Entorno de despliegue"
}

variable "rds_instance_identifier" {
  type        = string
  description = "Identificador de la instancia RDS"
}

variable "alb_arn_suffix" {
  type        = string
  description = "Sufijo del ARN del ALB"
}

variable "apigw_id" {
  type        = string
  description = "ID del API Gateway"
}

variable "apigw_stage" {
  type        = string
  description = "Stage del API Gateway"
}
