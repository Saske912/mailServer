provider "kubectl" {
  config_path    = "~/.kube/config"
  config_context = "default"
}

provider "vault" {
  address            = "https://vault.kolve.ru"
  add_address_to_env = true
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "default"
}

provider "cloudflare" {
  api_token = data.vault_generic_secret.cloudflare.data["token"]
}

provider "null" {}
