locals {
  install_docker_user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y docker

    systemctl enable --now docker
    usermod -aG docker ec2-user
  EOF
}

data "aws_ssm_parameter" "al2023_x86_64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_security_group" "ec2_outbound_all" {
  name        = "soci-v2-ec2-sg"
  description = "Security group for EC2 instances with full egress"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "soci-v2-ec2-sg" }
}

resource "aws_instance" "al2023_x86_64" {
  ami                    = data.aws_ssm_parameter.al2023_x86_64.value
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.private_subnets[0]
  user_data              = local.install_docker_user_data
  vpc_security_group_ids = [aws_security_group.ec2_outbound_all.id]
  tags                   = { Name = "soci-v2-al2023-x86_64" }
  depends_on             = [module.vpc]
}

resource "aws_instance" "al2023_arm64" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = "t4g.micro"
  subnet_id              = module.vpc.private_subnets[0]
  user_data              = local.install_docker_user_data
  vpc_security_group_ids = [aws_security_group.ec2_outbound_all.id]
  tags                   = { Name = "soci-v2-al2023-arm64" }
  depends_on             = [module.vpc]
}

output "al2023_x86_64_private_ip" {
  value = aws_instance.al2023_x86_64.private_ip
}

output "al2023_arm64_private_ip" {
  value = aws_instance.al2023_arm64.private_ip
}

output "al2023_x86_64_id" {
  value = aws_instance.al2023_x86_64.id
}

output "al2023_arm64_id" {
  value = aws_instance.al2023_arm64.id
}