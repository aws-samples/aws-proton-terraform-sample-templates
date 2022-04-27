output "LambdaFunction" {
  value = aws_lambda_function.function.function_name
}

output "LambdaRuntime" {
  value = var.service_instance.inputs.lambda_runtime
}