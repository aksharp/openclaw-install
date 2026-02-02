# Terraform for OpenClaw

**Setup entry point:** [top-level README](../README.md). This file is a reference for variables, backend, and post-apply steps.

---

## Variables

| Variable | Description |
|----------|-------------|
| `namespace` | Kubernetes namespace (default: `openclaw`). |
| `chart_path` | Path to the OpenClaw Helm chart (e.g. `../helm/openclaw`). |
| `openclaw_image_tag` | OpenClaw image tag (e.g. `v1.0.0`). |
| `ingress_domain` | Base domain (e.g. `openclaw.local` or your domain). |
| `tailscale_hostname` | Tailscale hostname for this node. |
| `gateway_token` | OpenClaw gateway token (sensitive). |
| `openai_api_key`, `anthropic_api_key`, `signal_account` | Optional; stored in Vault by the chart Job. |
| `cloudflare_zone_id` | Cloudflare zone ID for DNS (empty = skip DNS). |
| `ingress_ip` | IP for A records (set after first apply to enable DNS). |

Sensitive variables: `TF_VAR_gateway_token`, `TF_VAR_openai_api_key`, etc.

---

## What Terraform does

1. **Namespace** — Creates the Kubernetes namespace.
2. **App secrets Secret** — From your variables; chart Job populates Vault (`openclaw/gateway`, `openclaw/signal`).
3. **Helm release** — Installs/upgrades the OpenClaw chart.
4. **DNS (Cloudflare)** — When `cloudflare_zone_id` and `ingress_ip` are set, creates A records.
5. **Tailscale** — Provider configured; add resources in `main.tf` as needed.

---

## Backend (optional)

To keep state remotely (S3, GCS, Terraform Cloud), configure the `backend` block in `versions.tf`.

---

## After apply

- **Control UI** — Open gateway (Tailscale or port-forward) and paste the gateway token in Settings.
- **Signal** — Run `openclaw pairing list signal` and `openclaw pairing approve signal <CODE>`.

Full post-install steps: [docs/POST-INSTALL.md](../docs/POST-INSTALL.md).
