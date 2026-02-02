# ---------------------------------------------------------------------------
# OpenClaw Terraform — single config for cluster, Vault app secrets, DNS, Tailscale
# Copy terraform.tfvars.example to terraform.tfvars and set values.
# ---------------------------------------------------------------------------

variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/config"
  description = "Path to kubeconfig. Default works for kind/minikube. Override if your config is elsewhere."
}

variable "namespace" {
  type        = string
  default     = "openclaw"
  description = "Kubernetes namespace for OpenClaw."
}

variable "release_name" {
  type        = string
  default     = "openclaw"
  description = "Helm release name."
}

variable "chart_path" {
  type        = string
  description = "Path to the OpenClaw Helm chart (e.g. ../helm/openclaw)."
}

variable "openclaw_image_tag" {
  type        = string
  default     = "v1.0.0"
  description = "OpenClaw container image tag."
}

variable "ingress_domain" {
  type        = string
  description = "Base domain for Ingress (e.g. openclaw.local or your-domain.com)."
}

variable "tailscale_hostname" {
  type        = string
  default     = "openclaw"
  description = "Tailscale hostname for this node (from tailscale status or admin)."
}

# --- App secrets (stored in K8s Secret, then Job pushes to Vault) ---

variable "gateway_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "OpenClaw gateway token (stored in Vault openclaw/gateway)."
}

variable "openai_api_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "OpenAI API key (stored in Vault openclaw/gateway)."
}

variable "anthropic_api_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Anthropic API key (stored in Vault openclaw/gateway)."
}

variable "signal_account" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Signal account (e.g. phone number; stored in Vault openclaw/signal)."
}

variable "vault_app_secrets_secret_name" {
  type        = string
  default     = "openclaw-vault-app-secrets"
  description = "Kubernetes Secret name for app secrets (chart reads this and populates Vault)."
}

# --- Tailscale ---

variable "tailscale_api_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Tailscale API key for provider auth. Set via TF_VAR_tailscale_api_key or TAILSCALE_API_KEY env. Optional if not managing Tailscale resources."
}

variable "tailscale_oauth_client_id" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Tailscale OAuth client ID (for provider auth)."
}

variable "tailscale_oauth_client_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Tailscale OAuth client secret."
}

# --- Optional: cert-manager ClusterIssuer ---

variable "cert_manager_issuer_email" {
  type        = string
  default     = ""
  description = "Email for Let's Encrypt / cert-manager ClusterIssuer (leave empty to skip)."
}
