resource "kubernetes_persistent_volume_claim_v1" "claims" {
  for_each = { for claim in local.claims : claim.name => claim }
  metadata {
    namespace = kubernetes_namespace_v1.mail-server.metadata[0].name
    name      = each.value.name
    labels = {
      "storage" = "${each.value.name}-l"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = each.value.storage
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.mail-server]
}
