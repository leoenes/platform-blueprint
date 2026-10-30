# Karpenter IAM only. The Helm release, NodePool and EC2NodeClass are GitOps
# objects deployed by ArgoCD (infra/helm-charts/platform-apps). Terraform owns
# what needs AWS credentials; the cluster owns what runs in the cluster.

resource "aws_iam_service_linked_role" "spot" {
  aws_service_name = "spot.amazonaws.com"
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = module.eks.cluster_name

  # Stable node role name: referenced by name in the EC2NodeClass manifest.
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${var.cluster_name}-karpenter-node"
  create_instance_profile       = true

  enable_spot_termination = true

  # Pod Identity instead of IRSA: no OIDC annotation juggling per cluster.
  create_pod_identity_association = true
  namespace                       = "karpenter"
  service_account                 = "karpenter"

  tags = var.tags
}
