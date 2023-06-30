
resource "kubernetes_persistent_volume_claim_v1" "vmail" {
  metadata {
    namespace = "mail-server"
    name      = "vmail"
    labels = {
      "storage" = "vmail-l"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "7Gi"
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.mail-server]
}

resource "kubernetes_persistent_volume_claim_v1" "mysql" {
  metadata {
    namespace = "mail-server"
    name      = "mysql"
    labels = {
      "storage" = "mysql-l"
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

resource "kubernetes_persistent_volume_claim_v1" "clamav" {
  metadata {
    namespace = "mail-server"
    name      = "clamav"
    labels = {
      "storage" = "clamav-l"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.mail-server]
}

resource "kubernetes_persistent_volume_claim_v1" "spamassassin" {
  metadata {
    namespace = "mail-server"
    name      = "spamassassin"
    labels = {
      "storage" = "spamassassin-l"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.mail-server]
}

resource "kubernetes_persistent_volume_claim_v1" "postfix" {
  metadata {
    namespace = "mail-server"
    name      = "postfix"
    labels = {
      "storage" = "postfix-l"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.mail-server]
}

resource "kubernetes_persistent_volume_claim_v1" "custom" {
  metadata {
    namespace = "mail-server"
    name      = "custom"
    labels = {
      "storage" = "custom-l"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.mail-server]
}
