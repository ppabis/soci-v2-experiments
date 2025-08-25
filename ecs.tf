resource "aws_ecs_cluster" "soci_cluster" {
  name = "soci-cluster"
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
    }
  ])
}