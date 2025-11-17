# ============================================================================
# EKS Module - Main Configuration
# ============================================================================

data "aws_caller_identity" "current" {}

# ============================================================================
# IAM Role for EKS Cluster
# ============================================================================

resource "aws_iam_role" "cluster" {
  name = "${var.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-cluster-role"
    Type = "iam-role"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# ============================================================================
# IAM Role for EKS Node Group
# ============================================================================

resource "aws_iam_role" "node_group" {
  name = "${var.name_prefix}-eks-nodegroup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-nodegroup-role"
    Type = "iam-role"
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# ============================================================================
# Security Groups
# ============================================================================

resource "aws_security_group" "cluster" {
  name_prefix = "${var.name_prefix}-eks-cluster-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-cluster-sg"
    Type = "security-group"
  })
}

resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_security_group" "node_group" {
  name_prefix = "${var.name_prefix}-eks-nodegroup-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-nodegroup-sg"
    Type = "security-group"
  })
}

resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node_group.id
  source_security_group_id = aws_security_group.node_group.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow cluster to communicate with worker nodes"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node_group.id
  source_security_group_id = aws_security_group.cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node_group.id
  to_port                  = 443
  type                     = "ingress"
}

# ============================================================================
# CloudWatch Log Group
# ============================================================================

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name_prefix}-cluster/cluster"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-cluster-logs"
    Type = "log-group"
  })
}

# ============================================================================
# EKS Cluster
# ============================================================================

resource "aws_eks_cluster" "main" {
  name     = "${var.name_prefix}-cluster"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  dynamic "encryption_config" {
    for_each = var.enable_cluster_encryption ? [1] : []
    content {
      provider {
        key_arn = aws_kms_key.cluster[0].arn
      }
      resources = ["secrets"]
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.vpc_resource_controller,
    aws_cloudwatch_log_group.cluster,
  ]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-cluster"
    Type = "eks-cluster"
  })
}

# ============================================================================
# KMS Key for Cluster Encryption (if enabled)
# ============================================================================

resource "aws_kms_key" "cluster" {
  count = var.enable_cluster_encryption ? 1 : 0

  description             = "EKS Cluster ${var.name_prefix} Encryption Key"
  deletion_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-cluster-key"
    Type = "kms-key"
  })
}

resource "aws_kms_alias" "cluster" {
  count = var.enable_cluster_encryption ? 1 : 0

  name          = "alias/${var.name_prefix}-eks-cluster"
  target_key_id = aws_kms_key.cluster[0].key_id
}

# ============================================================================
# EKS Node Group
# ============================================================================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name_prefix}-nodegroup"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable = 1
  }

  # Remote access configuration (only if SSH key is provided)
  dynamic "remote_access" {
    for_each = var.ssh_key_name != null && var.ssh_key_name != "" ? [1] : []
    content {
      ec2_ssh_key               = var.ssh_key_name
      source_security_group_ids = [aws_security_group.node_group.id]
    }
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
  ]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-nodegroup"
    Type = "eks-nodegroup"
  })
}

# ============================================================================
# OIDC Identity Provider
# ============================================================================

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-oidc"
    Type = "oidc-provider"
  })
}

# ============================================================================
# EKS Add-ons
# ============================================================================

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  resolve_conflicts = "OVERWRITE"

  tags = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  resolve_conflicts = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]

  tags = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  resolve_conflicts = "OVERWRITE"

  tags = var.tags
}

# ============================================================================
# AWS Load Balancer Controller IAM Role (for service accounts)
# ============================================================================

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role_policy.json
  name               = "${var.name_prefix}-aws-load-balancer-controller"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aws-load-balancer-controller"
    Type = "iam-role"
  })
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  policy = file("${path.module}/aws-load-balancer-controller-iam-policy.json")
  name   = "${var.name_prefix}-AWSLoadBalancerControllerIAMPolicy"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-AWSLoadBalancerControllerIAMPolicy"
    Type = "iam-policy"
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}