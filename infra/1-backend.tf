################################################################################
# CONFIGURACIÓN DEL BACKEND
#
# Este archivo configura el backend para almacenar el estado de Terraform.
# Utiliza un bucket de S3 para almacenar el archivo de estado de forma remota,
# permitiendo la colaboración y el bloqueo de estado (si DynamoDB está configurado).
#
# Backend:
# - s3: Almacena el estado en el bucket 'tfstate-serviciosnube-angel-2025'.
################################################################################

terraform {
  backend "s3" {
    bucket       = "tfstate-serviciosnube-angel-2025"
    key          = "nube/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    profile      = "terraform-prod"
  }
}
