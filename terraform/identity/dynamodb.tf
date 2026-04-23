resource "aws_dynamodb_table" "users" {
  name         = "identity-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  tags = local.tags
}
