provider "vault" {}

resource "vault_auth_backend" "aws" {
  type        = "aws"
  path        = "aws"
  description = "aws auth method"
}

resource "vault_aws_auth_backend_role" "agent" {
  backend                  = vault_auth_backend.aws.path
  role                     = "agent-role"
  auth_type                = "iam"
  bound_iam_principal_arns = ["${var.bound_arn}"]
  token_ttl                = 60
  token_max_ttl            = 120
  token_policies           = ["default"]
}