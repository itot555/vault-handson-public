provider "vault" {}

resource "vault_ldap_auth_backend" "ldap" {
  description   = "openldap auth method"
  path          = "ldap"
  url           = var.ldap_url
  binddn        = var.bind_dn
  bindpass      = var.bind_pass
  userdn        = var.user_dn
  groupdn       = var.group_dn
  userattr      = var.user_addr
  groupfilter   = var.group_filter
  groupattr     = var.group_attr
  insecure_tls  = true
  token_ttl     = 10800 #3hours
  token_max_ttl = 86400 #24hours
  #userfilter    = var.user_filter
}