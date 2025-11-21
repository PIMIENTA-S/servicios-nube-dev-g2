################################################################################
# MÓDULO DE ALMACENAMIENTO (STORAGE)
#
# Este módulo agrupa los recursos de persistencia de datos:
# - Bucket S3 para imágenes
# - Base de datos RDS (PostgreSQL)
################################################################################

# ------------------------------------------------------------------------------
# S3 BUCKET
# ------------------------------------------------------------------------------
module "images_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.8.2"

  bucket = "${var.project}-${var.environment}-images-pimienta"

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  acl                      = null

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  force_destroy = false

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = { sse_algorithm = "AES256" }
    }
  }

  versioning = { enabled = true }

  lifecycle_rule = [
    {
      id                            = "noncurrent-tiering"
      enabled                       = true
      noncurrent_version_expiration = { noncurrent_days = 180 }
      noncurrent_version_transition = [
        { noncurrent_days = 30, storage_class = "STANDARD_IA" },
        { noncurrent_days = 90, storage_class = "GLACIER_IR" }
      ]
    }
  ]

  # Enforce TLS
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "DenyInsecureTransport",
      Effect    = "Deny",
      Principal = "*",
      Action    = "s3:*",
      Resource = [
        "arn:aws:s3:::${var.project}-${var.environment}-images-pimienta",
        "arn:aws:s3:::${var.project}-${var.environment}-images-pimienta/*"
      ],
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  tags = { Purpose = "nexacloud-images" }
}

# ------------------------------------------------------------------------------
# RDS
# ------------------------------------------------------------------------------
resource "random_password" "rds_master" {
  length  = 20
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "aws_ssm_parameter" "db_master_password" {
  name  = "/${var.project}/${var.environment}/db/master_password"
  type  = "SecureString"
  value = random_password.rds_master.result
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.13.1"

  identifier = "${var.project}-${var.environment}"

  engine         = var.rds_engine
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  db_name  = var.rds_db_name
  username = var.rds_username
  password = random_password.rds_master.result

  port = tostring(var.rds_port)

  publicly_accessible = var.rds_public_access
  multi_az            = var.rds_multi_az

  vpc_security_group_ids = var.vpc_security_group_ids

  create_db_subnet_group = true
  subnet_ids             = var.database_subnets

  storage_type          = "gp3"
  storage_encrypted     = true
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage

  enabled_cloudwatch_logs_exports = var.rds_engine == "postgres" ? ["postgresql"] : ["slowquery"]
  backup_retention_period         = var.rds_backup_retention_days

  deletion_protection = var.rds_deletion_protection
  skip_final_snapshot = var.rds_skip_final_snapshot
  apply_immediately   = true

  manage_master_user_password  = false
  performance_insights_enabled = false

  create_db_parameter_group = false
  create_db_option_group    = false
}
