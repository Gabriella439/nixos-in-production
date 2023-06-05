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

resource "aws_s3_bucket" "nixos-in-production" {
  bucket_prefix = "nixos-in-production"
}

resource "aws_s3_bucket_versioning" "nixos-in-production" {
  bucket = aws_s3_bucket.nixos-in-production.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "nixos-in-production" {
  name = "terraform-state"

  read_capacity = 1

  write_capacity = 1

  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

data "aws_iam_policy_document" "nixos-in-production" {
  statement {
    actions = [ "s3:ListBucket" ]

    resources = [ aws_s3_bucket.nixos-in-production.arn ]
  }

  statement {
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]

    resources = [ "${aws_s3_bucket.nixos-in-production.arn}/*" ]
  }

  statement {
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]

    resources = [
      "${aws_dynamodb_table.nixos-in-production.arn}/nixos-in-production"
    ]
  }
}

data "aws_caller_identity" "nixos-in-production" { }

resource "aws_iam_user_policy" "nixos-in-production" {
  policy = data.aws_iam_policy_document.nixos-in-production.json

  user = "${split("/", data.aws_caller_identity.nixos-in-production.arn)[1]}"
}

output "bucket" {
  value = aws_s3_bucket.nixos-in-production.id
}
