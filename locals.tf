locals {
  claims = tolist([
    {
      name    = "vmail"
      storage = "7Gi"
      path    = "/var/vmail"
    },
    {
      name    = "mysql"
      storage = "5Gi"
      path    = "/var/lib/mysql"
    },
    {
      name    = "clamav"
      storage = "2Gi"
      path    = "/var/lib/clamav"
    },
    {
      name    = "spamassassin"
      storage = "2Gi"
      path    = "/var/lib/spamassassin"
    },
    {
      name    = "postfix"
      storage = "2Gi"
      path    = "/var/spool/postfix"
    },
    # {
    #   name    = "custom"
    #   storage = "1Gi"
    #   path    = "/opt/iredmail/custom"
    # },
  ])
  ports = tolist([
    {
      number = 80
      name   = "http"
    },
    {
      number = 443
      name   = "https"
    },
    {
      number    = 110
      node_port = 31726
      name      = "pop3-tls"
    },
    {
      number    = 995
      node_port = 32336
      name      = "pop3-ssl"
    },
    {
      number    = 143
      node_port = 32314
      name      = "imap-tls"
    },
    {
      number    = 993
      node_port = 30918
      name      = "imap-ssl"
    },
    {
      number    = 25
      node_port = 30781
      name      = "smtp"
    },
    {
      number    = 587
      node_port = 32658
      name      = "smtp-tls"
    },
  ])
}
