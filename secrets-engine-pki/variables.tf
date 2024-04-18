variable "pki_path" {
  default = "pki-handson"
}

variable "common_names" {
  type    = map(string)
  default = {}
}