# openclaw-ingress Helm Chart

This chart installs **HAProxy Kubernetes Ingress Controller** and **cert-manager** (TLS) for use with the [openclaw](../openclaw) chart. It provides:

- **HAProxy** — Ingress controller (ingress class `haproxy`) for host-based routing (e.g. openclaw.{domain}, vault.{domain}).
- **cert-manager** — TLS certificate issuance and renewal (e.g. Let's Encrypt); TLS termination happens at the Ingress.

**Domain is fully configurable** in the **openclaw** chart: set `ingress.domain` (e.g. `your-domain.com`) and optionally override per-host with `ingress.hosts.gatewayHost`, `ingress.hosts.vaultHost`, etc.

---

## Requirements

- Kubernetes cluster
- Helm 3
- (Optional) DNS or `/etc/hosts` so your domain (e.g. openclaw.your-domain.com) resolves to the Ingress controller

---

## Install (one-time per cluster)

1. **Update dependencies** (downloads HAProxy and cert-manager subcharts):

   ```bash
   cd helm/openclaw-ingress
   helm dependency update
   ```

2. **Install the chart** (e.g. in namespace `ingress`):

   ```bash
   helm upgrade --install openclaw-ingress . -n ingress --create-namespace -f values.yaml
   ```

   Or override in a custom values file:

   ```bash
   helm upgrade --install openclaw-ingress . -n ingress --create-namespace -f my-values.yaml
   ```

3. **Optional: Create a ClusterIssuer** for cert-manager (e.g. Let's Encrypt) so the openclaw Ingress can use `cert-manager.io/cluster-issuer: letsencrypt-prod`. See [cert-manager docs](https://cert-manager.io/docs/configuration/acme/).

---

## Configure domain in the openclaw chart

In your **openclaw** values (e.g. `prerequisites.yaml`):

```yaml
ingress:
  enabled: true
  className: haproxy
  domain: your-domain.com   # configurable: e.g. my-domain.com, example.org
  tls:
    enabled: true
    secretName: ""          # cert-manager will create a secret when cluster-issuer annotation is set
  hosts:
    gateway: true
    gatewayHost: ""         # optional override; default openclaw.your-domain.com
    vault: true
    vaultHost: ""           # optional override; default vault.your-domain.com
    grafana: true
    grafanaHost: ""
    prometheus: false
    prometheusHost: ""
```

Then install or upgrade the openclaw chart:

```bash
helm upgrade --install openclaw ./helm/openclaw -f ./helm/openclaw/prerequisites.yaml -n openclaw --create-namespace
```

Point DNS (or Tailscale DNS / `/etc/hosts`) so that `openclaw.your-domain.com`, `vault.your-domain.com`, etc. resolve to the HAProxy Ingress controller's LoadBalancer IP or NodePort. Per V10: restrict access (Tailscale/private); do not expose to the public internet.

---

## Values (openclaw-ingress chart)

| Key | Description | Default |
|-----|-------------|---------|
| `haproxy.enabled` | Install HAProxy Kubernetes Ingress Controller | `true` |
| `certManager.enabled` | Install cert-manager | `true` |
| `kubernetes-ingress.*` | Pass-through to HAProxy subchart (ingress class, replicas, service type, etc.) | ingress class `haproxy` |
| `cert-manager.*` | Pass-through to cert-manager subchart (installCRDs, etc.) | `installCRDs: true` |

Domain and per-host names are **not** set in this chart; they are set in the **openclaw** chart via `ingress.domain` and `ingress.hosts.*Host`.

---

## See also

- [openclaw chart](../openclaw/README.md) — main OpenClaw application and Ingress resource
- [INGRESS-DNS-AND-LENS.md](../openclaw/docs/INGRESS-DNS-AND-LENS.md) — Ingress, DNS, Consul, Lens
