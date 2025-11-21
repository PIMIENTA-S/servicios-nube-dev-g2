output "api_invoke_url" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}

output "api_id" {
  value = aws_api_gateway_rest_api.api.id
}

output "stage_name" {
  value = aws_api_gateway_stage.prod.stage_name
}

output "api_key_value" {
  value     = aws_api_gateway_api_key.key.value
  sensitive = true
}
