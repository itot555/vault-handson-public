variable "users" {
  default = {
    user1 = {
      policies = ["write-fruits"]
      password = "changeme"
    }
    user2 = {
      policies = ["read-fruits"]
      password = "changeme"
    }
    user3 = {
      policies = ["all-vegetables"]
      password = "changeme"
    }
  }
}