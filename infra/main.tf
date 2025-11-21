################################################################################
# CONFIGURACIÓN PRINCIPAL (ROOT MODULE)
#
# Este archivo orquesta todos los módulos de infraestructura.
################################################################################

# ------------------------------------------------------------------------------
# NETWORKING
# ------------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  project            = var.project
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  database_subnets   = var.database_subnets
  single_nat_gateway = var.single_nat_gateway
  tags_extra         = var.tags_extra
  rds_port           = var.rds_port
  rds_public_access  = var.rds_public_access
  db_allowed_cidrs   = var.db_allowed_cidrs
}

# ------------------------------------------------------------------------------
# STORAGE
# ------------------------------------------------------------------------------
module "storage" {
  source = "./modules/storage"

  project     = var.project
  environment = var.environment

  rds_engine                = var.rds_engine
  rds_engine_version        = var.rds_engine_version
  rds_instance_class        = var.rds_instance_class
  rds_db_name               = var.rds_db_name
  rds_username              = var.rds_username
  rds_port                  = var.rds_port
  rds_public_access         = var.rds_public_access
  rds_multi_az              = var.rds_multi_az
  rds_allocated_storage     = var.rds_allocated_storage
  rds_max_allocated_storage = var.rds_max_allocated_storage
  rds_backup_retention_days = var.rds_backup_retention_days
  rds_deletion_protection   = var.rds_deletion_protection
  rds_skip_final_snapshot   = var.rds_skip_final_snapshot

  vpc_security_group_ids = [module.networking.rds_sg_id]
  database_subnets       = module.networking.database_subnets
}

# ------------------------------------------------------------------------------
# COMPUTE
# ------------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  vpc_id          = module.networking.vpc_id
  public_subnets  = module.networking.public_subnets
  private_subnets = module.networking.private_subnets

  alb_sg_id    = module.networking.alb_sg_id
  web_sg_id    = module.networking.web_sg_id
  lambda_sg_id = module.networking.lambda_sg_id

  instance_type         = var.instance_type
  asg_desired           = var.asg_desired
  asg_max               = var.asg_max
  alb_health_check_path = var.alb_health_check_path

  lambda_runtime        = var.lambda_runtime
  lambda_architectures  = var.lambda_architectures
  lambda_timeout        = var.lambda_timeout
  lambda_memory         = var.lambda_memory
  log_retention_in_days = var.log_retention_in_days
  enable_lambda_tags    = var.enable_lambda_tags
  use_docker_packaging  = var.use_docker_packaging
  lambda_exec_role_arn  = var.lambda_exec_role_arn
  images_env            = var.images_env
  students_env          = var.students_env
  db_init_env           = var.db_init_env
  lambda_tags_extra     = var.lambda_tags_extra

  images_bucket = "${var.project}-${var.environment}-images-pimienta" # Hardcoded name match with storage module
}

# ------------------------------------------------------------------------------
# API
# ------------------------------------------------------------------------------
module "api" {
  source = "./modules/api"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  lambda_arns = module.compute.lambda_arns
  lambda_names = {
    images   = module.compute.lambda_functions.images.function_name
    students = module.compute.lambda_functions.students.function_name
  }
}

# ------------------------------------------------------------------------------
# MONITORING
# ------------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  project     = var.project
  environment = var.environment

  rds_instance_identifier = module.storage.rds_instance_identifier
  alb_arn_suffix          = module.compute.alb_arn_suffix
  apigw_id                = module.api.api_id
  apigw_stage             = module.api.stage_name
}

# ------------------------------------------------------------------------------
# APP CONFIG
# ------------------------------------------------------------------------------
module "app_config" {
  source = "./modules/app-config"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region

  rds_endpoint = module.storage.rds_endpoint
  rds_port     = module.storage.rds_port
  rds_db_name  = var.rds_db_name
  rds_username = var.rds_username

  api_id        = module.api.api_id
  stage_name    = module.api.stage_name
  api_key_value = module.api.api_key_value
  alb_dns_name  = module.compute.alb_dns_name
}
