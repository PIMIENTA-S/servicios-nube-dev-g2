################################################################################
# OUTPUTS GLOBALES
################################################################################

output "alb_dns_name" {
  description = "DNS del Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "api_invoke_url" {
  description = "URL de invocación del API Gateway"
  value       = module.api.api_invoke_url
}

output "rds_endpoint" {
  description = "Endpoint de la base de datos RDS"
  value       = module.storage.rds_endpoint
}
