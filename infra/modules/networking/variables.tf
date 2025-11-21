variable "aws_region" {
  type        = string
  description = "Región de AWS"
}

variable "project" {
  type        = string
  description = "Nombre del proyecto"
}

variable "environment" {
  type        = string
  description = "Entorno de despliegue (dev, prod, etc.)"
}

variable "vpc_cidr" {
  type        = string
  description = "Bloque CIDR para la VPC"
}

variable "azs" {
  type        = list(string)
  description = "Zonas de disponibilidad"
}

variable "public_subnets" {
  type        = list(string)
  description = "Lista de CIDRs para subredes públicas"
}

variable "private_subnets" {
  type        = list(string)
  description = "Lista de CIDRs para subredes privadas"
}

variable "database_subnets" {
  type        = list(string)
  description = "Lista de CIDRs para subredes de base de datos"
}

variable "single_nat_gateway" {
  type        = bool
  description = "Usar un solo NAT Gateway para ahorrar costos"
  default     = true
}

variable "tags_extra" {
  type        = map(string)
  description = "Etiquetas adicionales"
  default     = {}
}

variable "rds_port" {
  type        = number
  description = "Puerto de la base de datos (para reglas de SG)"
}

variable "rds_public_access" {
  type        = bool
  description = "Permitir acceso público a RDS (controlado por CIDR)"
  default     = false
}

variable "db_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs permitidos para acceso a RDS si es público"
  default     = []
}
