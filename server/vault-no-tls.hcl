storage "raft" {
   path    = "/root/work/vault-handson-public/server/data"
   node_id = "node_1"
}

cluster_addr  = "http://127.0.0.1:8201"
api_addr      = "http://127.0.0.1:8200"
disable_mlock = true

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

ui = true