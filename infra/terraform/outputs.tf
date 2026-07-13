data "aws_caller_identity" "current" {}

output "aws_region" {
  description = "Region de AWS"
  value       = var.aws_region
}

output "cluster_name" {
  description = "Nombre del cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "vpc_id" {
  description = "ID de la VPC principal"
  value       = aws_vpc.main.id
}

output "frontend_repository_url" {
  description = "URL del repositorio ECR para el frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_despachos_repository_url" {
  description = "URL del repositorio ECR para backend despachos"
  value       = aws_ecr_repository.backend_despachos.repository_url
}

output "backend_ventas_repository_url" {
  description = "URL del repositorio ECR para backend ventas"
  value       = aws_ecr_repository.backend_ventas.repository_url
}
