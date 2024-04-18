resource "vault_policy" "admin" {
  name = "vault-admin"

  policy = <<EOT
path "*" {
  capabilities = ["sudo","read","create","update","delete","list","patch"]
}
EOT
}

resource "vault_policy" "write_fruits" {
  name = "write-fruits"

  policy = <<EOT
path "test/data/fruits" {
  capabilities = ["create", "update", "patch"]
}
EOT
}

resource "vault_policy" "read_fruits" {
  name = "read-fruits"

  policy = <<EOT
path "test/data/fruits" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "all_vegetables" {
  name = "all-vegetables"

  policy = <<EOT
path "test/data/vegetables" {
  capabilities = ["sudo","read","create","update","delete","list","patch"]
}
EOT
}