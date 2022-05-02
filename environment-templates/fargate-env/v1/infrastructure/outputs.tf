output "ClusterName" {
  value = aws_ecs_cluster.fargate_cluster.name
}

output "ClusterArn" {
  value = aws_ecs_cluster.fargate_cluster.arn
}

output "ServiceTaskDefExecutionRoleArn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "SnsTopicArn" {
  value = aws_sns_topic.ping_topic.arn
}

output "SnsTopicName" {
  value = aws_sns_topic.ping_topic.name
}

output "SnsRegion" {
  value = local.region
}

output "VpcId" {
  value = module.vpc.vpc_id
}

output "PublicSubnetOneId" {
  value = module.vpc.public_subnets[0]
}

output "PublicSubnetTwoId" {
  value = module.vpc.public_subnets[1]
}

output "PrivateSubnetOneId" {
  value = module.vpc.private_subnets[0]
}

output "PrivateSubnetTwoId" {
  value = module.vpc.private_subnets[1]
}

output "CloudMapNamespaceId" {
  value = aws_service_discovery_private_dns_namespace.service_discovery.id
}