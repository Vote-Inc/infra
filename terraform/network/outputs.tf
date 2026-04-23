output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "alb_dns_name" {
  description = "Public entry point for the entire application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_target_group_arn" {
  description = "Pass to the identity stack so its ECS service registers with the ALB"
  value       = aws_lb_target_group.identity.arn
}

output "identity_security_group_id" {
  value = aws_security_group.identity.id
}
