# One VPC per workload tier, RAM-shared to workload accounts.
# Subnets: protected (LBs), private (nodes), intra (data, no internet route).

module "vpc" {
  for_each = var.workload_vpcs
  source   = "terraform-aws-modules/vpc/aws"
  version  = "~> 5.1"

  name = "${var.org}-${each.key}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  cidr            = each.value.cidr
  public_subnets  = slice(each.value.public_subnets, 0, var.az_count)
  private_subnets = slice(each.value.private_subnets, 0, var.az_count)
  intra_subnets   = slice(each.value.intra_subnets, 0, var.az_count)

  map_public_ip_on_launch = false
  public_subnet_suffix    = "protected"
  public_subnet_tags      = { Type = "protected" }
  private_subnet_tags     = { Type = "private" }
  intra_subnet_tags       = { Type = "intra" }
  tags                    = { Type = each.key }

  enable_dns_support   = true
  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = each.value.single_nat_gateway
}

resource "aws_flow_log" "vpc" {
  for_each             = var.workload_vpcs
  log_destination      = var.flow_logs_bucket_arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = module.vpc[each.key].vpc_id
  tags                 = { Environment = each.key }
}

# RAM share to the owning workload account.
resource "aws_ram_resource_share" "vpc" {
  for_each                  = var.workload_vpcs
  name                      = "${var.org}-${each.key}-subnets"
  allow_external_principals = false
}

resource "aws_ram_principal_association" "vpc" {
  for_each           = var.workload_vpcs
  principal          = each.value.account_id
  resource_share_arn = aws_ram_resource_share.vpc[each.key].arn
}

resource "aws_ram_resource_association" "subnets" {
  for_each = merge([
    for name, vpc in var.workload_vpcs : {
      for idx, arn in concat(module.vpc[name].private_subnet_arns, module.vpc[name].intra_subnet_arns) :
      "${name}-${idx}" => { share = name, arn = arn }
    }
  ]...)

  resource_arn       = each.value.arn
  resource_share_arn = aws_ram_resource_share.vpc[each.value.share].arn
}

data "aws_availability_zones" "available" {
  state = "available"
}
