resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/ecs/nginx-${var.environment}"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/identity-${var.environment}"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "ballot" {
  name              = "/ecs/ballot-${var.environment}"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "vote" {
  name              = "/ecs/vote-${var.environment}"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "vote_fe" {
  name              = "/ecs/vote-fe-${var.environment}"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_ecs_task_definition" "api" {
  family                   = "evoting-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 4096
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "${aws_ecr_repository.nginx.repository_url}:latest"
      essential = true

      portMappings = [{
        containerPort = 8080
        protocol      = "tcp"
      }]

      dependsOn = [
        { containerName = "identity", condition = "START" },
        { containerName = "ballot",   condition = "START" },
        { containerName = "vote",     condition = "START" },
        { containerName = "vote-fe",  condition = "START" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.nginx.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "nginx"
        }
      }
    },

    {
      name      = "identity"
      image     = var.ghcr_image
      essential = true

      portMappings = [{
        containerPort = 8081
        protocol      = "tcp"
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost:8081/health || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      environment = [
        { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
        { name = "ASPNETCORE_URLS",        value = "http://+:8081" },
        { name = "Cognito__UserPoolId",    value = aws_cognito_user_pool.main.id },
        { name = "Cognito__ClientId",      value = aws_cognito_user_pool_client.api.id },
        { name = "Cognito__Region",        value = var.aws_region },
        { name = "DynamoDB__TableName",    value = aws_dynamodb_table.users.name },
        { name = "Frontend__Url",          value = var.frontend_url },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "identity"
        }
      }
    },

    {
      name      = "ballot"
      image     = var.ballot_ghcr_image
      essential = false

      portMappings = [{
        containerPort = 8082
        protocol      = "tcp"
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost:8082/health || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      environment = [
        { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
        { name = "ASPNETCORE_URLS",        value = "http://+:8082" },
        { name = "Frontend__Url",          value = var.frontend_url },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ballot.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ballot"
        }
      }
    },

    {
      name      = "vote"
      image     = var.vote_ghcr_image
      essential = false

      portMappings = [{
        containerPort = 8083
        protocol      = "tcp"
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost:8083/health || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      environment = [
        { name = "ASPNETCORE_ENVIRONMENT",  value = "Production" },
        { name = "ASPNETCORE_URLS",         value = "http://+:8083" },
        { name = "DynamoDB__Region",        value = var.aws_region },
        { name = "DynamoDB__TableName",     value = "evoting-votes" },
        { name = "DynamoDB__ServiceUrl",    value = "" },
        { name = "AuditDynamoDB__Region",   value = var.aws_region },
        { name = "AuditDynamoDB__TableName", value = "evoting-audit" },
        { name = "AuditDynamoDB__ServiceUrl", value = "" },
        { name = "Frontend__Url",           value = var.frontend_url },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.vote.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "vote"
        }
      }
    },

    {
      name      = "vote-fe"
      image     = var.vote_fe_ghcr_image
      essential = false

      portMappings = [{
        containerPort = 3000
        protocol      = "tcp"
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:3000/ || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT",     value = "3000" },
        { name = "HOSTNAME", value = "0.0.0.0" },
        { name = "API_URL",  value = "http://127.0.0.1:8080" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.vote_fe.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "vote-fe"
        }
      }
    },
  ])

  tags = local.tags
}

resource "aws_ecs_service" "api" {
  name            = "evoting-${var.environment}"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.identity_security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "nginx"
    container_port   = 8080
  }

  tags = local.tags
}
