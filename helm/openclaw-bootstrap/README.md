# OpenClaw Vault Bootstrap (second-phase chart)

This chart installs **only** the Vault bootstrap Job (and optional app-secrets Job). It is intended to be installed **after** the main OpenClaw release, once the Vault pod is Running and the Vault service is reachable.

Used by `./start.sh`: the script waits for Vault to be ready, then runs `helm upgrade --install openclaw-bootstrap ./helm/openclaw-bootstrap` with the correct values.

## Why a second chart?

The main OpenClaw chart can create the bootstrap Job at install time, but that Job’s init container must reach Vault. If the Job starts before Vault is listening, it fails and restarts. By installing this chart only after confirming Vault is reachable, the bootstrap Job succeeds on the first run.

## Values (set by start.sh or manually)

| Value | Description |
|-------|-------------|
| `namespace` | Kubernetes namespace (e.g. openclaw) |
| `vaultServiceName` | Vault Service name (e.g. openclaw-openclaw-vault) |
| `bootstrapKeysSecretName` | Secret for unseal key and root token |
| `gatewayTokenSecretName` | Secret created by the Job; gateway waits for this |
| `appSecretsSecretName` | Optional; if set, run the app-secrets Job |
| `vaultInitWaitLoops` | Init container wait loops × 2s (safety net; default 300) |

## Manual install (if not using start.sh)

```bash
# After the main openclaw release is up and Vault is reachable:
helm upgrade --install openclaw-bootstrap ./helm/openclaw-bootstrap -n openclaw \
  --set namespace=openclaw \
  --set vaultServiceName=openclaw-openclaw-vault \
  --set bootstrapKeysSecretName=openclaw-openclaw-vault-bootstrap-keys \
  --set gatewayTokenSecretName=openclaw-vault-gateway-token
# Optional: --set appSecretsSecretName=openclaw-vault-app-secrets
```

## Teardown

`./stop.sh` uninstalls this release before destroying the main stack. Or:

```bash
helm uninstall openclaw-bootstrap -n openclaw
```
