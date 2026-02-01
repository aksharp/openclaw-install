# OpenClaw on Kubernetes (kind) — Step-by-step deployment

This README gives **step-by-step instructions** to: register required accounts and create a prerequisites file, deploy the **Ingress** stack (HAProxy + cert-manager) with a single command, deploy **OpenClaw** (gateway, Vault, observability) with a single command, then verify with **Open Lens** and all URLs (observability, monitors, alerts) and run **debug use cases**.

Target: **local Kubernetes with kind**. Commands assume you are at the **repository root** unless noted.

---

## Prerequisites (install once)

- **Docker** — [Install](https://docs.docker.com/get-docker/) (required for kind).
- **kubectl** — [Install](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (e.g. `brew install kubectl`).
- **Helm 3** — [Install](https://helm.sh/docs/intro/install/) (e.g. `brew install helm`).
- **kind** — [Install](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) (e.g. `brew install kind`).

---

## Step 1 — Register required accounts and create `prerequisites.yaml`

### 1.1 Register / obtain required accounts and information

| What you need | How to get it |
|---------------|----------------|
| **OpenClaw version** | Go to [OpenClaw GitHub releases](https://github.com/openclaw/openclaw/releases), pick latest stable, note the tag (e.g. `v1.0.0`). |
| **Tailscale (optional for local)** | [Join Tailscale](https://tailscale.com/download); on the node run `tailscale status` and note the machine name (e.g. `openclaw-local`). For local-only you can use a placeholder like `openclaw-local`. |
| **Signal account** | Use a **dedicated** phone number for OpenClaw; you will store credentials in Vault later. Only the Vault path goes in config (e.g. `openclaw/signal`). |
| **Vault** | For local/kind: use **internal** Vault (chart deploys it). No account to register. |
| **Grafana admin password** | Choose a password; you will create a Kubernetes secret after deploy (see Step 5). |
| **Gateway token** | Generate a random string (e.g. `openssl rand -hex 24`); you will create a Kubernetes secret after deploy. |
| **Domain (optional)** | For Ingress DNS names (e.g. `openclaw.local`); for kind you can use `openclaw.local` and add it to `/etc/hosts`. |

No need to register for Moltbook unless you enable it; then add Moltbook API key in Vault later.

### 1.2 Create the prerequisites file

From the **repository root**:

```bash
cp helm/openclaw/prerequisites.yaml.example helm/openclaw/prerequisites.yaml
```

Edit `helm/openclaw/prerequisites.yaml` and set at least:

- **openclaw.image.tag** — the OpenClaw version from 1.1 (e.g. `v1.0.0`).
- **tailscale.hostname** — your Tailscale machine name or `openclaw-local` for local.
- **vault.internal.enabled** — `true` (chart deploys Vault).
- **gateway.signal.accountKeyInVault** — e.g. `openclaw/signal`.
- **gateway.moltbook.enabled** — `false` unless you use Moltbook.
- **observability.enabled** — `true` (Grafana, Prometheus, Loki, Alertmanager).
- **ingress** — Required. All access is via Ingress hostnames. HAProxy + cert-manager are always installed with the chart. Set `ingress.domain` (default `openclaw.local`).

Do **not** put secrets (gateway token, Grafana password, API keys) in this file; you create Kubernetes secrets after deploy (Step 5).

Full reference for every key: [helm/openclaw/docs/PREREQUISITES.md](helm/openclaw/docs/PREREQUISITES.md).

---

## Step 2 — Create kind cluster

Create a local Kubernetes cluster with kind **before** deploying Ingress or OpenClaw. The `kubectl` checks in Steps 3 and 4 need this cluster.

From the **repository root** (or any directory):

```bash
kind create cluster --name openclaw
```

Verify:

```bash
kubectl cluster-info
kubectl get nodes
```

Your context will be **kind-openclaw**.

---

## Step 3 — Ingress: single command (create and deploy)

One command installs and deploys the **openclaw-ingress** chart (HAProxy Kubernetes Ingress Controller + cert-manager): it creates all deployment artifacts and runs the Ingress stack in the cluster.

From the **repository root**:

```bash
helm dependency update ./helm/openclaw-ingress && helm upgrade --install openclaw-ingress ./helm/openclaw-ingress -f ./helm/openclaw-ingress/values.yaml -n ingress --create-namespace
```

- **First run:** installs the release (HAProxy + cert-manager).
- **Later runs:** upgrades the same release.
- All Ingress-related config is in `helm/openclaw-ingress/values.yaml`; override with `-f my-values.yaml` if needed.

Verify:

```bash
kubectl get pods -n ingress
kubectl get svc -n ingress
```

You should see HAProxy and cert-manager pods and services.

---

## Step 4 — OpenClaw: single command (create and deploy)

One command installs and deploys the **openclaw** chart (gateway, Vault, OTel Collector, Prometheus, Grafana, Loki, Alertmanager, optional Ingress resource): it creates all deployment artifacts and runs OpenClaw in the cluster.

From the **repository root**:

```bash
helm dependency update ./helm/openclaw && helm upgrade --install openclaw ./helm/openclaw -f ./helm/openclaw/prerequisites.yaml -n openclaw --create-namespace
```

- **First run:** installs the release (and optional HAProxy + cert-manager if enabled in `prerequisites.yaml`).
- **Later runs:** upgrades the same release.
- All input is in `helm/openclaw/prerequisites.yaml`.

Verify:

```bash
kubectl get pods -n openclaw
kubectl get deployments -n openclaw
kubectl get svc -n openclaw
```

You should see: gateway, vault, otel-collector, prometheus, grafana, loki, alertmanager (and optionally HAProxy/cert-manager if enabled in prerequisites).

---

## Step 5 — Create required secrets (manual, one-time)

Replace placeholders with your values:

```bash
# Gateway token (use a random string, e.g. openssl rand -hex 24)
kubectl create secret generic openclaw-gateway-token --from-literal=token=YOUR_GATEWAY_TOKEN -n openclaw

# Vault token (after populating Vault: create policy + token, then use that token here)
kubectl create secret generic openclaw-vault-gateway-token --from-literal=token=YOUR_VAULT_TOKEN -n openclaw

# Grafana admin password (optional)
kubectl create secret generic openclaw-grafana-admin --from-literal=admin-password=YOUR_GRAFANA_PASSWORD -n openclaw
```

Then populate Vault (port-forward, enable KV, put gateway/Signal secrets, create policy and token). Full steps: [helm/openclaw/docs/PREREQUISITES.md](helm/openclaw/docs/PREREQUISITES.md) Section 5.

---

## Step 6 — After deployment: verify and debug

### 6.1 Connect Open Lens to verify deployments

1. **Install [Open Lens](https://k8slens.dev/)** (or Lens Desktop) if you have not.
2. **Add the kind cluster:** Open Lens → **Catalog** or **File → Add Cluster**. Lens uses your default kubeconfig (`~/.kube/config`). The kind cluster appears as **kind-openclaw** (or the context name from `kubectl config current-context`).
3. **Select the cluster** and connect. You should see the cluster dashboard.
4. **Verify deployments:** In Lens, go to **Workloads → Deployments** and filter by namespace:
   - **ingress:** `openclaw-ingress-kubernetes-ingress`, cert-manager components.
   - **openclaw:** `openclaw-openclaw-gateway`, `openclaw-openclaw-vault`, `openclaw-openclaw-otel-collector`, `openclaw-openclaw-prometheus`, `openclaw-openclaw-grafana`, `openclaw-openclaw-loki`, `openclaw-openclaw-alertmanager`.
5. **Check pods:** Workloads → Pods; ensure pods in `openclaw` and `ingress` are Running.
6. **Check logs:** Click a pod → Logs to inspect container logs.

No extra cluster configuration is needed; Lens uses the same kubeconfig as `kubectl`.

---

### 6.2 Connect to all URLs (observability, monitors, alerts)

Access is **via Ingress only**. HAProxy routes by hostname to each service—one entry point, no per-service port-forwarding.

1. **Reach the Ingress controller.** On **kind**, the HAProxy service is often `LoadBalancer` with no external IP. Port-forward **once** to the HAProxy service. Get the service name with `kubectl get svc -n ingress` (e.g. `openclaw-ingress-kubernetes-ingress`):
   ```bash
   kubectl port-forward svc/openclaw-ingress-kubernetes-ingress 8080:80 -n ingress
   ```
   (Use 443 → 8443 if TLS is configured.)

2. **Point hostnames at localhost.** Add to `/etc/hosts` (use the domain from `prerequisites.yaml`, default `openclaw.local`):
   ```
   127.0.0.1 openclaw.openclaw.local vault.openclaw.local grafana.openclaw.local prometheus.openclaw.local
   ```

3. **Open in browser** (port 8080 if you forwarded 80→8080):
   - **Gateway (Control UI):** http://openclaw.openclaw.local:8080
   - **Vault:** http://vault.openclaw.local:8080
   - **Grafana:** http://grafana.openclaw.local:8080
   - **Prometheus:** http://prometheus.openclaw.local:8080

**Observability and monitoring:** Grafana (dashboards, Explore, Prometheus/LogQL); Prometheus (Targets, Alerts, Graph); Alertmanager (Alerts, Silences). Access all via the Ingress hostnames above (and prometheus/openclaw.local if you use the default domain).

---

### 6.3 Debug use case examples

**1. Gateway pod not Ready**

```bash
kubectl get pods -n openclaw -l app.kubernetes.io/component=gateway
kubectl describe pod -n openclaw -l app.kubernetes.io/component=gateway
kubectl logs -n openclaw -l app.kubernetes.io/component=gateway --tail=100
```

Common causes: missing secret `openclaw-gateway-token` or `openclaw-vault-gateway-token`; Vault not reachable. Fix: create secrets (Step 6.4); ensure Vault pod is running and gateway has correct `VAULT_ADDR`.

**2. No metrics in Prometheus**

```bash
# Check OTel collector is running and scraped
kubectl get pods -n openclaw -l app.kubernetes.io/component=otel-collector
kubectl port-forward svc/openclaw-openclaw-prometheus 9090:9090 -n openclaw
# Open http://localhost:9090/targets — otel-collector job should be UP
```

If targets are down: check OTel collector logs; ensure gateway has `OPENCLAW_OTEL_ENDPOINT` set (chart sets it when observability is enabled).

**3. Grafana “Bad Gateway” for Prometheus or Loki**

Datasources point at in-cluster service names. Check:

```bash
kubectl get svc -n openclaw
# Expect: openclaw-openclaw-prometheus, openclaw-openclaw-loki
```

In Grafana: **Connections → Data sources**; Prometheus URL should be `http://openclaw-openclaw-prometheus:9090`, Loki `http://openclaw-openclaw-loki:3100`. If release name differs, fix the datasource URLs or reinstall with default release name.

**4. Run OpenClaw security audit (V10)**

```bash
kubectl exec -it deployment/openclaw-openclaw-gateway -n openclaw -- openclaw security audit --fix
```

Inspect output for config or security issues; fix any reported items.

**5. Inspect gateway config and env**

```bash
kubectl exec -it deployment/openclaw-openclaw-gateway -n openclaw -- env | grep -E 'OPENCLAW|VAULT'
kubectl get configmap -n openclaw openclaw-openclaw-gateway-config -o yaml
```

**6. Vault not ready or gateway can’t reach Vault**

```bash
kubectl get pods -n openclaw -l app.kubernetes.io/component=vault
kubectl logs -n openclaw -l app.kubernetes.io/component=vault --tail=50
kubectl port-forward svc/openclaw-openclaw-vault 8200:8200 -n openclaw
# In another terminal: vault status (if vault CLI installed)
```

Ensure `openclaw-vault-gateway-token` secret exists and Vault is running; restart gateway pods after creating the token.

**7. Alertmanager not receiving alerts**

Prometheus must have `alerting` config pointing at Alertmanager. Chart configures this when `observability.alertmanager.enabled` is true. Check Prometheus config:

```bash
kubectl get configmap -n openclaw openclaw-openclaw-prometheus-config -o yaml | grep -A5 alerting
```

Check Alertmanager logs:

```bash
kubectl logs -n openclaw -l app.kubernetes.io/component=alertmanager --tail=50
```

---

## Summary

| Step | What | Single command / action |
|------|------|--------------------------|
| 1 | Register accounts, get prerequisites, create `prerequisites.yaml` | Copy example, edit `helm/openclaw/prerequisites.yaml` (see 1.1–1.2). |
| 2 | Create kind cluster | `kind create cluster --name openclaw` (do this before deploying). |
| 3 | Ingress: create and deploy (HAProxy + cert-manager) | `helm dependency update ./helm/openclaw-ingress && helm upgrade --install openclaw-ingress ./helm/openclaw-ingress -f ./helm/openclaw-ingress/values.yaml -n ingress --create-namespace` |
| 4 | OpenClaw: create and deploy (gateway, Vault, observability) | `helm dependency update ./helm/openclaw && helm upgrade --install openclaw ./helm/openclaw -f ./helm/openclaw/prerequisites.yaml -n openclaw --create-namespace` |
| 5 | Create required secrets (manual) | See Step 5 and [helm/openclaw/docs/PREREQUISITES.md](helm/openclaw/docs/PREREQUISITES.md) Section 5. |
| 6 | Verify: Lens, URLs, debug | 6.1 Open Lens → add kind cluster; 6.2 Port-forward and open Gateway, Vault, Grafana, Prometheus, Loki, Alertmanager; 6.3 Use debug examples above. |

**Detailed prerequisites and post-install steps:** [helm/openclaw/docs/PREREQUISITES.md](helm/openclaw/docs/PREREQUISITES.md).  
**Local Kubernetes (kind/minikube/Docker Desktop):** [helm/openclaw/docs/LOCAL-KUBERNETES-MAC.md](helm/openclaw/docs/LOCAL-KUBERNETES-MAC.md).
