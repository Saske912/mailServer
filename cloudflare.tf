
data "vault_generic_secret" "cloudflare" {
  path = "kv/cloudflare"
}

provider "cloudflare" {
  api_token = data.vault_generic_secret.cloudflare.data["token"]
}

resource "cloudflare_record" "spf" {
  zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).my-flora
  name    = "@"
  type    = "TXT"
  value   = "v=spf1 +a +mx ~all"
  ttl     = 1
}

resource "cloudflare_record" "dmark" {
  zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).my-flora
  name    = "_dmarc"
  type    = "TXT"
  value   = "v=DMARC1; p=reject; rua=mailto:postmaster@${data.vault_generic_secret.cloudflare.data["domain"]}; ruf=mailto:abuse@${data.vault_generic_secret.cloudflare.data["domain"]}; adkim=s; aspf=s; fo=1; sp=reject"
  ttl     = 1
}

resource "cloudflare_record" "MX" {
  zone_id  = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).my-flora
  name     = "@"
  type     = "MX"
  value    = data.vault_generic_secret.mail.data["HOSTNAME"]
  priority = 5
}

data "vault_generic_secret" "cluster" {
  path = "kv/cluster"
}

# resource "cloudflare_record" "xmpp-client" {
#   zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
#   name    = "_xmpp-client._tcp.kolve.ru."
#   type    = "SRV"
#   value   = "0 5 5222 ${data.vault_generic_secret.cluster.data["home"]}"
# }

# resource "cloudflare_record" "xmpp-server" {
#   zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
#   name    = "_xmpp-server._tcp.kolve.ru."
#   type    = "SRV"
#   value   = "0 5 5269 ${data.vault_generic_secret.cluster.data["home"]}"
# }

resource "cloudflare_record" "autoconfig" {
  zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).my-flora
  name    = "autoconfig"
  type    = "A"
  value   = data.vault_generic_secret.cluster.data["home"]
}

resource "cloudflare_record" "autodiscover" {
  zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).my-flora
  name    = "autodiscover"
  type    = "A"
  value   = data.vault_generic_secret.cluster.data["home"]
}
