variable "aws_region" {
  description = "AWS region for the Jenkins server"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (used for tagging)"
  type        = string
  default     = "dev"
}

variable "vpc_name" {
  description = "Name of the Jenkins VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the Jenkins VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block of the public subnet that hosts Jenkins"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. Jenkins + SonarQube + Docker need at least 8 GB RAM."
  type        = string
  default     = "t3.large"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB (Docker images, SonarQube and Trivy DB need space)"
  type        = number
  default     = 30
}

variable "jenkins_ec2_name" {
  description = "Name tag of the Jenkins EC2 instance"
  type        = string
  default     = "Jenkins-Build-Server"
}

variable "jenkins_security_group" {
  description = "Name of the Jenkins security group"
  type        = string
  default     = "jenkins-sg"
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH. Leave null to use SSM Session Manager only (no port 22)."
  type        = string
  default     = null
}

variable "allowed_cidr" {
  description = "Your public IP in CIDR form (for example 203.0.113.10/32). Only this range can reach Jenkins (8080), SonarQube (9000) and SSH (22)."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.allowed_cidr)) && var.allowed_cidr != "0.0.0.0/0"
    error_message = "allowed_cidr must be a valid CIDR and must not be 0.0.0.0/0. Use your own IP, e.g. \"$(curl -s https://checkip.amazonaws.com)/32\"."
  }
}
