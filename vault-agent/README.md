# Vault Agent

ここでは [Vault Agent](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent) を利用して、Nginx が利用する証明書を自動的に更新する様に設定します。

Vault Agent を利用する事で、Vault への認証、シークレットの取得、取得したシークレット情報のレンダリングなど、アプリケーションに変わって実施し、Vault - Vault Agent - アプリケーションの様に、Vault とアプリケーションの間に位置し、仲介を行います。

Vault Agent が利用する認証メソッド、Vault Agent に付与する権限の設定、Vault Agent の設定ファイルなどを作成していきます。

## Contents

- [Prerequisites](#prerequisites)
- [Configure PKI secrets engine](#configure-pki-secrets-engine)
- [Configure AppRole and Policy](#configure-approle-and-policy)
- [Configure Nginx](#configure-nginx)
- [Configure Vault Agent](#configure-vault-agent)
- [Check automatically certificate update](#check-automatically-certificate-update)
- [References](#references)

# Prerequisites

- [Vault サーバーセットアップ](https://github.com/itot555/vault-handson-public/tree/main/server)
- [Userpass 認証メソッドの設定](https://github.com/itot555/vault-handson-public/tree/main/auth-userpass)
- [PKI シークレットエンジン](https://github.com/itot555/vault-handson-public/tree/main/secrets-engine-pki)
- [AppRole の設定](https://github.com/itot555/vault-handson-public/tree/main/auth-approle)

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

既に設定されている以下の AppRole ロールと、それに付与されているポリシーを使って、Vault Agent の認証・認可を設定していきます。

```hcl
resource "vault_approle_auth_backend_role" "r5" {
  backend            = vault_auth_backend.approle.path
  role_name          = "agent"
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

Client-1 タブに移動し、以下のコマンドを実施します。

```bash
echo "127.0.0.1 nginx.handson.dev" >> /etc/hosts
```
```bash
cd work
```

ハンズオンで利用するコンテンツを client-1 サーバーでもでも利用できる様に、`git clone` で取得します。

```bash
git clone https://github.com/itot555/vault-handson-public.git
```

作業が終わったら、ディレクトリを移動します。

```bash
cd vault-handson-public/vault-agent
```

環境変数を設定します。以下の設定を行い、`client-1` から `hashistack` で動いている Vault サーバーにアクセスできる様にします。

```bash
export VAULT_ADDR="http://hashistack:8200"
```

Vault サーバーのルートトークンは、Terminal タブの `~/work/vault-handson-public/server/init.out` で確認できます。

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

Client-1-add タブに移動して、設定ファイルが問題ないか確認しておきます。

```bash
docker run --rm -v /root/work/vault-handson-public/vault-agent/configs/nginx:/etc/nginx nginx nginx -t
```

以下の様な出力で終わっていれば、次に進みます。

```console
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Nginx コンテナを起動します。

```bash
docker run -d -p 80:80 -p 443:443 --rm --name nginx-container -v /root/work/vault-handson-public/vault-agent/configs/nginx:/etc/nginx -d nginx
```

以下のコマンドで実行したコンテナが稼働している事を確認します。

```bash
docker ps -a
```

# Configure Vault Agent

続いて、Vault Agent の設定を行います。

Vault Agent では認証メソッドとして、AppRole を利用する事が可能です。

  - [Vault Auto-Auth AppRole method](https://developer.hashicorp.com/vault/docs/agent-and-proxy/autoauth/methods/approle)

[AppRole 認証メソッドの設定と確認](https://github.com/itot555/vault-handson-public/tree/main/auth-approle) で設定した AppRole 認証メソッドのロール `agent` の RoleID と SecretID を取得します。

Client-1 タブに移動し、以下のコマンドを実施します。

```bash
vault read -format=json auth/test/role/agent/role-id | jq  -r '.data.role_id' > /root/work/vault-handson-public/vault-agent/configs/roleID
export ROLE_ID_AGENT=$(cat /root/work/vault-handson-public/vault-agent/configs/roleID)
```
```bash
vault write -f -format=json auth/test/role/agent/secret-id | jq -r '.data.secret_id' > /root/work/vault-handson-public/vault-agent/configs/secretID
export SECRET_ID_AGENT=$(cat /root/work/vault-handson-public/vault-agent/configs/secretID)
```

一度、取得した `role-id`, `secret-id` の組み合わせで、client-1 から Vault にログイン出来るか確認してみます。

```bash
vault write auth/test/login role_id=$ROLE_ID_AGENT secret_id=$SECRET_ID_AGENT
```

無事にログインできたら、次に進みます。

事前に定義してある Vault Agent の設定ファイルを確認し、Vault Agent を起動します。Vault Agent の設定ファイルで定義できるパラメーターは[こちら](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent#configuration-file-options)で確認できます。

Client-1-add タブに移動して、設定ファイルが問題ないか確認しておきます。

```bash
cat work/vault-handson-public/vault-agent/configs/config.hcl
```
```bash
vault agent -config=/root/work/vault-handson-public/vault-agent/configs/config.hcl -log-level=debug &
```

# Check automatically certificate update

Client-1 タブに戻って、Nginx で利用している証明書が自動的に更新されることを確認します。

```bash
openssl s_client -showcerts -connect nginx.handson.dev:443 2>/dev/null | openssl x509 -inform pem -noout -text
```

**Notes:** 止める場合は、`Ctrl + c` で止める事ができます。

証明書が更新されるタイミングで、Client-1-add タブで以下の様なレスポンスが標準出力にされるはずです。

```console
2024-05-21T03:43:33.977Z [INFO]  agent.apiproxy: received request: method=GET path=/v1/sys/internal/ui/mounts/pki-handson-int/issue/server2
2024-05-21T03:43:33.977Z [DEBUG] agent.cache.leasecache: forwarding request from cache: method=GET path=/v1/sys/internal/ui/mounts/pki-handson-int/issue/server2
2024-05-21T03:43:33.977Z [INFO]  agent.apiproxy: forwarding request to Vault: method=GET path=/v1/sys/internal/ui/mounts/pki-handson-int/issue/server2
2024-05-21T03:43:33.978Z [DEBUG] agent.apiproxy.client: performing request: method=GET url=http://hashistack:8200/v1/sys/internal/ui/mounts/pki-handson-int/issue/server2
2024-05-21T03:43:33.981Z [DEBUG] agent.cache.leasecache: pass-through response; secret not renewable: method=GET path=/v1/sys/internal/ui/mounts/pki-handson-int/issue/server2
2024-05-21T03:43:33.982Z [INFO]  agent.apiproxy: received request: method=PUT path=/v1/pki-handson-int/issue/server2
2024-05-21T03:43:33.982Z [DEBUG] agent.cache.leasecache: forwarding request from cache: method=PUT path=/v1/pki-handson-int/issue/server2
2024-05-21T03:43:33.982Z [INFO]  agent.apiproxy: forwarding request to Vault: method=PUT path=/v1/pki-handson-int/issue/server2
2024-05-21T03:43:33.982Z [DEBUG] agent.apiproxy.client: performing request: method=PUT url=http://hashistack:8200/v1/pki-handson-int/issue/server2
2024-05-21T03:43:35.061Z [DEBUG] agent.cache.leasecache: pass-through response; secret not renewable: method=PUT path=/v1/pki-handson-int/issue/server2
2024-05-21T03:43:35.062Z [DEBUG] agent: Found certificate and set lease duration to 58 seconds
2024-05-21T03:43:35.062Z [DEBUG] agent: (runner) receiving dependency vault.write(pki-handson-int/issue/server2 -> a8d1d4da)
2024-05-21T03:43:35.062Z [DEBUG] agent: (runner) initiating run
2024-05-21T03:43:35.062Z [DEBUG] agent: (runner) checking template 06ec1a1f1f548ed53016f790a8935a7a
2024-05-21T03:43:35.063Z [DEBUG] agent: (runner) rendering "/root/work/vault-handson-public/vault-agent/configs/templates/cert.tmpl" => "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.crt"
2024-05-21T03:43:35.065Z [INFO]  agent: (runner) rendered "/root/work/vault-handson-public/vault-agent/configs/templates/cert.tmpl" => "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.crt"
2024-05-21T03:43:35.065Z [DEBUG] agent: (runner) appending command ["docker exec nginx-container nginx -s reload && echo Ok || echo Failed"] from "/root/work/vault-handson-public/vault-agent/configs/templates/cert.tmpl" => "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.crt"
2024-05-21T03:43:35.065Z [DEBUG] agent: (runner) checking template ae589bce91660107b75f61a1a898edcf
2024-05-21T03:43:35.066Z [DEBUG] agent: (runner) rendering "/root/work/vault-handson-public/vault-agent/configs/templates/ca.tmpl" => "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/ca.crt"
2024-05-21T03:43:35.066Z [DEBUG] agent: (runner) checking template 3e09f1936ea5d0f8488ddb4a94678346
2024-05-21T03:43:35.066Z [DEBUG] agent: (runner) rendering "/root/work/vault-handson-public/vault-agent/configs/templates/key.tmpl" => "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.key"
2024-05-21T03:43:35.068Z [INFO]  agent: (runner) rendered "/root/work/vault-handson-public/vault-agent/configs/templates/key.tmpl" => "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.key"
2024-05-21T03:43:35.068Z [DEBUG] agent: (runner) skipping command ["docker exec nginx-container nginx -s reload && echo Ok || echo Failed"] from "/root/work/vault-handson-public/vault-agent/configs/templates/key.tmpl" => "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.key" (already appended from "/root/work/vault-handson-public/vault-agent/configs/templates/cert.tmpl" => "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.crt")
2024-05-21T03:43:35.068Z [DEBUG] agent: (runner) diffing and updating dependencies
2024-05-21T03:43:35.068Z [DEBUG] agent: (runner) vault.write(pki-handson-int/issue/server2 -> a8d1d4da) is still needed
2024-05-21T03:43:35.068Z [INFO]  agent: (runner) executing command "[\"docker exec nginx-container nginx -s reload && echo Ok || echo Failed\"]" from "/root/work/vault-handson-public/vault-agent/configs/templates/cert.tmpl" => "/root/work/vault-handson-public/vault-agent/configs/nginx/ssl/cert.crt"
2024-05-21T03:43:35.068Z [INFO]  agent: (child) spawning: sh -c docker exec nginx-container nginx -s reload && echo Ok || echo Failed
2024/05/21 03:43:35 [notice] 134#134: signal process started
Ok
2024-05-21T03:43:35.157Z [DEBUG] agent: (runner) watching 1 dependencies
2024-05-21T03:43:35.157Z [DEBUG] agent: (runner) all templates rendered
```

Vault Agent に関するハンズオンは以上になります。

# References

- [Vault Auto-Auth AppRole method](https://developer.hashicorp.com/vault/docs/agent-and-proxy/autoauth/methods/approle)
- [Vault Agent Configuration file options](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent#configuration-file-options)