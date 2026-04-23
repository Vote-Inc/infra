resource "aws_cognito_user_pool" "main" {
  name = "identity-${var.environment}"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = local.tags
}

resource "aws_cognito_user_pool_client" "api" {
  name         = "identity-api-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  generate_secret                      = false
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation              = true
  refresh_token_validity               = 30
  access_token_validity                = 1
  id_token_validity                    = 1

  token_validity_units {
    refresh_token = "days"
    access_token  = "hours"
    id_token      = "hours"
  }
}

resource "aws_cognito_user_group" "main" {
  for_each = toset(["voters", "admin"])

  name         = each.key
  user_pool_id = aws_cognito_user_pool.main.id
}

locals {
  tags = {
    Environment = var.environment
    Application = "identity"
    ManagedBy   = "terraform"
  }
}
