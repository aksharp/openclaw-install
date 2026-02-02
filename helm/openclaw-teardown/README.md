# OpenClaw teardown Helm chart

This chart **rolls back** the OpenClaw deployment so the cluster returns to the same state as **before** anything was installed.

It does **not** run uninstall automatically. It installs a **ConfigMap** with a teardown script and prints the exact **commands** to run in NOTES. You run those commands from your machine (with `helm` and `kubectl`) to uninstall releases and delete namespaces.

---

## What gets removed

1. **OpenClaw release** (`openclaw` by default) — gateway, Vault, observability, HAProxy Ingress, cert-manager (all installed together by the openclaw chart).
2. **Optional:** the **namespace** (`openclaw` by default) so no leftover resources remain.

---

## Usage

### 1. Install the teardown chart (from repo root)

```bash
helm install teardown ./helm/openclaw-teardown -n default
```

Or with overrides if you used different release names or namespaces (copy from example first):

```bash
cp helm/openclaw-teardown/teardown-values.yaml.example helm/openclaw-teardown/teardown-values.yaml
# Edit teardown-values.yaml if needed (release names, namespaces)
helm install teardown ./helm/openclaw-teardown -n default -f helm/openclaw-teardown/teardown-values.yaml
```

### 2. Run the commands from NOTES

After install, Helm prints the commands. Run them in order:

```bash
# 1. Uninstall OpenClaw (gateway, Vault, observability, HAProxy, cert-manager)
helm uninstall openclaw -n openclaw --wait

# 2. Delete namespace (full rollback)
kubectl delete namespace openclaw --ignore-not-found --timeout=120s

# 3. Remove this teardown release (optional)
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
| `deleteNamespaces` | `true` | Delete namespace after uninstall for full rollback |

---

## Example: custom release/namespace

If you installed OpenClaw with a different release name or namespace:

```yaml
# teardown-values.yaml
openclaw:
  releaseName: my-openclaw
  namespace: my-openclaw-ns
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

After step 2, the cluster is back to the state before OpenClaw was installed.
