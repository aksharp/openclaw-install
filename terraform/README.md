# OpenClaw Terraform

Single-config automation: one `terraform.tfvars` (or variables) drives the OpenClaw Helm chart, app secrets (into Vault), DNS (Cloudflare), and Tailscale. After `terraform apply`, the only remaining manual steps are: paste gateway token in the Control UI and approve Signal pairings.

## What Terraform does

1. **Namespace** — Creates the Kubernetes namespace (e.g. `openclaw`).
2. **App secrets Secret** — Creates a Kubernetes Secret from your variables (`gateway_token`, `openai_api_key`, `anthropic_api_key`, `signal_account`). The Helm chart’s post-install Job reads this Secret and populates Vault (`openclaw/gateway`, `openclaw/signal`).
3. **Helm release** — Installs/upgrades the OpenClaw chart with your config (image tag, ingress domain, Tailscale hostname, Vault app-secrets Secret name).
4. **DNS (Cloudflare)** — When `cloudflare_zone_id` and `ingress_ip` are set, creates A records for `openclaw.<domain>`, `vault.<domain>`, `grafana.<domain>`, `prometheus.<domain>`.
5. **Tailscale** — Provider is configured; you can add resources (e.g. ACL, DNS preferences) in `main.tf` and set OAuth or `TAILSCALE_API_KEY` for auth.

## Prerequisites

- **kubectl** and **kubeconfig** pointing at your cluster (Terraform uses the default Kubernetes provider config).
- **Helm** — Run once before first apply:  
  `helm dependency update ../helm/openclaw`  
  (from repo root: `helm dependency update ./helm/openclaw`.)
- **Cloudflare** (optional) — API token with DNS edit for the zone; set `CLOUDFLARE_API_TOKEN` or use provider `api_token`.
- **Tailscale** — API key or OAuth for the provider; set `TAILSCALE_API_KEY` or variables.

## Quick start

1. **Copy the example vars**  
   `cp terraform.tfvars.example terraform.tfvars`

2. **Edit `terraform.tfvars`**  
   Set at least: `chart_path` (e.g. `../helm/openclaw` if running from `terraform/`), `ingress_domain`, `gateway_token`. Set `openai_api_key`, `anthropic_api_key`, `signal_account` as needed. For DNS, set `cloudflare_zone_id` and leave `ingress_ip` empty on first run.

3. **Init and apply** (from `terraform/` directory):
   ```bash
   terraform init
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```

4. **Get Ingress IP** (after first apply)  
   `kubectl get svc -n openclaw -l app.kubernetes.io/name=kubernetes-ingress`  
   Note the external IP (or hostname).

5. **Second apply with DNS** (optional)  
   Set `ingress_ip` in `terraform.tfvars` to that IP, then run `terraform apply -var-file=terraform.tfvars` again so Cloudflare A records are created.

## Variables

| Variable | Description |
|----------|-------------|
| `namespace` | Kubernetes namespace (default: `openclaw`). |
| `chart_path` | Path to the OpenClaw Helm chart (e.g. `../helm/openclaw`). |
| `openclaw_image_tag` | OpenClaw image tag (e.g. `v1.0.0`). |
| `ingress_domain` | Base domain (e.g. `openclaw.local` or `your-domain.com`). |
| `tailscale_hostname` | Tailscale hostname for this node. |
| `gateway_token` | OpenClaw gateway token (sensitive). |
| `openai_api_key`, `anthropic_api_key`, `signal_account` | Optional; stored in Vault by the chart Job. |
| `cloudflare_zone_id` | Cloudflare zone ID for DNS (empty = skip DNS). |
| `ingress_ip` | IP for A records (set after first apply to enable DNS). |

Sensitive variables can be set via environment variables: `TF_VAR_gateway_token`, `TF_VAR_openai_api_key`, etc.

## Backend (optional)

To keep Terraform state remotely (e.g. S3, GCS, Terraform Cloud), uncomment and fill the `backend` block in `versions.tf`.

## After apply

- **Control UI** — Open https://&lt;tailscale_hostname&gt; (or port-forward to the gateway) and paste the gateway token in Settings.
- **Signal** — Run `openclaw pairing list signal` and `openclaw pairing approve signal <CODE>`.

Full post-install steps are in [helm/openclaw/docs/PREREQUISITES.md](../helm/openclaw/docs/PREREQUISITES.md); with Terraform, Vault bootstrap and app-secrets population are already done.
