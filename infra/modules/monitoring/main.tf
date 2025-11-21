################################################################################
# MÓDULO DE MONITOREO (MONITORING)
#
# Este módulo define las alarmas de CloudWatch para monitorear la salud de la infraestructura.
################################################################################

# ==========================
# RDS MONITORING
# ==========================

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
    DBInstanceIdentifier = var.rds_instance_identifier
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
    LoadBalancer = var.alb_arn_suffix
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
    ApiName = var.apigw_id
    Stage   = var.apigw_stage
  }

  alarm_description = "API Gateway returning 5XX errors"
}
