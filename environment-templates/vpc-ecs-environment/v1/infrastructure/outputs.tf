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

output "sns_topic_name" {
  value = module.sns.sns_topic_name
}
