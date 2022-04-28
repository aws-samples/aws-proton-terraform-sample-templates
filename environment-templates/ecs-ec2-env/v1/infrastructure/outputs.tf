output "Cluster" {
  value = aws_ecs_cluster.cluster.name
}

output "ClusterArn" {
  value = aws_ecs_cluster.cluster.arn
}

output "ServiceTaskDefExecutionRole" {
  value = aws_iam_role.service-task-def-execution-role.arn
}

output "SnsTopic" {
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

output "PublicSubnet1" {
  value = module.vpc.public_subnets[0]
}

output "PublicSubnet2" {
  value = module.vpc.public_subnets[1]
}

output "PrivateSubnet1" {
  value = module.vpc.private_subnets[0]
}

output "PrivateSubnet2" {
  value = module.vpc.private_subnets[1]
}

output "CloudMapNamespaceId" {
  value = aws_service_discovery_private_dns_namespace.cloud_map_namespace.id
}

output "ECSHostSecurityGroupId" {
  value = aws_security_group.ecs_host_security_group.id
}
