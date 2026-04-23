output "votes_table_name" {
  value = aws_dynamodb_table.votes.name
}

output "audit_table_name" {
  value = aws_dynamodb_table.audit.name
}
