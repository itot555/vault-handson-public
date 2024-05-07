# Configure AppRole auth method

## Contents

- [Configure AppRole](#configure-approle)
- [Login with AppRole](#login-with-approle)
  - [`tokyo` role](#tokyo-role)
  - [`nagoya` role](#nagoya-role)
  - [`fukuoka` role](#fukuoka-role)
  - [`osaka` role](#osaka-role)
  - [Additional](#additional)
- [References](#references)

# Configure AppRole

**Notes:** Vault のルートトークンを確認したい場合、`~/work/vault-handson-public/server/init.out` を確認してください。

Vault プロバイダの認証は先ほど設定した、`VAULT_ADDR`, `VAULT_TOKEN` で行っています。`auth-tls` ディレクトリで作業を行っていた前提の手順になります。

```bash
export VAULT_TOKEN=$ROOT_TOKEN
```
```bash
cd ../auth-approle
```
```bash
terraform init
terraform plan
```

`terraform apply` を実行する前に、現在有効化されている認証メソッドを確認しておきます。

```bash
vault auth list
```

確認できたら、Terraform コードを反映させて、AppRole 認証メソッドを設定します。

```bash
terraform apply -auto-approve
```

設定された内容を確認します。今まで有効化してきた認証メソッドは、`Type` と `Path` を同じ名前にしてきましたが、今回は `Path` を `test` としています。この様に同一の認証メソッドタイプで別パスを指定する事が可能です。

```bash
vault auth list
```

*コマンド出力例*
```console
Path         Type        Accessor                  Description                                Version
----         ----        --------                  -----------                                -------
cert/        cert        auth_cert_dfb203ab        tls auth method                            n/a
test/        approle     auth_approle_24a38abe     approle auth method                        n/a
token/       token       auth_token_f3b4b406       token based credentials                    n/a
userpass/    userpass    auth_userpass_0867db63    for human access on handson environment    n/a
```

ここでは 4 つのロールを定義しています。

```hcl
resource "vault_approle_auth_backend_role" "r1" {
  backend            = vault_auth_backend.approle.path
  role_name          = "tokyo"
  secret_id_num_uses = 1
  secret_id_ttl      = 300
  token_policies     = ["default", "read-fruits"]
  token_ttl          = 300
  token_max_ttl      = 600
}

resource "vault_approle_auth_backend_role" "r2" {
  backend            = vault_auth_backend.approle.path
  role_name          = "osaka"
  secret_id_num_uses = 3
  secret_id_ttl      = 600
  token_policies     = ["default", "read-fruits"]
  token_ttl          = 600
  token_max_ttl      = 600
}

resource "vault_approle_auth_backend_role" "r3" {
  backend               = vault_auth_backend.approle.path
  role_name             = "nagoya"
  secret_id_bound_cidrs = ["10.0.10.0/24"]
  secret_id_num_uses    = 1
  secret_id_ttl         = 300
  token_policies        = ["default", "all-vegetables"]
  token_ttl             = 300
  token_max_ttl         = 600
}

resource "vault_approle_auth_backend_role" "r4" {
  backend            = vault_auth_backend.approle.path
  role_name          = "fukuoka"
  secret_id_num_uses = 3
  secret_id_ttl      = 600
  token_policies     = ["default", "all-vegetables"]
  token_ttl          = 600
  token_max_ttl      = 600
  token_bound_cidrs  = ["10.0.10.0/24"]
}
```

`vault` CLI では以下のコマンドで確認出来ます。

```bash
vault list auth/test/role
```

```bash
vault read auth/test/role/tokyo
```
```bash
vault read auth/test/role/osaka
```
```bash
vault read auth/test/role/nagoya
```
```bash
vault read auth/test/role/fukuoka
```

*コマンド出力例*
```console
Key                        Value
---                        -----
bind_secret_id             true
local_secret_ids           false
secret_id_bound_cidrs      <nil>
secret_id_num_uses         1
secret_id_ttl              5m
token_bound_cidrs          []
token_explicit_max_ttl     0s
token_max_ttl              10m
token_no_default_policy    false
token_num_uses             0
token_period               0s
token_policies             [default read-fruits]
token_ttl                  5m
token_type                 default
```

各ロールに紐づく `role-id` は Terraform で既に払い出しているので、ファイルに保存しておきます。

```bash
terraform output -json tokyo_roleid | jq -r . > role-id/tokyo
terraform output -json osaka_roleid | jq -r . > role-id/osaka
terraform output -json nagoya_roleid | jq -r . > role-id/nagoya
terraform output -json fukuoka_roleid | jq -r . > role-id/fukuoka
```

```bash
ls -la role-id/
```

それぞれ環境変数に設定しておきます。

**Notes:** これ以降、環境変数の定義で使っている `_O` は、英大文字オーです。

```bash
export ROLE_ID_T=$(cat role-id/tokyo)
export ROLE_ID_O=$(cat role-id/osaka)
export ROLE_ID_N=$(cat role-id/nagoya)
export ROLE_ID_F=$(cat role-id/fukuoka)
```

各ロールに紐づく `role-id` の値を確認してみます。

```bash
echo $ROLE_ID_T
echo $ROLE_ID_O
echo $ROLE_ID_N
echo $ROLE_ID_F
```

# Login with AppRole

## `tokyo` role 

`tokyo` ロールを利用して、Vault にログインします。まずは、`secret-id` を生成していきます。`secret-id` の生成はロール毎に固有のパスが設けられており、そのエンドポイントに対してリクエストを行う事で動的に生成されます。この作業はルートトークンで作業を実施しているため、`tokyo` ロールの `secret-id` を生成出来ますが、`secret-id` を生成するというオペレーションもポリシーでアクセス制御する事が可能です。

```bash
vault write -f auth/test/role/tokyo/secret-id
```

*コマンド出力例*
```console
Key                   Value
---                   -----
secret_id             a5a2b95c-d37e-33c7-11b4-116b095f93ba
secret_id_accessor    b32d048c-f160-3046-a73f-47aa8681efd7
secret_id_num_uses    1
secret_id_ttl         5m
```

生成された `secret_id` は5分間有効であり、利用回数は1回となっている事が分かります。再度同様のコマンドを実行すると、別の `secret-id` が生成され、動的に生成されている事が確認出来ると思います。

```bash
vault write -f auth/test/role/tokyo/secret-id
```

`tokyo` ロールでログインするために、`secret-id` も環境変数に設定します。

```bash
export SECRET_ID_T=$(vault write -format=json -f auth/test/role/tokyo/secret-id | jq -r ".data.secret_id")
echo $SECRET_ID_T
```

`vault` CLI で、`tokyo` ロールを利用し、ログインします。

```bash
vault write auth/test/login role_id=$ROLE_ID_T secret_id=$SECRET_ID_T
```

生成されたトークンを環境変数に設定します。

```bash
export VAULT_TOKEN=
```

生成されたトークンには、`read-fruits` ポリシーが付与されており、このポリシーに明示的に付与された権限の範囲で Vault を操作出来ます。

OK

```bash
vault kv get test/fruits
```

NG

```bash
vault kv get test/vegetables
```

もう一度同じ `secret_id` でログインしてみます。

```bash
vault write auth/test/login role_id=$ROLE_ID_T secret_id=$SECRET_ID_T
```

以下の様な出力と共にログインが出来なかったと思います。`tokyo` ロールに設定した、`secret-id` に関する制約が有効である事を確認出来ます。

*コマンド出力例*
```console
Error writing data to auth/test/login: Error making API request.

URL: PUT https://127.0.0.1:8200/v1/auth/test/login
Code: 400. Errors:

* invalid role or secret ID
```

## `nagoya` role

環境変数 `VAULT_TOKEN` をルートトークンに設定し直します。

**Notes:** Vault のルートトークンを確認したい場合、`~/work/vault-handson-public/server/init.out` を確認してください。

```bash
export VAULT_TOKEN=$ROOT_TOKEN
```

`nagoya` ロールでログインするために、`secret_id` を生成します。

```bash
export SECRET_ID_N=$(vault write -format=json -f auth/test/role/nagoya/secret-id | jq -r ".data.secret_id")
echo $SECRET_ID_N
```

ログインを試みてます。

```bash
vault write auth/test/login role_id=$ROLE_ID_N secret_id=$SECRET_ID_N
```

ログインは失敗したかと思います。`nogoya` ロールの設定を確認してみます。コマンド出力例にある通り、`secret_id_bound_cidrs` 制約により、この `secret-id` を利用出来る CIDR レンジに制約があります。そのため、この環境からは `nagoya` ロールを利用して、ログインする事が出来ません。

```bash
vault read auth/test/role/nagoya
```

*コマンド出力例*
```console
Key                        Value
---                        -----
bind_secret_id             true
local_secret_ids           false
secret_id_bound_cidrs      [10.0.10.0/24]
secret_id_num_uses         1
secret_id_ttl              5m
token_bound_cidrs          []
token_explicit_max_ttl     0s
token_max_ttl              10m
token_no_default_policy    false
token_num_uses             0
token_period               0s
token_policies             [default all-vegetables]
token_ttl                  5m
token_type                 default
```

## `fukuoka` role

環境変数 `VAULT_TOKEN` をルートトークンに設定し直します。

**Notes:** Vault のルートトークンを確認したい場合、`~/work/vault-handson-public/server/init.out` を確認してください。

```bash
export VAULT_TOKEN=$ROOT_TOKEN
```

`fukuoka` ロールでログインするために、`secret_id` を生成します。

```bash
export SECRET_ID_F=$(vault write -format=json -f auth/test/role/fukuoka/secret-id | jq -r ".data.secret_id")
echo $SECRET_ID_F
```

ログインを試みてます。

```bash
vault write auth/test/login role_id=$ROLE_ID_F secret_id=$SECRET_ID_F
```

以下の様に問題なく、トークンが生成されると思います。

*コマンド出力例*
```console
Key                     Value
---                     -----
token                   hvs.xxx
token_accessor          AHVbBI57nOrWWzyP1dx5rYzc
token_duration          10m
token_renewable         true
token_policies          ["all-vegetables" "default"]
identity_policies       []
policies                ["all-vegetables" "default"]
token_meta_role_name    fukuoka
```

生成されたトークンを環境変数に設定し、付与されたポリシー `all-vegetables` で許可された作業を実施してみます。

```bash
export VAULT_TOKEN=
```

```bash
vault kv get test/vegetables
```

このコマンドは `* permission denied` というメッセージがレスポンスされ、失敗したと思います。失敗した原因を確認してみます。`VAULT_TOKEN` 環境変数をリセットし、ルートトークンに変更します。

```bash
unset VAULT_TOKEN
export VAULT_TOKEN=$ROOT_TOKEN
```

`fukuoka` ロールの設定を確認してみます。コマンド出力例にある通り、`token_bound_cidrs` 制約により、このロールでログインする事によって生成されたトークンには CIDR レンジに制約があります。そのため、この環境からは `fukuoka` ロールでログインし、生成されたトークンを用いた作業は行えません。

```bash
vault read auth/test/role/fukuoka
```

*コマンド出力例*
```console
Key                        Value
---                        -----
bind_secret_id             true
local_secret_ids           false
secret_id_bound_cidrs      <nil>
secret_id_num_uses         3
secret_id_ttl              10m
token_bound_cidrs          [10.0.10.0/24]
token_explicit_max_ttl     0s
token_max_ttl              10m
token_no_default_policy    false
token_num_uses             0
token_period               0s
token_policies             [default all-vegetables]
token_ttl                  10m
token_type                 default
```

## `osaka` role

環境変数 `VAULT_TOKEN` をルートトークンに設定し直します。

**Notes:** Vault のルートトークンを確認したい場合、`~/work/vault-handson-public/server/init.out` を確認してください。

```bash
export VAULT_TOKEN=$ROOT_TOKEN
```

AppRole のロール設定時に様々な制約を掛けられるため、Vault へのログインをセキュアにし、かつ生成されたトークンの利用にも制約を掛けられるため、しっかりを設定を行う事でセキュアに運用出来る認証メソッドであるという事をご確認頂けたかと思います。

ただ、`secret-id` をクライアント側がどう取得するかは工夫が必要になります。

`osaka` ロールの `secret-id` のみを生成できるトークンを生成しています。トークンは基本的には認証メソッドを通じて、動的に生成されるものになりますが、Vault の仕組みとしてトークンを直接生成する事も出来ます。

*トークンの生成*

```hcl
resource "vault_token" "r2_secretid" {
  display_name = "osaka-secretid"

  policies = ["generate-osaka-secretid", "self-manage-token"]

  renewable = true
  ttl       = "24h"

  renew_min_lease = 43200
  renew_increment = 86400
}
```

*トークンに付与したポリシー*

```hcl
resource "vault_policy" "r2_secretid" {
  name = "generate-osaka-secretid"

  policy = <<EOT
path "auth/${var.approle_path}/role/osaka/secret-id" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "token" {
  name = "self-manage-token"

  policy = <<EOT
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
EOT
}
```

`osaka` ロールの `secret-id` のみを生成できるトークンを環境変数に設定します。

```bash
export GEN_SECRET_ID_O_TOKEN=$(terraform output -json osaka_secretid_client_token | jq . -r)
echo $GEN_SECRET_ID_O_TOKEN
```

トークンのメタデータを確認します。

```bash
export VAULT_TOKEN=$GEN_SECRET_ID_O_TOKEN
vault token lookup
```

*コマンド出力例*
```console
Key                 Value
---                 -----
accessor            bb4xPja4pNF7zaT7FF1KYtby
creation_time       1713413059
creation_ttl        24h
display_name        token-osaka-secretid
entity_id           n/a
expire_time         2024-04-19T04:04:19.730150079Z
explicit_max_ttl    0s
id                  hvs.xxx
issue_time          2024-04-18T04:04:19.730159955Z
meta                <nil>
num_uses            0
orphan              false
path                auth/token/create
policies            [default generate-osaka-secretid self-manage-token]
renewable           true
ttl                 23h52m44s
type                service
```

このトークンは、`renewable` が `true` となっており、かつ `explicit_max_ttl` が定義されていないため、`ttl` 内に更新処理をしてあげれば、同じトークンを延長して利用する事が出来ます。

```bash
vault token renew
```

*コマンド出力例*
```console
Key                  Value
---                  -----
token                hvs.xxx
token_accessor       bb4xPja4pNF7zaT7FF1KYtby
token_duration       24h
token_renewable      true
token_policies       ["default" "generate-osaka-secretid" "self-manage-token"]
identity_policies    []
policies             ["default" "generate-osaka-secretid" "self-manage-token"]
```

トークンのバリューは同じ値になっていると思いますが、トークンの有効期限が延長されているのが分かると思います。

```bash
vault token lookup
```

*コマンド出力例*
```console
Key                  Value
---                  -----
accessor             bb4xPja4pNF7zaT7FF1KYtby
creation_time        1713413059
creation_ttl         24h
display_name         token-osaka-secretid
entity_id            n/a
expire_time          2024-04-19T04:11:45.499085191Z
explicit_max_ttl     0s
id                   hvs.xxx
issue_time           2024-04-18T04:04:19.730159955Z
last_renewal         2024-04-18T04:11:45.499085311Z
last_renewal_time    1713413505
meta                 <nil>
num_uses             0
orphan               false
path                 auth/token/create
policies             [default generate-osaka-secretid self-manage-token]
renewable            true
ttl                  23h59m54s
type                 service
```

`osaka` ロールの `secret-id` のみを生成できるトークンを使って、`secret-id` を生成し、`osaka` ロールでログインしたいと思います。

ここでの手順は API を利用する想定での手順で実施してみます。

```bash
export SECRET_ID_O=$(curl --header "X-VAULT-TOKEN: $GEN_SECRET_ID_O_TOKEN" --request POST $VAULT_ADDR/v1/auth/test/role/osaka/secret-id | jq -r .data.secret_id)
echo $SECRET_ID_O
```

問題なければ、`osaka` ロールでログインします。

```bash
export VAULT_CLIENT_TOKEN_O=$(curl --request POST --data '{"role_id": "'"$ROLE_ID_O"'", "secret_id": "'"$SECRET_ID_O"'"}' $VAULT_ADDR/v1/auth/test/login | jq -r .auth.client_token)
export VAULT_TOKEN=$VAULT_CLIENT_TOKEN_O
```

`osaka` ロールには、`read-fruits` ポリシーが付与されているので、アクセス制御がなされているか確認してみます。

OK

```bash
curl --header "X-VAULT-TOKEN: $VAULT_CLIENT_TOKEN_O" $VAULT_ADDR/v1/test/data/fruits | jq -r
```

*コマンド出力例*
```json
{
  "request_id": "d06cc917-e928-6dd8-1a13-586a26200bd6",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": {
    "data": {
      "member1": "apple",
      "member2": "banana",
      "member3": "cherry"
    },
    "metadata": {
      "created_time": "2024-04-18T00:40:12.957165454Z",
      "custom_metadata": null,
      "deletion_time": "",
      "destroyed": false,
      "version": 2
    }
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null,
  "mount_type": "kv"
}
```

NG

```bash
curl --header "X-VAULT-TOKEN: $VAULT_CLIENT_TOKEN_O" $VAULT_ADDR/v1/test/data/vegetables | jq -r
```

## Additional

`secret-id` の取得方法をさらにセキュアな方法にする方法として、`secret-id` の生成時に `-wrap-ttl` フラグを利用する方法があります。

この方法を利用して頂く事で、`secret-id` が平文でレスポンスされる代わりに、トークン使用回数が1回に限定された短い TTL のラッピングトークンがレスポンスされます。
実際の `secret-id` は、このラッピングトークンの Cubbyhole にストアされ、ラッピングトークンを持っているクライアントのみがアンラップ処理を行う事で、実際の `secret-id` を取得する事が可能になります。

ここも API を用いて実施していきます。`--header "X-Vault-Wrap-TTL: 60s"` を付与して、`secret-id` を生成します。

```bash
curl --header "X-VAULT-TOKEN: $GEN_SECRET_ID_O_TOKEN" --header "X-Vault-Wrap-TTL: 60s" --request POST $VAULT_ADDR/v1/auth/test/role/osaka/secret-id | jq
```

そうすると、`secret-id` がレスポンスされずに、トークンがレスポンスされます。このトークンは TTL が 60秒なので、60秒経つとこのトークンが利用出来ません。

*コマンド出力例*
```json
{
  "request_id": "",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": null,
  "wrap_info": {
    "token": "hvs.xxx",
    "accessor": "5UTuNEveZEYEKfQqDQlfPSYq",
    "ttl": 60,
    "creation_time": "2024-04-18T04:54:00.6747582Z",
    "creation_path": "auth/test/role/osaka/secret-id",
    "wrapped_accessor": "5abddc57-f972-b238-6cf0-6ff3373779fc"
  },
  "warnings": null,
  "auth": null,
  "mount_type": ""
}
```

トークンをアンラップします。そうすると実際の `secret-id` がレスポンスされます。

```bash
curl --header "X-VAULT-TOKEN: hvs.xxx" --request POST $VAULT_ADDR/v1/sys/wrapping/unwrap | jq
```

*コマンド出力例*
```json
{
  "request_id": "4c538710-19eb-8a56-a42c-a5b67303cb2a",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": {
    "secret_id": "a6c96495-38d2-d981-4b80-7397fecffda2",
    "secret_id_accessor": "8f08b3cf-de0c-d345-1667-e4b2746a6c1b",
    "secret_id_num_uses": 3,
    "secret_id_ttl": 600
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null,
  "mount_type": "approle"
}
```

`osaka` ロールでのログインまでをラッピングトークンを利用した形にすると、以下の様な形になります。

```bash
export WRAP_TOKEN_O=$(curl --header "X-VAULT-TOKEN: $GEN_SECRET_ID_O_TOKEN" --header "X-Vault-Wrap-TTL: 60s" --request POST $VAULT_ADDR/v1/auth/test/role/osaka/secret-id | jq -r .wrap_info.token)
export SECRET_ID_O=$(curl --header "X-VAULT-TOKEN: $WRAP_TOKEN_O" --request POST $VAULT_ADDR/v1/sys/wrapping/unwrap | jq -r .data.secret_id)
export VAULT_CLIENT_TOKEN_O=$(curl --request POST --data '{"role_id": "'"$ROLE_ID_O"'", "secret_id": "'"$SECRET_ID_O"'"}' $VAULT_ADDR/v1/auth/test/login | jq -r .auth.client_token)
```

# References

- [AppRole auth method](https://developer.hashicorp.com/vault/docs/auth/approle)
- [AppRole auth method (API)](https://developer.hashicorp.com/vault/api-docs/auth/approle)
- [Token auth method (API)](https://developer.hashicorp.com/vault/api-docs/auth/token)