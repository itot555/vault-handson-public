# SSH secrets engine

## Contents

- [Prerequisites](#prerequisites)
- [Set up ssh secrets engine](#set-up-ssh-secrets-engine)
- [Set up ssh server on client-1](#set-up-ssh-server-on-client-1)
- [Set up ssh client](#set-up-ssh-client)
  - [Login with `user1` with userpass auth method](#login-with-user1-with-userpass-auth-method)
  - [Login with `user2` with userpass auth method](#login-with-user2-with-userpass-auth-method)
- [References](#references)

# Prerequisites

- [Vault サーバーセットアップ](https://github.com/itot555/vault-handson-public/tree/main/server)
- [Userpass 認証メソッドの設定](https://github.com/itot555/vault-handson-public/tree/main/auth-userpass)

> [!NOTE]
> Vault のルートトークンを確認したい場合、`~/work/vault-handson-public/server/init.out` を確認してください。

# Set up ssh secrets engine

SSH 証明書用の SSH シークレットエンジンの設定を行っていきます。Terminal タブで作業を行います。

```bash
export VAULT_TOKEN=$ROOT_TOKEN
```
```bash
cd ~/work/vault-handson-public/secrets-engine-ssh-cert/
```
```bash
terraform init
terraform plan
```

Vault 側で Vault 内で定義する CA 用のキーペアを作成しています。

```hcl
resource "vault_ssh_secret_backend_ca" "ssh_signer" {
  backend              = vault_mount.ssh_signer.path
  generate_signing_key = true
}
```

一方、既にキーペアを Vault の外部で用意されている場合、以下の様な形で指定し、定義する事も可能です。

```bash
vault write ssh-client-signer/config/ca \
  private_key="..." \
  public_key="..."
```

プラン内容を確認できたら、Terraform コードを適用させて、SSH シークレットエンジンを設定します。

```bash
terraform apply -auto-approve
```

Terraform で設定された SSH ロールは以下のコマンドで確認する事が出来ます。

```bash
vault list ssh-client-signer/roles
```

ロールの詳細な内容を確認するには以下のコマンドを実行します。ここでは、`client1` という SSH ロールを設定しています。

```bash
vault read ssh-client-signer/roles/client1
```
```console
Key                            Value
---                            -----
algorithm_signer               rsa-sha2-256
allow_bare_domains             false
allow_host_certificates        false
allow_subdomains               false
allow_user_certificates        true
allow_user_key_ids             false
allowed_critical_options       n/a
allowed_domains                n/a
allowed_domains_template       false
allowed_extensions             permit-pty,permit-port-forwarding
allowed_user_key_lengths       map[]
allowed_users                  ubuntu,ssh-certs-test
allowed_users_template         false
default_critical_options       map[]
default_extensions             map[permit-pty:]
default_extensions_template    false
default_user                   n/a
default_user_template          false
key_id_format                  n/a
key_type                       ca
max_ttl                        0s
not_before_duration            30s
ttl                            10m
```

# Set up ssh server on client-1

Client-1 タブに移動して、SSH シークレットエンジンを利用してアクセスするホスト側の設定を行います。

SSH シークレットエンジンで設定した CA の公開鍵を client-1 上にファイルとして保存します。クライアント署名の公開鍵は API の `/public_key` エンドポイントからアクセス可能で、このエンドポイントに関しては、認証を行う事なくアクセスする事が可能です。

```bash
curl -o /etc/ssh/trusted-user-ca-keys.pem http://hashistack:8200/v1/ssh-client-signer/public_key
```
```bash
cat /etc/ssh/trusted-user-ca-keys.pem
```

この公開鍵を信頼する様に、SSH サーバの設定を更新します。

```bash
echo "TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem" >> /etc/ssh/sshd_config
```
```bash
cat /etc/ssh/sshd_config
```

設定ファイルを更新したら、SSH サーバーをリスタートします。

```bash
systemctl restart sshd
```

また、client-1 上にユーザー `ssh-certs-test` を作成しておきます。

```bash
useradd -m --shell /bin/bash ssh-certs-test
cat /etc/passwd | grep "ssh-certs-test"
```

これでターゲットとなるホスト側の作業は終了です。

# Set up ssh client

Terminal タブに戻ります。

SSH シークレットエンジンで署名するための、SSH アクセスで利用するキーペアを作成します。キーペアは、`/root/work/vault-handson-public/secrets-engine-ssh-cert/` 下に作成する様にしています。

パスフレーズを求められますが、何も入力せずに Enter を入力してください。

```bash
ssh-keygen -t rsa -C "hoge@hashistack.com"
```
```console
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa): /root/work/vault-handson-public/secrets-engine-ssh-cert/id_rsa
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /root/work/vault-handson-public/secrets-engine-ssh-cert/id_rsa
Your public key has been saved in /root/work/vault-handson-public/secrets-engine-ssh-cert/id_rsa.pub
The key fingerprint is:
SHA256:E1BXbzEuNHyi49vDDvtzjx8QZu/M91TY7NU0qrkqfRM hoge@hashistack.com
The key's randomart image is:
+---[RSA 3072]----+
|      ... .o+ o  |
|       . . .o+.o |
|        .  ..*+..|
|         .o oo+=o|
|        S. . o..*|
|         ..Eo =.o|
|        . .*.  =+|
|       . ..=* .o+|
|        ..++++.o+|
+----[SHA256]-----+
```

作成した SSH キーペアの公開鍵に対して、Vault へ署名をリクエストする事を許可するポリシー `ssh-sign-client1` を作成します。必要となる capabilities は、API ドキュメント [Sign SSH key](https://developer.hashicorp.com/vault/api-docs/secret/ssh#sign-ssh-key) でご確認頂けます。

```bash
vault policy write ssh-sign-client1 - <<EOF
path "ssh-client-signer/sign/client1" {
  capabilities = [ "create", "update" ]
}
EOF
```

作成したポリシーを確認します。

```bash
vault policy read ssh-sign-client1
```
```console
path "ssh-client-signer/sign/client1" {
  capabilities = [ "create", "update" ]
}
```

作成したポリシーを [Userpass 認証メソッドの設定](https://github.com/itot555/vault-handson-public/tree/main/auth-userpass)で作成した `user1` ユーザーに追加で付与します。

```bash
vault write auth/userpass/users/user1 policies="write-fruits,ssh-sign-client1"
```

## Login with `user1` with userpass auth method

設定した `VAULT_TOKEN` を一度リセットしてから、Userpass 認証メソッドのユーザー `user1` でログインします。

```bash
unset VAULT_TOKEN
```

`user1` でログインします。

```bash
vault login -method=userpass -path=userpass username=user1 password=changeme
```

以下の様なレスポンスがされ、トークンに `ssh-sign-client1` ポリシーが付与されていることを確認します。

```console
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
token                  hvs.CAES...DE
token_accessor         IMagGcx6V17xO1napELCZnUO
token_duration         30m
token_renewable        true
token_policies         ["default" "ssh-sign-client1" "write-fruits"]
identity_policies      []
policies               ["default" "ssh-sign-client1" "write-fruits"]
token_meta_username    user1
```

SSH シークレットエンジンで署名され公開鍵を作成します。作成し、ファイルに書き出した `signed-cert.pub` は先ほど作成した公開鍵とは別物になります。

```bash
vault write -field=signed_key ssh-client-signer/sign/client1 public_key=@id_rsa.pub valid_principals="ubuntu,ssh-certs-test" > signed-cert.pub
```

署名された公開鍵を使って、ターゲットのマシン(`client-1`)に SSH 接続します。Vault から署名された公開鍵と対応する秘密鍵の両方を SSH 呼び出しへの認証として提供する必要があります。`ubuntu`, `ssh-certs-test` ユーザーでログインしてみます。

```bash
ssh -i signed-cert.pub -i id_rsa ubuntu@client-1
```
```bash
ssh -i signed-cert.pub -i id_rsa ssh-certs-test@client-1
```

## Login with `user2` with userpass auth method

続いて、署名するための API エンドポイントに対するポリシーが付与されていないユーザーでの挙動を確認します。

```bash
unset VAULT_TOKEN
```

`user2` でログインします。

```bash
vault login -method=userpass -path=userpass username=user2 password=changeme
```

`user2` は権限がないため、SSH シークレットエンジンで署名され公開鍵を作成する事が出来ません。

```bash
vault write -field=signed_key ssh-client-signer/sign/client1 public_key=@id_rsa.pub valid_principals="ubuntu,ssh-certs-test" > signed-cert.pub
```

# References

- [Signed SSH certificates](https://developer.hashicorp.com/vault/docs/secrets/ssh/signed-ssh-certificates)
- [SSH secrets engine (API)](https://developer.hashicorp.com/vault/api-docs/secret/ssh)