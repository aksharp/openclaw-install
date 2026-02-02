# Cloudflare DNS (optional)

Creates A records for OpenClaw Ingress hosts. Run **after** the main Terraform apply.

## Prerequisites

- Main Terraform apply completed
- Ingress controller has an external IP

## Usage

1. Get the Ingress IP:
   ```bash
   kubectl get svc -n openclaw -l app.kubernetes.io/name=kubernetes-ingress
   ```

2. Copy the example and set values:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Apply (from `terraform/cloudflare/`):
   ```bash
   terraform init
   terraform apply -var-file=terraform.tfvars
   ```

Variables: `cloudflare_api_token`, `cloudflare_zone_id`, `ingress_ip`, `ingress_domain`, `dns_ttl`.
