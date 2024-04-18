provider "tls" {}

provider "local" {}

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "ca" {
  content         = tls_private_key.ca.private_key_pem
  filename        = "${path.cwd}/certs/ca_private_key.pem"
  file_permission = "0600"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem   = tls_private_key.ca.private_key_pem
  is_ca_certificate = true

  subject {
    common_name         = var.lab_common_name
    organization        = var.lab_organization_name
    organizational_unit = var.lab_organizational_unit
  }

  validity_period_hours = 87600 #10years

  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}

resource "local_file" "ca_cert" {
  content         = tls_self_signed_cert.ca.cert_pem
  filename        = "${path.cwd}/certs/ca.pem"
  file_permission = "0600"
}

# Configure for Vault server
resource "tls_private_key" "vault" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "vault_key" {
  content         = tls_private_key.vault.private_key_pem
  filename        = "${path.cwd}/certs/vault_private_key.pem"
  file_permission = "0600"
}

resource "tls_cert_request" "vault_csr" {
  private_key_pem = tls_private_key.vault.private_key_pem

  subject {
    common_name         = var.lab_common_name
    organization        = var.lab_organization_name
    organizational_unit = var.lab_organizational_unit
  }

  dns_names    = ["*.vault.${var.lab_domain}"]
  ip_addresses = ["127.0.0.1"]
}

resource "tls_locally_signed_cert" "vault_cert" {
  cert_request_pem   = tls_cert_request.vault_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 43800 #5years

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

resource "local_file" "chu_dev_cert_pem" {
  content         = tls_locally_signed_cert.vault_cert.cert_pem
  filename        = "${path.cwd}/certs/vault_cert.pem"
  file_permission = "0600"
}

