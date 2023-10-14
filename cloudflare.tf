data "vault_generic_secret" "cloudflare" {
  path = "secret/cloudflare"
}

provider "cloudflare" {
  api_token = data.vault_generic_secret.cloudflare.data["token"]
}

# resource "cloudflare_record" "sfp" {
#   zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
#   name    = "@"
#   type    = "TXT"
#   value   = "v=spf1 +a +mx ~all"
#   ttl     = 1
# }

# resource "cloudflare_record" "dmark" {
#   zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
#   name    = "_dmarc"
#   type    = "TXT"
#   value   = <<EOT
#   "v=DMARC1; p=reject; rua=mailto:${data.vault_generic_secret.mail.data["POSTMASTER_EMAIL"]}; 
#   ruf=mailto:${data.vault_generic_secret.mail.data["POSTMASTER_EMAIL"]}; adkim=s;
#    aspf=s; fo=1; sp=reject"
#    EOT
#   ttl     = 1
# }

# resource "cloudflare_record" "dkim" {
#   zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
#   name    = "kolve._domainkey" # The subdomain where you want to create the DKIM record
#   type    = "TXT"              # Type should be TXT for DKIM records
#   ttl     = 1
#   value   = <<EOT
#   v=DKIM1;h=sha256;k=rsa;p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDZxfKG8HVCLq
#   Io/eyY9LF50WO03Sf0cSr7cQ3MGWkN73CUYzB86UiCBWQ+A3rBhCc880uoy1uFVZUFuPXlaxJkn
#   upJucmnGGTgLcg+ZPRbifyKsrAh3MN0PlvqsapkRqhuBPRmtB77ujGg1wYK7wAemSRGB++znMKA
#   kp8iKKNzRwIDAQAB
#   EOT
# }

resource "cloudflare_record" "MX" {
  zone_id  = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
  name     = "@"
  type     = "MX"
  value    = data.vault_generic_secret.mail.data["HOSTNAME"]
  priority = 5
}

data "vault_generic_secret" "cluster" {
  path = "secret/cluster"
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
  zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
  name    = "autoconfig"
  type    = "A"
  value   = data.vault_generic_secret.cluster.data["home"]
}

resource "cloudflare_record" "autodiscover" {
  zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
  name    = "autodiscover"
  type    = "A"
  value   = data.vault_generic_secret.cluster.data["home"]
}
