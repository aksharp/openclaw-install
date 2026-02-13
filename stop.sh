#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Tear down OpenClaw: Terraform destroy (Cloudflare optional, then main).
# Usage: ./stop.sh [ -y | --yes ]  # -y skips confirmation
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

confirm() {
  if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
    return 0
  fi
  echo "This will destroy all Terraform-managed resources (namespace, Helm release, optional DNS)."
  read -r -p "Continue? [y/N] " reply
  case "$reply" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
}

confirm "$1"

# Optional: destroy Cloudflare DNS first (if terraform.tfvars exists there)
CLOUDFLARE_DIR="terraform/cloudflare"
if [[ -f "$CLOUDFLARE_DIR/terraform.tfvars" ]]; then
  echo "Destroying Cloudflare DNS (terraform/cloudflare)..."
  (cd "$CLOUDFLARE_DIR" && terraform init -input=false && terraform destroy -var-file=terraform.tfvars -auto-approve)
  echo "Cloudflare destroy done."
fi

# Bootstrap chart (second Helm release; not managed by Terraform)
if helm list -n openclaw -q 2>/dev/null | grep -q openclaw-bootstrap; then
  echo "Uninstalling openclaw-bootstrap..."
  helm uninstall openclaw-bootstrap -n openclaw 2>/dev/null || true
fi

# Main stack: namespace, app secrets, Helm release
echo "Destroying main stack (terraform/)..."
cd terraform
terraform init -input=false
terraform destroy -var-file=terraform.tfvars -auto-approve
echo "Done. OpenClaw Terraform resources have been destroyed."
