# Regional Transit Gateway hub. Attachments are never auto-accepted.

module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "~> 2.12"

  name        = "${var.org}-${var.region}-tgw"
  description = "Hub for ${var.region}"

  enable_auto_accept_shared_attachments = false
  share_tgw                             = false

  vpc_attachments = {
    for name, vpc in var.workload_vpcs : name => {
      vpc_id      = module.vpc[name].vpc_id
      subnet_ids  = module.vpc[name].private_subnets
      dns_support = true
      tgw_routes  = [{ destination_cidr_block = vpc.cidr }]
    }
  }

  tags = var.tags
}

# Cross-region peering, requester side; the accepter is the other region's instance.
resource "aws_ec2_transit_gateway_peering_attachment" "peer" {
  count = var.peer_tgw_id != "" ? 1 : 0

  transit_gateway_id      = module.tgw.ec2_transit_gateway_id
  peer_transit_gateway_id = var.peer_tgw_id
  peer_region             = var.peer_region

  tags = merge(var.tags, { Name = "${var.region}-to-${var.peer_region}" })
}
