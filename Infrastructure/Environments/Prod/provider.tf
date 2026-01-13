terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # --- BACKEND SU S3 ---
  backend "s3" {
    bucket         = "us-east-1-terraform-progetto-prova"
    key            = "prod/terraform.tfstate"           # <--- Nota: cartella "prod"
    region         = "us-east-1"
    dynamodb_table = "terraform-prova-pipeline"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}