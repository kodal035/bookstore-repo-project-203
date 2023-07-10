terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.7.0"
    }
        github = {
      source = "integrations/github"
      version = "5.29.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "github" {
    token = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

resource "github_repository" "bookstore-project-203" {
    name = "bookstore-repo-project-203"
    auto_init = true
    visibility = "public"   
}

resource "github_branch_default" "main" {
    branch = "main"
    repository = github_repository.bookstore-project-203.name  
}

variable "files" {
    default = ["bookstore-api.py", "Dockerfile", "docker-compose.yml", "requirements.txt"]
  
}

resource "github_repository_file" "myfiles" {
    for_each = toset(var.files)    
    content = file(each.value)
    file = each.value
    repository = github_repository.bookstore-project-203.name
    branch = "main"
    commit_message = "managed by terraform"
    overwrite_on_create = true
}

resource "aws_instance" "tf-docker-ec2" {
    ami = "ami-0f9fc25dd2506cf6d"
    instance_type = "t2.micro"
    key_name = "firstpemkey"
    security_groups = ["kodal035-docker-sec-gr-203"] 
    tags = {
        Name = "Kodal035-Web Server of Bookstore"
    }
    user_data = <<-EOF
          #! /bin/bash
          yum update -y
          amazon-linux-extras install docker -y
          systemctl start docker
          systemctl enable docker
          usermod -a -G docker ec2-user
          curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)" \
          -o /usr/local/bin/docker-compose
          chmod +x /usr/local/bin/docker-compose  
          mkdir -p /home/ec2-user/bookstore-api
          cd /home/ec2-user/bookstore-api          
          TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
          FOLDER="https://$TOKEN@raw.githubusercontent.com/kodal035/bookstore-repo-project-203/main/"
          curl -s -o bookstore-api.py -L "$FOLDER"bookstore-api.py 
          curl -s -o Dockerfile -L "$FOLDER"Dockerfile 
          curl -s -o docker-compose.yml -L "$FOLDER"docker-compose.yml 
          curl -s -o requirements.txt -L "$FOLDER"requirements.txt 
          docker build -t bookstore-api:latest .
          docker-compose up -d
        EOF
    depends_on = [github_repository.bookstore-project-203, github_repository_file.myfiles]
           
}

resource "aws_security_group" "tf-docker-ec2-sec-gr" {
    name = "kodal035-docker-sec-gr-203"
    tags = {
      "Name" = "docker-sec-gr-203"
    }
    ingress {
        from_port = 80
        protocol = "tcp"
        to_port = 80
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        protocol = "tcp"
        to_port = 22
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        protocol = "-1"
        to_port = 0
        cidr_blocks = ["0.0.0.0/0"]
    }
 
}

output "website" {
    value = "http://${aws_instance.tf-docker-ec2.public_dns}"
}
