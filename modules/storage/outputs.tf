output "resource_name" {
  value = aws_s3_bucket.this.id
  description = "Nom du bucket S3 créé"
}