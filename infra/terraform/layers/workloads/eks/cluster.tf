# EKS on RAM-shared subnets. Karpenter provides capacity; one small system pool hosts it.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version
  vpc_id             = local.vpc_id
  subnet_ids         = local.private_subnet_ids

  endpoint_public_access  = var.endpoint_public_access
  endpoint_private_access = true

  enabled_log_types = ["api", "audit", "authenticator"]

  encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # Account root, not the caller ARN: SSO vs CI applies otherwise drift every run.
  kms_key_administrators = ["arn:aws:iam::${var.account_id}:root"]

  # Access is declared, never inherited from the applier.
  enable_cluster_creator_admin_permissions = false

  access_entries = merge(
    {
      ci = {
        principal_arn = "arn:aws:iam::${var.account_id}:role/gh-actions-terraform"
        policy_associations = {
          admin = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    },
    {
      for name, arn in local.sso_admin_role_arns : "sso-admin-${name}" => {
        principal_arn = arn
        policy_associations = {
          admin = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    },
    {
      for name, arn in local.sso_viewer_role_arns : "sso-view-${name}" => {
        principal_arn = arn
        policy_associations = {
          view = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    },
  )

  eks_managed_node_groups = {
    for name, pool in var.node_pools : name => {
      instance_types = [pool.instance_type]
      min_size       = pool.min_size
      max_size       = pool.max_size
      desired_size   = pool.desired_size
      labels         = merge({ "pool" = name }, pool.labels)
      taints         = pool.taints
    }
  }

  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = {}
    aws-ebs-csi-driver     = {}
  }

  tags = var.tags
}

resource "aws_kms_key" "eks" {
  description             = "EKS secrets encryption — ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}
