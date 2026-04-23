
resource "aws_dynamodb_table" "votes" {
  name         = "evoting-votes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "electionId"
  range_key    = "voterHash"

  attribute {
    name = "electionId"
    type = "S"
  }

  attribute {
    name = "voterHash"
    type = "S"
  }

  tags = local.tags
}

resource "aws_dynamodb_table" "audit" {
  name         = "evoting-audit"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "electionId"
  range_key    = "version"

  attribute {
    name = "electionId"
    type = "S"
  }

  attribute {
    name = "version"
    type = "N"
  }

  attribute {
    name = "receiptId"
    type = "S"
  }

  global_secondary_index {
    name            = "receiptId-index"
    hash_key        = "receiptId"
    projection_type = "ALL"
  }

  tags = local.tags
}
