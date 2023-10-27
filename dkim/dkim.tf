data "kubernetes_service_account_v1" "dkim" {
  metadata {
    name      = "dkim"
    namespace = kubernetes_namespace_v1.mail-server.metadata[0].name
  }
}

data "kubernetes_config_map" "my_cluster" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
}

resource "kubernetes_secret" "dkim" {
  metadata {
    name      = kubernetes_service_account_v1.name.metadata[0].name
    namespace = kubernetes_namespace_v1.mail-server.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.name.metadata[0].name
    }
  }
  type       = "kubernetes.io/service-account-token"
  depends_on = [kubernetes_service_account.user_service_accounts]
}

resource "kubernetes_config_map" "kubeconfig" {
  metadata {
    name      = "kubeconfig"
    namespace = kubernetes_namespace_v1.mail-server.metadata[0].name
  }
  data = {
    "config" = <<EOT
apiVersion: v1
kind: Config
clusters:
- name: default
  cluster:
    certificate-authority-data: ${base64encode(data.kubernetes_config_map.my_cluster.data["ca.crt"])}
    server: https://${var.base_domain}:6443
contexts:
- context:
	cluster: default
	user: default
	namespace: ${kubernetes_namespace_v1.mail-server.metadata[0].name}
  name: default
current-context: default
users:
- name: default
  user:
    token: ${kubernetes_secret.dkim.data["token"]}
	  EOT
  }
}

resource "kubernetes_job" "dkim" {
  metadata {
    name      = "dkim"
    namespace = kubernetes_namespace_v1.mail-server.metadata[0].name
  }
  spec {
    template {
      metadata {
        labels = {
          app = "dkim"
        }
      }
      spec {
        volume {
          name = "dkim"
          empty_dir {}
        }
        volume {
          name = kubernetes_config_map.kubeconfig.metadata[0].name
          config_map {
            name = kubernetes_config_map.kubeconfig.metadata[0].name
          }
        }
        dynamic "container" {
          for_each = tolist(var.domains)
          content {
            name    = "dkim"
            image   = "instrumentisto/opendkim"
            command = ["opendkim-genkey"]
            args = [
              "--subdomains",
              "--domain=${each.value.name}",
              "--selector=${each.value.selector}",
              "--directory=/tmp"
            ]
            volume_mount {
              mount_path = "/tmp"
              name       = "dkim"
              read_only  = false
            }
          }
        }
        container {
          name    = "kubectl"
          image   = "bitnami/kubectl:latest"
          command = ["kubectl"]
          args = [
            "create",
            "configmap",
            kubernetes_config_map.kubeconfig.metadata[0].name,
            "--from-file=/tmp"
          ]
          volume_mount {
            mount_path = "/tmp"
            name       = "dkim"
            read_only  = true
          }
          volume_mount {
            mount_path = ".kube/"
            name       = kubernetes_config_map.kubeconfig.metadata[0].name
          }
        }
      }
    }
  }
}

output "config-map-name" {
  value = kubernetes_config_map.kubeconfig.metadata[0].name
}
