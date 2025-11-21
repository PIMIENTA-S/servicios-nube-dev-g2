################################################################################
# MÓDULO DE CÓMPUTO (COMPUTE)
#
# Este módulo agrupa los recursos de procesamiento:
# - Funciones Lambda
# - Auto Scaling Group (ASG) con EC2
# - Application Load Balancer (ALB)
################################################################################

# ------------------------------------------------------------------------------
# LAMBDAS
# ------------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"

  tags = merge({
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }, var.lambda_tags_extra)

  # Imagen SAM para el empaquetado Docker
  sam_image = var.lambda_runtime == "python3.13" ? "public.ecr.aws/sam/build-python3.13:latest" : "public.ecr.aws/sam/build-python3.12:latest"
}

# IAM Role
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  count              = var.lambda_exec_role_arn == "" ? 1 : 0
  name               = "${local.name_prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.enable_lambda_tags ? local.tags : {}
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count      = var.lambda_exec_role_arn == "" ? 1 : 0
  role       = aws_iam_role.lambda_exec[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.lambda_exec_role_arn == "" ? 1 : 0
  role       = aws_iam_role.lambda_exec[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "images_s3_access" {
  count = var.lambda_exec_role_arn == "" ? 1 : 0

  name = "${local.name_prefix}-images-s3"
  role = aws_iam_role.lambda_exec[0].name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "ListBucket",
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = "arn:aws:s3:::${var.images_bucket}"
      },
      {
        Sid      = "ReadObjects",
        Effect   = "Allow",
        Action   = ["s3:GetObject"],
        Resource = "arn:aws:s3:::${var.images_bucket}/*"
      }
    ]
  })
}

locals {
  lambda_role_arn = element(concat(aws_iam_role.lambda_exec[*].arn, [var.lambda_exec_role_arn]), 0)
}

# Build directory
resource "null_resource" "ensure_build_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/build"
  }
  triggers = { always = timestamp() }
}

# Docker packaging (optional)
resource "null_resource" "images_pip" {
  triggers = { use = tostring(var.use_docker_packaging) }
  provisioner "local-exec" {
    when    = create
    command = var.use_docker_packaging ? "docker run --rm -v ${path.module}/lambdas/images_handler:/var/task ${local.sam_image} /bin/bash -lc 'if [ -f requirements.txt ]; then pip install -r requirements.txt -t /var/task; fi'" : "echo skip"
  }
}

resource "null_resource" "students_pip" {
  triggers = { use = tostring(var.use_docker_packaging) }
  provisioner "local-exec" {
    when    = create
    command = var.use_docker_packaging ? "docker run --rm -v ${path.module}/lambdas/students_writer:/var/task ${local.sam_image} /bin/bash -lc 'if [ -f requirements.txt ]; then pip install -r requirements.txt -t /var/task; fi'" : "echo skip"
  }
}

resource "null_resource" "db_init_pip" {
  triggers = { use = tostring(var.use_docker_packaging) }
  provisioner "local-exec" {
    when    = create
    command = var.use_docker_packaging ? "docker run --rm -v ${path.module}/lambdas/db_init:/var/task ${local.sam_image} /bin/bash -lc 'if [ -f requirements.txt ]; then pip install -r requirements.txt -t /var/task; fi'" : "echo skip"
  }
}

# ZIPs
data "archive_file" "images_zip" {
  depends_on  = [null_resource.ensure_build_dir, null_resource.images_pip]
  type        = "zip"
  source_dir  = "${path.module}/lambdas/images_handler"
  output_path = "${path.module}/build/images_handler.zip"
}

data "archive_file" "students_zip" {
  depends_on  = [null_resource.ensure_build_dir, null_resource.students_pip]
  type        = "zip"
  source_dir  = "${path.module}/lambdas/students_writer"
  output_path = "${path.module}/build/students_writer.zip"
}

data "archive_file" "db_init_zip" {
  depends_on  = [null_resource.ensure_build_dir, null_resource.db_init_pip]
  type        = "zip"
  source_dir  = "${path.module}/lambdas/db_init"
  output_path = "${path.module}/build/db_init.zip"
}

# Log Groups
resource "aws_cloudwatch_log_group" "images" {
  name              = "/aws/lambda/${local.name_prefix}-images-handler"
  retention_in_days = var.log_retention_in_days
  tags              = var.enable_lambda_tags ? local.tags : {}
}

