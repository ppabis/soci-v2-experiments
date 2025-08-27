resource "aws_ecs_cluster" "soci_cluster" {
  name = "soci-cluster"
}

resource "aws_security_group" "soci_service_sg" {
  name        = "test-soci-service-sg"
  description = "Security group for test service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/soci-service"
  retention_in_days = 7
}

resource "aws_ecs_service" "soci_service" {
  name            = "soci-service"
  cluster         = aws_ecs_cluster.soci_cluster.id
  task_definition = aws_ecs_task_definition.soci_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.soci_service_sg.id]
  }

  tags = {
    Name = "soci-service"
  }
}

resource "aws_ecs_task_definition" "soci_task" {
  family                   = "soci-task"
  memory                   = 512
  cpu                      = 256
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  tags                     = { Name = "soci-task" }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "soci-container"
      image     = "${aws_ecr_repository.soci_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

output "service_arn" {
  value = aws_ecs_service.soci_service.id
}