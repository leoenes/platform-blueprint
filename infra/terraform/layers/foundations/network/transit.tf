# Regional Transit Gateway: hub for workload VPCs, the VPN/zero-trust VPC and
# cross-region peering. Attachments are not auto-accepted; each one is a
# reviewed change in this layer.

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

# Cross-region peering to the other hub (us-east-1 <-> eu-west-2). Created on
# the "requester" side only; the accepter lives in the other region's instance.
resource "aws_ec2_transit_gateway_peering_attachment" "peer" {
  count = var.peer_tgw_id != "" ? 1 : 0

  transit_gateway_id      = module.tgw.ec2_transit_gateway_id
  peer_transit_gateway_id = var.peer_tgw_id
  peer_region             = var.peer_region

  tags = merge(var.tags, { Name = "${var.region}-to-${var.peer_region}" })
}
