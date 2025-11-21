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

variable "lambda_arns" {
  type        = map(string)
  description = "Mapa de ARNs de las funciones Lambda"
}

variable "lambda_names" {
  type        = map(string)
  description = "Mapa de nombres de las funciones Lambda"
}
