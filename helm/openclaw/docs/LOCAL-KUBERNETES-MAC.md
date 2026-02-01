# Running OpenClaw on Kubernetes locally (macOS)

This guide explains how to run a **local Kubernetes cluster** on your Mac and deploy the full OpenClaw Helm chart (gateway, Vault, OTel Collector, Prometheus, Grafana, Loki, Alertmanager) on it.

---

## 1. Choose a local Kubernetes option

You can use any of these; pick one.

| Option | Best for | Notes |
|--------|----------|--------|
| **Docker Desktop** | Easiest if you already use Docker | Built-in Kubernetes; enable in Settings. |
| **minikube** | Lightweight, multi-driver | Works with Docker, HyperKit, or VM. |
| **kind** (Kubernetes in Docker) | CI or multi-node locally | Clusters are Docker containers. |

---

## 2. Prerequisites (install once)

- **kubectl** — [Install](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (e.g. `brew install kubectl`).
- **Helm 3** — [Install](https://helm.sh/docs/intro/install/) (e.g. `brew install helm`).
- **Docker** — Required for Docker Desktop and for kind; optional driver for minikube.

---

## 3. Start a local Kubernetes cluster

### Option A: Docker Desktop (built-in Kubernetes)

1. Open **Docker Desktop** → **Settings** (gear icon) → **Kubernetes**.
2. Enable **Enable Kubernetes** and click **Apply & Restart**.
3. Wait until the Kubernetes context is ready (green indicator in the status bar).
4. Verify:
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

Your context is usually `docker-desktop` or `docker-for-desktop`.

### Option B: minikube

1. Install minikube: `brew install minikube`.
2. Start a cluster (Docker driver; needs Docker running):
   ```bash
   minikube start --driver=docker
   ```
   Or use the default driver (e.g. HyperKit on Mac): `minikube start`.
3. Verify:
   ```bash
   kubectl cluster-info
   minikube status
   ```

Use `minikube dashboard` for the Kubernetes dashboard if you want it.

### Option C: kind (Kubernetes in Docker)

1. Install kind: `brew install kind`.
2. Create a cluster:
   ```bash
   kind create cluster --name openclaw
   ```
3. Verify:
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

Your context will be `kind-openclaw`.

---

## 4. Deploy the OpenClaw Helm chart

These steps assume the chart is in `helm/openclaw` (relative to your repo root).

### 4.1 Copy and fill the configuration file

From the **repository root**:

```bash
cp helm/openclaw/prerequisites.yaml.example helm/openclaw/prerequisites.yaml
```

Edit `helm/openclaw/prerequisites.yaml` and set at least:

- **openclaw.image.tag** — e.g. `v1.0.0` (see [OpenClaw releases](https://github.com/openclaw/openclaw/releases)).
- **tailscale.hostname** — e.g. `openclaw-local` (for local-only you can keep default).
- **observability.*** — leave enabled if you want the full stack (Grafana, Loki, Prometheus, Alertmanager).

For **local use only**, you can leave Vault internal, keep observability enabled, and use minimal overrides. Do **not** put secrets in this file.

### 4.2 Create the namespace (optional; Helm can create it)

```bash
kubectl create namespace openclaw
```

### 4.3 Create required secrets

The gateway needs a token and (if using Vault) a Vault token. Create secrets **before** or **after** the first install; the gateway will use them when present.

```bash
# Replace <GATEWAY_TOKEN> and <VAULT_TOKEN> with your values
kubectl create secret generic openclaw-gateway-token \
  --from-literal=token=<GATEWAY_TOKEN> \
  -n openclaw

kubectl create secret generic openclaw-vault-gateway-token \
  --from-literal=token=<VAULT_TOKEN> \
  -n openclaw
```

If you use **internal Vault**, you can use a placeholder Vault token for the first install, then populate Vault and create a real token (see [README](../README.md) and NOTES after install).

**Grafana (optional):** To set an admin password via secret:

```bash
kubectl create secret generic openclaw-grafana-admin \
  --from-literal=admin-password=<YOUR_GRAFANA_PASSWORD> \
  -n openclaw
```

Then in `prerequisites.yaml` set:

```yaml
observability:
  grafana:
    existingSecret: openclaw-grafana-admin
    secretKey: admin-password
```

### 4.4 Install or upgrade the chart (single command)

From the **repository root**. This installs the gateway, Vault, observability, **and** HAProxy + cert-manager (Ingress is required):

```bash
helm dependency update ./helm/openclaw
helm upgrade --install openclaw ./helm/openclaw \
  -f ./helm/openclaw/prerequisites.yaml \
  -n openclaw \
  --create-namespace
```

Or from the **parent of the chart** (e.g. `helm/`), with `prerequisites.yaml` in that directory:

```bash
cd helm
helm upgrade --install openclaw ./openclaw -f ./openclaw/prerequisites.yaml -n openclaw --create-namespace
```

This single command **installs** on first run and **upgrades** on later runs.

### 4.5 Check that everything is running

```bash
kubectl get pods -n openclaw
kubectl get deployments -n openclaw
kubectl get svc -n openclaw
```

You should see (when observability is enabled):

- **OpenClaw gateway** — `openclaw-openclaw-gateway` (or `<release>-<chart>-gateway`)
- **Vault** — `openclaw-openclaw-vault`
- **OTel Collector** — `openclaw-openclaw-otel-collector`
- **Prometheus** — `openclaw-openclaw-prometheus`
- **Grafana** — `openclaw-openclaw-grafana`
- **Loki** — `openclaw-openclaw-loki`
- **Alertmanager** — `openclaw-openclaw-alertmanager`

Release name is `openclaw` and chart name is `openclaw`, so the full prefix is `openclaw-openclaw-`.

---

## 5. Access services (Ingress only)

Access is **via Ingress only**. No per-service port-forwarding. Ingress is required; the openclaw chart always installs HAProxy.

1. **Port-forward once to the HAProxy Ingress controller** (on kind, LoadBalancer has no external IP). The controller is in the release namespace: `kubectl get svc -n openclaw` and look for the HAProxy service (e.g. `openclaw-kubernetes-ingress`):
   ```bash
   kubectl port-forward svc/openclaw-kubernetes-ingress 8080:80 -n openclaw
   ```

2. **Add hostnames to `/etc/hosts`** (use the domain from `prerequisites.yaml`, default `openclaw.local`):
   ```
   127.0.0.1 openclaw.openclaw.local vault.openclaw.local grafana.openclaw.local prometheus.openclaw.local
   ```

3. **Open in browser** (port 8080):
   - **Gateway (Control UI):** http://openclaw.openclaw.local:8080
   - **Vault:** http://vault.openclaw.local:8080 (enable KV, add gateway/Signal secrets, create policy and token)
   - **Grafana:** http://grafana.openclaw.local:8080
   - **Prometheus:** http://prometheus.openclaw.local:8080

---

## 6. Post-install (same as production)

After the first install, complete the steps printed in **NOTES** (and in the main [README](../README.md)):

1. **Populate Vault** — Port-forward Vault, enable KV, add `openclaw/gateway` and `openclaw/signal`, create gateway policy and token, update the `openclaw-vault-gateway-token` secret.
2. **Control UI** — Open the gateway via Ingress (http://openclaw.openclaw.local:8080), paste the gateway token in Settings.
3. **Signal** — Link and approve pairings via CLI or Control UI.
4. **Security audit** — e.g. `kubectl exec -it deployment/openclaw-openclaw-gateway -n openclaw -- openclaw security audit --fix`.

For **production** you would use **Tailscale** (Serve for the gateway, no Funnel) and access dashboards over Tailscale instead of port-forward; see [OPENCLAW-DOCKER-SECURE-INSTALL-V10.md](../../OPENCLAW-DOCKER-SECURE-INSTALL-V10.md).

---

## 6.1 Using Lens with this cluster

**Lens** (the Kubernetes IDE) uses the **same kubeconfig** as `kubectl`. No changes to the OpenClaw chart or cluster are required.

- **Local cluster:** After starting Docker Desktop / minikube / kind and deploying the chart, open Lens → it will pick up your default kubeconfig. Add the cluster (or switch context) if needed. No port-forward or Ingress is required for Lens; it talks to the API server like `kubectl`.
- **Remote cluster:** Ensure the API server is reachable (e.g. via Tailscale or VPN) and your kubeconfig points at it; then add that cluster in Lens.

Access is via Ingress hostnames only; see [INGRESS-DNS-AND-LENS.md](INGRESS-DNS-AND-LENS.md) for details.

---

## 7. Clean up

- **Uninstall the release:**
  ```bash
  helm uninstall openclaw -n openclaw
  ```
- **Remove the namespace (and all resources in it):**
  ```bash
  kubectl delete namespace openclaw
  ```
- **Stop the cluster:**
  - **Docker Desktop:** Disable Kubernetes in Settings, or leave it on.
  - **minikube:** `minikube stop` or `minikube delete`.
  - **kind:** `kind delete cluster --name openclaw`.

---

## 8. Troubleshooting

| Issue | What to check |
|-------|----------------|
| Pods not starting | `kubectl describe pod <pod> -n openclaw` and `kubectl logs <pod> -n openclaw`. |
| Gateway can’t reach Vault | Ensure `vault.address` in values matches the Vault service name (e.g. `http://openclaw-openclaw-vault:8200`). |
| OTLP / Prometheus no metrics | Ensure OTel Collector is running and Prometheus scrapes `openclaw-openclaw-otel-collector:8888`. Check gateway config has `OPENCLAW_OTEL_ENDPOINT` set. |
| Grafana “bad gateway” for Prometheus/Loki | Service names must match: `openclaw-openclaw-prometheus`, `openclaw-openclaw-loki` (or your release/chart name). |
| Image pull errors | For kind: `kind load docker-image <image>` if using local images. For minikube: `eval $(minikube docker-env)` and build locally, or use a registry. |

For more detail, see the main [README](../README.md) and [OPENCLAW-DOCKER-SECURE-INSTALL-V10.md](../../OPENCLAW-DOCKER-SECURE-INSTALL-V10.md).
