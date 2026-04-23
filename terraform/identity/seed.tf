locals {
  seed_users = var.environment == "dev" ? {
    voter1 = { email = "voter1@test.com", group = "voters" }
    voter2 = { email = "voter2@test.com", group = "voters" }
    voter3 = { email = "voter3@test.com", group = "voters" }
    admin1 = { email = "admin@test.com", group = "admin" }
  } : {}
}

resource "aws_cognito_user" "seed" {
  for_each = local.seed_users

  user_pool_id   = aws_cognito_user_pool.main.id
  username       = each.value.email
  password       = var.seed_user_password
  message_action = "SUPPRESS"

  attributes = {
    email          = each.value.email
    email_verified = "true"
  }
}

resource "aws_cognito_user_in_group" "seed" {
  for_each = local.seed_users

  user_pool_id = aws_cognito_user_pool.main.id
  username     = aws_cognito_user.seed[each.key].username
  group_name   = aws_cognito_user_group.main[each.value.group].name
}

resource "random_uuid" "seed_user_id" {
  for_each = local.seed_users
}

resource "aws_dynamodb_table_item" "seed_users" {
  for_each   = local.seed_users
  table_name = aws_dynamodb_table.users.name
  hash_key   = aws_dynamodb_table.users.hash_key

  item = jsonencode({
    pk     = { S = each.value.email }
    userId = { S = random_uuid.seed_user_id[each.key].result }
  })
}
