# [WIP] Productionized Installation of OpenClaw

OpenClaw (gateway, Vault, observability, HAProxy Ingress, cert-manager) is deployed with **Terraform** from a single config file. This README is the entry point.

---

## Prerequisites

- **Kubernetes cluster** (e.g. [kind](https://kind.sigs.k8s.io/), minikube, or any cluster with kubectl access).
- **kubectl** — [Install](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
- **Terraform** — [Install](https://developer.hashicorp.com/terraform/install) (e.g. `brew install terraform`).
- **Helm** — [Install](https://helm.sh/docs/intro/install/) (used by Terraform to install the chart).
- **Tailscale** — [Join Tailscale](https://tailscale.com/download); note your machine name (`tailscale status`).
- **Cloudflare** (optional, for DNS) — API token for your zone; set `CLOUDFLARE_API_TOKEN` or provider config.
- **Vault CLI** (optional) — Only if you need to put app secrets in Vault manually; [install](https://developer.hashicorp.com/vault/downloads).

---

## Setup (Terraform)

1. **Create a Kubernetes cluster** (if you don’t have one). Example with kind:

   ```bash
   kind create cluster --name openclaw
   ```

2. **Prepare Helm chart dependencies** (once):

   ```bash
   helm dependency update ./helm/openclaw
   ```

3. **Configure Terraform:**

   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```

   Edit `terraform/terraform.tfvars`. Set at least:

   - `chart_path` — e.g. `../helm/openclaw` if you run Terraform from `terraform/` (or `./helm/openclaw` from repo root).
   - `ingress_domain` — e.g. `openclaw.local` or your domain.
   - `tailscale_hostname` — your Tailscale machine name.
   - `gateway_token` — your OpenClaw gateway token (generate e.g. `openssl rand -hex 24`).
   - Optionally: `openai_api_key`, `anthropic_api_key`, `signal_account` (Terraform puts them in a Secret; the chart pushes them into Vault).
   - For DNS: `cloudflare_zone_id`; leave `ingress_ip` empty on first run.

4. **Apply Terraform** (from repo root or from `terraform/`):

   ```bash
   cd terraform
   terraform init
   terraform apply -var-file=terraform.tfvars
   ```

   Terraform creates the namespace, app-secrets Secret (from your vars), and the OpenClaw Helm release (Vault bootstrap and app-secrets population run as Jobs). If you set `cloudflare_zone_id`, run apply again after you have the Ingress IP: set `ingress_ip` in `terraform.tfvars` and run `terraform apply -var-file=terraform.tfvars` again.

5. **Get Ingress IP** (for DNS or /etc/hosts):

   ```bash
   kubectl get svc -n openclaw -l app.kubernetes.io/name=kubernetes-ingress
   ```

   Use the EXTERNAL-IP (or hostname). Add `/etc/hosts` entries or set `ingress_ip` and re-apply for Cloudflare A records.

---

## After apply: manual steps

These are the only steps not automated by Terraform:

1. **Control UI** — Open the gateway (via Tailscale or port-forward) and paste the **gateway token** in Settings (the same value you set in `gateway_token` in Terraform).
2. **Tailscale Serve** — Expose the gateway port (e.g. 18789) via Tailscale Serve to your tailnet; do not use Funnel for the gateway.
3. **Signal** — Run `openclaw pairing list signal` and `openclaw pairing approve signal <CODE>` (from a CLI pod or the Control UI).
4. **Optional:** Grafana admin password, TLS/cert-manager ClusterIssuer, security audit (`openclaw security audit --fix`).

Full list and commands: **[docs/POST-INSTALL.md](docs/POST-INSTALL.md)**.

---

## Teardown

To remove OpenClaw and restore the cluster:

```bash
helm install teardown ./helm/openclaw-teardown -n default
```

Then run the commands printed in NOTES (uninstall openclaw release, delete namespace, optionally uninstall teardown).

Details: [helm/openclaw-teardown/README.md](helm/openclaw-teardown/README.md).

---

## Documentation

| Doc | Purpose |
|-----|---------|
| **This README** | Entry point: Terraform setup, post-install, teardown. |
| [docs/POST-INSTALL.md](docs/POST-INSTALL.md) | Post-install manual steps (Control UI, Tailscale Serve, Signal, TLS, DNS). |
| [terraform/README.md](terraform/README.md) | Terraform variables, providers, backend. |
| [helm/openclaw-teardown/README.md](helm/openclaw-teardown/README.md) | Teardown chart usage. |
| [helm/openclaw/README.md](helm/openclaw/README.md) | Chart reference (values, what the chart deploys). |

---

## Summary

| Step | Action |
|------|--------|
| 1 | Create Kubernetes cluster (e.g. `kind create cluster --name openclaw`). |
| 2 | `helm dependency update ./helm/openclaw`. |
| 3 | Copy `terraform/terraform.tfvars.example` → `terraform/terraform.tfvars`, set vars (domain, tailscale hostname, gateway_token, etc.). |
| 4 | `cd terraform && terraform init && terraform apply -var-file=terraform.tfvars`. |
| 5 | (Optional) Set `ingress_ip` and re-apply for DNS. |
| 6 | Post-install: Control UI (paste token), Tailscale Serve, Signal pairing — see [POST-INSTALL](docs/POST-INSTALL.md). |
