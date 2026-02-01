# Ingress (HAProxy), DNS names, Consul, and Lens

**Access is via Ingress only.** This doc explains how **Ingress** (HAProxy + the chart’s Ingress resource) provides **DNS-style hostnames** (e.g. `openclaw.openclaw.local`, `vault.openclaw.local`) so you access everything through one entry point—no per-service port-forwarding. Also: when **Consul** helps (and when it doesn’t), and how **Lens** connects to your cluster.

---

## 1. Ingress + DNS: the only access path

**Goal:** Access OpenClaw, Vault, Grafana, Prometheus, etc. via hostnames (e.g. `openclaw.{domain}`, `vault.{domain}`, `grafana.{domain}`). There is no per-service port-forward option; HAProxy is the single entry point and routes by **Host** header to the right Service.

### 1.1 HAProxy and TLS (built into the OpenClaw chart)

1. **The OpenClaw chart always installs HAProxy and cert-manager.** Ingress is required. When you install the openclaw chart, the HAProxy Kubernetes Ingress Controller (ingress class `haproxy`) and cert-manager are installed as dependencies. The chart's Ingress resource uses `ingress.className: haproxy`.
2. **Set the Ingress domain** in `prerequisites.yaml`. Default: `ingress.domain: openclaw.local`. Override for production (e.g. `your-domain.com`):

   ```yaml
   ingress:
     className: haproxy
     domain: openclaw.local   # or your-domain.com for production
     tls:
       enabled: true
       secretName: ""            # cert-manager creates secret when cluster-issuer annotation is set
     hosts:
       gateway: true
       gatewayHost: ""            # optional override; default openclaw.{domain}
       vault: true
       vaultHost: ""
       grafana: true
       grafanaHost: ""
       prometheus: false
       prometheusHost: ""
   ```

   You can override any host with a different name (e.g. `gatewayHost: app.example.org`).

3. **Point DNS** for your domain at the Ingress controller (the openclaw chart installs the controller in the release namespace):

   - **Cloud / LoadBalancer:** The HAProxy Helm chart typically exposes a LoadBalancer Service. Get its external IP/hostname and create DNS A/CNAME records:
     - `openclaw.my-domain.com` → that IP/hostname  
     - `vault.my-domain.com` → same  
     - `grafana.my-domain.com` → same  
   - **Local (Docker Desktop / minikube / kind):** Use a local DNS override (e.g. `/etc/hosts`) or a local DNS server so `openclaw.my-domain.com` etc. resolve to the Ingress endpoint (e.g. `127.0.0.1` or minikube IP). For minikube: `minikube tunnel` or NodePort + `minikube ip`.

4. **Install or upgrade the release** (the Ingress resource is always created when `ingress.domain` is set):

   ```bash
   helm dependency update ./helm/openclaw
   helm upgrade --install openclaw ./helm/openclaw -f prerequisites.yaml -n openclaw --create-namespace
   ```

You then use **https://openclaw.my-domain.com**, **https://vault.my-domain.com**, **https://grafana.my-domain.com** (with TLS if configured) without port-forwarding.

### 1.2 NGINX Ingress instead of HAProxy

If you prefer NGINX Ingress instead of HAProxy:

1. Do **not** rely on the chart's built-in HAProxy; install the [NGINX Ingress controller](https://kubernetes.github.io/ingress-nginx/deploy/) (e.g. via Helm or manifest) and disable or override the chart's HAProxy dependency if your setup supports it.
2. In your OpenClaw values set:

   ```yaml
   ingress:
     className: nginx
     domain: my-domain.com
     # ... same as above
   ```

3. Point DNS at the NGINX Ingress LoadBalancer / NodePort and upgrade the release as above.

The chart’s single Ingress resource works with any controller that supports **host-based routing** (HAProxy, NGINX, Traefik, etc.); only `ingress.className` and controller installation differ.

### 1.3 V10 security: don’t expose to the public internet

Per [OPENCLAW-DOCKER-SECURE-INSTALL-V10.md](../../OPENCLAW-DOCKER-SECURE-INSTALL-V10.md), the gateway and Vault should **not** be on the public internet. Prefer:

- **Tailscale:** Run the Ingress controller (or a proxy) on a node that’s on your tailnet; use Tailscale DNS or MagicDNS so `openclaw.my-domain.com` resolves only for tailnet devices.
- **Private IP / VPN:** Expose the Ingress only on a private IP and access via VPN or bastion.
- **Restrict by IP / auth:** Use Ingress annotations (or a WAF) to limit who can reach `openclaw.*` and `vault.*`.

So: Ingress + DNS gives you **no port-forward** and **friendly names**; keep that entry point **not** on the public internet (Tailscale / private / VPN).

---

## 2. Consul: when it helps and when it doesn’t

