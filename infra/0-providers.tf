################################################################################
# CONFIGURACIÓN DE PROVEEDORES
#
# Este archivo configura los proveedores de Terraform requeridos para el proyecto.
# Especifica la versión requerida de Terraform y el proveedor de AWS.
#
# Proveedores:
# - hashicorp/aws: Proveedor principal para interactuar con los servicios de AWS.
################################################################################

terraform {
  required_version = ">= 1.13.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.19.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Owner       = "apimienta@unal.edu.co"
      ManagedBy   = "terraform"
      Project     = var.project
      Environment = var.environment
    }
  }
}
