terraform {
  required_version = ">= 0.13"

  backend "s3" {
    profile = "<AWS_ACCOUNT_NAME>"
    region  = "<AWS_REGION>"
    bucket  = "terraform.<AWS_ACCOUNT_NAME>"
    key     = "aws-env.tfstate"
  }
}

provider "aws" {
  region              = var.region
  profile             = var.profile_name
  version             = "= 2.66.0"
  allowed_account_ids = [var.account_id]
}


resource "aws_iam_account_alias" "account_alias" {
  account_alias = var.profile_name
}

resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 10
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = false
  allow_users_to_change_password = true
}

module "compute-env" {
  source = "./compute-env"
}
