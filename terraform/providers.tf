terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Oder eine aktuelle stabile Version
    }
  }

  backend "s3" {
    # Konfiguration wird über Umgebungsvariablen oder Backend-Config-Datei in CI gesetzt
    # bucket         = "WIRD_IN_CI_GESETZT_ODER_HIER_HARTCODIERT" # Verwende Secret TF_STATE_BUCKET
    # key            = "global/s3/terraform.tfstate"
    # region         = "WIRD_IN_CI_GESETZT_ODER_HIER_HARTCODIERT" # Verwende Secret AWS_REGION
    # dynamodb_table = "WIRD_IN_CI_GESETZT_ODER_HIER_HARTCODIERT" # Verwende Secret TF_STATE_DYNAMODB_TABLE
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  # Credentials werden durch die GitHub Action aws-actions/configure-aws-credentials
  # als Umgebungsvariablen bereitgestellt (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY).
}