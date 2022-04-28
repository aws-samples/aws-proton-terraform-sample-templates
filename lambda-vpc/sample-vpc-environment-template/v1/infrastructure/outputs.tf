output "vpc_arn" {
  value = module.vpc.vpc_arn
}

output "subnet_id" {
  value = one(module.vpc.private_subnets) # there is a known issue with terraform lists as outputs for proton
}

output "security_group_id" {
  value = module.vpc.default_security_group_id
}