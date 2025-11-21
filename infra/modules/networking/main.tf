################################################################################
# MÓDULO DE RED (NETWORKING)
#
# Este módulo agrupa todos los recursos relacionados con la red:
# - VPC (Virtual Private Cloud)
# - Subredes, Tablas de Rutas, NAT Gateway
# - Endpoints de VPC (SSM, S3, etc.)
# - Grupos de Seguridad (Security Groups)
################################################################################

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.5.0"

  name = "${var.project}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs              = var.azs
  public_subnets   = var.public_subnets   # ALB
  private_subnets  = var.private_subnets  # Lambdas/EC2
  database_subnets = var.database_subnets # RDS

  create_database_subnet_group = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  create_igw         = true
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  # Etiquetas
  tags = merge({
    "Component" = "networking"
  }, var.tags_extra)
}

# ------------------------------------------------------------------------------
# VPC ENDPOINTS
# ------------------------------------------------------------------------------
locals {
  vpce_subnets = module.vpc.private_subnets
}

# SG para endpoints interface (HTTPS desde la VPC)
resource "aws_security_group" "vpce" {
  name   = "${var.project}-${var.environment}-vpce-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Interface endpoints
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnets
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnets
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnets
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnets
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnets
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true
}

# Endpoint (Gateway) para S3 en tablas de ruteo privadas
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}

# ------------------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------------------

# ALB
resource "aws_security_group" "alb" {
  name   = "${var.project}-${var.environment}-alb-sg"
  vpc_id = module.vpc.vpc_id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Public HTTP"
  }

  # HTTPS (opcional si tienes cert en el ALB)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Public HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-alb-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# EC2 web (detrás del ALB, app en 3000)
resource "aws_security_group" "web" {
  name   = "${var.project}-${var.environment}-web-sg"
  vpc_id = module.vpc.vpc_id

  # Solo el ALB puede llegar al puerto 3000
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Traffic from ALB to app port 3000"
  }

  # Sin SSH (usa SSM)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-web-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# Lambdas en VPC
resource "aws_security_group" "lambdas" {
  name   = "${var.project}-${var.environment}-lambda-sg"
  vpc_id = module.vpc.vpc_id

  # Egresos abiertos (la SG de destino controla el ingreso)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-lambda-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# RDS (puerto tomado de var.rds_port) - recibe de Lambdas y EC2 web
resource "aws_security_group" "rds" {
  name   = "${var.project}-${var.environment}-rds-sg"
  vpc_id = module.vpc.vpc_id

  # Interno desde lambdas y web
  ingress {
    from_port       = var.rds_port
    to_port         = var.rds_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lambdas.id, aws_security_group.web.id]
    description     = "DB access from Lambdas and Web"
  }

  # Opcional: acceso externo restringido si rds_public_access=true
  dynamic "ingress" {
    for_each = var.rds_public_access ? var.db_allowed_cidrs : []
    content {
      from_port   = var.rds_port
      to_port     = var.rds_port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "External allowed CIDR to RDS"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-rds-sg"
    Project     = var.project
    Environment = var.environment
  }
}
