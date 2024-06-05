provider "vault" {}

resource "vault_mount" "ssh_signer" {
  path        = "ssh-client-signer"
  type        = "ssh"
  description = "signed ssh certificates"
}

resource "vault_ssh_secret_backend_ca" "ssh_signer" {
  backend              = vault_mount.ssh_signer.path
  generate_signing_key = true
}

resource "vault_ssh_secret_backend_role" "client1" {
  name                    = "client1"
  backend                 = vault_mount.ssh_signer.path
  key_type                = "ca"
  algorithm_signer        = "rsa-sha2-256"
  allow_user_certificates = true
  allowed_users           = "ubuntu,ssh-certs-test"
  allowed_extensions      = "permit-pty,permit-port-forwarding"
  default_extensions = {
    permit-pty = ""
  }
  #default_user = ""
  ttl          = "10m"
}