# Configure userpass auth method

Vault のクライアントとしてヒトがアクセスする場合の挙動を確認するために、Userpass 認証メソッドを設定します。また、この後利用するサンプルシークレットとポリシー設定もここで行います。

Vault プロバイダの認証は先ほど設定した、`VAULT_ADDR`, `VAULT_TOKEN` で行っています。`server` ディレクトリで作業を行っていた前提の手順になります。

## Contents

- [Configure userpass, kv-v2 and policy](#configure-userpass-kv-v2-and-policy)
- [Login with userpass](#login-with-userpass)
- [References](#references)

# Configure userpass, kv-v2 and policy

```bash
cd ../auth-userpass
terraform init
terraform plan
```

`terraform apply` を実行する前に、現在有効化されている認証メソッド、シークレットエンジン、ポリシーを確認しておきます。

```bash
vault auth list
```

*コマンド出力例*
```console
Path      Type     Accessor               Description                Version
----      ----     --------               -----------                -------
token/    token    auth_token_0a30cf9a    token based credentials    n/a
```

```bash
vault secrets list
```

*コマンド出力例*
```console
Path          Type         Accessor              Description
----          ----         --------              -----------
cubbyhole/    cubbyhole    cubbyhole_f3b84e2b    per-token private secret storage
identity/     identity     identity_4e9e6a46     identity store
sys/          system       system_7ec96a5c       system endpoints used for control, policy and debugging
```

```bash
vault policy list
```

*コマンド出力例*
```console
default
root
```

確認できたら、Terraform コードを反映させます。

```bash
terraform apply -auto-approve
```

有効化された認証メソッドを確認してみます。

```bash
vault auth list
```

次に、ポリシーをリストしてみます。以下のような出力になっているはずです。

```bash
vault policy list
```

*コマンド出力例*
```console
all-vegetables
default
read-fruits
vault-admin
write-fruits
root
```

個別にポリシーの内容を確認するには、`vault policy read <POLICY_NAME>` で確認出来ます。

```bash
vault policy read read-fruits
```

作成したシークレットも確認します。

```bash
vault secrets list
vault kv list test
```

`vault kv list` で以下の様に出力されるはずです。

*コマンド出力例*
```console
Keys
----
fruits
vegetables
```

シークレットの中の Key-Value データを確認してみます。

```bash
vault kv get test/fruits
vault kv get test/vegetables
```

それぞれ以下の様な出力になると思います。

*コマンド出力例*
```console
== Secret Path ==
test/data/fruits

======= Metadata =======
Key                Value
---                -----
created_time       2024-04-17T08:10:10.238183681Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1

===== Data =====
Key        Value
---        -----
member1    apple
member2    banana
```

*コマンド出力例*
```console
==== Secret Path ====
test/data/vegetables

======= Metadata =======
Key                Value
---                -----
created_time       2024-04-17T08:10:10.232470727Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1

===== Data =====
Key        Value
---        -----
member1    asparagus
member2    broccoli
member3    cabbage
```

# Login with userpass

作成したユーザー、`admin` と `user1~3` それぞれの挙動を確認してみます。

```bash
vault login -method=userpass -path=userpass username=admin password=changeme
```

出力された Vault クライアントトークンを環境変数に設定します。

**Notes:** `VAULT_TOKEN` が定義されていなければ、自動で設定されます。

```bash
export VAULT_TOKEN=
```

Terraform コードの中で定義した Vault ポリシー `vault-admin` が付与されているため、以下のコマンドを実行するための権限が付与されており、問題なくオペレーションが完了すると思います。

```bash
vault auth list
vault secrets list
vault kv get test/fruits
vault kv get test/vegetables
```

設定した `VAULT_TOKEN` を一度リセットしてから、`user1` でログインします。

```bash
unset VAULT_TOKEN
```

`user1` でログインします。

```bash
vault login -method=userpass -path=userpass username=user1 password=changeme
```

`user1` には `write-fruits` ポリシーのみが付与されており、`test/fruits` への読取の処理は認可されません。

```bash
vault kv get test/fruits
```

`write-fruits` ポリシーでは、`test/fruits` への書込み、更新、追加の処理が認可されているため、以下のコマンドは正常に終了します。

```bash
vault kv patch -mount=test -cas=1 fruits member3=cherry
```

設定した `VAULT_TOKEN` を一度リセットしてから、同じ様に、`user2`, `user3` でログインし、ポリシーによる認可の挙動を確認します。

```bash
unset VAULT_TOKEN
```

**user2**

```bash
vault login -method=userpass -path=userpass username=user2 password=changeme
```

OK

```bash
vault kv get test/fruits
```

NG

```bash
vault kv patch -mount=test -cas=3 fruits member4=durian
```

```bash
unset VAULT_TOKEN
```

**user3**

```bash
vault login -method=userpass -path=userpass username=user3 password=changeme
```

NG

```bash
vault kv get test/fruits
```

OK

```bash
vault kv get test/vegetables
```

認証メソッドが変更されても、Vault へのアクセス制御という観点では同じ考え方で実装されています。

**Notes:** Vault のルートトークンを確認したい場合、`~/work/vault-handson-public/server/init.out` を確認してください。

# References

- [Userpass auth method](https://developer.hashicorp.com/vault/docs/auth/userpass)
- [CLI - kv](https://developer.hashicorp.com/vault/docs/commands/kv)
- [KV secrets engine - version 2](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2)
- [KV secrets engine - version 2 (API)](https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2)
- [Policies](https://developer.hashicorp.com/vault/docs/concepts/policies)