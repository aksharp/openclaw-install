# OpenClaw Helm: Single configuration and manual steps

**All inputs** go into **one configuration file** (`prerequisites.yaml`). **All manual steps** (to gather information and to complete after install) are in this document. You run **one Helm command** with that file.

---

## 1. Single configuration file

- **File:** Copy [prerequisites.yaml.example](../prerequisites.yaml.example) to `prerequisites.yaml` (same directory as the chart, or pass path with `-f`).
- **Do not put secrets** in this file. Secrets are created with `kubectl create secret` or stored in Vault (see Section 4).
- **Every configurable input** is in this file; override only what you need; the rest come from chart defaults.

---

## 2. Inputs: what to set and how to get them (manual steps)

Use this table to **gather** each value (manual step), then put it in the correct key in `prerequisites.yaml`.

| Input | Manual step to get it | Config key in prerequisites.yaml |
|-------|------------------------|----------------------------------|
| **OpenClaw version** | Go to [GitHub releases](https://github.com/openclaw/openclaw/releases), pick latest stable, note the tag (e.g. `v1.2.3`). | `openclaw.image.tag` |
| **Namespace** | Choose a dedicated namespace (e.g. `openclaw`). Use the same in the Helm command with `-n`. | `--namespace` and/or `namespaceOverride` |
| **Tailscale hostname** | On the node that will run OpenClaw: run `tailscale status` or check Tailscale admin; note the machine name (e.g. `openclaw-prod`). | `tailscale.hostname` |
| **Vault** | Chart deploys Vault in server mode and bootstraps it (init, unseal, KV, policy, gateway token, K8s secret); you only put application secrets in Vault (Section 5.1). | — |
| **Signal account** | Use a dedicated phone number for OpenClaw; you will store credentials in Vault; only the Vault path is in config. | `gateway.signal.accountKeyInVault` (e.g. `openclaw/signal`) |
| **Moltbook** | Decide if you use Moltbook; if yes, you will add Moltbook API key in Vault later. | `gateway.moltbook.enabled` (true/false) |
| **Observability: same vs different host** | **Same host:** Leave `observability.otlpEndpointTailscale` empty (in-cluster URL is used). **Different host:** Note the Tailscale hostname of the observability host (e.g. `http://observability:4318`). | `observability.enabled`, `observability.otlpEndpointTailscale`; enable/disable `observability.grafana`, `observability.prometheus`, `observability.loki`, `observability.alertmanager` |
| **Grafana admin password** | Choose a password; you will create a Kubernetes secret (see Section 4). Optionally set `observability.grafana.existingSecret` and `secretKey`. | `observability.grafana.existingSecret`, `observability.grafana.secretKey` |
| **Ingress / DNS domain** | **Required (prerequisite).** All access is via Ingress hostnames. The chart always installs HAProxy and cert-manager. Set `ingress.domain` (default `openclaw.local`); for production use your domain (e.g. `your-domain.com`) and point DNS or `/etc/hosts` so `openclaw.{domain}`, `vault.{domain}`, etc. resolve to the Ingress controller. Per V10: restrict access (Tailscale/private). | `ingress.domain` (default openclaw.local); optional `ingress.hosts.gatewayHost`, `vaultHost`, etc. |
| **TLS for Ingress** | If using cert-manager: set `ingress.tls.enabled: true`; create a ClusterIssuer after install (see Section 4). If using a pre-created secret: set `ingress.tls.secretName`. | `ingress.tls.enabled`, `ingress.tls.secretName` |
| **Resource limits** | Optional; defaults are 4G memory, 4 CPU for the gateway. Adjust if needed. | `gateway.resources` |

---

## 3. How to fill the configuration file

1. **Copy the example:**  
   `cp prerequisites.yaml.example prerequisites.yaml`  
   (from the directory that contains the openclaw chart, e.g. `helm/openclaw/`.)

2. **Edit `prerequisites.yaml`** and set at least:
   - `openclaw.image.tag` — from Section 2 (OpenClaw version).
   - `tailscale.hostname` — from Section 2 (Tailscale hostname).
   - `gateway.signal.accountKeyInVault` — Vault path for Signal (e.g. `openclaw/signal`).
   - `gateway.moltbook.enabled` — true/false.
   - `observability.enabled` and components (grafana, prometheus, loki, alertmanager) as desired.
   - `observability.otlpEndpointTailscale` — only if observability is on another host.
   - `ingress.domain` — required prerequisite; default is `openclaw.local`; override for production (e.g. your-domain.com). HAProxy and cert-manager are always installed.
   - `ingress.tls.enabled` — set true for TLS at the Ingress (and configure cert-manager ClusterIssuer).

3. **Optional overrides:** Set any of the per-host overrides (`ingress.hosts.gatewayHost`, etc.), namespace, or resource limits as needed. All keys are in [values.yaml](../values.yaml).

---

## 4. Single Helm command

From the **repository root** (or the parent of the chart):

```bash
helm dependency update ./helm/openclaw
helm upgrade --install openclaw ./helm/openclaw -f ./helm/openclaw/prerequisites.yaml -n openclaw --create-namespace
```

- **First run:** installs the release (HAProxy + cert-manager are always installed with the chart).
- **Later runs:** upgrade the same release (e.g. after changing `openclaw.image.tag` or other values).
- **All input** is in `prerequisites.yaml`; no extra flags needed for normal use.
- Use a different namespace if you set it: replace `openclaw` with your namespace in both `-n` and in the config if you use `namespaceOverride`.

If your working directory is already `helm/openclaw` and `prerequisites.yaml` is there:

```bash
helm dependency update .
helm upgrade --install openclaw . -f prerequisites.yaml -n openclaw --create-namespace
```

---

## 5. Post-install manual steps (in order)

These steps are **not** automated by the chart; do them after the Helm command. All are documented here in one place.

### 5.1 Populate Vault

Internal Vault runs in **server mode** (file storage, non-root). A post-install Job bootstraps it: waits for Vault, runs `vault operator init` (if not already initialized), stores root token and unseal key in Secret `openclaw-vault-bootstrap-keys`, unseals, enables KV at `openclaw`, creates the `openclaw-read` policy, creates a limited gateway token, and populates the Kubernetes secret `openclaw-vault-gateway-token`. The gateway reads the **gateway token** and API keys from Vault (path `openclaw/gateway`), not from a Kubernetes secret.

**You only need to put your application secrets into Vault** after the Job completes:

**Prerequisite:** Install the Vault CLI. macOS: `brew tap hashicorp/tap && brew install hashicorp/tap/vault`. Other platforms: [Vault downloads](https://developer.hashicorp.com/vault/downloads).

1. Check the bootstrap Job: `kubectl get jobs -n openclaw -l app.kubernetes.io/component=vault-bootstrap`. Wait until it completes (e.g. `kubectl wait job/openclaw-openclaw-vault-auto-bootstrap -n openclaw --for=condition=complete --timeout=300s`).
2. Port-forward to Vault (in a separate terminal):  
   `kubectl port-forward svc/openclaw-openclaw-vault 8200:8200 -n openclaw`. Set `export VAULT_ADDR='http://127.0.0.1:8200'`.
3. Get the root token from the bootstrap Secret (one-time, to put secrets):  
   `export VAULT_TOKEN=$(kubectl get secret openclaw-openclaw-vault-bootstrap-keys -n openclaw -o jsonpath='{.data.root_token}' | base64 -d)`  
   Then login is already set.
4. Put gateway secrets (include **gateway_token**):  
   `vault kv put openclaw/gateway gateway_token=<YOUR_GATEWAY_TOKEN> openai_api_key=... anthropic_api_key=...`.
5. Put Signal: `vault kv put openclaw/signal account=+1...` (and any other keys your gateway expects).

The chart creates the gateway token and the Kubernetes secret `openclaw-vault-gateway-token`; no manual policy/token or `kubectl create secret` needed.

### 5.2 Create Kubernetes secrets

- **Vault token:** The chart creates `openclaw-vault-gateway-token`; no action needed.
- **Grafana admin (optional):** If you set `observability.grafana.existingSecret`:
  ```bash
  kubectl create secret generic openclaw-grafana-admin --from-literal=admin-password=<PASSWORD> -n openclaw
  ```

You do **not** create a Kubernetes secret for the gateway token; it lives in Vault at `openclaw/gateway` as `gateway_token`.

### 5.3 Configure Tailscale Serve (V10)

- Join the cluster/node to Tailscale if not already.
- Do **not** use Funnel for the gateway.
- Expose the gateway port (e.g. 18789) via Tailscale Serve to your tailnet only.

### 5.4 Access Control UI and paste token

- Via Tailscale: `https://<tailscale.hostname>` (after Serve is configured).
- Or port-forward: `kubectl port-forward svc/<gateway-service-name> 18789:18789 -n openclaw`.
- Open the Control UI and paste the gateway token in Settings (the same token you put in Vault at `openclaw/gateway` as `gateway_token`).

### 5.5 Link Signal and approve pairings

- Run `openclaw pairing list signal` and `openclaw pairing approve signal <CODE>` (via a CLI pod or the Control UI).

### 5.6 Run security audit

```bash
kubectl exec -it deployment/<gateway-deployment-name> -n openclaw -- openclaw security audit --fix
```

(Deployment name is e.g. `openclaw-openclaw-gateway`.)

### 5.7 TLS / cert-manager (Ingress is always enabled)

- Create a ClusterIssuer (e.g. Let's Encrypt) so cert-manager can issue certificates for your Ingress hosts. Example:
  ```bash
  kubectl apply -f - <<EOF
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-prod
  spec:
    acme:
      server: https://acme-v02.api.letsencrypt.org/directory
      email: you@your-domain.com
      privateKeySecretRef:
        name: letsencrypt-prod
      solvers:
        - http01:
            ingress:
              class: haproxy
  EOF
  ```
- Add the annotation to the OpenClaw Ingress (or set it in values): `cert-manager.io/cluster-issuer: letsencrypt-prod`.

### 5.8 Point DNS at the Ingress

- Point `openclaw.<your-domain>`, `vault.<your-domain>`, `grafana.<your-domain>` (and any overrides) to the Ingress controller's LoadBalancer IP or NodePort. Use Tailscale DNS, `/etc/hosts`, or your DNS provider. Per V10: do not expose to the public internet; use Tailscale or private IP.

---

## 6. Summary

| What | Where |
|------|--------|
| **All inputs** | Single file: `prerequisites.yaml` (copy from prerequisites.yaml.example). |
| **How to get each input** | Section 2 (table: manual step → config key). |
| **How to fill the file** | Section 3. |
| **Single Helm command** | Section 4. |
| **All post-install manual steps** | Section 5 (secrets, Vault, Tailscale, Control UI, Signal, audit, TLS, DNS). |

For the full V10 checklist, see [OPENCLAW-DOCKER-SECURE-INSTALL-V10.md](../../OPENCLAW-DOCKER-SECURE-INSTALL-V10.md).