**Consul** is a service mesh and service-discovery platform (DNS, health checks, KV, optional mTLS).

### 2.1 “No port-forward” and “DNS names like openclaw.my-domain.com”

- **Ingress (HAProxy/NGINX)** is what actually gives you:
  - A single entry point (no port-forward to each app).
  - DNS names that resolve to that entry point and are routed by host (openclaw.my-domain.com, vault.my-domain.com, etc.).
- **Consul** does **not** replace Ingress for this. In Kubernetes, **service discovery** is already provided by **Kubernetes Services and cluster DNS** (e.g. `openclaw-openclaw-gateway.openclaw.svc.cluster.local`). Consul’s DNS would be an extra layer, and **external** DNS names like `openclaw.my-domain.com` are still best done with Ingress + your real DNS (or Tailscale DNS).

So for “no port-forward” and “openclaw.my-domain.com / vault.my-domain.com”:** use Ingress (and optionally Tailscale). You don’t need Consul for that.

### 2.2 When Consul can still be useful

- **Multi-datacenter / multi-cluster:** Consul can federate services across datacenters or clusters and provide discovery across them.
- **Service mesh (Consul Connect):** mTLS between services, traffic splitting, intentions. Only relevant if you want mesh features beyond “route to service by hostname.”
- **External services:** Register non-Kubernetes backends in Consul and expose them via Consul DNS or sidecar.
- **KV / config:** You already use Vault for secrets; Consul KV could be used for non-secret config, but it’s optional.

**Summary:** For the OpenClaw Helm setup, **Ingress + DNS** solves “no port-forward” and “openclaw.my-domain.com” style names. **Consul is optional** and only needed if you want multi-DC discovery, service mesh, or Consul-specific features. No change to the current chart is required for Consul; if you add Consul later, it would typically run alongside the existing Services.

---

## 3. Lens: connecting to your Kubernetes cluster

**Lens** is a desktop IDE for Kubernetes. It uses the **same kubeconfig** as `kubectl` (the current context). **No changes to the OpenClaw Helm chart or cluster are required** for Lens to work.

### 3.1 Local cluster (Docker Desktop, minikube, kind)

1. Start your cluster and deploy OpenClaw as usual (see [LOCAL-KUBERNETES-MAC.md](LOCAL-KUBERNETES-MAC.md)).
2. Open **Lens**.
3. **Add cluster:** Lens will pick up your default kubeconfig (`~/.kube/config`). If your cluster is already the current context (e.g. `docker-desktop`, `minikube`, `kind-openclaw`), Lens will show it. Otherwise: **File → Add Cluster** (or **Catalog**) and choose the kubeconfig / context for your cluster.
4. No firewall or Ingress changes are needed; Lens talks to the cluster API the same way `kubectl` does (local context).

### 3.2 Remote cluster (e.g. on a server or cloud)

1. **Reachability:** Lens must be able to reach the cluster’s **API server** (e.g. `https://<api-server>:6443`). That usually means:
   - The API has a public endpoint (cloud), or  
   - You’re on the same network/VPN, or  
   - You use **Tailscale** (or similar) so your laptop and the cluster node share a network and you use the Tailscale IP/hostname of the API.
2. **Kubeconfig:** Your local kubeconfig must point at that API (server URL, certs, token or exec auth). Merge the remote cluster’s kubeconfig into `~/.kube/config` or a file you add in Lens.
3. **Lens:** Add the cluster in Lens using that kubeconfig/context. No Helm or chart changes are required.

### 3.3 Nothing to change in the chart

- The OpenClaw chart does **not** expose the Kubernetes API; the API is provided by the cluster itself (Docker Desktop, minikube, kind, or your cloud provider).
- Lens does **not** need Ingress, HAProxy, or Consul to connect; it only needs **network path to the API server** and a **valid kubeconfig**.

So: **use Ingress for DNS names and no port-forward; use Lens with your existing kubeconfig** — no adjustments to the current setup are required for Lens.

---

## 4. Quick reference

| Need | Use |
|------|-----|
| No port-forward + DNS names (openclaw.my-domain.com, vault.my-domain.com) | **Ingress** (HAProxy or NGINX) — chart always uses Ingress; set `ingress.domain` + real DNS or Tailscale DNS |
| Service discovery inside the cluster | **Kubernetes Services/DNS** (already there) |
| Multi-DC, service mesh, Consul-specific features | **Consul** (optional; not required for DNS or port-forward) |
| Connect with Lens | **Kubeconfig** + reachable API server; no chart changes |

See also: [README](../README.md), [LOCAL-KUBERNETES-MAC.md](LOCAL-KUBERNETES-MAC.md), [OPENCLAW-DOCKER-SECURE-INSTALL-V10.md](../../OPENCLAW-DOCKER-SECURE-INSTALL-V10.md).
