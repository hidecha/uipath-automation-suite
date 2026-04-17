### Key Pair

## Generate a secure private key and encodes it as PEM
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

## Create Key Pair
resource "aws_key_pair" "key_pair" {
  key_name   = "${var.res_prefix}-key-pair"
  public_key = tls_private_key.key_pair.public_key_openssh
}

## Save file
resource "local_sensitive_file" "ssh_key" {
  filename        = "${aws_key_pair.key_pair.key_name}.pem"
  content         = tls_private_key.key_pair.private_key_pem
  file_permission = "0600"
}

### Bastion VM (Windows)

## Get latest Windows Server AMI
data "aws_ami" "windows_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-Japanese-Full-Base-*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

## Create Windows EC2 Instance for Bastion
resource "aws_instance" "vm_basion" {
  ami                         = data.aws_ami.windows_ami.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet_public[0].id
  vpc_security_group_ids      = [aws_security_group.sg_bastion.id]
  source_dest_check           = false
  key_name                    = aws_key_pair.key_pair.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 64
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "${var.res_prefix}-bastion"
  }
}

## Elastic IP for Bastion
resource "aws_eip" "eip_vm" {
  domain = "vpc"

  tags = {
    Name = "${var.res_prefix}-eip-bastion"
  }
}

### Elastic IP to Bastion association
resource "aws_eip_association" "eip_vm_assoc" {
  instance_id   = aws_instance.vm_basion.id
  allocation_id = aws_eip.eip_vm.id
}

### Client VM (Linux)

## Get latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

## Create EC2 Instance for Client
resource "aws_instance" "vm_client" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet_private[0].id
  vpc_security_group_ids      = [aws_security_group.sg_internal.id]
  source_dest_check           = false
  key_name                    = aws_key_pair.key_pair.key_name
  associate_public_ip_address = false

  # root disk
  root_block_device {
    volume_size           = 64
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "${var.res_prefix}-client"
  }
}
