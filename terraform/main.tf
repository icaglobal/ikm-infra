terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Use the default VPC to avoid NAT Gateway / VPC costs (demo only)
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------------------------
# IAM — allow the instance to pull from ECR
# ---------------------------------------------------------------------------
resource "aws_iam_role" "tinkar" {
  name = "tinkar-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.tinkar.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "tinkar" {
  name = "tinkar-instance-profile"
  role = aws_iam_role.tinkar.name
}

# ---------------------------------------------------------------------------
# Security group
# TODO: Replace allowed_cidrs/ssh_cidrs with ICA IP ranges before going live.
#       No auth is currently configured in the service itself.
# ---------------------------------------------------------------------------
resource "aws_security_group" "tinkar" {
  name        = "tinkar-sg"
  description = "Tinkar service: REST (8085) and gRPC (9095)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "REST API"
    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "gRPC"
    from_port   = 9095
    to_port     = 9095
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "tinkar-sg"
    Project = "ikm-infra"
  }
}

# ---------------------------------------------------------------------------
# Latest Amazon Linux 2023 x86_64 AMI
# (matches the linux/amd64 platform forced in the Dockerfile)
# ---------------------------------------------------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ---------------------------------------------------------------------------
# EC2 instance
# TODO: RocksDB data handling — the image bakes the data folder in at build
#       time (~6 GB+). Confirm the ECR image includes the data before
#       deploying, or revisit with an EFS/S3 mount approach.
# ---------------------------------------------------------------------------
resource "aws_instance" "tinkar" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.tinkar.name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.tinkar.id]
  key_name               = var.key_pair_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = true
  }

  # Derive the ECR registry host from the full image URL
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    # Install Docker
    dnf install -y docker
    systemctl enable --now docker

    # Authenticate to ECR and pull the image
    ECR_REGISTRY=$(echo "${var.ecr_image_url}" | cut -d'/' -f1)
    aws ecr get-login-password --region ${var.aws_region} \
      | docker login --username AWS --password-stdin "$ECR_REGISTRY"

    docker pull ${var.ecr_image_url}

    # Run the container
    docker run -d \
      --name tinkar \
      --restart unless-stopped \
      -p 8085:8085 \
      -p 9095:9095 \
      ${var.ecr_image_url}
  EOF

  tags = {
    Name    = "tinkar-service"
    Project = "ikm-infra"
  }
}

# ---------------------------------------------------------------------------
# Elastic IP — stable address that survives stop/start
# ---------------------------------------------------------------------------
resource "aws_eip" "tinkar" {
  instance = aws_instance.tinkar.id
  domain   = "vpc"

  tags = {
    Name    = "tinkar-eip"
    Project = "ikm-infra"
  }
}
