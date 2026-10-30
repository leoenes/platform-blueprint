output "vpc_ids" {
  value = { for k, v in module.vpc : k => v.vpc_id }
}

output "private_subnet_ids" {
  value = { for k, v in module.vpc : k => v.private_subnets }
}

output "intra_subnet_ids" {
  value = { for k, v in module.vpc : k => v.intra_subnets }
}

output "transit_gateway_id" {
  value = module.tgw.ec2_transit_gateway_id
}
