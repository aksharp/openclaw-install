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
| **Vault: internal vs external** | **Internal:** Chart deploys Vault in dev mode; no URL to gather. **External:** Have your Vault URL (e.g. `https://vault.example.com`). | `vault.internal.enabled` (true/false); `vault.address` if external |
| **Signal account** | Use a dedicated phone number for OpenClaw; you will store credentials in Vault; only the Vault path is in config. | `gateway.signal.accountKeyInVault` (e.g. `openclaw/signal`) |
| **Moltbook** | Decide if you use Moltbook; if yes, you will add Moltbook API key in Vault later. | `gateway.moltbook.enabled` (true/false) |
| **Observability: same vs different host** | **Same host:** Leave `observability.otlpEndpointTailscale` empty (in-cluster URL is used). **Different host:** Note the Tailscale hostname of the observability host (e.g. `http://observability:4318`). | `observability.enabled`, `observability.otlpEndpointTailscale`; enable/disable `observability.grafana`, `observability.prometheus`, `observability.loki`, `observability.alertmanager` |
| **Grafana admin password** | Choose a password; you will create a Kubernetes secret (see Section 4). Optionally set `observability.grafana.existingSecret` and `secretKey`. | `observability.grafana.existingSecret`, `observability.grafana.secretKey` |
| **Ingress / DNS domain** | Choose your base domain (e.g. `your-domain.com`). You will point DNS (or Tailscale DNS / `/etc/hosts`) so that `openclaw.your-domain.com`, `vault.your-domain.com`, etc. resolve to the Ingress controller. Per V10: restrict access (Tailscale/private). | `ingress.enabled`, `ingress.domain`; optional `ingress.hosts.gatewayHost`, `vaultHost`, `grafanaHost`, `prometheusHost` |
| **HAProxy + TLS (Ingress controller)** | If you want the chart to install HAProxy and cert-manager (one command), set both to true. Otherwise install an Ingress controller separately and set `ingress.className` to match. | `haproxy.enabled` (true/false), `certManager.enabled` (true/false) |
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
   - `vault.internal.enabled` — true if chart should deploy Vault; false if external.
   - `vault.address` — only if external Vault.
   - `gateway.signal.accountKeyInVault` — Vault path for Signal (e.g. `openclaw/signal`).
   - `gateway.moltbook.enabled` — true/false.
   - `observability.enabled` and components (grafana, prometheus, loki, alertmanager) as desired.
   - `observability.otlpEndpointTailscale` — only if observability is on another host.
   - `ingress.enabled`, `ingress.domain` — if you want DNS names (e.g. openclaw.your-domain.com).
   - `ingress.tls.enabled` — if you want TLS at the Ingress.
   - `haproxy.enabled`, `certManager.enabled` — true if you want the chart to install HAProxy and cert-manager (single command).

3. **Optional overrides:** Set any of the per-host overrides (`ingress.hosts.gatewayHost`, etc.), namespace, or resource limits as needed. All keys are in [values.yaml](../values.yaml).

---

## 4. Single Helm command

From the **repository root** (or the parent of the chart):

```bash
helm dependency update ./helm/openclaw
helm upgrade --install openclaw ./helm/openclaw -f ./helm/openclaw/prerequisites.yaml -n openclaw --create-namespace
```

- **First run:** installs the release (and optional HAProxy + cert-manager if enabled in prerequisites.yaml).
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

### 5.1 Create Kubernetes secrets

- **Gateway token:** Generate a token (e.g. random string); create the secret:
  ```bash
  kubectl create secret generic openclaw-gateway-token --from-literal=token=<GATEWAY_TOKEN> -n openclaw
  ```
- **Vault token (if using Vault):** After populating Vault and creating a policy/token for the gateway, create the secret:
  ```bash
  kubectl create secret generic openclaw-vault-gateway-token --from-literal=token=<VAULT_TOKEN> -n openclaw
  ```
- **Grafana admin (optional):** If you set `observability.grafana.existingSecret`:
  ```bash
  kubectl create secret generic openclaw-grafana-admin --from-literal=admin-password=<PASSWORD> -n openclaw
  ```

### 5.2 Populate Vault (if internal Vault is enabled)

1. Port-forward: `kubectl port-forward svc/<vault-service-name> 8200:8200 -n openclaw` (service name is `<release>-<chart>-vault`, e.g. `openclaw-openclaw-vault`).
2. Enable KV: `vault secrets enable -path=openclaw kv-v2`.
3. Put gateway secrets: `vault kv put openclaw/gateway gateway_token=... openai_api_key=... anthropic_api_key=...`.
4. Put Signal: `vault kv put openclaw/signal account=+1...` (and any other keys your gateway expects).
5. Create a Vault policy that allows read on `openclaw/*` and create a token for the gateway; store that token in the Kubernetes secret `openclaw-vault-gateway-token` (see 5.1).

### 5.3 Configure Tailscale Serve (V10)

- Join the cluster/node to Tailscale if not already.
- Do **not** use Funnel for the gateway.
- Expose the gateway port (e.g. 18789) via Tailscale Serve to your tailnet only.

### 5.4 Access Control UI and paste token

- Via Tailscale: `https://<tailscale.hostname>` (after Serve is configured).
- Or port-forward: `kubectl port-forward svc/<gateway-service-name> 18789:18789 -n openclaw`.
- Open the Control UI and paste the gateway token in Settings.

### 5.5 Link Signal and approve pairings

- Run `openclaw pairing list signal` and `openclaw pairing approve signal <CODE>` (via a CLI pod or the Control UI).

### 5.6 Run security audit

```bash
kubectl exec -it deployment/<gateway-deployment-name> -n openclaw -- openclaw security audit --fix
```

(Deployment name is e.g. `openclaw-openclaw-gateway`.)

### 5.7 TLS / cert-manager (if you enabled Ingress + cert-manager)

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

### 5.8 Point DNS at the Ingress (if using Ingress)

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
