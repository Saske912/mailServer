variable "domains" {
  type = list(object({
    name     = string,
    selector = string,
    dkim     = string
  }))
  default = [{ name = "my-flora.shop", selector = "flora", dkim = "my-flora.shop.pem" },
  { name = "kolve.ru", selector = "kolve", dkim = "kolve.ru.pem" }]
}

resource "kubernetes_config_map_v1" "amavis" {
  metadata {
    name      = "amavis"
    namespace = var.name
  }
  data = {
    "amavis" = templatefile("amavis-config.tpl", { domains = var.domains, amavispass = data.vault_generic_secret.mail.data["AMAVISD_DB_PASSWORD"] })
  }
}
