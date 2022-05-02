output "AppRunnerServiceArn" {
  value = aws_apprunner_service.service[0].arn
}

output "AppRunnerServiceURL" {
  value = "https://${aws_apprunner_service.service[0].service_url}"
}
