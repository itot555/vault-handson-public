storage "raft" {
   path    = "/root/work/vault-handson-public/server/data"
   node_id = "node_1"
}

cluster_addr  = "https://127.0.0.1:8201"
api_addr      = "https://127.0.0.1:8200"
disable_mlock = true

listener "tcp" {
  address            = "127.0.0.1:8200"
  tls_cert_file      = "/root/work/vault-handson-public/server/certs/vault_cert.pem"
  tls_key_file       = "/root/work/vault-handson-public/server/certs/vault_private_key.pem"
  tls_client_ca_file = "/root/work/vault-handson-public/server/certs/ca.pem"
}

ui = true