resource "aws_cloudwatch_log_group" "students" {
  name              = "/aws/lambda/${local.name_prefix}-students-writer"
  retention_in_days = var.log_retention_in_days
  tags              = var.enable_lambda_tags ? local.tags : {}
}

resource "aws_cloudwatch_log_group" "dbinit" {
  name              = "/aws/lambda/${local.name_prefix}-db-init"
  retention_in_days = var.log_retention_in_days
  tags              = var.enable_lambda_tags ? local.tags : {}
}

# Lambda functions
locals {
  lambda_subnets = var.private_subnets
  lambda_sg_ids  = [var.lambda_sg_id]
}

resource "aws_lambda_function" "images" {
  function_name = "${local.name_prefix}-images-handler"
  role          = local.lambda_role_arn
  handler       = "app.handler"
  runtime       = var.lambda_runtime
  architectures = var.lambda_architectures
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  filename         = data.archive_file.images_zip.output_path
  source_code_hash = data.archive_file.images_zip.output_base64sha256

  dynamic "vpc_config" {
    for_each = length(local.lambda_subnets) > 0 ? [1] : []
    content {
      subnet_ids         = local.lambda_subnets
      security_group_ids = local.lambda_sg_ids
    }
  }

  environment {
    variables = merge(
      {
        S3_BUCKET = var.images_bucket
        S3_PREFIX = "images"
      },
      var.images_env
    )
  }

  tags       = var.enable_lambda_tags ? local.tags : {}
  depends_on = [aws_cloudwatch_log_group.images]
  publish    = true
}

resource "aws_lambda_function" "students" {
  function_name = "${local.name_prefix}-students-writer"
  role          = local.lambda_role_arn
  handler       = "app.handler"
  runtime       = var.lambda_runtime
  architectures = var.lambda_architectures
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  filename         = data.archive_file.students_zip.output_path
  source_code_hash = data.archive_file.students_zip.output_base64sha256

  dynamic "vpc_config" {
    for_each = length(local.lambda_subnets) > 0 ? [1] : []
    content {
      subnet_ids         = local.lambda_subnets
      security_group_ids = local.lambda_sg_ids
    }
  }

  environment { variables = var.students_env }

  tags       = var.enable_lambda_tags ? local.tags : {}
  depends_on = [aws_cloudwatch_log_group.students]
  publish    = true
}

resource "aws_lambda_function" "db_init" {
  function_name = "${local.name_prefix}-db-init"
  role          = local.lambda_role_arn
  handler       = "app.handler"
  runtime       = var.lambda_runtime
  architectures = var.lambda_architectures
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  filename         = data.archive_file.db_init_zip.output_path
  source_code_hash = data.archive_file.db_init_zip.output_base64sha256

  dynamic "vpc_config" {
    for_each = length(local.lambda_subnets) > 0 ? [1] : []
    content {
      subnet_ids         = local.lambda_subnets
      security_group_ids = local.lambda_sg_ids
    }
  }

  environment { variables = var.db_init_env }

  tags       = var.enable_lambda_tags ? local.tags : {}
  depends_on = [aws_cloudwatch_log_group.dbinit]
  publish    = true
}

# ------------------------------------------------------------------------------
# ALB & ASG
# ------------------------------------------------------------------------------

# AMI Amazon Linux 2023
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Rol para SSM (sin abrir SSH)
resource "aws_iam_role" "ec2_role" {
  name = "${var.project}-${var.environment}-ec2-ssm"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}


resource "aws_launch_template" "web" {
  name_prefix   = "${var.project}-${var.environment}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile { name = aws_iam_instance_profile.ec2_profile.name }
  vpc_security_group_ids = [var.web_sg_id]


  user_data = base64encode(file("${path.module}/script/app.sh"))


  block_device_mappings {
    device_name = "/dev/xvda" # raíz
    ebs {
      volume_size           = 40
      volume_type           = "gp3"
      delete_on_termination = true
      iops                  = 3000
      throughput            = 125
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project}-${var.environment}-web" }
  }
}

resource "aws_lb" "alb" {
  name               = "${var.project}-${var.environment}-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnets
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.project}-${var.environment}-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = var.alb_health_check_path
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_autoscaling_group" "asg" {
  name                = "${var.project}-${var.environment}-asg"
  desired_capacity    = var.asg_desired
  max_size            = var.asg_max
  min_size            = 1
  vpc_zone_identifier = var.private_subnets

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]
  health_check_type = "EC2"

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 90
      instance_warmup        = 60
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-web"
    propagate_at_launch = true
  }
}
