locals {
  az = data.aws_availability_zones.available.names[0]
}

############################
# Network (single public subnet)
############################
resource "aws_vpc" "jenkins" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.vpc_name }
}

resource "aws_internet_gateway" "jenkins" {
  vpc_id = aws_vpc.jenkins.id

  tags = { Name = "${var.vpc_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.jenkins.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = { Name = "jenkins-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.jenkins.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins.id
  }

  tags = { Name = "${var.vpc_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

############################
# Security group - only YOUR IP can reach the server
############################
resource "aws_security_group" "jenkins" {
  name        = var.jenkins_security_group
  description = "Security group for the Jenkins server"
  vpc_id      = aws_vpc.jenkins.id

  tags = { Name = var.jenkins_security_group }
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_ui" {
  security_group_id = aws_security_group.jenkins.id
  description       = "Jenkins UI"
  cidr_ipv4         = var.allowed_cidr
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sonarqube_ui" {
  security_group_id = aws_security_group.jenkins.id
  description       = "SonarQube UI"
  cidr_ipv4         = var.allowed_cidr
  from_port         = 9000
  to_port           = 9000
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count = var.key_name == null ? 0 : 1

  security_group_id = aws_security_group.jenkins.id
  description       = "SSH"
  cidr_ipv4         = var.allowed_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.jenkins.id
  description       = "Allow all outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

############################
# IAM role for the instance
# Jenkins uses this role instead of long-lived access keys stored in Jenkins.
############################
resource "aws_iam_role" "jenkins" {
  name = "${var.jenkins_ec2_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Session Manager access (shell without SSH keys / open port 22)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# LEARNING LAB ONLY: Jenkins creates VPC, IAM roles, EKS, NAT, etc., so it needs broad rights.
# For anything real, replace this with a least-privilege policy.
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.jenkins_ec2_name}-profile"
  role = aws_iam_role.jenkins.name
}

############################
# Jenkins EC2 instance
############################
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  monitoring                  = true

  user_data                   = file("${path.module}/../scripts/install_build_tools.sh")
  user_data_replace_on_change = true

  # IMDSv2 only (hop limit 2 so containers on the host can still reach it)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = var.jenkins_ec2_name }

  lifecycle {
    # A newer AL2023 AMI must not silently replace (and wipe) the Jenkins server.
    ignore_changes = [ami]
  }
}
