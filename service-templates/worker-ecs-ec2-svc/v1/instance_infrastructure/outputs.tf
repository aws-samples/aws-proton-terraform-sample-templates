output "ServiceSqsDeadLetterQueueName" {
  value = aws_sqs_queue.ecs_processing_dlq.name
}

output "ServiceSqsDeadLetterQueueArn" {
  value = aws_sqs_queue.ecs_processing_dlq.arn
}

output "ServiceSqsQueueName" {
  value = aws_sqs_queue.ecs_processing_queue.name
}

output "ServiceSqsQueueArn" {
  value = aws_sqs_queue.ecs_processing_queue.arn
}