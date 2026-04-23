output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.api.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.users.name
}

output "nginx_ecr_repository_url" {
  description = "ECR URL for the nginx sidecar image — built and pushed by the infra CI"
  value       = aws_ecr_repository.nginx.repository_url
}

output "cognito_user_groups" {
  value = keys(aws_cognito_user_group.main)
}

output "seed_users" {
  description = "Seeded test user emails (dev only)"
  value       = { for k, v in local.seed_users : k => v.email }
}
