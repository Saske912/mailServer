data "vault_generic_secret" "cloudflare" {
  path = "secret/cloudflare"
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

resource "cloudflare_record" "dkim" {
  depends_on = [null_resource.fetch_files]
  for_each = {
    for domain in var.domains : domain.selector => {
      file_content = file(".cache/${domain.selector}.txt")
      name         = domain.name
    }
  }
  zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
  name    = format("%s%s%s", regex("^(.+?)_domainkey", each.value.file_content)[0], "_domainkey.", each.value.name)
  type    = "TXT"
  ttl     = 1
  value   = format("%s%s", "v=DKIM1; k=rsa; p=", regex("p=(.+?)\"", each.value.file_content)[0])
}

output "record" {
  value = cloudflare_record.dkim["kolve"].name
}

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
