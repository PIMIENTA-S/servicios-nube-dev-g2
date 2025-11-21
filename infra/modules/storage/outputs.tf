output "rds_endpoint" {
  value = module.db.db_instance_endpoint
}

output "rds_port" {
  value = module.db.db_instance_port
}

output "rds_arn" {
  value = module.db.db_instance_arn
}

output "rds_instance_identifier" {
  value = module.db.db_instance_identifier
}

output "images_bucket_id" {
  value = module.images_bucket.s3_bucket_id
}

output "images_bucket_arn" {
  value = module.images_bucket.s3_bucket_arn
}
