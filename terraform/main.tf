terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket" # Replace with your actual bucket name
    key    = "mediahub/terraform.tfstate"
    region = "us-east-1"
  }
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

# Fetch the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security Group to allow necessary ports
resource "aws_security_group" "web_sg" {
  name        = "front-ap-sg"
  description = "Allow SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# The EC2 Instance
resource "aws_instance" "vm" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "media-hub" 
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data =   file("${path.module}/setup.sh")

  tags = {
    Name = "MediaHub-Backend"
  }
}

# Elastic IP to keep the IP address static
resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id
  domain   = "vpc"
}

# Output the IP so GitHub Actions can use it for SSH
output "public_ip" {
  value = aws_eip.app_eip.public_ip
  description = "Click this link to access your hosted Media-hub frontend project."
}
