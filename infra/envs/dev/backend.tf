# Remote state for the DEV environment. Each environment has its own bucket
# and key so a mistake in dev can never touch prod state.
#
# For an offline review (no AWS account) see scripts/tf-plan.sh, which swaps
# this for a local backend via a temporary *_override.tf file.
terraform {
  backend "s3" {
    bucket       = "hotel-bookings-tfstate-dev"
    key          = "hotel-bookings/dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
