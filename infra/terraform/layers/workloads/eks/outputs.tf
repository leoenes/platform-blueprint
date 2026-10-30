output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "karpenter_node_role_name" {
  value = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  value = module.karpenter.queue_name
}
