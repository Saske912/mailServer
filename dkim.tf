resource "kubernetes_persistent_volume_claim" "dkim" {
  metadata {
    name      = "dkim"
    namespace = kubernetes_namespace_v1.mail-server.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Mi"
      }
    }
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
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.dkim.metadata[0].name
          }
        }
        dynamic "container" {
          for_each = tolist(var.domains)
          content {
            name    = "dkim-${container.value.selector}"
            image   = "instrumentisto/opendkim"
            command = ["opendkim-genkey"]
            args = [
              "--subdomains",
              "--domain=${container.value.name}",
              "--selector=${container.value.selector}",
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
          name    = "change-permissions"
          image   = "alpine"
          command = ["chmod"]
          args    = ["-R", "755", "/tmp"]
          volume_mount {
            mount_path = "/tmp"
            name       = "dkim"
            read_only  = false
          }
        }
      }
    }
  }
}
