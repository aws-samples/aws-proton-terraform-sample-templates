output "fargate_cluster" {
  value = aws_ecs_cluster.fargate_cluster
}

output "fargate_cluster_arn" {
  value = aws_ecs_cluster.fargate_cluster.arn
}

output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "sns_topic" {
  value = aws_sns_topic.ping_topic
}

output "sns_topic_name" {
  value = aws_sns_topic.ping_topic.name
}

output "sns_region" {
  value = local.region
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_one_id" {
  value = module.vpc.public_subnets[0]
}

output "public_subnet_two_id" {
  value = module.vpc.public_subnets[1]
}

output "private_subnet_one_id" {
  value = module.vpc.private_subnets[0]
}

output "private_subnet_two_id" {
  value = module.vpc.private_subnets[1]
}

output "cloud_map_namespace_id" {
  value = aws_service_discovery_private_dns_namespace.service_discovery.id
}