terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # --- BACKEND SU S3 (La memoria remota) ---
  backend "s3" {
    bucket         = "us-east-1-terraform-progetto-prova"
    key            = "dev/terraform.tfstate"           # <--- Nota: cartella "dev"
    region         = "us-east-1"                        # La regione del BUCKET
    dynamodb_table = "terraform-prova-pipeline"
    encrypt        = true
  }
}

# (Il resto del provider aws rimane uguale)
provider "aws" {
  region = var.aws_region
}