pid_file = "./pidfile"

vault {
  address = "http://hashistack:8200"
}

auto_auth {
  method "approle" {
    mount_path = "auth/test"
    config = {
      role_id_file_path                   = "/root/work/vault-handson-public/vault-agent/configs/roleID"
      secret_id_file_path                 = "/root/work/vault-handson-public/vault-agent/configs/secretID"
      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "/root/work/vault-handson-public/vault-agent/configs/approleToken"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address     = "127.0.0.1:8100"
  tls_disable = true
}

template {
  source      = "/root/work/vault-handson-public/vault-agent/configs/templates/cert.tmpl"
  destination = "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.crt"
  command     = "docker exec nginx-container nginx -s reload && echo Ok || echo Failed"
}

template {
  source      = "/root/work/vault-handson-public/vault-agent/configs/templates/ca.tmpl"
  destination = "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/ca.crt"
  command     = "docker exec nginx-container nginx -s reload && echo Ok || echo Failed"
}

template {
  source      = "/root/work/vault-handson-public/vault-agent/configs/templates/key.tmpl"
  destination = "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.key"
  command     = "docker exec nginx-container nginx -s reload && echo Ok || echo Failed"
}