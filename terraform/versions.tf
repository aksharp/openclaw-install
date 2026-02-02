terraform {
  required_version = ">= 1.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.1"
    }
  }

  # Optional: remote backend for state (e.g. S3, GCS, Terraform Cloud)
  # backend "remote" { ... }
}

# Kubernetes and Helm — use kubeconfig (default ~/.kube/config).
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

provider "tailscale" {
  api_key = var.tailscale_api_key
}
