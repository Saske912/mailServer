terraform {
  backend "kubernetes" {
    secret_suffix = "mail-server"
    config_path   = "~/.kube/config"
  }
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.20.0"
    }
    mikrotik = {
      source  = "kube-cloud/mikrotik"
      version = "0.12.0"
    }
  }
}

provider "vault" {
  address = "http://10.0.0.45:8200"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

data "vault_generic_secret" "cloudflare" {
  path = "kv/cloudflare"
}

provider "cloudflare" {
  api_token = data.vault_generic_secret.cloudflare.data["token"]
}

resource "cloudflare_record" "spf" {
  zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
  name    = "kolve.ru"
  type    = "TXT"
  value   = "v=spf1 redirect=_spf.mail.ru +a +mx ~all"
  ttl     = 1
}

resource "cloudflare_record" "dmark" {
  zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
  name    = "_dmarc"
  type    = "TXT"
  value   = "v=DMARC1; p=reject; rua=mailto:saveloy@yandex.ru"
  ttl     = 1
}

data "vault_generic_secret" "dkim" {
  path = "kv/dkim-keys/kolve.ru"
}

resource "cloudflare_record" "dkim" {
  zone_id = jsondecode(data.vault_generic_secret.cloudflare.data["zone"]).kolve
  name    = "mail._domainkey"
  value   = "v=DKIM1; h=sha256; k=rsa; s=email; p=${data.vault_generic_secret.dkim.data.public_key}"
  type    = "TXT"
  ttl     = 3600
}

resource "kubernetes_namespace_v1" "mail-server" {
  metadata {
    name = "mail-server"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "vmail" {
  metadata {
    namespace = "mail-server"
    name      = "vmail"
    labels = {
      "storage" = "vmail"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.mail-server]
}

variable "name" {
  default = "mail-server"
}

data "vault_generic_secret" "mail" {
  path = "kv/mail"
}


resource "kubernetes_config_map_v1" "mail-server" {
  metadata {
    name      = var.name
    namespace = var.name
  }
  data = {
    "HOSTNAME"                         = data.vault_generic_secret.mail.data["HOSTNAME"]
    "FIRST_MAIL_DOMAIN_ADMIN_PASSWORD" = data.vault_generic_secret.mail.data["FIRST_MAIL_DOMAIN_ADMIN_PASSWORD"]
    "FIRST_MAIL_DOMAIN"                = data.vault_generic_secret.mail.data["FIRST_MAIL_DOMAIN"]
    "MLMMJADMIN_API_TOKEN"             = data.vault_generic_secret.mail.data["MLMMJADMIN_API_TOKEN"]
    "ROUNDCUBE_DES_KEY"                = data.vault_generic_secret.mail.data["ROUNDCUBE_DES_KEY"]
  }
}

resource "kubernetes_deployment_v1" "mail-server" {
  metadata {
    name      = "mail-server"
    namespace = var.name
    labels = {
      "app" = "mail-server"
    }
  }
  spec {
    selector {
      match_labels = {
        "app" = "mail-server"
      }
    }
    replicas = 1
    template {
      metadata {
        labels = {
          "app" = "mail-server"
        }
      }
      spec {
        container {
          image = "iredmail/mariadb:stable"
          name  = "iredmail"
          volume_mount {
            name       = "vmail"
            mount_path = "/var/vmail"
          }
          port {
            container_port = 80
          }
          port {
            container_port = 443
          }
          env_from {
            config_map_ref {
              name = var.name
            }
          }
        }
        volume {
          name = "vmail"
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "mail-server" {
  metadata {
    name      = "mail-server"
    namespace = var.name
    labels = {
      "service" = "mail-server"
    }
  }
  spec {
    type = "LoadBalancer"
    selector = {
      "app" = "mail-server"
    }
    port {
      port = 80
      name = "http"
    }
    port {
      port = 443
      name = "https"
    }
  }
}

resource "kubernetes_ingress_v1" "mail-server" {
  metadata {
    name      = var.name
    namespace = var.name
    annotations = {
      "cert-manager.io/cluster-issuer"               = "pfile"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = [data.vault_generic_secret.mail.data["HOSTNAME"]]
      secret_name = "${data.vault_generic_secret.mail.data["HOSTNAME"]}-tls"
    }
    rule {
      host = data.vault_generic_secret.mail.data["HOSTNAME"]
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.name
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
}

data "vault_generic_secret" "microtik_home" {
  path = "kv/mikrotiks/home"
}

provider "mikrotik" {
  host           = "${data.vault_generic_secret.microtik_home.data["host"]}:8728" # Or set MIKROTIK_HOST environment variable
  username       = data.vault_generic_secret.microtik_home.data["username"]       # Or set MIKROTIK_USER environment variable
  password       = data.vault_generic_secret.microtik_home.data["password"]       # Or set MIKROTIK_PASSWORD environment variable
  tls            = true                                                           # Or set MIKROTIK_TLS environment variable
  ca_certificate = "cert_export_ServerCA_home.crt"                                # Or set MIKROTIK_CA_CERTIFICATE environment variable
  insecure       = true                                                           # Or set MIKROTIK_INSECURE environment variable
}

resource "mikrotik_firewall_nat" "nat_rule" {
  chain               = "dstnat"
  action              = "dst-nat"
  destination_port    = "465"
  protocol            = "tcp"
  destination_address = "10.0.0.45"
  in_interface        = "ether1"
  in_bridge_port      = "465"
}

# resource "mikrotik_dns_record" "record" {
#   name    = "example.domain.com"
#   address = "192.168.88.1"
#   ttl     = 300
# }
