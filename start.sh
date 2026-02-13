#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Stand up OpenClaw: prerequisites, Helm deps, Terraform init/apply, healthchecks.
# On failure, prints what went wrong and suggested fix.
# Usage: ./start.sh
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default namespace/release (must match terraform.tfvars if you changed them)
NAMESPACE="${OPENCLAW_NAMESPACE:-openclaw}"
RELEASE_NAME="${OPENCLAW_RELEASE:-openclaw}"
# Gateway deployment name (release + chart name "openclaw" + "-gateway")
GATEWAY_DEPLOYMENT="${RELEASE_NAME}-openclaw-gateway"
# Secret created by Vault bootstrap job; gateway waits for this (chart default)
VAULT_GATEWAY_TOKEN_SECRET="${OPENCLAW_VAULT_GATEWAY_TOKEN_SECRET:-openclaw-vault-gateway-token}"
# Vault service/deployment name (main chart: release-openclaw-vault)
VAULT_SERVICE_NAME="${RELEASE_NAME}-openclaw-vault"
BOOTSTRAP_KEYS_SECRET_NAME="${VAULT_SERVICE_NAME}-bootstrap-keys"
# App-secrets Secret name (Terraform creates this when gateway_token etc. are set)
VAULT_APP_SECRETS_SECRET="${OPENCLAW_VAULT_APP_SECRETS_SECRET:-openclaw-vault-app-secrets}"
BOOTSTRAP_CHART_PATH="helm/openclaw-bootstrap"

fail() {
  echo ""
  echo "=== FAILED ==="
  echo -e "$1"
  echo ""
  echo "--- How to fix ---"
  echo -e "$2"
  echo ""
  exit 1
}

step() {
  echo ""
  echo ">>> $1"
}

# Poll until CMD succeeds or TIMEOUT seconds. INTERVAL between tries. On failure, call fail with MSG and FIX.
wait_for_check() {
  local desc="$1"
  local cmd="$2"
  local timeout_sec="${3:-60}"
  local interval_sec="${4:-5}"
  local fix_msg="$5"
  local elapsed=0
  while [[ $elapsed -lt "$timeout_sec" ]]; do
    if eval "$cmd" &>/dev/null; then
      echo "  [OK] $desc"
      return 0
    fi
    echo "  ... $desc (${elapsed}s / ${timeout_sec}s)"
    sleep "$interval_sec"
    elapsed=$((elapsed + interval_sec))
  done
  fail "Check failed after ${timeout_sec}s: $desc" "$fix_msg"
}

# --- Prerequisites ---
step "Checking prerequisites (kubectl, terraform, helm)"
for cmd in kubectl terraform helm; do
  if ! command -v "$cmd" &>/dev/null; then
    fail "Missing required command: $cmd" \
      "Install $cmd and ensure it is on your PATH. See README.md Prerequisites."
  fi
done

if ! kubectl cluster-info &>/dev/null; then
  fail "Cannot reach Kubernetes cluster (kubectl cluster-info failed)." \
    "Start a cluster (e.g. kind create cluster --name openclaw) and ensure KUBECONFIG or ~/.kube/config is set."
fi

# --- Config ---
step "Checking Terraform config"
if [[ ! -f terraform/terraform.tfvars ]]; then
  fail "terraform/terraform.tfvars not found." \
    "Copy: cp terraform/terraform.tfvars.example terraform/terraform.tfvars\n   Then edit and set namespace, chart_path, ingress_domain, tailscale_hostname, gateway_token."
fi

# --- Helm dependencies ---
step "Updating Helm chart dependencies"
if ! (cd helm/openclaw && helm dependency update .); then
  fail "helm dependency update failed in helm/openclaw." \
    "Check that helm/openclaw/Chart.yaml and Chart.lock exist. Run from repo root: helm dependency update ./helm/openclaw"
fi

# --- Terraform init (main) ---
step "Terraform init (main stack)"
if ! (cd terraform && terraform init -input=false); then
  fail "terraform init failed in terraform/." \
    "Check network access and Terraform/provider versions. Run: cd terraform && terraform init"
fi

# --- Terraform plan (main) ---
step "Terraform plan (main stack)"
if ! (cd terraform && terraform plan -var-file=terraform.tfvars -out=tfplan -input=false); then
  fail "terraform plan failed." \
    "Fix variable or provider errors in terraform.tfvars or variables.tf. Run: cd terraform && terraform plan -var-file=terraform.tfvars"
