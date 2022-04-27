output "LambdaFunctionName" {
  value = aws_lambda_function.lambda_function.function_name
}

output "SqsQueueName" {
  value = aws_sqs_queue.processing_queue.name
}

output "SqsQueueArn" {
  value = aws_sqs_queue.processing_queue.arn
}

output "SqsQueueUrl" {
  value = aws_sqs_queue.processing_queue.url
}

output "LambdaRuntime" {
  value = aws_lambda_function.lambda_function.runtime
}
