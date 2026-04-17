### EKS Cluster

## IAM Role for EKS Control Plane
resource "aws_iam_role" "iam_role_controlplane" {
  name = "${var.res_prefix}-controlplane-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "iam_role_controlplane_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.iam_role_controlplane.name
}

## IAM Role for EKS Worker Node
resource "aws_iam_role" "iam_role_workernode" {
  name = "${var.res_prefix}-workernode-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

### Managed policies attachment
resource "aws_iam_role_policy_attachment" "iam_role_workernode_policy" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly"
  ])

  policy_arn = "arn:aws:iam::aws:policy/${each.key}"
  role       = aws_iam_role.iam_role_workernode.name
}

resource "aws_iam_role_policy" "iam_policy_workernode_ebs" {
  name = "EBS_CSI_Driver"
  role = aws_iam_role.iam_role_workernode.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DeleteVolume"
        ]
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:volume/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AttachVolume",
          "ec2:DetachVolume"
        ]
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume"
        ]
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:volume/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ]
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:snapshot/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot"
        ]
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:volume/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = [
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:volume/*",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:snapshot/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "iam_policy_workernode_efs" {
  name = "EFS_CSI_Driver"
  role = aws_iam_role.iam_role_workernode.name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeAvailabilityZones"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets"
        ],
        "Resource" : "arn:aws:elasticfilesystem:${var.region}:${data.aws_caller_identity.current.account_id}:file-system/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticfilesystem:DescribeAccessPoints"
        ],
        "Resource" : "arn:aws:elasticfilesystem:${var.region}:${data.aws_caller_identity.current.account_id}:access-point/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticfilesystem:CreateAccessPoint"
        ],
        "Resource" : "arn:aws:elasticfilesystem:${var.region}:${data.aws_caller_identity.current.account_id}:file-system/*",
        "Condition" : {
          "StringLike" : {
            "aws:RequestTag/efs.csi.aws.com/cluster" : "true"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : "elasticfilesystem:DeleteAccessPoint",
        "Resource" : "arn:aws:elasticfilesystem:${var.region}:${data.aws_caller_identity.current.account_id}:access-point/*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/efs.csi.aws.com/cluster" : "true"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "iam_policy_workernode_elb" {
  name = "ELB_Permissions"
  role = aws_iam_role.iam_role_workernode.name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "ELBDescribe",
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeLoadBalancerPolicies",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTags"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "ELBManage",
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
          "elasticloadbalancing:DetachLoadBalancerFromSubnets",
          "elasticloadbalancing:AttachLoadBalancerToSubnets",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:ConfigureHealthCheck",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:CreateLoadBalancerListeners",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
          "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancerListeners",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:CreateLoadBalancerPolicy",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ],
        "Resource" : [
          "arn:aws:elasticloadbalancing:${var.region}:${data.aws_caller_identity.current.account_id}:loadbalancer/*",
          "arn:aws:elasticloadbalancing:${var.region}:${data.aws_caller_identity.current.account_id}:targetgroup/*",
          "arn:aws:elasticloadbalancing:${var.region}:${data.aws_caller_identity.current.account_id}:listener/*"
        ]
      }
    ]
  })
}

### S3 access policy
resource "aws_iam_policy" "s3_access" {
  name        = "${var.res_prefix}-s3-access"
  description = "IAM policy for EKS worker nodes to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:ListBucket",
          "s3:PutBucketCORS",
          "s3:GetBucketCORS",
          "s3:DeleteBucketCORS",
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  policy_arn = aws_iam_policy.s3_access.arn
  role       = aws_iam_role.iam_role_workernode.name
}

### SQS access policy
resource "aws_iam_policy" "sqs_access" {
  name        = "${var.res_prefix}-sqs-access"
  description = "IAM policy for EKS worker nodes to access SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.res_prefix}-gallupx-*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sqs_access_attachment" {
  policy_arn = aws_iam_policy.sqs_access.arn
  role       = aws_iam_role.iam_role_workernode.name
}

## EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.res_prefix}-cluster"
  role_arn = aws_iam_role.iam_role_controlplane.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids         = var.enable_public_access ? local.public_subnet_ids : local.private_subnet_ids
    security_group_ids = [aws_security_group.sg_internal.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.iam_role_controlplane_policy
  ]
}

## Add-On
resource "aws_eks_addon" "eks_addons" {
  for_each = toset(["vpc-cni", "coredns", "kube-proxy", "aws-ebs-csi-driver", "aws-efs-csi-driver"])

  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = each.key

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_nodegroup_cpu
  ]
}

## Launch Template for EKS Node Group
resource "aws_launch_template" "eks_nodegroup_template" {
  name = "${var.res_prefix}-nodegroup-template"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 256
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = var.tags
  }
}

## Create EKS Node Group (CPU)
resource "aws_eks_node_group" "eks_nodegroup_cpu" {
  count = var.number_of_cpu_nodes > 0 ? 1 : 0

  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.res_prefix}-nodegroup-cpu"
  ami_type        = "AL2023_x86_64_STANDARD"
  node_role_arn   = aws_iam_role.iam_role_workernode.arn
  subnet_ids      = var.enable_public_access ? local.public_subnet_ids : local.private_subnet_ids
  instance_types  = [var.cpu_instance_type]

  scaling_config {
    desired_size = var.number_of_cpu_nodes
    min_size     = var.number_of_cpu_nodes
    max_size     = var.number_of_cpu_nodes > 0 ? var.number_of_cpu_nodes : 1
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.eks_nodegroup_template.id
    version = aws_launch_template.eks_nodegroup_template.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.iam_role_workernode_policy
  ]
}

## Create EKS Node Group (GPU)
resource "aws_eks_node_group" "eks_nodegroup_gpu" {
  count = var.number_of_gpu_nodes > 0 ? 1 : 0

  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.res_prefix}-nodegroup-gpu"
  ami_type        = "AL2023_x86_64_NVIDIA"
  node_role_arn   = aws_iam_role.iam_role_workernode.arn
  subnet_ids      = var.enable_public_access ? local.public_subnet_ids : local.private_subnet_ids
  instance_types  = [var.gpu_instance_type]

  scaling_config {
    desired_size = var.number_of_gpu_nodes
    min_size     = var.number_of_gpu_nodes
    max_size     = var.number_of_gpu_nodes > 0 ? var.number_of_gpu_nodes : 1
  }

  taint {
    key    = "nvidia.com/gpu"
    value  = "present"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "accelerator" = "nvidia-gpu"
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.eks_nodegroup_template.id
    version = aws_launch_template.eks_nodegroup_template.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.iam_role_workernode_policy
  ]
}

## Create EKS Node Group (AS Robot)
resource "aws_eks_node_group" "eks_nodegroup_asrobot" {
  count = var.number_of_asrobot_nodes > 0 ? 1 : 0

  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.res_prefix}-nodegroup-asrobot"
  ami_type        = "AL2023_x86_64_STANDARD"
  node_role_arn   = aws_iam_role.iam_role_workernode.arn
  subnet_ids      = var.enable_public_access ? local.public_subnet_ids : local.private_subnet_ids
  instance_types  = [var.asrobot_instance_type]

  scaling_config {
    desired_size = var.number_of_asrobot_nodes
    min_size     = var.number_of_asrobot_nodes
    max_size     = var.number_of_asrobot_nodes > 0 ? var.number_of_asrobot_nodes : 1
  }

  taint {
    key    = "serverless.robot"
    value  = "present"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "serverless.robot"  = "true"
    "serverless.daemon" = "true"
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.eks_nodegroup_template.id
    version = aws_launch_template.eks_nodegroup_template.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.iam_role_workernode_policy
  ]
}

### Private DNS Zone for Automation Suite

resource "aws_route53_zone" "dns_zone" {
  name = var.eks_fqdn
  vpc {
    vpc_id = aws_vpc.vpc.id
  }

  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_record" "dns_cname_record" {
  for_each = toset(["alm", "monitoring", "objectstore", "registry", "insights", "apps"])

  zone_id = aws_route53_zone.dns_zone.zone_id
  name    = "${each.key}.${var.eks_fqdn}"
  type    = "CNAME"
  ttl     = 300
  records = [var.eks_fqdn]
}

### EFS File system

resource "aws_efs_file_system" "efs_file" {
  creation_token = "${var.res_prefix}-efs"
  encrypted      = true

  tags = {
    Name = "${var.res_prefix}-efs"
  }
}

resource "aws_efs_mount_target" "efs_mount" {
  count = length(var.availability_zones)

  file_system_id  = aws_efs_file_system.efs_file.id
  subnet_id       = var.enable_public_access ? local.public_subnet_ids[count.index] : local.private_subnet_ids[count.index]
  security_groups = [aws_security_group.sg_internal.id]
}
