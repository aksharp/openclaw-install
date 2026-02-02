# OpenClaw Helm Chart (V10)

Helm chart to deploy [OpenClaw](https://github.com/openclaw/openclaw) following the secure baseline in [OPENCLAW-DOCKER-SECURE-INSTALL-V10.md](../../OPENCLAW-DOCKER-SECURE-INSTALL-V10.md). **All inputs** go into **one configuration file**; **all manual steps** (to gather information and after install) are in **one documentation file**; you run **one Helm command**.

---

## Requirements

- **Helm 3**
- **Kubernetes** cluster (any supported version). For local development on Mac, see [Running Kubernetes locally (macOS)](docs/LOCAL-KUBERNETES-MAC.md) (Docker Desktop, minikube, or kind).
- **Tailscale** (V10): join the cluster or node to your tailnet for remote access; do **not** use Funnel for the gateway
- **Secrets**: gateway token and API keys go in **Vault** (path `openclaw/gateway`); only the **Vault token** is stored as a Kubernetes secret so the gateway can authenticate to Vault (see [docs/PREREQUISITES.md](docs/PREREQUISITES.md))

---

## Single configuration and single command

**All inputs** and **all manual steps** are in one place: **[docs/PREREQUISITES.md](docs/PREREQUISITES.md)**.

- **Single configuration file:** Copy [prerequisites.yaml.example](prerequisites.yaml.example) to `prerequisites.yaml` and fill it. Every configurable input is in this file. Do **not** put secrets in it.
- **Single documentation file:** [**docs/PREREQUISITES.md**](docs/PREREQUISITES.md) contains: (1) what to set and **how to get each value** (manual steps), (2) how to fill the config file, (3) the **single Helm command**, (4) **all post-install manual steps**.
- **Single Helm command:** From repo root (or chart parent):
  ```bash
  helm dependency update ./helm/openclaw
  helm upgrade --install openclaw ./helm/openclaw -f ./helm/openclaw/prerequisites.yaml -n openclaw --create-namespace
  ```
  All input is in `prerequisites.yaml`. Ingress is required: HAProxy and cert-manager are always installed; all access is via Ingress hostnames.

**Start here:** [docs/PREREQUISITES.md](docs/PREREQUISITES.md).

---

## Reference (detailed)

### Step 1 — Gather manual information and fill the configuration file

All **manual prerequisites** and **non-secret settings** go into **one file** (e.g. `prerequisites.yaml`). Use [prerequisites.yaml.example](prerequisites.yaml.example) as a template: copy it to `prerequisites.yaml`, then fill in the values below.

**Do not put secrets in this file.** Secrets are stored in Kubernetes Secrets or Vault and referenced by name (see “Secrets to create” below).

#### 1.1 What you need and how to get it

| Item | Where to get it | Config key |
|------|-----------------|------------|
| **OpenClaw version** | [GitHub releases](https://github.com/openclaw/openclaw/releases) — pick latest stable | `openclaw.image.tag` (e.g. `v1.2.3`) |
| **Namespace** | Choose a dedicated namespace (e.g. `openclaw`) | `--namespace` and/or override in values |
| **Tailscale hostname** | Tailscale admin or `tailscale status` on the node that will run OpenClaw | `tailscale.hostname` (e.g. `openclaw-prod`) |
| **Vault** | Internal: chart deploys Vault in server mode (file storage, non-root); init and unseal required (PREREQUISITES 5.1); address is the in-cluster service. External: your Vault URL | `vault.address` (internal default: `http://openclaw-vault:8200`) |
| **Signal account** | Dedicated phone number for OpenClaw; stored in Vault, not in this file | `gateway.signal.accountKeyInVault` (e.g. `openclaw/signal`) |
| **Moltbook** | Enable only if you use Moltbook; add Moltbook API key in Vault | `gateway.moltbook.enabled` (true/false) |
| **Observability** | Same host: OTLP endpoint is set automatically to the in-cluster OTel Collector. Different host: set `observability.otlpEndpointTailscale` to the Tailscale hostname (e.g. `http://observability:4318`). Stack includes Prometheus, Grafana, Loki, Alertmanager (V10). | `observability.*` (enable/disable components) |
| **Ingress / DNS** | **Required.** All access is via Ingress hostnames. HAProxy and cert-manager are always installed. Set `ingress.domain` (default `openclaw.local`); for production use your domain (e.g. your-domain.com) and add /etc/hosts or DNS. Per V10: restrict access (Tailscale/private). See [docs/INGRESS-DNS-AND-LENS.md](docs/INGRESS-DNS-AND-LENS.md). | `ingress.domain`, `ingress.hosts.*Host` (optional overrides) |
| **Resource limits** | Optional; defaults are 4G memory, 4 CPU | `gateway.resources` |

#### 1.2 Secrets to create (not in the config file)

Create these **before or after** the first `helm upgrade --install` (see NOTES after install):

| Secret | Purpose | Example |
|--------|---------|--------|
| **Gateway token** | Token for Control UI and API access; stored in **Vault** at `openclaw/gateway` as `gateway_token` (not a K8s secret) | Put in Vault when you run `vault kv put openclaw/gateway gateway_token=...` (see PREREQUISITES.md Section 5). |
| **Vault token** (if using Vault) | Token the gateway uses to authenticate to Vault | `kubectl create secret generic openclaw-vault-gateway-token --from-literal=token=<VAULT_TOKEN> -n openclaw` (after creating the token in Vault). |

If you use **internal Vault**, you also populate Vault with:

- `openclaw/gateway`: `gateway_token`, `openai_api_key`, `anthropic_api_key`, etc.
- `openclaw/signal`: Signal account details
- (Optional) Moltbook credentials

Then create a Vault policy and token for the gateway, and store that token in the `openclaw-vault-gateway-token` Kubernetes secret. See the post-install NOTES and [OPENCLAW-DOCKER-SECURE-INSTALL-V10.md](../../OPENCLAW-DOCKER-SECURE-INSTALL-V10.md) for exact steps.

#### 1.3 How to fill the configuration file

1. Copy the example:  
   `cp prerequisites.yaml.example prerequisites.yaml`
2. Edit `prerequisites.yaml` and set at least:
   - `openclaw.image.tag` — desired OpenClaw release
   - `tailscale.hostname` — your Tailscale machine name
   - `vault.*` — internal vs external, and `vault.address` if external
   - `gateway.signal.accountKeyInVault` — Vault path for Signal
   - `gateway.moltbook.enabled` — true/false
   - `observability.*` — enable/disable and OTLP endpoint (or Tailscale hostname if observability is on another host)
3. Override any other values (namespace, resources, etc.) as needed. All keys are documented in [values.yaml](values.yaml).

---

### Step 2 — Run the Helm chart (single command)

From **repository root** (chart at `./helm/openclaw`):

```bash
helm upgrade --install openclaw ./helm/openclaw -f ./helm/openclaw/prerequisites.yaml -n openclaw --create-namespace
```

From the **parent of the chart** (e.g. `helm/`), with `prerequisites.yaml` in that directory:

```bash
helm upgrade --install openclaw ./openclaw -f prerequisites.yaml -n openclaw --create-namespace
```

- **First run:** installs the release.
- **Later runs:** upgrade the same release (e.g. after changing `openclaw.image.tag` or other values).
- All input is in `prerequisites.yaml`; no extra flags needed for normal use.

Use a specific namespace if you prefer:

```bash
helm upgrade --install openclaw ./openclaw -f prerequisites.yaml -n my-openclaw-ns --create-namespace
```

Keep your `prerequisites.yaml` in version control (without secrets) so deployments are repeatable.

---

## After install (manual steps)

All post-install manual steps (secrets, Vault, Tailscale Serve, Control UI, Signal, security audit, TLS, DNS) are in **[docs/PREREQUISITES.md](docs/PREREQUISITES.md)** Section 5. Helm will also print a short **NOTES** summary.

---

## Upgrading OpenClaw

1. In `prerequisites.yaml`, set a new stable version:  
   `openclaw.image.tag: "v1.3.0"`
2. Run the same Helm command (see [docs/PREREQUISITES.md](docs/PREREQUISITES.md) Section 4):  
   `helm dependency update ./helm/openclaw && helm upgrade --install openclaw ./helm/openclaw -f ./helm/openclaw/prerequisites.yaml -n openclaw --create-namespace`
3. Restart gateway pods if needed; re-run the security audit (see NOTES).

---

## Debugging

- **Validate and dry-run:**  
  `helm lint ./openclaw -f prerequisites.yaml`  
  `helm upgrade --install openclaw ./openclaw -f prerequisites.yaml -n openclaw --dry-run --debug`
- **Chart structure:** One template per main resource (gateway, Vault, observability) under [templates/](templates/); shared logic in [_helpers.tpl](templates/_helpers.tpl). Inspect rendered manifests with `--dry-run --debug` to see final YAML.

---

## Chart layout (extending)

```
helm/
├── openclaw/             # Main OpenClaw chart (gateway, Vault, observability, Ingress; HAProxy + cert-manager always included)
├── openclaw-ingress/     # Deprecated: use openclaw chart (Ingress is built-in)

openclaw/
├── Chart.yaml
├── values.yaml           # Defaults; all keys documented; ingress.domain and ingress.hosts.*Host configurable
├── prerequisites.yaml.example   # Copy to prerequisites.yaml and fill
├── README.md             # This file (Step 1 + Step 2)
├── docs/
│   ├── PREREQUISITES.md          # Single doc: all inputs, manual steps to get them, single Helm command, post-install steps
│   └── LOCAL-KUBERNETES-MAC.md   # Local K8s on Mac (Docker Desktop, minikube, kind)
├── templates/
│   ├── _helpers.tpl      # Labels, names
│   ├── gateway-*.yaml    # Gateway Deployment, Service, ConfigMap
│   ├── vault-*.yaml      # Optional internal Vault
│   ├── observability/   # OTel Collector, Prometheus, Grafana, Loki, Alertmanager
│   ├── ingress.yaml     # Ingress resource (openclaw.{domain}, vault.{domain}) — always created when domain is set
│   └── NOTES.txt        # Post-install checklist
```

**Deployments created (when enabled):** (1) OpenClaw gateway, (2) Vault (internal), (3) OTel Collector, (4) Prometheus, (5) Grafana, (6) Loki, (7) Alertmanager. Optional: Mimir (long-term storage).

To extend: add new values under `gateway.*` or `observability.*` with safe defaults, and add or adjust templates as needed. OpenClaw application version is controlled only by `openclaw.image.tag` in your config file.

---

## Reference

- **V10 secure install (full guide):** [OPENCLAW-DOCKER-SECURE-INSTALL-V10.md](../../OPENCLAW-DOCKER-SECURE-INSTALL-V10.md)
- **Chart design:** [OPENCLAW-HELM-CHART-DESIGN.md](../../OPENCLAW-HELM-CHART-DESIGN.md)
- **Local Kubernetes on Mac:** [docs/LOCAL-KUBERNETES-MAC.md](docs/LOCAL-KUBERNETES-MAC.md) — Docker Desktop, minikube, kind, and full deploy steps
- **Single config + all manual steps:** [docs/PREREQUISITES.md](docs/PREREQUISITES.md) — all inputs, how to get them, single Helm command, post-install steps
- **Ingress, DNS names, Consul, Lens:** [docs/INGRESS-DNS-AND-LENS.md](docs/INGRESS-DNS-AND-LENS.md) — Ingress is required (HAProxy + cert-manager always installed); configurable domain; Lens
