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

既に設定されている以下の AppRole のロールと、それに付与されているポリシーを使って、Vault Agent の認証・認可を設定していきます。

```hcl
resource "vault_approle_auth_backend_role" "r5" {
  backend            = vault_auth_backend.approle.path
  role_name          = "agent"
  secret_id_num_uses = 3
  secret_id_ttl      = 600
  token_policies     = ["default", "read-pki-server2-role"]
  token_ttl          = 300
  token_max_ttl      = 600
  depends_on         = [vault_policy.agent]
}
```

```hcl
resource "vault_policy" "agent" {
  name = "read-pki-server2-role"

  policy = <<EOT
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
```

# Configure Nginx

Client-2 タブに移動し、以下のコマンドを実施します。

```bash
echo "127.0.0.1 nginx.handson.dev" >> /etc/hosts
```
```bash
cd work
```

ハンズオンで利用するコンテンツを client-2 サーバーでもでも利用できる様に、`git clone` で取得します。

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
```bash
export VAULT_TOKEN=$ROOT_TOKEN
```

まず、Nginx の設定を行います。Nginx コンテナをプルします。

```bash
docker pull nginx &
```

以下の様な出力がされたら、Enter を入力します。

```console
latest: Pulling from library/nginx
09f376ebb190: Pull complete 
a11fc495bafd: Pull complete 
933cc8470577: Pull complete 
999643392fb7: Pull complete 
971bb7f4fb12: Pull complete 
45337c09cd57: Pull complete 
de3b062c0af7: Pull complete 
Digest: sha256:a484819eb60211f5299034ac80f6a681b06f89e65866ce91f356ed7c72af059c
Status: Downloaded newer image for nginx:latest
docker.io/library/nginx:latest
```

Nginx コンテナイメージがダウンロードされた事を確認します。

```bash
docker image ls
```

続いて、Nginx で利用する証明書を設定します。

```bash
vault write -format=json pki-handson-int/issue/server2 common_name="nginx.handson.dev" ttl="10m" > cert.json
```
```bash
jq -r .data.ca_chain[0] cert.json > /root/work/vault-handson-public/vault-agent/configs/nginx/ssl/ca.crt
jq -r .data.certificate cert.json > /root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.crt
jq -r .data.private_key cert.json > /root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.key
```

Client-2-add タブに移動して、設定ファイルが問題ないか確認しておきます。

```bash
docker run --rm -v /root/work/vault-handson-public/vault-agent/configs/nginx:/etc/nginx nginx nginx -t
```

問題なければ、Nginx コンテナを起動します。

```bash
docker run --rm --network=host --name nginx-container -v /root/work/vault-handson-public/vault-agent/configs/nginx:/etc/nginx -d nginx
```

# Configure Vault Agent

続いて、Vault Agent の設定を行います。

Vault Agent では AppRole 認証メソッドを利用する事が可能です。

  - [Vault Auto-Auth AppRole method](https://developer.hashicorp.com/vault/docs/agent-and-proxy/autoauth/methods/approle)

[AppRole 認証メソッドの設定と確認](https://github.com/itot555/vault-handson-public/tree/main/auth-approle) で設定した AppRole 認証メソッドのロール `agent` の RoleID と SecretID を取得します。

Client-2 タブに移動し、以下のコマンドを実施します。

```bash
vault read -format=json auth/test/role/agent/role-id | jq  -r '.data.role_id' > /root/work/vault-handson-public/vault-agent/configs/roleID
export ROLE_ID_AGENT=$(cat /root/work/vault-handson-public/vault-agent/configs/roleID)
```
```bash
vault write -f -format=json auth/test/role/agent/secret-id | jq -r '.data.secret_id' > /root/work/vault-handson-public/vault-agent/configs/secretID
export SECRET_ID_AGENT=$(cat /root/work/vault-handson-public/vault-agent/configs/secretID)
```

一度、この role-id, secret-id の組み合わせでログイン出来るか確認してみます。

```bash
vault write auth/test/login role_id=$ROLE_ID_AGENT secret_id=$SECRET_ID_AGENT
```

事前に定義してある Vault Agent の設定ファイルを確認し、Vault Agent を起動します。Vault Agent の設定ファイルで定義できるパラメーターは[こちら](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent#configuration-file-options)で確認できます。

Client-2-add タブに移動して、設定ファイルが問題ないか確認しておきます。

```bash
cat work/vault-handson-public/vault-agent/configs/config.hcl
```
```bash
vault agent -config=/root/work/vault-handson-public/vault-agent/configs/config.hcl -log-level=debug &
```

# Check automatically certificate update

Client-2 タブに戻って、Nginx で利用している証明書が自動的に更新されることを確認します。

```bash
openssl s_client -showcerts -connect nginx.handson.dev:443 2>/dev/null | openssl x509 -inform pem -noout -text
```

証明書が更新されるタイミングで、Client-2-add タブで以下の様なレスポンスが標準出力にされるはずです。

```console
2022/09/30 01:16:55.688536 [DEBUG] Found certificate and set lease duration to 90 seconds
2022/09/30 01:16:55.688801 [DEBUG] (runner) receiving dependency vault.write(pki_int/issue/example-dot-com -> 618fc3c7)
2022/09/30 01:16:55.688841 [DEBUG] (runner) initiating run
2022/09/30 01:16:55.688863 [DEBUG] (runner) checking template fc9ef85ce58035044880126ffcbcc27d
......
2022/09/30 01:16:56.209314 [DEBUG] (runner) watching 1 dependencies
2022/09/30 01:16:56.209476 [DEBUG] (runner) all templates rendered
```