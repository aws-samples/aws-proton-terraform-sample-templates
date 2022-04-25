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

output "SnsTopicArn" {
  value = module.sns.sns_topic_arn
}

output "SnsTopicName" {
  value = module.sns.sns_topic_name
}

output "VpcSecurityGroup" {
  value = module.vpc.default_security_group_id
}
