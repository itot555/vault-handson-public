provider "vault" {}

# Root CA
resource "vault_mount" "root" {
  path        = "pki-handson"
  type        = "pki"
  description = "root ca in vault handson environment"

  default_lease_ttl_seconds = 94608000  #3year
  max_lease_ttl_seconds     = 157680000 #5year
}

resource "vault_pki_secret_backend_root_cert" "root" {
  backend     = vault_mount.root.path
  type        = "internal"
  common_name = "handson.dev"
  ttl         = "94608000"
}

resource "vault_pki_secret_backend_config_urls" "config_urls" {
  backend                 = vault_mount.root.path
  issuing_certificates    = ["https://127.0.0.1:8200/v1/${var.pki_path}/ca"]
  crl_distribution_points = ["https://127.0.0.1:8200/v1/${var.pki_path}/crl"]
}

# Intermediate CA
resource "vault_mount" "int" {
  path        = "pki-handson-int"
  type        = "pki"
  description = "intermediate ca in vault handson environment"

  default_lease_ttl_seconds = 31536000 #1year
  max_lease_ttl_seconds     = 63072000 #2year
}

resource "vault_pki_secret_backend_intermediate_cert_request" "int" {
  backend     = vault_mount.int.path
  type        = "internal"
  common_name = "handson.dev intermediate ca"
}

# Intermediate CA signed by Root CA's private key
resource "vault_pki_secret_backend_root_sign_intermediate" "root" {
  depends_on  = [vault_pki_secret_backend_intermediate_cert_request.int]
  backend     = vault_mount.root.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.int.csr
  common_name = "handson.dev intermediate ca"
  format      = "pem"
  ttl         = 63072000
}

# Import cert to vault
resource "vault_pki_secret_backend_intermediate_set_signed" "int" {
  backend     = vault_mount.int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.root.certificate
}

# Configure role for server
resource "vault_pki_secret_backend_role" "server1" {
  backend          = vault_mount.int.path
  name             = "server1"
  ttl              = 15768000 #6month
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["handson.dev"]
  allow_subdomains = true
  server_flag      = true
  client_flag      = false
}

resource "vault_pki_secret_backend_role" "server2" {
  backend          = vault_mount.int.path
  name             = "server2"
  ttl              = 2628000 #1month
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["handson.dev"]
  allow_subdomains = true
  server_flag      = true
  client_flag      = false
}

# Configure role for client
resource "vault_pki_secret_backend_role" "client1" {
  backend          = vault_mount.int.path
  name             = "client1"
  ttl              = 15768000 #6month
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["handson.dev"]
  allow_subdomains = true
  server_flag      = false
  client_flag      = true
}

# Issue cert
resource "vault_pki_secret_backend_cert" "db" {
  depends_on = [vault_pki_secret_backend_role.server1]

  backend    = vault_mount.int.path
  name       = vault_pki_secret_backend_role.server1.name
  ttl        = 15768000 #6month
  auto_renew = true

  common_name = "db.handson.dev"
}

resource "vault_pki_secret_backend_cert" "app" {
  depends_on = [vault_pki_secret_backend_role.server2]

  backend    = vault_mount.int.path
  name       = vault_pki_secret_backend_role.server2.name
  ttl        = 600 #10min
  auto_renew = true

  common_name = "app.handson.dev"
}

resource "vault_pki_secret_backend_cert" "client" {
  depends_on = [vault_pki_secret_backend_role.client1]

  for_each = var.common_names

  backend    = vault_mount.int.path
  name       = vault_pki_secret_backend_role.client1.name
  ttl        = 15768000 #6month
  auto_renew = true

  common_name = each.value
}