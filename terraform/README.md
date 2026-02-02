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
| `tailscale_api_key` | Tailscale API key (sensitive). Optional; set when managing Tailscale resources. |

Sensitive variables: `TF_VAR_gateway_token`, `TF_VAR_tailscale_api_key`, etc.

**Cloudflare DNS** (optional): Run from `terraform/cloudflare/` after main apply. See [terraform/cloudflare/README.md](cloudflare/README.md).

---

## What Terraform does

1. **Namespace** — Creates the Kubernetes namespace.
2. **App secrets Secret** — From your variables; chart Job populates Vault (`openclaw/gateway`, `openclaw/signal`).
3. **Helm release** — Installs/upgrades the OpenClaw chart.
4. **DNS (Cloudflare)** — Optional; run from `terraform/cloudflare/` when needed.
5. **Tailscale** — Provider configured; add resources in `main.tf` as needed.

---

## Backend (optional)

To keep state remotely (S3, GCS, Terraform Cloud), configure the `backend` block in `versions.tf`.

---

## After apply

- **Control UI** — Open gateway (Tailscale or port-forward) and paste the gateway token in Settings.
- **Signal** — Run `openclaw pairing list signal` and `openclaw pairing approve signal <CODE>`.

Full post-install steps: [docs/POST-INSTALL.md](../docs/POST-INSTALL.md).
