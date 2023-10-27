resource "kubernetes_config_map_v1" "amavis" {
  metadata {
    name      = "amavis"
    namespace = var.name
  }
  data = {
    "amavis" = templatefile("amavis-config.tpl", { domains = var.domains, amavispass = data.vault_generic_secret.mail.data["AMAVISD_DB_PASSWORD"] })
  }
}
