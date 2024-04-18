# Prepare TLS auth method with PKI secrets engine

**Notes:** Vault のルートトークンを確認したい場合、`~/work/vault-handson-public/server/init.out` を確認してください。

Vault プロバイダの認証は先ほど設定した、`VAULT_ADDR`, `VAULT_TOKEN` で行っています。`auth-userpass` ディレクトリで作業を行っていた前提の手順になります。

TLS 認証メソッドで利用する認証局や、クライアント証明書を PKI シークレットエンジンを利用して準備します。

```bash
cd ../secrets-engine-pki
terraform init
terraform plan
```

`terraform apply` を実行する前に、現在有効化されているシークレットエンジンを確認しておきます。

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
test/         kv           kv_45562179           kv-v2 secrets engine for test
```

確認できたら、Terraform コードを反映させて、PKI シークレットエンジンを設定します。

```bash
terraform apply -auto-approve
```

PKI シークレットエンジンを利用して、Root と Intermediate な認証局を Vault サーバー内に作成する事ができました。

```bash
vault secrets list
```

*コマンド出力例*
```console
Path                Type         Accessor              Description
----                ----         --------              -----------
cubbyhole/          cubbyhole    cubbyhole_f3b84e2b    per-token private secret storage
identity/           identity     identity_4e9e6a46     identity store
pki-handson-int/    pki          pki_c38e1842          intermediate ca in vault handson environment
pki-handson/        pki          pki_732eb520          root ca in vault handson environment
sys/                system       system_7ec96a5c       system endpoints used for control, policy and debugging
test/               kv           kv_45562179           kv-v2 secrets engine for test
```

PKI ロールが 3 つ作成されている事が確認できます。TLS 認証メソッドでは、`client` ロールを介して生成した証明書と秘密鍵を利用します。

```bash
vault list pki-handson-int/roles/
```

ロールで定義されている内容は以下の様に `vault` CLI から確認可能です。

```bash
vault read pki-handson-int/roles/client1
```

次の、TLS 認証メソッドの設定で利用する証明書と秘密鍵をファイルにして保存しておきます。

```bash
terraform output -json client_private_key | jq -r '.["client1"]' > ../auth-tls/certs/client1_key.pem
terraform output -json client_certificate | jq -r '.["client1"]' > ../auth-tls/certs/client1_cert.pem

terraform output -json client_private_key | jq -r '.["client2"]' > ../auth-tls/certs/client2_key.pem
terraform output -json client_certificate | jq -r '.["client2"]' > ../auth-tls/certs/client2_cert.pem

terraform output -json client_private_key | jq -r '.["client2"]' > ../auth-tls/certs/client3_key.pem
terraform output -json client_certificate | jq -r '.["client2"]' > ../auth-tls/certs/client3_cert.pem
```

# References

- [PKI secrets engine](https://developer.hashicorp.com/vault/docs/secrets/pki)
- [PKI secrets engine (API)](https://developer.hashicorp.com/vault/api-docs/secret/pki)