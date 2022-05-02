output "AppRunnerServiceArn" {
  value = length(aws_apprunner_service.service) > 0 ? aws_apprunner_service.service[0].arn : "null"
}

output "AppRunnerServiceURL" {
  value = length(aws_apprunner_service.service) > 0 ? "https://${aws_apprunner_service.service[0].service_url}" : "null"
}