variable "private_key_file" {
  type = string
  nullable = false
}

variable "region" {
  type = string
  nullable = false
}

provider "aws" {
  profile = "nixos-in-production"
  region = var.region
}

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

resource "aws_security_group" "todo" {
  # This is needed for the "nixos" module to manage the target host
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = [ "0.0.0.0/0" ]
  }

  # This is needed since we build on the target machine so that the machine can
  # download dependencies
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # This lets us access our web server
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_key_pair" "nixos-in-production" {
  public_key = file("${var.private_key_file}.pub")
}

module "ami" {
  source = "github.com/Gabriella439/terraform-nixos-ng//ami?ref=d8563d06cc65bc699ffbf1ab8d692b1343ecd927"
  release = "22.11"
  region = var.region
  system = "x86_64-linux"
}

resource "aws_instance" "todo" {
  ami = module.ami.ami
  instance_type = "t3.micro"
  security_groups = [ aws_security_group.todo.name ]
  key_name = aws_key_pair.nixos-in-production.key_name

  root_block_device {
    volume_size = 7
  }
}

# This ensures that the instance is reachable via `ssh` before we deploy NixOS
resource "null_resource" "wait" {
  provisioner "remote-exec" {
    connection {
      host = aws_instance.todo.public_dns
      private_key = file(var.private_key_file)
    }

    inline = [ ":" ]
  }
}

module "nixos" {
  source = "github.com/Gabriella439/terraform-nixos-ng//nixos?ref=d8563d06cc65bc699ffbf1ab8d692b1343ecd927"
  host = "root@${aws_instance.todo.public_ip}"
  flake = ".#default"
  arguments = [ "--build-host", "root@${aws_instance.todo.public_ip}" ]
  ssh_options = "-o StrictHostKeyChecking=accept-new"
  depends_on = [ null_resource.wait ]
}

output "public_dns" {
  value = aws_instance.todo.public_dns
}
