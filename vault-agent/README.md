# Vault Agent

ここでは [Vault Agent](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent) を利用して、Nginx が利用する証明書を自動的に更新する様に設定します。

Vault Agent を利用する事で、Vault への認証、シークレットの取得、取得したシークレット情報のレンダリングなど、アプリケーションに変わって実施し、Vault - Vault Agent - アプリケーションの様に、Vault とアプリケーションの間に位置し、仲介を行います。

Vault Agent が利用する認証メソッド、Vault Agent に付与する権限の設定、Vault Agent の設定ファイルなどを作成していきます。

**Notes:** 事前に、[PKI シークレットエンジン](https://github.com/itot555/vault-handson-public/tree/main/secrets-engine-pki)と [AppRole の設定](https://github.com/itot555/vault-handson-public/tree/main/auth-approle)を行っておいて下さい。

## Contents

- [Configure PKI secrets engine](#configure-pki-secrets-engine)
- [Configure AppRole and Policy](#configure-approle-and-policy)
- [Configure Nginx](#configure-nginx)
- [Configure Vault Agent](#configure-vault-agent)
- [Check automatically certificate update](#check-automatically-certificate-update)

# Configure PKI secrets engine

既に設定されている以下の PKI ロールを利用して、Vault Agent からは証明書を発行する様にします。

```hcl
resource "vault_pki_secret_backend_role" "server2" {
  backend          = vault_mount.int.path
  name             = "server2"
  ttl              = 2628000 #1month
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["handson.dev"]
  allow_subdomains = true
  server_flag      = true
  client_flag      = false
}
```

# Configure AppRole and Policy

Terminal タブにて以下を実施します。

```bash
cd ~/work/vault-handson-public/auth-approle
```

Editor タブを開いて、`main.tf`, `policy.tf` の以下のコメントアウトを外し、リソースブロック `vault_approle_auth_backend_role.rt5`, `vault_policy.agent` を有効にします。

*main.tf*

```hcl
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
```

*policy.tf*

```hcl
/*
resource "vault_policy" "agent" {
  name = "vault-agent"

  policy = <<EOT
# Permits token creation
path "auth/token/create" {
  capabilities = ["update"]
}
# Enable secrets engine
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
# List enabled secrets engine
path "sys/mounts" {
  capabilities = ["read", "list"]
}
# Issue certs with servers role
path "pki-handson-int/issue/server2" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
# List role
path "pki-handson-int/roles/server2" {
  capabilities = ["read", "list"]
}
EOT
}
*/
```

ファイルを修正し、保存された事を確認し、以下のコマンドを実行します。

```bash
terraform plan
```

内容を確認したら、変更を反映させます。

```bash
terraform apply -auto-approve
```

# Configure Nginx

Client-2 タブに移動し、以下のコマンドを実施します。

```bash
echo "127.0.0.1 nginx.handson.dev" >> /etc/hosts
```
```bash
cd work
```

ハンズオンで利用するコンテンツを Client-2 タブでも利用できる様に、`git clone` で取得します。

```bash
git clone https://github.com/itot555/vault-handson-public.git
```

作業が終わったら、ディレクトリを移動します。

```bash
cd vault-handson-public/vault-agent
```

環境変数を設定します。以下の設定を行い、`client-2` から `hashistack` で動いている Vault サーバーにアクセスできる様にします。

```bash
export VAULT_ADDR="http://hashistack:8200"
```

ルートトークンは、Terminal タブの `~/work/vault-handson-public/server/init.out` で確認できます。

```bash
export ROOT_TOKEN=
```

まず、Nginx の設定を行います。Nginx コンテナをプルします。

```bash
docker pull nginx &
```

続いて、Nginx で利用する証明書を設定します。

```bash
vault write -format=json pki-handson-int/issue/server2 common_name="nginx.handson.dev" ttl="5m" > cert.json
```
```bash
jq -r .data.ca_chain[0] cert.json > /root/work/vault-handson-public/vault-agent/configs/nginx/ssl/ca.crt
jq -r .data.certificate cert.json > /root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.crt
jq -r .data.private_key cert.json > /root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.key
```

Nginx コンテナを起動します。

```bash
docker run --rm --network=host --name nginx-container -v /root/work/vault-handson-public/vault-agent/configs/nginx:/etc/nginx -d nginx
```

# Configure Vault Agent

続いて、Vault Agent の設定を行います。

Vault Agent では AppRole 認証メソッドを利用する事が可能です。

  - [Vault Auto-Auth AppRole method](https://developer.hashicorp.com/vault/docs/agent-and-proxy/autoauth/methods/approle)

先ほど設定した AppRole 認証メソッドのロール `agent` の RoleID と SecretID を取得します。

```bash
vault read -format=json auth/approle/role/agent/role-id | jq  -r '.data.role_id' > /root/work/vault-handson-public/vault-agent/configs/roleID
```
```bash
vault write -f -format=json auth/approle/role/agent/secret-id | jq -r '.data.secret_id' > /root/work/vault-handson-public/vault-agent/configs/secretID
```

事前に定義してある Vault Agent の設定ファイルを確認し、Vault Agent を起動します。Vault Agent の設定ファイルで定義できるパラメーターは[こちら](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent#configuration-file-options)で確認できます。

```bash
cat config.hcl
```
```bash
vault agent -config=/root/work/vault-handson-public/vault-agent/configs/vault_agent/config.hcl -log-level=debug &
```

# Check automatically certificate update

Client-2 タブで作業を続け、Nginx で利用している証明書が自動的に更新されることを確認します。

```bash
openssl s_client -showcerts -connect nginx.handson.dev:443 2>/dev/null | openssl x509 -inform pem -noout -text
```

証明書が更新されるタイミングで、以下の様なレスポンスが標準出力にされるはずです。

```console
2022/09/30 01:16:55.688536 [DEBUG] Found certificate and set lease duration to 90 seconds
2022/09/30 01:16:55.688801 [DEBUG] (runner) receiving dependency vault.write(pki_int/issue/example-dot-com -> 618fc3c7)
2022/09/30 01:16:55.688841 [DEBUG] (runner) initiating run
2022/09/30 01:16:55.688863 [DEBUG] (runner) checking template fc9ef85ce58035044880126ffcbcc27d
......
2022/09/30 01:16:56.209314 [DEBUG] (runner) watching 1 dependencies
2022/09/30 01:16:56.209476 [DEBUG] (runner) all templates rendered
```