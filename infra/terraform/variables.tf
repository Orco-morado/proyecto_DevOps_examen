variable "aws_region" {
  description = "Region de AWS para el despliegue"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo del nombre de proyecto para nombrar recursos"
  type        = string
  default     = "devopsVG"
}

variable "cluster_version" {
  description = "Version del cluster EKS"
  type        = string
  default     = "1.32"
}
