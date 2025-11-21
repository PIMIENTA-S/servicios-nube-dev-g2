################################################################################
# MÓDULO DE CONFIGURACIÓN DE APLICACIÓN (APP CONFIG)
#
# Este módulo almacena la configuración de la aplicación en SSM Parameter Store.
################################################################################

# Host / endpoint del RDS
resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project}/${var.environment}/db/host"
  type  = "String"
  value = var.rds_endpoint
}

# Puerto
resource "aws_ssm_parameter" "db_port" {
  name  = "/${var.project}/${var.environment}/db/port"
  type  = "String"
  value = tostring(var.rds_port)
}

# Nombre de base
resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project}/${var.environment}/db/name"
  type  = "String"
  value = var.rds_db_name
}

# Usuario
resource "aws_ssm_parameter" "db_user" {
  name  = "/${var.project}/${var.environment}/db/user"
  type  = "String"
  value = var.rds_username
}


# ############################################
# SSM params para URLs y API keys de la app
# ############################################

# Base URL de API Gateway
locals {
  api_base_url = "https://${var.api_id}.execute-api.${var.aws_region}.amazonaws.com/${var.stage_name}"
}

# --- URLs a tus endpoints ---
# /images (GET) -> Lambda "images"
resource "aws_ssm_parameter" "lambda_s3_url" {
  name  = "/${var.project}/${var.environment}/lambda/s3/url"
  type  = "String"
  value = "${local.api_base_url}/images"
}

# /students (POST) -> Lambda "students"
resource "aws_ssm_parameter" "lambda_db_url" {
  name  = "/${var.project}/${var.environment}/lambda/db/url"
  type  = "String"
  value = "${local.api_base_url}/students"
}

# --- API Keys ---
resource "aws_ssm_parameter" "lambda_s3_apikey" {
  name  = "/${var.project}/${var.environment}/lambda/s3/apikey"
  type  = "SecureString"
  value = var.api_key_value
}

resource "aws_ssm_parameter" "lambda_db_apikey" {
  name  = "/${var.project}/${var.environment}/lambda/db/apikey"
  type  = "SecureString"
  value = var.api_key_value
}

# --- Otros parámetros usados por tu user_data ---
# Ruta para stress
resource "aws_ssm_parameter" "stress_path" {
  name  = "/${var.project}/${var.environment}/stress/path"
  type  = "String"
  value = "/stress"
}

# URL del ALB
resource "aws_ssm_parameter" "alb_url" {
  name  = "/${var.project}/${var.environment}/alb/url"
  type  = "String"
  value = "http://${var.alb_dns_name}"
}
