# ---------------------------------------------------------------------------
# OpenClaw Terraform outputs
# ---------------------------------------------------------------------------

output "namespace" {
  value       = kubernetes_namespace.openclaw.metadata[0].name
  description = "Kubernetes namespace where OpenClaw is installed."
}

output "release_name" {
  value       = helm_release.openclaw.name
  description = "Helm release name."
}

output "ingress_hostnames" {
  value = [
    "openclaw.${var.ingress_domain}",
    "vault.${var.ingress_domain}",
    "grafana.${var.ingress_domain}",
    "prometheus.${var.ingress_domain}"
  ]
  description = "Ingress hostnames (add to /etc/hosts or ensure DNS records point to ingress_ip)."
}

output "next_steps" {
  value       = <<-EOT
    Remaining manual steps:
    1. Get Ingress IP: kubectl get svc -n openclaw -l app.kubernetes.io/name=kubernetes-ingress
    2. For Cloudflare DNS: cd terraform/cloudflare && terraform apply
    3. Open Control UI (https://${var.tailscale_hostname} or port-forward) and paste the gateway token in Settings.
    4. Link Signal: openclaw pairing list signal && openclaw pairing approve signal <CODE>
  EOT
  description = "Remaining manual steps after apply."
}
