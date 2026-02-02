# OpenClaw Helm Chart

Helm chart for [OpenClaw](https://github.com/openclaw/openclaw): gateway, Vault, observability, HAProxy Ingress, cert-manager. **Setup is done via Terraform** — see the [top-level README](../../README.md).

---

## Reference

### Requirements

- Helm 3, Kubernetes cluster, kubectl.
- Tailscale: join the cluster/node to your tailnet; do not use Funnel for the gateway.
- Secrets: gateway token and API keys go in Vault (path `openclaw/gateway`); Terraform or the chart Jobs populate them.

### What the chart deploys

- OpenClaw gateway
- Vault (server mode; bootstrap Job runs init, unseal, KV, policy, gateway token, K8s secret)
- OTel Collector, Prometheus, Grafana, Loki, Alertmanager
- HAProxy Ingress, cert-manager (always included)
- Ingress for `openclaw.<domain>`, `vault.<domain>`, `grafana.<domain>`, etc.

### Key values (see [values.yaml](values.yaml))

| Value | Description |
|-------|-------------|
| `openclaw.image.tag` | OpenClaw image tag (e.g. `v1.0.0`). |
| `tailscale.hostname` | Tailscale machine name for this node. |
| `ingress.domain` | Base domain (e.g. `openclaw.local`). |
| `vault.appSecretsSecret` | K8s Secret name; chart Job reads it and populates Vault (used by Terraform). |
| `observability.*` | Enable/disable Grafana, Prometheus, Loki, Alertmanager; OTLP endpoint. |
| `gateway.resources` | Optional resource limits (default 4G memory, 4 CPU). |

### Post-install steps

After Terraform apply: Control UI (paste token), Tailscale Serve, Signal pairing. See [docs/POST-INSTALL.md](../../docs/POST-INSTALL.md).

### Upgrading

Update `openclaw.image.tag` in your Terraform vars (or in `prerequisites.yaml` if you run Helm directly) and re-apply or run `helm upgrade`.

### Chart layout

```
openclaw/
├── Chart.yaml
├── values.yaml
├── prerequisites.yaml.example   # Optional; Terraform passes values directly
├── templates/
│   ├── gateway-*, vault-*, observability/*
│   ├── ingress.yaml
│   └── NOTES.txt
```
Post-install steps: [docs/POST-INSTALL.md](../../docs/POST-INSTALL.md) (repo root).

### Debugging

- `helm lint ./openclaw -f prerequisites.yaml`
- `helm upgrade --install openclaw ./openclaw -n openclaw --dry-run --debug`
