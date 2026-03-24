variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type. t3.medium recommended for Spring Boot + RocksDB under Java 25."
  type        = string
  default     = "t3.medium"
}

variable "ecr_image_url" {
  description = "Full ECR image URL including tag, e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/tinkar:latest"
  type        = string
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair to use for SSH access"
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach the REST (8085) and gRPC (9095) ports. Lock to ICA IPs before going live."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_cidrs" {
  description = "CIDRs allowed SSH access. Lock to ICA IPs before going live."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
