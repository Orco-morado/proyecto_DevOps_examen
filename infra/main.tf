terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" 
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# GRUPO DE SEGURIDAD CORREGIDO CON TUS PUERTOS REALES
resource "aws_security_group" "sg_proyecto_devops" {
  name        = "sg_proyecto_sistema_unificado" 
  description = "Reglas de red ajustadas a los puertos originales del estudiante" 

  # Puerto 22: SSH para administración y GitHub Actions
  ingress {
    from_port   = 22 
    to_port     = 22 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Puerto 8081: Tu Frontend React (Nginx sin root)
  ingress {
    from_port   = 8081 
    to_port     = 8081 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Puerto 8082: Tu API de Despachos
  ingress {
    from_port   = 8082 
    to_port     = 8082 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Puerto 8083: Tu API de Ventas
  ingress {
    from_port   = 8083 
    to_port     = 8083 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # EGRESS: Salida total a internet para descargar Docker y actualizar paquetes
  egress {
    from_port   = 0 
    to_port     = 0 
    protocol    = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
  }
}

# INSTANCIA EC2: Servidor Ubuntu (t3.medium)
resource "aws_instance" "servidor_devops" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"           
  key_name      = "vockey" 

  vpc_security_group_ids = [aws_security_group.sg_proyecto_devops.id] 

  tags = {
    Name = "Servidor-Ecosistema-Potente" 
  }
}

output "instancia_ip_publica" {
  value       = aws_instance.servidor_devops.public_ip
  description = "La nueva IP pública del servidor"
}