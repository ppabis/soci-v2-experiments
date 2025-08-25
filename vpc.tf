module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = "soci-v2-vpc"
  cidr = "10.60.0.0/16"

  azs             = ["us-east-2a"]
  public_subnets  = ["10.60.1.0/24"]
  private_subnets = ["10.60.2.0/24"]

  enable_nat_gateway = true
  create_igw         = true
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "soci-v2-vpc-endpoints-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "soci-v2-vpc-endpoints-sg"
  }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.21.0"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }
  }
}


resource "aws_ec2_instance_connect_endpoint" "private" {
  subnet_id          = module.vpc.private_subnets[0]
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  preserve_client_ip = false
}


