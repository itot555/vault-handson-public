resource "vault_policy" "r1_secretid" {
  name = "generate-tokyo-secretid"

  policy = <<EOT
path "auth/${var.approle_path}/role/tokyo/secret-id" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "r2_secretid" {
  name = "generate-osaka-secretid"

  policy = <<EOT
path "auth/${var.approle_path}/role/osaka/secret-id" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "r3_secretid" {
  name = "generate-nagoya-secretid"

  policy = <<EOT
path "auth/${var.approle_path}/role/nagoya/secret-id" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "r4_secretid" {
  name = "generate-nagoya-secretid"

  policy = <<EOT
path "auth/${var.approle_path}/role/fukuoka/secret-id" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "token" {
  name = "self-manage-token"

  policy = <<EOT
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
EOT
}