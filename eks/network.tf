### Virtual Network

## VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_address
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.res_prefix}-vpc"
  }
}

## Public Subnets
resource "aws_subnet" "subnet_public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 1)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.res_prefix}-subnet-public${format("%02d", count.index + 1)}"
  }
}

## Private Subnets
resource "aws_subnet" "subnet_private" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + 11)
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.res_prefix}-subnet-private${format("%02d", count.index + 1)}"
  }
}

locals {
  public_subnet_ids  = aws_subnet.subnet_public[*].id
  private_subnet_ids = aws_subnet.subnet_private[*].id
}

## Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.res_prefix}-igw"
  }
}

## Elastic IPs for NAT Gateways
resource "aws_eip" "eip_ngw" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name = "${var.res_prefix}-eip-ngw${format("%02d", count.index + 1)}"
  }
}

## NAT Gateways
resource "aws_nat_gateway" "ngw" {
  count = length(var.availability_zones)

  connectivity_type = "public"
  subnet_id         = aws_subnet.subnet_public[count.index].id
  allocation_id     = aws_eip.eip_ngw[count.index].id

  tags = {
    Name = "${var.res_prefix}-ngw${format("%02d", count.index + 1)}"
  }

  depends_on = [aws_internet_gateway.igw]
}

## Route table for Public Subnet
resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.res_prefix}-rt-public"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.rt_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

## Route Tables for Private Subnets
resource "aws_route_table" "rt_private" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.res_prefix}-rt-private${format("%02d", count.index + 1)}"
  }
}

resource "aws_route" "private_nat_gateway" {
  count = length(var.availability_zones)

  route_table_id         = aws_route_table.rt_private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw[count.index].id
}

## Route Table to Public Subnets association
resource "aws_route_table_association" "rt_public_assoc" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.subnet_public[count.index].id
  route_table_id = aws_route_table.rt_public.id
}

## Route Tables to Private Subnets association
resource "aws_route_table_association" "rt_private_assoc" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.subnet_private[count.index].id
  route_table_id = aws_route_table.rt_private[count.index].id
}

### Network Security Group

## Security Group for Bastion
resource "aws_security_group" "sg_bastion" {
  name   = "${var.res_prefix}-sg-bastion"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.res_prefix}-sg-bastion"
  }
}

## Security Group for VPC
resource "aws_security_group" "sg_internal" {
  name   = "${var.res_prefix}-sg-internal"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_address]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.res_prefix}-sg-internal"
  }
}
