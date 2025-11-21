############################################
# RDS con terraform-aws-modules/rds/aws
############################################

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

  publicly_accessible    = var.rds_public_access
  multi_az               = var.rds_multi_az

  # ✔️ Aquí usas el SG ya existente del archivo 4-sg.tf
  vpc_security_group_ids = [aws_security_group.rds.id]

  create_db_subnet_group = true
  subnet_ids             = module.vpc.database_subnets

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

output "rds_endpoint" {
  value = module.db.db_instance_endpoint
}

output "rds_port" {
  value = module.db.db_instance_port
}

output "rds_arn" {
  value = module.db.db_instance_arn
}
