# Root CA
output "ca_certificate" {
  description = "Root CA's certificate"
  value       = vault_pki_secret_backend_root_cert.root.certificate
}

output "ca_issuing_ca" {
  description = "Issuing Root CA"
  value       = vault_pki_secret_backend_root_cert.root.issuing_ca
}

output "ca_serial_number" {
  description = "Root CA's serial number"
  value       = vault_pki_secret_backend_root_cert.root.serial_number
}

# Intermediate CA
output "csr" {
  description = "Intermediate CA's CSR"
  value       = vault_pki_secret_backend_intermediate_cert_request.int.csr
}

output "cert" {
  description = "Certificate for Intermediate CA signed by Root CA"
  value       = vault_pki_secret_backend_root_sign_intermediate.root.certificate
}

output "ca_chain" {
  description = "A list of the issuing and intermediate CA certificates"
  value       = vault_pki_secret_backend_root_sign_intermediate.root.ca_chain
}

output "certificate_bundle" {
  description = "The concatenation of the intermediate CA and the issuing CA certificates (PEM encoded)"
  value       = vault_pki_secret_backend_root_sign_intermediate.root.certificate_bundle
}

# Issue cert for app
output "app_ca_chain" {
  description = "Certificate's CA chain"
  value       = vault_pki_secret_backend_cert.app.ca_chain
}

output "app_private_key" {
  description = "Private key for app server's certificate"
  value       = vault_pki_secret_backend_cert.app.private_key
  sensitive   = true
}

output "app_certificate" {
  description = "Server's certificate for app"
  value       = vault_pki_secret_backend_cert.app.certificate
}

# Issue cert for db
output "db_ca_chain" {
  description = "Certificate's CA chain"
  value       = vault_pki_secret_backend_cert.db.ca_chain
}

output "db_private_key" {
  description = "Private key for db server's certificate"
  value       = vault_pki_secret_backend_cert.db.private_key
  sensitive   = true
}

output "db_certificate" {
  description = "Server's certificate for db"
  value       = vault_pki_secret_backend_cert.db.certificate
}

# Issue cert for client
output "client_ca_chain" {
  value       = { for key, instance in vault_pki_secret_backend_cert.client : key => instance.ca_chain }
  description = "The CA chain for each client certificate."
}

output "client_private_key" {
  value       = { for key, instance in vault_pki_secret_backend_cert.client : key => instance.private_key }
  description = "The private key for each client certificate."
  sensitive   = true
}

output "client_certificate" {
  value       = { for key, instance in vault_pki_secret_backend_cert.client : key => instance.certificate }
  description = "The certificate for each client."
}
