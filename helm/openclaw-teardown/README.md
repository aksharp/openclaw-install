# OpenClaw teardown Helm chart

This chart **rolls back** the OpenClaw deployment and Ingress stack so the cluster returns to the same state as **before** anything was installed.

It does **not** run uninstall automatically. It installs a **ConfigMap** with a teardown script and prints the exact **commands** to run in NOTES. You run those commands from your machine (with `helm` and `kubectl`) to uninstall releases and delete namespaces.

---

## What gets removed

1. **OpenClaw release** (`openclaw` by default) — gateway, Vault, observability, HAProxy, cert-manager (all installed together by the openclaw chart).
2. **Optional:** standalone **openclaw-ingress** release (only if you installed that chart separately).
3. **Optional:** the **namespaces** (`openclaw`, and `ingress` if used) so no leftover resources remain.

---

## Usage

### 1. Install the teardown chart (from repo root)

```bash
helm install teardown ./helm/openclaw-teardown -n default
```

Or with overrides if you used different release names or namespaces:

```bash
helm install teardown ./helm/openclaw-teardown -n default -f helm/openclaw-teardown/teardown-values.yaml
```

### 2. Run the commands from NOTES

After install, Helm prints the commands. Run them in order:

```bash
# 1. Uninstall OpenClaw (gateway, Vault, observability, HAProxy, cert-manager)
helm uninstall openclaw -n openclaw --wait

# 2. (Only if you installed openclaw-ingress separately) Uninstall openclaw-ingress
helm uninstall openclaw-ingress -n ingress --wait

# 3. Delete namespaces (full rollback)
kubectl delete namespace openclaw --ignore-not-found --timeout=120s
kubectl delete namespace ingress --ignore-not-found --timeout=120s   # only if you used it

# 4. Remove this teardown release (optional)
helm uninstall teardown -n default
```

### 3. Optional: run the script from the ConfigMap

The chart installs a ConfigMap with a shell script. To view it:

```bash
kubectl get configmap openclaw-teardown-teardown-script -n default -o jsonpath='{.data.teardown\.sh}'
```

Copy the output and run it locally (you need `helm` and `kubectl` in your PATH).

---

## Configuration (values.yaml)

| Value | Default | Description |
|-------|---------|-------------|
| `openclaw.releaseName` | `openclaw` | Helm release name for the openclaw chart |
| `openclaw.namespace` | `openclaw` | Namespace where openclaw was installed |
| `openclawIngress.enabled` | `false` | Set `true` if you installed the standalone openclaw-ingress chart |
| `openclawIngress.releaseName` | `openclaw-ingress` | Release name for openclaw-ingress |
| `openclawIngress.namespace` | `ingress` | Namespace for openclaw-ingress |
| `deleteNamespaces` | `true` | Delete namespaces after uninstall for full rollback |

---

## Example: custom release/namespace

If you installed OpenClaw with a different release name or namespace:

```yaml
# teardown-values.yaml
openclaw:
  releaseName: my-openclaw
  namespace: my-openclaw-ns
openclawIngress:
  enabled: false
deleteNamespaces: true
```

Then:

```bash
helm install teardown ./helm/openclaw-teardown -f teardown-values.yaml -n default
# Then run the commands shown in NOTES
```

---

## Summary

| Step | Action |
|------|--------|
| 1 | `helm install teardown ./helm/openclaw-teardown -n default` |
| 2 | Run the `helm uninstall` and `kubectl delete namespace` commands from NOTES |
| 3 | Optionally `helm uninstall teardown -n default` to remove the teardown release |

After step 2, the cluster is back to the state before OpenClaw and Ingress were installed.
