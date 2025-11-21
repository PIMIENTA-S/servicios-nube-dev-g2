output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Bloque CIDR de la VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnets" {
  description = "IDs de las subredes públicas"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "IDs de las subredes privadas"
  value       = module.vpc.private_subnets
}

output "database_subnets" {
  description = "IDs de las subredes de base de datos"
  value       = module.vpc.database_subnets
}

output "private_route_table_ids" {
  description = "IDs de las tablas de enrutamiento privadas"
  value       = module.vpc.private_route_table_ids
}

output "alb_sg_id" {
  description = "ID del Security Group del ALB"
  value       = aws_security_group.alb.id
}

output "web_sg_id" {
  description = "ID del Security Group de los servidores Web"
  value       = aws_security_group.web.id
}

output "lambda_sg_id" {
  description = "ID del Security Group de las Lambdas"
  value       = aws_security_group.lambdas.id
}

output "rds_sg_id" {
  description = "ID del Security Group de RDS"
  value       = aws_security_group.rds.id
}
