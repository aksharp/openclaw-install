# ---------------------------------------------------------------------------
# OpenClaw Terraform — namespace, app secrets Secret, Helm release, DNS, Tailscale
# Run: terraform init && terraform plan -var-file=terraform.tfvars && terraform apply -var-file=terraform.tfvars
# ---------------------------------------------------------------------------

locals {
  create_app_secrets = (var.gateway_token != "" || var.openai_api_key != "" || var.anthropic_api_key != "" || var.signal_account != "")
}

# --- Namespace ---

resource "kubernetes_namespace" "openclaw" {
  metadata {
    name = var.namespace
  }
}

# --- App secrets Secret (Job in chart reads this and populates Vault) ---

resource "kubernetes_secret_v1" "app_secrets" {
  count = local.create_app_secrets ? 1 : 0

  metadata {
    name      = var.vault_app_secrets_secret_name
    namespace = kubernetes_namespace.openclaw.metadata[0].name
  }

  data = {
    gateway_token     = base64encode(var.gateway_token)
    openai_api_key    = base64encode(var.openai_api_key)
    anthropic_api_key = base64encode(var.anthropic_api_key)
    signal_account    = base64encode(var.signal_account)
  }

  type = "Opaque"
}

# --- Helm release ---

resource "helm_release" "openclaw" {
  name             = var.release_name
  namespace        = kubernetes_namespace.openclaw.metadata[0].name
  repository       = null
  chart            = var.chart_path
  create_namespace = false
  wait             = false # Don't block on post-upgrade hook (Vault bootstrap Job); it runs in background; gateway waits for secret
  timeout          = 300

  values = [
    yamlencode({
      openclaw = {
        image = {
          tag = var.openclaw_image_tag
        }
      }
      tailscale = {
        hostname = var.tailscale_hostname
      }
      ingress = {
        domain = var.ingress_domain
      }
      vault = {
        bootstrap = {
          installSeparately = true   # Bootstrap Job installed by start.sh after Vault is reachable (openclaw-bootstrap chart)
        }
        appSecretsSecret = local.create_app_secrets ? var.vault_app_secrets_secret_name : ""
      }
    })
  ]

  # Ensure app-secrets Secret exists before install so the app-secrets Job can run
  depends_on = [kubernetes_secret_v1.app_secrets]
}

# --- DNS (Cloudflare) — optional; run from terraform/cloudflare/ when needed ---

# --- Tailscale: ACL or DNS preferences (provider auth via env TAILSCALE_API_KEY or OAuth) ---

# Uncomment and set tailscale_oauth_* if you want to manage Tailscale resources.
# Example: MagicDNS preferences or ACL. Serve is per-machine and may require node auth.
# resource "tailscale_dns_preferences" "prefs" {
#   magic_dns = true
# }
# See: https://registry.terraform.io/providers/tailscale/tailscale/latest/docs
