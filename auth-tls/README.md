# Configure TLS auth method

**Notes:** Vault のルートトークンを確認したい場合、`~/work/vault-handson-public/server/init.out` を確認してください。

Vault プロバイダの認証は先ほど設定した、`VAULT_ADDR`, `VAULT_TOKEN` で行っています。`secrets-engine-pki` ディレクトリで作業を行っていた前提の手順になります。

TLS 認証メソッドを設定していきます。

```bash
cd ../auth-tls
terraform init
terraform plan
```

`terraform apply` を実行する前に、現在有効化されている認証メソッドを確認しておきます。

```bash
vault auth list
```

確認できたら、Terraform コードを反映させて、TLS 認証メソッドを設定します。

```bash
terraform apply -auto-approve
```

TLS 認証ロールは、PKI シークレットエンジンを使って作成した認証局を利用し、設定しています。

ロールとしては 2 つ、`client1` と `others` を作成しています。

```hcl
resource "vault_cert_auth_backend_role" "client1" {
  name                 = "client1"
  certificate          = data.terraform_remote_state.pki.outputs.certificate_bundle
  backend              = vault_auth_backend.cert.path
  allowed_common_names = ["client1.handson.dev"]
  token_ttl            = 600
  token_max_ttl        = 1200
  token_policies       = ["vault-admin"]
}
```

```hcl
resource "vault_cert_auth_backend_role" "others" {
  name                 = "others"
  certificate          = data.terraform_remote_state.pki.outputs.certificate_bundle
  backend              = vault_auth_backend.cert.path
  allowed_common_names = ["client2.handson.dev", "client3.handson.dev"]
  token_ttl            = 600
  token_max_ttl        = 1200
  token_policies       = ["default"]
}
```

それぞれのロールの定義を `vault` CLI から確認してみます。

```bash
vault auth list
vault list auth/cert/certs
```

それぞれのロール設定を確認する場合は以下の様に確認する事が出来ます。

```bash
vault read auth/cert/certs/client1
```

先ほどファイルに保存しておいた証明書と秘密鍵のペアを利用して、TLS 認証メソッドでログインしてみます。

```bash
vault login -method=cert -client-cert=./certs/client1_cert.pem -client-key=./certs/client1_key.pem name=client1
```

TLS ロール `client1` でログインする事が出来、ポリシー `read-fruits` が付与された Vault クライアントトークンがレスポンスされると思います。レスポンスされたクライアントトークンを `VAULT_TOKEN` 環境変数に設定します。

```bash
export VAULT_TOKEN=
```

`auth-userpass` で実施した様に、Vault ポリシーによって、ちゃんとアクセス制御がなされている事を確認します。

OK

```bash
vault kv get test/fruits
```

NG

```bash
vault kv get test/vegetables
```

`VAULT_TOKEN` 環境変数をアンセットして、同じ TLS ロールで、`client2` の証明書と秘密鍵のペアでログインしてみます。

```bash
unset VAULT_TOKEN
```

```bash
vault login -method=cert -client-cert=./certs/client2_cert.pem -client-key=./certs/client2_key.pem name=client1
```

こちらは、許可されていない CNAME でアクセスしようとして、アクセスが許可されないはずです。

`client2` の証明書と秘密鍵のペアを許可しているロール `others` を利用してログインしてみます。

```bash
vault login -method=cert -client-cert=./certs/client2_cert.pem -client-key=./certs/client2_key.pem name=others
```

同様にポリシーによるアクセス制御を確認します。

NG

```bash
vault kv get test/fruits
```

OK

```bash
vault kv get test/vegetables
```

この様に TLS 証明書を用いて、Vault への認証を行い、ロールに付与されたポリシーで認可設定を行う事が可能です。

# References

- [TLS certificates auth method](https://developer.hashicorp.com/vault/docs/auth/cert)
- [TLS certificate auth method (API)](https://developer.hashicorp.com/vault/api-docs/auth/cert)