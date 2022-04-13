output "HttpApiEndpoint" {
  description = "The default endpoint for the HTTP API."

  value = aws_apigatewayv2_stage.lambda.invoke_url
}

output "LambdaRuntime" {
  value = var.service_instance.inputs.lambda_runtime
}