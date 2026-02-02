# Post-install manual steps

After **Terraform apply** (see [top-level README](../README.md)), these steps are not automated. Do them in order.

---

## Troubleshooting: Gateway pod stuck in Pending / Init

If `kubectl port-forward svc/openclaw-openclaw-gateway 18789:18789 -n openclaw` fails with "pod is not running" or "status=Pending", the gateway is waiting for the Vault gateway token secret. This can happen if the Helm release timed out before the Vault bootstrap Job finished.

**Fix:** Run the recovery job to create the missing secret:

```bash
# From repo root:
kubectl apply -f scripts/vault-bootstrap-complete-job.yaml -n openclaw
# Or from terraform/: kubectl apply -f ../scripts/vault-bootstrap-complete-job.yaml -n openclaw

kubectl wait job/vault-bootstrap-complete -n openclaw --for=condition=complete --timeout=120s
```

If the job fails, inspect logs: `kubectl logs job/vault-bootstrap-complete -n openclaw`. Then retry the port-forward once the secret exists.

---

## 1. Control UI — paste gateway token

- Open the gateway via Tailscale or port-forward:  
  `kubectl port-forward svc/<gateway-service-name> 18789:18789 -n openclaw`
- In the Control UI, go to Settings and paste the **gateway token** (the same value you set in Terraform `gateway_token`).

---

## 2. Tailscale Serve

- Do **not** use Funnel for the gateway.
- Expose the gateway port (e.g. 18789) via Tailscale Serve to your tailnet only.

---

## 3. Signal — pair and approve

Run from a CLI pod or the Control UI:

```bash
openclaw pairing list signal
openclaw pairing approve signal <CODE>
```

---

## 4. Anthropic (Claude Code CLI setup-token)

To use your **Claude Pro/Max subscription** instead of an Anthropic API key:

1. Install Claude Code CLI: `curl -fsSL https://claude.ai/install.sh | bash`
2. Run `claude setup-token` and copy the token.
3. Paste it into OpenClaw:
   - **Control UI**: Settings → Models → Anthropic → paste setup-token, or
   - **CLI**: `kubectl exec -it deployment/<gateway-deployment-name> -n openclaw -- openclaw models auth paste-token --provider anthropic` (paste when prompted)

Leave `anthropic_api_key` empty in Terraform when using this flow.

---

## 5. Optional steps

| Step | Action |
|------|--------|
| **Grafana admin** | Create a secret and set `observability.grafana.existingSecret` if you use Grafana. |
| **TLS / cert-manager** | Create a ClusterIssuer (e.g. Let's Encrypt) so cert-manager can issue certificates. Add annotation to Ingress: `cert-manager.io/cluster-issuer: letsencrypt-prod`. |
| **DNS** | Point `openclaw.<domain>`, `vault.<domain>`, etc. at the Ingress IP (or use Terraform + Cloudflare). |
| **Security audit** | `kubectl exec -it deployment/<gateway-deployment-name> -n openclaw -- openclaw security audit --fix` |

---

## Vault and app secrets (Terraform flow)

With Terraform, the chart's Jobs handle Vault bootstrap and app-secrets: Terraform creates the app-secrets Secret from your variables; the chart's Job reads it and runs `vault kv put openclaw/gateway` and `vault kv put openclaw/signal`. You do not need to port-forward to Vault or run the Vault CLI unless you add secrets manually later.
