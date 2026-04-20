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

## IRSA Role for EFS CSI Driver (separated from the worker node role
## to prevent accidental trust-policy overwrites.)
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}

locals {
  oidc_host = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

resource "aws_iam_role" "iam_role_efs_csi" {
  name = "${var.res_prefix}-efs-csi-driver-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:efs-csi-*"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "iam_role_efs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.iam_role_efs_csi.name
}

## IRSA Role for EBS CSI Driver
resource "aws_iam_role" "iam_role_ebs_csi" {
  name = "${var.res_prefix}-ebs-csi-driver-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "iam_role_ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.iam_role_ebs_csi.name
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
    subnet_ids              = var.enable_public_access ? local.public_subnet_ids : local.private_subnet_ids
    security_group_ids      = [aws_security_group.sg_internal.id]
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_access
    public_access_cidrs     = var.enable_public_access ? ["${var.my_ip}/32"] : null
  }

  depends_on = [
    aws_iam_role_policy_attachment.iam_role_controlplane_policy
  ]
}

## Add-On (bundled with the cluster; versions pinned to avoid unplanned drift.)
resource "aws_eks_addon" "eks_addons" {
  for_each = toset(["coredns", "kube-proxy"])

  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = each.key
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_nodegroup_cpu
  ]
}

## VPC CNI addon — uses WARM_IP_TARGET instead of WARM_ENI_TARGET to prevent
## IP address exhaustion in /24 node subnets.  Custom networking routes Pod
## secondary IPs to the dedicated Pod subnets (100.64.x.x/18).
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  configuration_values = jsonencode({
    env = {
      AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
      ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"
      WARM_IP_TARGET                     = "5"
      MINIMUM_IP_TARGET                  = "3"
    }
  })

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_nodegroup_cpu
  ]
}

## ENIConfig per AZ — tells VPC CNI which Pod subnet to use for secondary IPs.
resource "kubernetes_manifest" "eniconfig" {
  for_each = { for i, az in var.availability_zones : az => aws_subnet.subnet_pod[i].id }

  manifest = {
    apiVersion = "crd.k8s.amazonaws.com/v1alpha1"
    kind       = "ENIConfig"
    metadata = {
      name = each.key
    }
    spec = {
      securityGroups = [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id]
      subnet         = each.value
    }
  }

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_node_group.eks_nodegroup_cpu
  ]
}

## EBS CSI driver addon with its dedicated IRSA role.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.iam_role_ebs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_nodegroup_cpu,
    aws_iam_role_policy_attachment.iam_role_ebs_csi_policy
  ]
}

## EFS CSI driver addon with its dedicated IRSA role.
resource "aws_eks_addon" "efs_csi" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "aws-efs-csi-driver"
  service_account_role_arn    = aws_iam_role.iam_role_efs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_nodegroup_cpu,
    aws_iam_role_policy_attachment.iam_role_efs_csi_policy
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
