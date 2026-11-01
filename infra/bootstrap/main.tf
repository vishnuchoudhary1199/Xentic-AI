# One-time setup: the S3 buckets that hold the dev and prod Terraform state.
# This stack keeps its own state locally (it only manages two buckets).
#
#   cd infra/bootstrap
#   terraform init
#   terraform apply
#
# Bucket names are global. If the defaults are taken, override state_buckets and
# pass the same name to the env with: terraform init -backend-config="bucket=<name>"

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "hotel-bookings"
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}

variable "aws_region" {
  description = "Region for the state buckets."
  type        = string
  default     = "ap-south-1"
}

variable "state_buckets" {
  description = "Environment => state bucket name. Must match bucket in envs/<env>/backend.tf."
  type        = map(string)
  default = {
    dev  = "hotel-bookings-tfstate-dev"
    prod = "hotel-bookings-tfstate-prod"
  }
}

resource "aws_s3_bucket" "state" {
  for_each = var.state_buckets

  bucket = each.value

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  for_each = aws_s3_bucket.state

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Old state versions are kept for 90 days so a bad apply can be rolled back.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

data "aws_iam_policy_document" "tls_only" {
  for_each = aws_s3_bucket.state

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      each.value.arn,
      "${each.value.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id
  policy = data.aws_iam_policy_document.tls_only[each.key].json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

output "state_buckets" {
  description = "Created state buckets."
  value       = { for env, b in aws_s3_bucket.state : env => b.bucket }
}
