variable "aws_region" {
  type        = string
  description = "Région AWS utilisée pour les ressources"
}

variable "floci_endpoint" {
  type        = string
  description = "URL de l'endpoint local de Floci (émulateur AWS)"
}

variable "project_name" {
  type        = string
  description = "Nom du projet"
}

variable "environment" {
  type        = string
  description = "Environnement"
}