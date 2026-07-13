locals {
  cluster_name = "${var.project_name}-eks"
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
  common_tags = {
    Project = var.project_name
    Course  = "ISY1101"
  }
}

resource "aws_security_group" "cluster" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "Security group for EKS control plane"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_eks_cluster" "main" {
  name                        = local.cluster_name
  role_arn                    = data.aws_iam_role.lab_role.arn
  version                     = var.cluster_version
  bootstrap_self_managed_addons = false}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = data.aws_iam_role.lab_role.arn
  subnet_ids      = aws_subnet.public[*].id

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 20

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }

  tags = local.common_tags
}
