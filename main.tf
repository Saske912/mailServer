terraform {
  backend "kubernetes" {
    secret_suffix  = "mail-server"
    config_path    = "~/.kube/config"
    config_context = "default"
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
    vault = {
      source  = "hashicorp/vault"
      version = "3.21.0"
    }
  }
}

resource "kubernetes_namespace_v1" "mail-server" {
  metadata {
    name = "mail-server"
  }
}

data "vault_generic_secret" "mail" {
  path = "secret/mail"
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

resource "kubectl_manifest" "mail-tls" {
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
  %{for domain in var.domains~}
  - "${domain.name}"
  %{endfor~}
EOT
}

resource "kubernetes_deployment_v1" "mail-server" {
  depends_on = [kubernetes_persistent_volume_claim_v1.claims,
  kubernetes_job.dkim]
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
        node_selector = {
          external-ip   = "true"
          fast-internet = "true"
        }
        container {
          image = "iredmail/mariadb:stable"
          name  = "iredmail"
          dynamic "port" {
            for_each = local.ports
            content {
              container_port = port.value.number
              name           = port.value.name
            }
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
          dynamic "volume_mount" {
            for_each = local.claims
            content {
              name       = volume_mount.value.name
              mount_path = volume_mount.value.path
            }
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

            read_only = false
          }
          dynamic "volume_mount" {
            for_each = local.tls
            content {
              name       = volume_mount.value.name
              mount_path = volume_mount.value.mount_path
              sub_path   = volume_mount.value.path
              read_only  = false
            }
          }
        }
        dynamic "volume" {
          for_each = local.claims
          content {
            name = volume.value.name
            persistent_volume_claim {
              claim_name = volume.value.name
            }
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
          name = "dkim"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.dkim.metadata[0].name
          }
        }
        dynamic "volume" {
          for_each = local.tls
          content {
            name = volume.value.name
            secret {
              secret_name = "mail-tls"
              items {
                key  = volume.value.key
                path = volume.value.path
              }
            }
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
    dynamic "port" {
      for_each = local.ports
      content {
        port        = port.value.number
        target_port = port.value.name
        name        = port.value.name
        node_port   = can(port.value.node_port) ? port.value.node_port : null
      }
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
