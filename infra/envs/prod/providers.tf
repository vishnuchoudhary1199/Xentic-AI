provider "aws" {
  region = var.aws_region

  # offline_plan = true lets reviewers run `terraform plan -refresh=false`
  # without an AWS account: dummy credentials and no STS/metadata calls.
  # Never set it for a real apply.
  access_key                  = var.offline_plan ? "mock-access-key" : null
  secret_key                  = var.offline_plan ? "mock-secret-key" : null
  skip_credentials_validation = var.offline_plan
  skip_requesting_account_id  = var.offline_plan
  skip_metadata_api_check     = var.offline_plan

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "Xentic-AI"
    }
  }
}
