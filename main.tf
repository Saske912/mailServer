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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

provider "vault" {
  address = "http://10.0.0.45:8200"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}


resource "kubernetes_namespace_v1" "mail-server" {
  metadata {
    name = "mail-server"
  }
}


variable "name" {
  default = "mail-server"
}

variable "cert_domains" {
  type = list(string)
  default = [
    "kolve.ru", "my-flora.shop", "mail.my-flora.shop", "develop.kolve.ru"
  ]
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
    "HOSTNAME"          = data.vault_generic_secret.mail.data["HOSTNAME"]
    "FIRST_MAIL_DOMAIN" = data.vault_generic_secret.mail.data["FIRST_MAIL_DOMAIN"]
    "POSTMASTER_EMAIL"  = data.vault_generic_secret.mail.data["POSTMASTER_EMAIL"]
    //disable clamav
    "clamav" = ""
  }
}

resource "kubernetes_secret_v1" "mail-server" {
  metadata {
    name      = var.name
    namespace = var.name
  }
  data = {
    "FIRST_MAIL_DOMAIN_ADMIN_PASSWORD" = data.vault_generic_secret.mail.data["FIRST_MAIL_DOMAIN_ADMIN_PASSWORD"]
    "MLMMJADMIN_API_TOKEN"             = data.vault_generic_secret.mail.data["MLMMJADMIN_API_TOKEN"]
    "ROUNDCUBE_DES_KEY"                = data.vault_generic_secret.mail.data["ROUNDCUBE_DES_KEY"]
    "AMAVISD_DB_PASSWORD"              = data.vault_generic_secret.mail.data["AMAVISD_DB_PASSWORD"]
  }
}

resource "kubectl_manifest" "my-flora-dot-shop" {
  yaml_body = <<EOT
apiVersion: "cert-manager.io/v1"
kind: "Certificate"
metadata:
  name: "mail"
  namespace: "mail-server"
spec:
  secretName: "mail-tls"
  additionalOutputFormats:
  - type: CombinedPEM
  issuerRef:
    name: "pfile"
    kind: "ClusterIssuer"
    group: "cert-manager.io"
  dnsNames:
  %{for domain in var.cert_domains~}
  - "${domain}"
  %{endfor~}
EOT
}

resource "kubectl_manifest" "dkim" {
  yaml_body = <<EOT
apiVersion: v1
kind: Secret
metadata:
  name: dkim
  namespace: ${var.name}
type: Opaque
data:
  %{for domain in var.domains~}
  ${domain.dkim}: "${base64encode(file(domain.dkim))}"
  %{endfor~}
EOT
}


resource "kubernetes_deployment_v1" "mail-server" {
  depends_on = [kubernetes_persistent_volume_claim_v1.clamav, kubernetes_persistent_volume_claim_v1.mysql,
  kubernetes_persistent_volume_claim_v1.vmail, kubectl_manifest.my-flora-dot-shop]
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
          volume_mount {
            name       = "mysql"
            mount_path = "/var/lib/mysql"
          }
          volume_mount {
            name       = "clamav"
            mount_path = "/var/lib/clamav"
          }
          volume_mount {
            name       = "spamassassin"
            mount_path = "/var/lib/spamassassin"
          }
          volume_mount {
            name       = "postfix"
            mount_path = "/var/spool/postfix"
          }
          volume_mount {
            name       = "custom"
            mount_path = "/opt/iredmail/custom"
          }
          port {
            container_port = 80
            name           = "http"
          }
          port {
            container_port = 443
            name           = "https"
          }
          port {
            container_port = 110
            name           = "pop3-tls"
          }
          port {
            container_port = 995
            name           = "pop3-ssl"
          }
          port {
            container_port = 143
            name           = "imap-tls"
          }
          port {
            container_port = 993
            name           = "imap-ssl"
          }
          port {
            container_port = 25
            name           = "smtp"
          }
          port {
            container_port = 587
            name           = "smtp-tls"
          }
          env_from {
            config_map_ref {
              name = var.name
            }
          }
          env_from {
            secret_ref {
              name = var.name
            }
          }
          volume_mount {
            name       = "key"
            mount_path = "/opt/iredmail/ssl/key.pem"
            sub_path   = "key.pem"
            read_only  = true
          }
          volume_mount {
            name       = "cert"
            mount_path = "/opt/iredmail/ssl/cert.pem"
            sub_path   = "cert.pem"
            read_only  = true
          }
          volume_mount {
            name       = "combined"
            mount_path = "/opt/iredmail/ssl/combined.pem"
            sub_path   = "combined.pem"
            read_only  = true
          }
          volume_mount {
            name       = "clamfail"
            mount_path = "/etc/supervisor/conf.d/clamav.conf"
            sub_path   = "clamav.conf"
          }
          volume_mount {
            name       = "amavis"
            mount_path = "/etc/amavis/conf.d/50-user"
            sub_path   = "50-user"
          }
          volume_mount {
            name       = "dkim"
            mount_path = "/opt/iredmail/custom/amavisd/dkim"
            read_only  = true
          }
        }
        volume {
          name = "vmail"
          persistent_volume_claim {
            claim_name = "vmail"
          }
        }
        volume {
          name = "custom"
          persistent_volume_claim {
            claim_name = "custom"
          }
        }
        volume {
          name = "mysql"
          persistent_volume_claim {
            claim_name = "mysql"
          }
        }
        volume {
          name = "clamav"
          persistent_volume_claim {
            claim_name = "clamav"
          }
        }
        volume {
          name = "spamassassin"
          persistent_volume_claim {
            claim_name = "spamassassin"
          }
        }
        volume {
          name = "postfix"
          persistent_volume_claim {
            claim_name = "postfix"
          }
        }
        volume {
          name = "amavis"
          config_map {
            name = "amavis"
            items {
              key  = "amavis"
              path = "50-user"
            }
          }
        }
        volume {
          name = "clamfail"
          config_map {
            name = var.name
            items {
              key  = "clamav"
              path = "clamav.conf"
            }
          }
        }
        volume {
          name = "combined"
          secret {
            secret_name = "mail-tls"
            items {
              key  = "tls-combined.pem"
              path = "combined.pem"
            }
          }
        }
        volume {
          name = "key"
          secret {
            secret_name = "mail-tls"
            items {
              key  = "tls.key"
              path = "key.pem"
            }
          }
        }
        volume {
          name = "cert"
          secret {
            secret_name = "mail-tls"
            items {
              key  = "tls.crt"
              path = "cert.pem"
            }
          }
        }
        volume {
          name = "dkim"
          secret {
            secret_name = "dkim"
          }
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
      port        = 80
      name        = "http"
      target_port = "http"
    }
    port {
      port        = 443
      name        = "https"
      target_port = "https"
    }
    port {
      port        = 110
      name        = "pop3-tls"
      target_port = "pop3-tls"
      node_port   = 31726
    }
    port {
      port        = 25
      name        = "smtp"
      target_port = "smtp"
      node_port   = 30781
    }
    port {
      port        = 587
      name        = "smtp-tls"
      target_port = "smtp-tls"
      node_port   = 32658
    }
    port {
      port        = 143
      name        = "imap-tls"
      target_port = "imap-tls"
      node_port   = 32314
    }
    port {
      port        = 993
      name        = "imap-ssl"
      target_port = "imap-ssl"
      node_port   = 30918
    }
    port {
      port        = 995
      name        = "pop3-ssl"
      target_port = "pop3-ssl"
      node_port   = 32336
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
