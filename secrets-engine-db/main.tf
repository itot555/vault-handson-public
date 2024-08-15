provider "vault" {}

resource "vault_mount" "db" {
  path = "db"
  type = "database"
}

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_mount.db.path
  name          = "postgres"
  allowed_roles = ["postgres-readonly", "postgres-readwrite"]

  postgresql {
    connection_url = "postgres://{{username}}:{{password}}@10.0.1.70:5432/exampledb"
    username       = "user"
    password       = "user_password"
  }
}

resource "vault_database_secret_backend_role" "readonly" {
  backend             = vault_mount.db.path
  name                = "postgres-readonly"
  db_name             = vault_database_secret_backend_connection.postgres.name
  creation_statements = ["CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';", "GRANT ro_exampledb TO \"{{name}}\";"]
  default_ttl         = "1800"
  max_ttl             = "3600"
}

resource "vault_database_secret_backend_role" "readwrite" {
  backend             = vault_mount.db.path
  name                = "postgres-readwrite"
  db_name             = vault_database_secret_backend_connection.postgres.name
  creation_statements = ["CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';", "GRANT rw_exampledb TO \"{{name}}\";"]
  default_ttl         = "600"
  max_ttl             = "1800"
}

resource "vault_database_secret_backend_connection" "mysql" {
  backend       = vault_mount.db.path
  name          = "mysql"
  allowed_roles = ["mysql-all"]

  mysql {
    connection_url = "{{username}}:{{password}}@tcp(10.0.1.70:3306)/"
    username       = "root"
    password       = "root_password"
  }
}

resource "vault_database_secret_backend_role" "all" {
  backend             = vault_mount.db.path
  name                = "mysql-all"
  db_name             = vault_database_secret_backend_connection.mysql.name
  creation_statements = ["CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';"]
  default_ttl         = "1800"
  max_ttl             = "3600"
}