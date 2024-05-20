provider "vault" {}

resource "vault_auth_backend" "approle" {
  path        = var.approle_path
  type        = "approle"
  description = "approle auth method"
}

resource "vault_approle_auth_backend_role" "r1" {
  backend            = vault_auth_backend.approle.path
  role_name          = "tokyo"
  secret_id_num_uses = 1
  secret_id_ttl      = 300
  token_policies     = ["default", "read-fruits"]
  token_ttl          = 300
  token_max_ttl      = 600
}

resource "vault_approle_auth_backend_role" "r2" {
  backend            = vault_auth_backend.approle.path
  role_name          = "osaka"
  secret_id_num_uses = 3
  secret_id_ttl      = 600
  token_policies     = ["default", "read-fruits"]
  token_ttl          = 600
  token_max_ttl      = 600
}

resource "vault_approle_auth_backend_role" "r3" {
  backend               = vault_auth_backend.approle.path
  role_name             = "nagoya"
  secret_id_bound_cidrs = ["10.0.10.0/24"]
  secret_id_num_uses    = 1
  secret_id_ttl         = 300
  token_policies        = ["default", "all-vegetables"]
  token_ttl             = 300
  token_max_ttl         = 600
}

resource "vault_approle_auth_backend_role" "r4" {
  backend            = vault_auth_backend.approle.path
  role_name          = "fukuoka"
  secret_id_num_uses = 3
  secret_id_ttl      = 600
  token_policies     = ["default", "all-vegetables"]
  token_ttl          = 600
  token_max_ttl      = 600
  token_bound_cidrs  = ["10.0.10.0/24"]
}

data "vault_approle_auth_backend_role_id" "r1" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.r1.role_name
}

data "vault_approle_auth_backend_role_id" "r2" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.r2.role_name
}

data "vault_approle_auth_backend_role_id" "r3" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.r3.role_name
}

data "vault_approle_auth_backend_role_id" "r4" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.r4.role_name
}

resource "vault_token" "r1_secretid" {
  display_name = "tokyo-secretid"

  policies = ["generate-tokyo-secretid", "self-manage-token"]

  renewable = true
  ttl       = "24h"

  renew_min_lease = 43200
  renew_increment = 86400
}

resource "vault_token" "r2_secretid" {
  display_name = "osaka-secretid"

  policies = ["generate-osaka-secretid", "self-manage-token"]

  renewable = true
  ttl       = "24h"

  renew_min_lease = 43200
  renew_increment = 86400
}

resource "vault_token" "r3_secretid" {
  display_name = "nagoya-secretid"

  policies = ["generate-nagoya-secretid", "self-manage-token"]

  renewable = true
  ttl       = "24h"

  renew_min_lease = 43200
  renew_increment = 86400
}

resource "vault_token" "r4_secretid" {
  display_name = "fukuoka-secretid"

  policies = ["generate-fukuoka-secretid", "self-manage-token"]

  renewable = true
  ttl       = "24h"

  renew_min_lease = 43200
  renew_increment = 86400
}

/*
resource "vault_approle_auth_backend_role" "r5" {
  backend            = vault_auth_backend.approle.path
  role_name          = "agent"
  secret_id_num_uses = 3
  secret_id_ttl      = 300
  token_policies     = ["default", "vault-agent"]
  token_ttl          = 300
  token_max_ttl      = 600
}
*/