resource "null_resource" "fetch_files" {
  depends_on = [kubernetes_deployment_v1.mail-server]
  for_each   = { for idx, domain in var.domains : idx => domain }
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "kubectl -n mail-server exec deploy/mail-server iredmail -- cat /opt/iredmail/custom/amavisd/dkim/${each.value.selector}.txt > .cache/${each.value.selector}.txt"
  }
}
