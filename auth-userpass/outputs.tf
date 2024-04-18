output "user_ids" {
  value = { for k, v in vault_generic_endpoint.user_entity : k => v.write_data["id"] }
}