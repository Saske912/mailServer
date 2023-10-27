variable "name" {
  default = "mail-server"
}

variable "base_domain" {
  type    = string
  default = "kolve.ru"
}

variable "domains" {
  type = list(object({
    name     = string,
    selector = string
  }))
  default = [
  { name = "kolve.ru", selector = "kolve" }]
}