fi

# --- Terraform apply (main) ---
step "Terraform apply (main stack)"
if ! (cd terraform && terraform apply -input=false tfplan); then
  fail "terraform apply failed." \
    "Inspect the error above. Common fixes: ensure cluster is up, chart_path is correct (e.g. ../helm/openclaw from terraform/), and required vars are set in terraform.tfvars."
fi
rm -f terraform/tfplan

# --- Healthcheck: namespace ---
step "Healthcheck: namespace"
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  fail "Namespace $NAMESPACE not found after apply." \
    "Terraform may have used a different namespace. Check: kubectl get ns. If you use a custom namespace in terraform.tfvars, set OPENCLAW_NAMESPACE and re-run."
fi

# --- Healthcheck: Helm release ---
step "Healthcheck: Helm release"
if ! helm list -n "$NAMESPACE" -q 2>/dev/null | grep -q "^${RELEASE_NAME}$"; then
  fail "Helm release '$RELEASE_NAME' not found in namespace $NAMESPACE." \
    "Check: helm list -n $NAMESPACE. If release name differs in terraform.tfvars, set OPENCLAW_RELEASE and re-run. Inspect: helm status -n $NAMESPACE $RELEASE_NAME"
fi

# --- Healthcheck: pods not in bad state (excluding gateway and Vault Job pods; those are handled in checklist) ---
step "Healthcheck: pod status"
BAD_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | awk '
  ($3=="Error" || $3=="CrashLoopBackOff" || $3=="ImagePullBackOff" || $3=="ErrImagePull") &&
  ($1 !~ /vault-bootstrap|vault-app-secrets/) { print $1 " (" $3 ")" }' || true)
if [[ -n "$BAD_PODS" ]]; then
  fail "Some pods are in a bad state:\n$BAD_PODS" \
    "Inspect: kubectl describe pod -n $NAMESPACE <pod>\n   Logs: kubectl logs -n $NAMESPACE <pod> [--previous]"
fi

# --- Scale gateway to 0 so it doesn't sit in init waiting; we'll bring it up after checklist ---
step "Pausing gateway until Vault is ready"
if kubectl get deployment -n "$NAMESPACE" "$GATEWAY_DEPLOYMENT" &>/dev/null; then
  kubectl scale deployment -n "$NAMESPACE" "$GATEWAY_DEPLOYMENT" --replicas=0
  echo "  Gateway scaled to 0; will start after checklist passes."
else
  echo "  Gateway deployment not found (name: $GATEWAY_DEPLOYMENT); skipping scale-down."
fi

# --- Vault + gateway checklist: Vault ready, then bootstrap (second Helm release), then gateway ---
step "Checklist: Vault pod and service (must pass before bootstrap)"
wait_for_check \
  "Vault pod is Running" \
  "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=vault --field-selector=status.phase=Running -o name | grep -q ." \
  120 5 \
  "Vault did not become Ready. Check: kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=vault; kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/component=vault; kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=vault --tail=50"

# vault status exits 0 when sealed+initialized, 2 when not initialized/sealed (server is still reachable)
wait_for_check \
  "Vault service is reachable" \
  "kubectl exec -n $NAMESPACE deploy/$VAULT_SERVICE_NAME -- sh -c 'vault status >/dev/null 2>&1; r=\$?; [ \$r -eq 0 ] || [ \$r -eq 2 ]'" \
  60 5 \
  "Vault pod is running but vault status failed. Check: kubectl exec -n $NAMESPACE deploy/$VAULT_SERVICE_NAME -- vault status; kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=vault --tail=50"

step "Installing Vault bootstrap (openclaw-bootstrap chart)"
BOOTSTRAP_SET_APP=""
if kubectl get secret -n "$NAMESPACE" "$VAULT_APP_SECRETS_SECRET" &>/dev/null; then
  BOOTSTRAP_SET_APP="--set appSecretsSecretName=$VAULT_APP_SECRETS_SECRET"
  echo "  App-secrets Secret $VAULT_APP_SECRETS_SECRET found; bootstrap chart will run app-secrets Job."
