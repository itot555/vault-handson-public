# Vault server setup

まずは、Vault サーバーをセットアップします。今回は TLS 認証メソッドを利用するため、サーバー証明書を作成し、Vault サーバーを起動します。

```bash
cd work
```

ハンズオンで利用するコンテンツを `git clone` で取得します。

```bash
git clone https://github.com/itot555/vault-handson-public.git
cd vault-handson-public/server/
```

作業が終わったら、ディレクトリを移動し、以下のコマンドを実行します。

```bash
terraform init
terraform plan
```

問題なくコマンドが通ったら、`terraform apply -auto-approve` コマンドを実行します。

```bash
terraform apply -auto-approve
```

`terraform apply` が問題なく完了すると、`cets` ディレクトリに証明書が生成されているはずです。

その証明書を利用し、Vault サーバーの設定ファイルを作成しています。

```bash
cat vault.hcl
```

設定ファイルが確認したら、Server1 タブで以下を実行し、Vault サーバーを起動させます。下記のコマンドを実行したら、Terminal タブに戻ります。

```bash
vault server -config=/root/work/vault-handson-public/server/vault.hcl
```

Terminal タブで Vault サーバーで利用している証明書を信頼された証明書として登録します。

```bash
mkdir /usr/share/ca-certificates/handson
cp certs/ca.pem /usr/share/ca-certificates/handson/ca.crt
cp certs/vault_cert.pem /usr/share/ca-certificates/handson/vault.crt
```

下のコマンドの `update-ca-certificates` で `2 added, 0 removed; done.` と出力されればOKです。

```bash
echo "handson/ca.crt" >> /etc/ca-certificates.conf
echo "handson/vault.crt" >> /etc/ca-certificates.conf
update-ca-certificates
```

`VAULT_ADDR` 環境変数を設定し、Vault の初期化を行い、Unseal 処理を行います。

```bash
export VAULT_ADDR="https://127.0.0.1:8200"
```

```bash
vault operator init -key-shares=1 -key-threshold=1 | tee init.out
```

`Unseal Key 1:` の値を環境変数 `UNSEAL_KEY` に、`Initial Root Token:` の値を環境変数 `ROOT_TOKEN` に設定し、それを環境変数 `VAULT_TOKEN` に設定します。

```bash
export ROOT_TOKEN=
export VAULT_TOKEN=$ROOT_TOKEN
export UNSEAL_KEY=
```

Unseal 処理を行います。

```bash
vault operator unseal $UNSEAL_KEY
```

Unseal 処理が完了し、`vault status` コマンドで Vault サーバーのステータスを確認し、`Sealed` が `false` となっていれば、Vault サーバーのセットアップは完了です。

```bash
vault status
```

*コマンド出力例*
```console
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            1
Threshold               1
Version                 1.16.1
Build Date              2024-04-03T12:35:53Z
Storage Type            raft
Cluster Name            vault-cluster-e83091e6
Cluster ID              d582aaad-ca5c-e6e1-c1f2-d0694a50169b
HA Enabled              true
HA Cluster              n/a
HA Mode                 standby
Active Node Address     <none>
Raft Committed Index    29
Raft Applied Index      29
```

# References

### Documents

- [Vault configuration](https://developer.hashicorp.com/vault/docs/configuration)
- [CLI - server](https://developer.hashicorp.com/vault/docs/commands/server)

### Validated Design

- [Detailed design](https://developer.hashicorp.com/validated-designs/vault-solution-design-guides-vault-enterprise/detailed-design)

### Tutorial

- [Configure Vault](https://developer.hashicorp.com/vault/tutorials/operations/configure-vault)
- [Production hardening](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening)