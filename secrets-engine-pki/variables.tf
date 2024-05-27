variable "pki_path" {
  default = "pki-handson"
}

variable "common_names" {
  type    = map(string)
  default = {}
}

variable "vault_url" {
  type    = string
  default = "https://127.0.0.1:8200"
}