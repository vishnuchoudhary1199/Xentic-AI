#!/usr/bin/env bash
#
# Run fmt -> init -> validate -> plan for one Terraform environment.
#
#   ./scripts/tf-plan.sh dev            # real S3 backend + your AWS credentials
#   ./scripts/tf-plan.sh prod --offline # no AWS account needed (review / CI)
#
# --offline swaps the S3 backend for a throwaway local one (via a temporary
# backend_override.tf that is always removed on exit) and passes
# offline_plan=true so the AWS provider uses dummy credentials and makes no
# API calls. Combined with -refresh=false this yields a full, realistic plan of
# every resource without touching AWS.
#
# The plan is written to infra/envs/<env>/plan/ as a binary plan (tfplan) and a
# human-readable text file (tfplan.txt).
set -euo pipefail

usage() {
  echo "usage: $0 <dev|prod> [--offline]" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
ENV_NAME="$1"
OFFLINE=false
[[ "${2:-}" == "--offline" ]] && OFFLINE=true

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT_DIR}/infra/envs/${ENV_NAME}"
[[ -d "${ENV_DIR}" ]] || { echo "error: no such environment: ${ENV_DIR}" >&2; exit 2; }

command -v terraform >/dev/null || { echo "error: terraform is not installed" >&2; exit 1; }

cd "${ENV_DIR}"
mkdir -p plan

echo "==> terraform fmt -check (whole infra tree)"
terraform -chdir="${ROOT_DIR}/infra" fmt -check -recursive -diff

PLAN_ARGS=(-refresh=false -input=false -out=plan/tfplan)

if [[ "${OFFLINE}" == true ]]; then
  OVERRIDE="${ENV_DIR}/backend_override.tf"
  trap 'rm -f "${OVERRIDE}"' EXIT
  cat > "${OVERRIDE}" <<EOF
# Temporary file written by scripts/tf-plan.sh --offline. Do not commit.
terraform {
  backend "local" {
    path = "plan/offline.tfstate"
  }
}
EOF
  PLAN_ARGS+=(-var=offline_plan=true -lock=false)
  echo "==> terraform init (offline: local backend)"
  terraform init -input=false -reconfigure
else
  echo "==> terraform init (S3 backend)"
  terraform init -input=false
fi

echo "==> terraform validate"
terraform validate

echo "==> terraform plan ${PLAN_ARGS[*]}"
terraform plan "${PLAN_ARGS[@]}"

terraform show -no-color plan/tfplan > plan/tfplan.txt
echo
echo "Plan saved: ${ENV_DIR}/plan/tfplan.txt"
grep -E '^Plan:' plan/tfplan.txt || true
