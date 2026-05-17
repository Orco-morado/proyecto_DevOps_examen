provider "aws" {
  region = "us-east-1"
}

# Grupo de seguridad para abrir los puertos del ecosistema Docker
resource "aws_security_group" "sg_proyecto_devops" {
  name        = "sg_proyecto_nota2"
  description = "Reglas de red para el frontend y microservicios"

  # Acceso SSH para administrar el servidor
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto del Frontend (React)
  ingress {
    from_port   = 5173
    to_port     = 5173
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto de la API de Despachos
  ingress {
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto de la API de Ventas
  ingress {
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Salida a internet permitida para descargar Docker y paquetes
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instancia EC2 Ubuntu tamaño t2.micro (Capa gratuita)
resource "aws_instance" "servidor_devops" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu Server 22.04 LTS en us-east-1
  instance_type = "t2.micro"             # Exigido por la rúbrica

  # Vincula las reglas de los puertos a esta máquina
  vpc_security_group_ids = [aws_security_group.sg_proyecto_devops.id]

  tags = {
    Name = "Servidor-Ecosistema-Nota2"
  }
}