fi
if ! helm upgrade --install openclaw-bootstrap "$BOOTSTRAP_CHART_PATH" -n "$NAMESPACE" \
  --set namespace="$NAMESPACE" \
  --set vaultServiceName="$VAULT_SERVICE_NAME" \
  --set bootstrapKeysSecretName="$BOOTSTRAP_KEYS_SECRET_NAME" \
  --set gatewayTokenSecretName="$VAULT_GATEWAY_TOKEN_SECRET" \
  $BOOTSTRAP_SET_APP 2>&1; then
  fail "Helm install/upgrade openclaw-bootstrap failed." \
    "Check: helm list -n $NAMESPACE; helm status openclaw-bootstrap -n $NAMESPACE; kubectl get all -n $NAMESPACE -l app.kubernetes.io/name=openclaw-bootstrap"
fi
echo "  [OK] openclaw-bootstrap chart installed."

step "Checklist: bootstrap Job and gateway token"
wait_for_check \
  "Vault bootstrap job succeeded" \
  "kubectl get job -n $NAMESPACE -l app.kubernetes.io/component=vault-bootstrap -o jsonpath='{.items[0].status.succeeded}' 2>/dev/null | grep -q 1" \
  600 10 \
  "Bootstrap job did not succeed. Check: kubectl logs job/ -n $NAMESPACE -l app.kubernetes.io/component=vault-bootstrap; kubectl describe job -n $NAMESPACE -l app.kubernetes.io/component=vault-bootstrap. Fix Vault/init issues then delete the job and re-run: helm upgrade openclaw-bootstrap $BOOTSTRAP_CHART_PATH -n $NAMESPACE ..."

wait_for_check \
  "Gateway token secret exists ($VAULT_GATEWAY_TOKEN_SECRET)" \
  "kubectl get secret -n $NAMESPACE $VAULT_GATEWAY_TOKEN_SECRET -o name &>/dev/null" \
  30 3 \
  "Secret $VAULT_GATEWAY_TOKEN_SECRET not found. Bootstrap job should create it. Check: kubectl get secret -n $NAMESPACE; kubectl logs job/ -n $NAMESPACE -l app.kubernetes.io/component=vault-bootstrap"

# Optional: vault-app-secrets job (populates openclaw/gateway from Terraform Secret)
if kubectl get job -n "$NAMESPACE" -l app.kubernetes.io/component=vault-app-secrets &>/dev/null; then
  wait_for_check \
    "Vault app-secrets job succeeded" \
    "kubectl get job -n $NAMESPACE -l app.kubernetes.io/component=vault-app-secrets -o jsonpath='{.items[0].status.succeeded}' 2>/dev/null | grep -q 1" \
    300 10 \
    "App-secrets job did not succeed. Check: kubectl logs job/ -n $NAMESPACE -l app.kubernetes.io/component=vault-app-secrets; ensure Terraform created the app-secrets Secret and keys (e.g. gateway_token)."
fi

step "Starting OpenClaw gateway"
kubectl scale deployment -n "$NAMESPACE" "$GATEWAY_DEPLOYMENT" --replicas=1
echo "  Gateway scaled to 1."

wait_for_check \
  "Gateway pod is Running" \
  "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=gateway --field-selector=status.phase=Running -o name | grep -q ." \
  120 5 \
  "Gateway pod did not reach Running. Check: kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=gateway; kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/component=gateway; kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=gateway --tail=100"

# --- Optional: Cloudflare DNS ---
CLOUDFLARE_DIR="terraform/cloudflare"
if [[ -f "$CLOUDFLARE_DIR/terraform.tfvars" ]]; then
  step "Applying Cloudflare DNS (optional)"
  if ! (cd "$CLOUDFLARE_DIR" && terraform init -input=false && terraform apply -var-file=terraform.tfvars -auto-approve -input=false); then
    echo ""
    echo "Cloudflare apply failed. Get Ingress IP and set ingress_ip in $CLOUDFLARE_DIR/terraform.tfvars then re-run:"
    echo "  kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=kubernetes-ingress"
    echo "  cd $CLOUDFLARE_DIR && terraform apply -var-file=terraform.tfvars"
    echo ""
    # Don't exit; main stack is up
  else
    echo "Cloudflare DNS apply done."
  fi
fi

# --- Success ---
echo ""
echo "=== OpenClaw is up ==="
echo ""
echo "Next steps:"
echo "  1. Get Ingress IP: kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=kubernetes-ingress"
echo "  2. Post-install (Control UI, Tailscale Serve, Signal): docs/POST-INSTALL.md"
echo ""
