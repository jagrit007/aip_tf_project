# VPC and Networking
resource "aws_vpc" "prefect_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "prefect-ecs"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.prefect_vpc.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "prefect-ecs-public-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.prefect_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "prefect-ecs-private-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prefect_vpc.id

  tags = {
    Name = "prefect-ecs-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "prefect-ecs-nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "prefect-ecs-nat-gw"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.prefect_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "prefect-ecs-public-rt"
  }
}

# Route Table for Private Subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.prefect_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "prefect-ecs-private-rt"
  }
}

# Route Table Association for Public Subnets
resource "aws_route_table_association" "public_rta" {
  count          = 3
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Route Table Association for Private Subnets
resource "aws_route_table_association" "private_rta" {
  count          = 3
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "prefect-ecs-tasks-sg"
  description = "Allow necessary traffic for Prefect ECS tasks"
  vpc_id      = aws_vpc.prefect_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prefect-ecs-tasks-sg"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "prefect_cluster" {
  name = "prefect-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "prefect-ecs"
  }
}

# Service Discovery
resource "aws_service_discovery_private_dns_namespace" "prefect_namespace" {
  name        = "default.prefect.local"
  description = "Private DNS namespace for Prefect services"
  vpc         = aws_vpc.prefect_vpc.id
}

# AWS Secrets Manager for Prefect API Key
resource "aws_secretsmanager_secret" "prefect_api_key" {
  name = "prefect-api-key"
}

resource "aws_secretsmanager_secret_version" "prefect_api_key_version" {
  secret_id     = aws_secretsmanager_secret.prefect_api_key.id
  secret_string = var.prefect_api_key
}

# IAM Task Execution Role
resource "aws_iam_role" "prefect_task_execution_role" {
  name = "prefect-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "prefect-ecs"
  }
}

# Attach the ECS Task Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.prefect_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Policy for Secrets Manager access
resource "aws_iam_policy" "secrets_manager_access" {
  name        = "PrefectSecretsManagerAccess"
  description = "Allows ECS tasks to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.prefect_api_key.arn
      }
    ]
  })
}

# Attach the Secrets Manager policy to the task execution role
resource "aws_iam_role_policy_attachment" "task_secrets_manager_attachment" {
  role       = aws_iam_role.prefect_task_execution_role.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}

# ECS Task Definition for Prefect Worker
resource "aws_ecs_task_definition" "prefect_worker" {
  family                   = "prefect-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.prefect_task_execution_role.arn
  task_role_arn            = aws_iam_role.prefect_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "prefect-worker"
      image     = "prefecthq/prefect:2-latest"
      essential = true
      command = [
        "prefect", "worker", "start",
        "--pool", "ecs-work-pool",
        "--name", "dev-worker"
      ]
      environment = [
        {
          name  = "PREFECT_API_URL",
          value = "https://api.prefect.cloud/api/accounts/${var.prefect_account_id}/workspaces/${var.prefect_workspace_id}"
        },
        {
          name  = "PREFECT_LOGGING_LEVEL",
          value = "INFO"
        }
      ]
      secrets = [
        {
          name      = "PREFECT_API_KEY"
          valueFrom = aws_secretsmanager_secret.prefect_api_key.arn # aws_secretsmanager_secret_version.prefect_api_key_version.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/prefect-worker"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  tags = {
    Name = "prefect-ecs"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "prefect_worker_logs" {
  name              = "/ecs/prefect-worker"
  retention_in_days = 30

  tags = {
    Name = "prefect-ecs"
  }
}

# ECS Service for Prefect Worker
resource "aws_ecs_service" "prefect_worker_service" {
  name            = "prefect-worker-service"
  cluster         = aws_ecs_cluster.prefect_cluster.id
  task_definition = aws_ecs_task_definition.prefect_worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for subnet in aws_subnet.private_subnets : subnet.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.prefect_worker_discovery.arn
  }

  tags = {
    Name = "prefect-ecs"
  }
}

# Service Discovery Service
resource "aws_service_discovery_service" "prefect_worker_discovery" {
  name = "prefect-worker"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.prefect_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}