# Post-install manual steps

After **Terraform apply** (see [top-level README](../README.md)), these steps are not automated. Do them in order.

Terraform does **not** wait for the Vault bootstrap Job (so apply won't time out). The gateway pod waits for the gateway-token secret; once the Job completes, the gateway starts. To wait explicitly: `kubectl wait job -n openclaw -l app.kubernetes.io/component=vault-bootstrap --for=condition=complete --timeout=600s`

---

## Troubleshooting: Gateway pod stuck in Pending / Init

If `kubectl port-forward svc/openclaw-openclaw-gateway 18789:18789 -n openclaw` fails with "pod is not running" or "status=Pending", the gateway is waiting for the Vault gateway token secret. This can happen if the Helm release timed out before the Vault bootstrap Job finished.

**Fix A — bootstrap-keys has valid keys:** Run the recovery job:

```bash
# From repo root:
kubectl apply -f scripts/vault-bootstrap-complete-job.yaml -n openclaw
# Or from terraform/: kubectl apply -f ../scripts/vault-bootstrap-complete-job.yaml -n openclaw

kubectl wait job/vault-bootstrap-complete -n openclaw --for=condition=complete --timeout=120s
```

**Bootstrap init container in Back-off:** The bootstrap Job waits for Vault then inits or copies keys. If Vault isn’t ready or bootstrap-keys is empty while Vault is already initialized, the init container fails. Check: `kubectl logs -n openclaw -l app.kubernetes.io/component=vault-bootstrap --all-containers` and `kubectl get pods -n openclaw -l app.kubernetes.io/component=vault`. If Vault is running but keys were lost, use Fix B.

**Fix B — bootstrap-keys is empty:** The bootstrap Job never completed (e.g. Vault was crashing). Reset and re-apply:

```bash
# 1. Delete the failed bootstrap job and empty secret so the chart can recreate them
kubectl delete job -n openclaw -l app.kubernetes.io/component=vault-bootstrap --ignore-not-found
kubectl delete secret openclaw-openclaw-vault-bootstrap-keys -n openclaw --ignore-not-found

# 2. Re-run Terraform (Vault pod will restart with fix; bootstrap Job will run again)
cd terraform && terraform apply -var-file=terraform.tfvars
```

If the recovery job fails, inspect logs: `kubectl logs job/vault-bootstrap-complete -n openclaw`. Then retry the port-forward once the secret exists.

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
