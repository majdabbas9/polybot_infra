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
  # profile = "default"  # change in case you want to work with another AWS account profile
}
# if infra == true then build the infrastructure
# else build the sqs dynamo s3
module "k8s-cluster" {
  source = "./modules/k8s-cluster"
  username = var.username
  azs    = var.azs
  ami = var.ami
  region = var.region
  key_pair_name = var.key_pair_name
}
