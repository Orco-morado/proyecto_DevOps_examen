resource "aws_ecr_repository" "frontend" {
  name                 = "${lower(var.project_name)}-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
    Course  = "ISY1101"
  }
}

resource "aws_ecr_repository" "backend_despachos" {
  name                 = "${lower(var.project_name)}-back-despachos"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
    Course  = "ISY1101"
  }
}

resource "aws_ecr_repository" "backend_ventas" {
  name                 = "${lower(var.project_name)}-back-ventas"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
    Course  = "ISY1101"
  }
}
