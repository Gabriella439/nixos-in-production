terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.56"
    }
  }
}

variable "region" {
  type = string
  nullable = false
}

provider "aws" {
  profile = "nixos-in-production"
  region = var.region
}

resource "aws_security_group" "todo" {
  # The "nixos" Terraform module requires SSH access to the machine to deploy
  # our desired NixOS configuration.
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = [ "0.0.0.0/0" ]
  }

  # We will be building our NixOS configuration on the target machine, so we
  # permit all outbound connections so that the build can download any missing
  # dependencies.
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  # Allow port 80 so that we can view our TODO list web page
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

# Generate an SSH key pair as strings stored in Terraform state
resource "tls_private_key" "nixos-in-production" {
  algorithm = "ED25519"
}

# Synchronize the SSH private key to a local file that the "nixos" module can
# use
resource "local_sensitive_file" "ssh_private_key" {
    filename = "${path.module}/id_ed25519"
    content = tls_private_key.nixos-in-production.private_key_openssh
}

resource "local_file" "ssh_public_key" {
    filename = "${path.module}/id_ed25519.pub"
    content = tls_private_key.nixos-in-production.public_key_openssh
}

# Mirror the SSH public key to EC2 so that we can later install the public key
# as an authorized key for our server
resource "aws_key_pair" "nixos-in-production" {
  public_key = tls_private_key.nixos-in-production.public_key_openssh
}

module "ami" {
  source = "github.com/Gabriella439/terraform-nixos-ng//ami?ref=06d207ebc1c3de68d1bc52129d0fa23d61de5525"
  release = "23.05"
  region = var.region
  system = "x86_64-linux"
}

resource "aws_instance" "todo" {
  # This will be an AMI for a stock NixOS server which we'll get to below.
  ami = module.ami.ami

  # We could use a smaller instance size, but at the time of this writing the
  # t3.micro instance type is available for 750 hours under the AWS free tier.
  instance_type = "t3.micro"

  # Install the security groups we defined earlier
  security_groups = [ aws_security_group.todo.name ]

  # Install our SSH public key as an authorized key
  key_name = aws_key_pair.nixos-in-production.key_name

  # Request a bit more space because we will be building on the machine
  root_block_device {
    volume_size = 7
  }

  # We will use this in a future chapter to bootstrap other secrets
  user_data = <<-EOF
    #!/bin/sh
    (umask 377; echo '${tls_private_key.nixos-in-production.private_key_openssh}' > /var/lib/id_ed25519)
    EOF
}

# This ensures that the instance is reachable via `ssh` before we deploy NixOS
resource "null_resource" "wait" {
  provisioner "remote-exec" {
    connection {
      host = aws_instance.todo.public_dns
      private_key = tls_private_key.nixos-in-production.private_key_openssh
    }

    inline = [ ":" ]  # Do nothing; we're just testing SSH connectivity
  }
}

module "nixos" {
  source = "github.com/Gabriella439/terraform-nixos-ng//nixos?ref=06d207ebc1c3de68d1bc52129d0fa23d61de5525"
  host = "root@${aws_instance.todo.public_ip}"
  flake = ".#default"
  arguments = [ "--build-host", "root@${aws_instance.todo.public_ip}" ]
  ssh_options = "-o StrictHostKeyChecking=accept-new -i ${local_sensitive_file.ssh_private_key.filename}"
  depends_on = [ null_resource.wait ]
}

output "public_dns" {
  value = aws_instance.todo.public_dns
}
