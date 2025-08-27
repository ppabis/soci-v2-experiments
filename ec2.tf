locals {
  install_docker_user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y docker git

    systemctl enable --now docker
    usermod -aG docker ec2-user

    git clone https://github.com/ppabis/soci-v2-experiments /home/ec2-user/soci-v2-experiments
    git clone https://github.com/ppabis/ecr-aws-soci-index-builder /home/ec2-user/ecr-aws-soci-index-builder
    
    cd /home/ec2-user/ecr-aws-soci-index-builder/soci-index-generator-standalone/
    docker build -t soci-gen:latest .
    
    cd /home/ec2-user/soci-v2-experiments/test_image/
    docker build -t $${repo_url}:$${img_arch} .
    aws ecr get-login-password | docker login --username AWS --password-stdin $${registry_url}
    docker push $${repo_url}:$${img_arch}

    curl -LO "https://github.com/oras-project/oras/releases/download/v1.2.2/oras_1.2.2_linux_$${img_arch}.tar.gz"
    mkdir -p /tmp/oras-install/
    tar -zxf oras_1.2.2_*.tar.gz -C /tmp/oras-install/
    mv /tmp/oras-install/oras /usr/local/bin/
    rm -rf oras_1.2.2_*.tar.gz /tmp/oras-install/
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
  ami           = data.aws_ssm_parameter.al2023_x86_64.value
  instance_type = "t3.micro"
  subnet_id     = module.vpc.private_subnets[0]
  user_data = templatestring(local.install_docker_user_data, {
    repo_url     = aws_ecr_repository.soci_repo.repository_url
    img_arch     = "amd64"
    registry_url = split("/", aws_ecr_repository.soci_repo.repository_url)[0]
  })
  vpc_security_group_ids = [aws_security_group.ec2_outbound_all.id]
  tags                   = { Name = "soci-v2-al2023-x86_64" }
  depends_on             = [module.vpc]
  iam_instance_profile   = aws_iam_instance_profile.ec2_role.name
}

resource "aws_instance" "al2023_arm64" {
  ami           = data.aws_ssm_parameter.al2023_arm64.value
  instance_type = "t4g.micro"
  subnet_id     = module.vpc.private_subnets[0]
  user_data = templatestring(local.install_docker_user_data, {
    repo_url     = aws_ecr_repository.soci_repo.repository_url
    img_arch     = "arm64"
    registry_url = split("/", aws_ecr_repository.soci_repo.repository_url)[0]
  })
  vpc_security_group_ids = [aws_security_group.ec2_outbound_all.id]
  tags                   = { Name = "soci-v2-al2023-arm64" }
  depends_on             = [module.vpc]
  iam_instance_profile   = aws_iam_instance_profile.ec2_role.name
}

output "ec2_instance_connect_cli_arm64" {
  value = <<EOF
  aws ec2-instance-connect ssh \
   --region ${data.aws_region.current.name} \
   --instance-id ${aws_instance.al2023_arm64.id} \
   --instance-ip ${aws_instance.al2023_arm64.private_ip} \
   --connection-type eice \
   --os-user ec2-user
  EOF
}

output "ec2_instance_connect_cli_x86_64" {
  value = <<EOF
  aws ec2-instance-connect ssh \
   --region ${data.aws_region.current.name} \
   --instance-id ${aws_instance.al2023_x86_64.id} \
   --instance-ip ${aws_instance.al2023_x86_64.private_ip} \
   --connection-type eice \
   --os-user ec2-user
  EOF
}