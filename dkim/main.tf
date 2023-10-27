terraform {
  backend "kubernetes" {
    secret_suffix  = "mail-server-dkim"
    config_path    = "~/.kube/config"
    config_context = "default"
  }
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.20.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "default"
}
