resource "aws_ecs_cluster" "main" {
  name = "evoting-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}
