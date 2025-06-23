terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.55"
    }
  }
  backend "s3" {
    bucket = "majd-tf-bucket"
    key    = "tfstate.json"
    region = "eu-west-1"
    # dynamodb_table = "<table-name>"  # Optional for state locking
  }
  required_version = ">= 1.7.0"
}

provider "aws" {
  region  = var.region
  profile = "default"  # change in case you want to work with another AWS account profile
}

resource "aws_instance" "polybot_app" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  tags = {
    Name      = "majd-tf-practice-${var.env}"
    Terraform = "true"
    env = var.env
  }
}
