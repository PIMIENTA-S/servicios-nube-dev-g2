output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "alb_arn" {
  value = aws_lb.alb.arn
}

output "alb_arn_suffix" {
  value = aws_lb.alb.arn_suffix
}

output "lambda_arns" {
  value = {
    images   = aws_lambda_function.images.arn
    students = aws_lambda_function.students.arn
    db_init  = aws_lambda_function.db_init.arn
  }
}

output "lambda_functions" {
  value = {
    images   = aws_lambda_function.images
    students = aws_lambda_function.students
    db_init  = aws_lambda_function.db_init
  }
}
