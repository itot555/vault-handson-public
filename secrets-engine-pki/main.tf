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
  issuing_certificates    = ["${var.vault_url}/v1/${var.pki_path}/ca"]
  crl_distribution_points = ["${var.vault_url}/v1/${var.pki_path}/crl"]
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

# For ACME
resource "vault_mount" "int_acme" {
  path        = "pki-acme-int"
  type        = "pki"
  description = "intermediate ca for acme in vault handson environment"

  default_lease_ttl_seconds = 2592000 #30days
  max_lease_ttl_seconds     = 7776000 #90days

  options = {
    "passthrough_request_headers" = "If-Modified-Since"
    "allowed_response_headers"    = "Last-Modified,Location,Replay-Nonce,Link"
  }
}

resource "vault_pki_secret_backend_intermediate_cert_request" "int_acme" {
  backend     = vault_mount.int_acme.path
  type        = "internal"
  common_name = "handson.dev intermediate ca acme"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "root_acme" {
  depends_on  = [vault_pki_secret_backend_intermediate_cert_request.int_acme]
  backend     = vault_mount.root.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.int_acme.csr
  common_name = "handson.dev intermediate ca"
  format      = "pem"
  ttl         = 7776000
}

resource "vault_pki_secret_backend_intermediate_set_signed" "int_acme" {
  backend     = vault_mount.int_acme.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.root.certificate
}

resource "vault_pki_secret_backend_config_cluster" "int_acme" {
  backend  = vault_mount.int_acme.path
  path     = "${var.vault_url}/v1/pki-acme-int/"
  aia_path = "${var.vault_url}/v1/pki-acme-int"
}

resource "vault_pki_secret_backend_config_urls" "int_acme" {
  backend                 = vault_mount.int_acme.path
  issuing_certificates    = ["{{cluster_aia_path}}/issuer/{{issuer_id}}/der"]
  crl_distribution_points = ["{{cluster_aia_path}}/issuer/{{issuer_id}}/crl/der"]
  ocsp_servers            = ["{{cluster_path}}/ocsp"]
  enable_templating       = true
}

resource "vault_pki_secret_backend_role" "acme" {
  backend        = vault_mount.int_acme.path
  name           = "acme"
  issuer_ref     = "default"
  allow_any_name = true
  max_ttl        = 2592000
  no_store       = false
}

resource "vault_generic_endpoint" "pki_int_acme" {
  path = "${vault_mount.int_acme.path}/config/acme"

  data_json = jsonencode({
    enable = true
  })
}