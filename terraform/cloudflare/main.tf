locals {
  ingress_hosts = ["openclaw", "vault", "grafana", "prometheus"]
}

resource "cloudflare_record" "ingress_hosts" {
  for_each = toset(local.ingress_hosts)

  zone_id = var.cloudflare_zone_id
  name    = each.key
  type    = "A"
  value   = var.ingress_ip
  ttl     = var.dns_ttl
  comment = "OpenClaw Ingress (Terraform)"
}
