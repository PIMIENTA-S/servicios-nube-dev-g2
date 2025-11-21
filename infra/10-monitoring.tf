############################################
# MONITOREO: ALB, API GW, RDS
############################################

# ==========================
# ALB → obtener ARN suffix
# ==========================
data "aws_lb" "main" {
  arn = aws_lb.alb.arn
}

locals {
  alb_arn_suffix = data.aws_lb.main.arn_suffix

  # API Gateway
  apigw_id    = aws_api_gateway_rest_api.api.id
  apigw_stage = aws_api_gateway_stage.prod.stage_name
}

# ==========================
# RDS MONITORING
# ==========================

# Tu módulo RDS no tiene output "db_instance_id",
# por lo que debemos tomarlo del recurso real:
#data "aws_db_instance" "db" {
#  db_instance_identifier = module.db.db_instance_identifier
#}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${var.project}-${var.environment}-rds-free-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2000000000 # 2GB

  dimensions = {
    DBInstanceIdentifier = module.db.db_instance_identifier
  }

  alarm_description = "RDS free storage too low"
}


# ==========================
# ALB 5XX MONITORING
# ==========================

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project}-${var.environment}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5

  dimensions = {
    LoadBalancer = local.alb_arn_suffix
  }

  alarm_description = "ALB returning too many 5XX errors"
}

# ==========================
# API GATEWAY 5XX MONITORING
# ==========================

resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  alarm_name          = "${var.project}-${var.environment}-apigw-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 1

  dimensions = {
    ApiName = local.apigw_id
    Stage   = local.apigw_stage
  }

  alarm_description = "API Gateway returning 5XX errors"
}
