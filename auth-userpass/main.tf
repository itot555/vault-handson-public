resource "vault_auth_backend" "userpass" {
  type        = "userpass"
  description = "for human access on handson environment"

  tune {
    default_lease_ttl = "1800s"
    max_lease_ttl     = "3600s"
  }
}

# Vault admin
resource "vault_generic_endpoint" "admin" {
  depends_on           = [vault_auth_backend.userpass, vault_policy.admin]
  path                 = "auth/userpass/users/admin"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["vault-admin", "default"],
  "password": "changeme"
}
EOT
}

resource "vault_generic_endpoint" "admin_token" {
  depends_on     = [vault_generic_endpoint.admin]
  path           = "auth/userpass/login/admin"
  disable_read   = true
  disable_delete = true

  data_json = <<EOT
{
  "password": "changeme"
}
EOT
}

resource "vault_generic_endpoint" "admin_entity" {
  depends_on           = [vault_generic_endpoint.admin_token]
  disable_read         = true
  disable_delete       = true
  path                 = "identity/lookup/entity"
  ignore_absent_fields = true
  write_fields         = ["id"]

  data_json = <<EOT
{
  "alias_name": "admin",
  "alias_mount_accessor": "${vault_auth_backend.userpass.accessor}"
}
EOT
}

# Vault user
resource "vault_generic_endpoint" "user" {
  for_each             = var.users
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/${each.key}"
  ignore_absent_fields = true

  data_json = jsonencode({
    policies = each.value.policies
    password = each.value.password
  })
}

resource "vault_generic_endpoint" "user_token" {
  for_each       = var.users
  depends_on     = [vault_generic_endpoint.user]
  path           = "auth/userpass/login/${each.key}"
  disable_read   = true
  disable_delete = true

  data_json = jsonencode({
    password = each.value.password
  })
}

resource "vault_generic_endpoint" "user_entity" {
  for_each             = var.users
  depends_on           = [vault_generic_endpoint.user_token]
  disable_read         = true
  disable_delete       = true
  path                 = "identity/lookup/entity"
  ignore_absent_fields = true
  write_fields         = ["id"]

  data_json = jsonencode({
    alias_name           = each.key
    alias_mount_accessor = vault_auth_backend.userpass.accessor
  })
}