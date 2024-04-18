data "terraform_remote_state" "pki" {

  backend = "local"

  config = {
    path = "${path.module}/../secrets-engine-pki/terraform.tfstate"
  }
}

provider "vault" {}

resource "vault_auth_backend" "cert" {
  description = "tls auth method"
  path        = "cert"
  type        = "cert"
}

resource "vault_cert_auth_backend_role" "client1" {
  name                 = "client1"
  certificate          = data.terraform_remote_state.pki.outputs.certificate_bundle
  backend              = vault_auth_backend.cert.path
  allowed_common_names = ["client1.handson.dev"]
  token_ttl            = 600
  token_max_ttl        = 1200
  token_policies       = ["default", "read-fruits"]
}

resource "vault_cert_auth_backend_role" "others" {
  name                 = "others"
  certificate          = data.terraform_remote_state.pki.outputs.certificate_bundle
  backend              = vault_auth_backend.cert.path
  allowed_common_names = ["client2.handson.dev", "client3.handson.dev"]
  token_ttl            = 600
  token_max_ttl        = 1200
  token_policies       = ["default", "all-vegetables"]
}