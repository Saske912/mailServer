variable "domains" {
  type = list(object({
    name     = string,
    selector = string
  }))
  default = [
  { name = "kolve.ru", selector = "kolve" }]
}

variable "base_domain" {
  type = string
}
