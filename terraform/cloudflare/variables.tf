variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token. Set via TF_VAR_cloudflare_api_token or CLOUDFLARE_API_TOKEN."
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID for the domain."
}

variable "ingress_ip" {
  type        = string
  description = "IP address of the Ingress controller for DNS A records."
}

variable "ingress_domain" {
  type        = string
  description = "Base domain (e.g. openclaw.local or your-domain.com)."
}

variable "dns_ttl" {
  type        = number
  default     = 300
  description = "TTL for DNS A records."
}
