output "tokyo_roleid" {
  description = "The RoleID of the role: tokyo"
  value       = data.vault_approle_auth_backend_role_id.r1.role_id
}

output "osaka_roleid" {
  description = "The RoleID of the role: osaka"
  value       = data.vault_approle_auth_backend_role_id.r2.role_id
}

output "nagoya_roleid" {
  description = "The RoleID of the role: nagoya"
  value       = data.vault_approle_auth_backend_role_id.r3.role_id
}

output "fukuoka_roleid" {
  description = "The RoleID of the role: nagoya"
  value       = data.vault_approle_auth_backend_role_id.r4.role_id
}

output "tokyo_secretid_client_token" {
  description = "String containing the client token for generating tokyo secretid"
  value       = vault_token.r1_secretid.client_token
  sensitive   = true
}

output "osaka_secretid_client_token" {
  description = "String containing the client token for generating osaka secretid"
  value       = vault_token.r2_secretid.client_token
  sensitive   = true
}

output "nagoya_secretid_client_token" {
  description = "String containing the client token for generating nagoya secretid"
  value       = vault_token.r3_secretid.client_token
  sensitive   = true
}

output "fukuoka_secretid_client_token" {
  description = "String containing the client token for generating fukuoka secretid"
  value       = vault_token.r4_secretid.client_token
  sensitive   = true
}