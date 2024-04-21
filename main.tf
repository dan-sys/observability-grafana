terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "iamadmin"
}

terraform {
  backend "s3" {
    bucket  = "tfstate-bucket-observe-with-grafana"
    key     = "build/terraform.tfstate"
    region  = "us-east-1"
  }
}


resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "tfstate-bucket-observe-with-grafana"
  force_destroy = true
}

# ec2 