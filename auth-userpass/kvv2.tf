resource "vault_mount" "kvv2" {
  path        = "test"
  type        = "kv"
  options     = { version = "2" }
  description = "kv-v2 secrets engine for test"
}

resource "vault_kv_secret_v2" "fruits" {
  mount               = vault_mount.kvv2.path
  name                = "fruits"
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode(
    {
      member1 = "apple",
      member2 = "banana"
    }
  )
  depends_on = [
    vault_mount.kvv2
  ]
}

resource "vault_kv_secret_v2" "vegetables" {
  mount               = vault_mount.kvv2.path
  name                = "vegetables"
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode(
    {
      member1 = "asparagus",
      member2 = "broccoli",
      member3 = "cabbage"
    }
  )
  depends_on = [
    vault_mount.kvv2
  ]
}