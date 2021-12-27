terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.39"
    }

    auth0 = {
      source = "alexkappa/auth0"
      version = "~> 0.24"
    }
    google = {
      source = "hashicorp/google"
      version = "~> 3.57"
    }
  }

  /*
  backend "s3" {
    bucket = "opc-infra"
    key = "opc-dev-state"
    region = "ap-southeast-2"
  }
  */

  backend "remote" {
    organization = "opalpolicy"
    workspaces {
      name = "aws-infra"
    }
  }

}

provider "aws" {
  profile = "opc"
  region = var.region
}

provider "aws" {
  profile = "opc"
  region = "us-east-1"
  alias = "virginia"
}

provider "auth0" {
  domain = var.auth0_canonical_domain
  client_id = var.auth0_tf_client_id
  client_secret = var.auth0_tf_client_secret
  debug = "true"
}

provider "google" {
  project = "openpolicy-dev"
  region  = "australia-southeast1"
  //zone    = "australia-southeast1a"
}
