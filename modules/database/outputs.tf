output "resource_name" {
  value = aws_dynamodb_table.this.id
  description = "Nom de la table DynamoDB créée"
}