# PGP encrypted key shares

Vault は暗号化キーでデータを暗号化します。その暗号化キーは、ルートキーとして知られる第二のキーでさらに暗号化されます。Vault の初期化時に、[Shamir 秘密鍵分散アルゴリズム](https://developer.hashicorp.com/vault/docs/concepts/seal#shamir-seals)を使用して、ルートキーをいくつかのキーシェアに分割することができます。Shamir を使用する場合、これらのキーシェアはアンシールキーと呼ばれますが、[オートシール](https://developer.hashicorp.com/vault/docs/concepts/seal#auto-unseal)や HSM を使用する場合は、[リカバリキー](https://developer.hashicorp.com/vault/docs/concepts/seal#recovery-key)と呼ばれます。

Vault を初期化すると、以下の様な16進エンコードまたは base64 エンコードされたキーシェアと初期ルートトークン値の平文表現が返されます。

```console
Unseal Key 1: eU...
Unseal Key 2: w9...
Unseal Key 3: 5e...
Unseal Key 4: jm...
Unseal Key 5: ej...
Initial Root Token: hvs.xxx
Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.
Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!
It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

Vault は、[GNU Privacy Guard（GPG）](https://www.gnupg.org/documentation/manuals/gnupg/)などの [RFC 4880](https://www.ietf.org/rfc/rfc4880.txt) 準拠の PGP ソフトウェアから生成されたユーザ提供の公開鍵を使用して、初期化時にキーシェアとルートトークンの初期値を暗号化する事が出来ます。

[`pgp-keys`](https://developer.hashicorp.com/vault/docs/commands/operator/init#pgp-keys) および [`root-token-pgp-key`](https://developer.hashicorp.com/vault/docs/commands/operator/init#root-token-pgp-key) オプションをつけて Vault を初期化すると、指定された GPG 公開鍵でアンシールキーとルートトークンを暗号化し、暗号化された値を base64 エンコードし、プレーンテキスト値の代わりにそれらの値を出力します。

ここではそれを試します。[Vault サーバーセットアップ](https://github.com/itot555/vault-handson-public/tree/main/server) の Vault 初期化の前まで作業が完了している事を確認して下さい。

## Contents

- [Prepare GPG key share](#prepare-gpg-key-share)
- [Initialize Vault with public key](#initialize-vault-with-public-key)
- [Unseal Vault with encrypted key share](#unseal-vault-with-encrypted-key-share)
- [Access to Vault](#access-to-vault)
- [Additional](#additional)
- [References](#references)

# Prepare GPG key share

Terminal タブで作業を行います。`gpg` がインストールされている事を確認します。

```bash
which gpg
```

ディレクトリを移動します。

```bash
cd ~/work/vault-handson-public/operator-encrypted-key-share
```

設定ファイルを確認します。

```bash
cat zucchini_key.conf
```

GPG キーを作成します。

```bash
gpg --full-gen-key --batch zucchini_key.conf
```

以下の様な出力がされます。

```console
gpg: directory '/root/.gnupg' created
gpg: keybox '/root/.gnupg/pubring.kbx' created
gpg: Generating a basic OpenPGP key for admin
gpg: /root/.gnupg/trustdb.gpg: trustdb created
gpg: key E9B7F34123F61320 marked as ultimately trusted
gpg: directory '/root/.gnupg/openpgp-revocs.d' created
gpg: revocation certificate stored as '/root/.gnupg/openpgp-revocs.d/2FF45F1233AC39CB2781114CE9B7F34123F61320.rev'
gpg: done
```

公開鍵をファイルに落としておきます。

```bash
gpg --output /root/.gnupg/zucchini_key.pub --export zucchini@handson.dev
```

後ほど base64 でエンコードされた公開鍵が必要になるため、それも準備しておきます。

```bash
cat ~/work/vault-handson-public/operator-encrypted-key-share/zucchini_key.pub | base64 > zucchini_key_base64.pub
```

# Initialize Vault with public key

Vault を初期化するために、`VAULT_ADDR` を設定します。

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
```

> [!TIP]
> TLS を有効化して、Vault サーバーを立ち上げている場合は以下の通り、環境変数を設定して下さい。

```bash
export VAULT_ADDR="https://127.0.0.1:8200"
```

以下のコマンドで Vault を初期化します。

```bash
vault operator init -pgp-keys zucchini_key.pub -root-token-pgp-key zucchini_key.pub -key-shares=1 -key-threshold=1 | tee /root/work/vault-handson-public/server/init.out
```

以下の様な出力がレスポンスされます。

```console
Unseal Key 1: wcFMA041S...vStD4vX05goEq

Initial Root Token: wcFMA041Sh...8lSxhad2

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

# Unseal Vault with encrypted key share

暗号化されたアンシールキーは、レスポンスされた値を Base64 でデコードし、GPG でデコードされた値を復号し、`vault operator unseal` で利用します。

```bash
grep 'Unseal Key 1' /root/work/vault-handson-public/server/init.out | awk '{print $NF}' | base64 --decode > zucchini_unseal_key.dat
```

```bash
vault operator unseal $(gpg --decrypt /root/work/vault-handson-public/operator-encrypted-key-share/zucchini_unseal_key.dat)
```

> [!NOTE]
> パスフレーズの入力を求められるので、`zucchini_key.conf` に記載のあるパスフレーズの値を入力します。

無事にアンシールが完了すると以下の様な出力がレスポンスされます。

```console
gpg: encrypted with 4096-bit RSA key, ID 4E354A14B1549748, created 2024-05-28
      "Zucchini (Zucchini is a Vault PGP user) <zucchini@handson.dev>"
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            1
Threshold               1
Version                 1.16.2
Build Date              2024-04-22T16:25:54Z
Storage Type            raft
Cluster Name            vault-cluster-47b12d4e
Cluster ID              cd7ef79a-0900-3274-9752-781d5e96dc5e
HA Enabled              true
HA Cluster              n/a
HA Mode                 standby
Active Node Address     <none>
Raft Committed Index    29
Raft Applied Index      29
```

# Access to Vault

アンシールキー同様、初期ルートトークンも暗号化されていますので、Base64 でデコードし、GPG でデコードされた値を復号します。

```bash
grep 'Initial Root Token' /root/work/vault-handson-public/server/init.out | awk '{print $NF}' | base64 --decode > initial_root_token.dat
```

```bash
export ROOT_TOKEN=$(gpg --decrypt /root/work/vault-handson-public/operator-encrypted-key-share/initial_root_token.dat)
export VAULT_TOKEN=$ROOT_TOKEN
```

`vault` コマンドを実行して、初期ルートトークンでアクセス出来る事を確認します。

```bash
vault secrets list
```

```console
Path          Type         Accessor              Description
----          ----         --------              -----------
cubbyhole/    cubbyhole    cubbyhole_98f4525b    per-token private secret storage
identity/     identity     identity_b952a09d     identity store
sys/          system       system_69bd6152       system endpoints used for control, policy and debugging
```

次は、[Userpass 認証メソッドの設定](https://github.com/itot555/vault-handson-public/tree/main/auth-userpass)を行って下さい。

# Additional

rekey の処理を実施してみます。

```bash
vault operator rekey -init -backup -key-shares=1 -key-threshold=1 -pgp-keys /root/work/vault-handson-public/operator-encrypted-key-share/zucchini_unseal_key.dat
```

以下の様な出力がレスポンスされると思います。

```console
Key                      Value
---                      -----
Nonce                    5cb058b9-cde8-2dc5-308c-072ffec5c63d
Started                  true
Rekey Progress           0/1
New Shares               1
New Threshold            1
Verification Required    false
PGP Fingerprints         [2ff45f1233ac39cb2781114ce9b7f34123f61320]
Backup                   true
```

環境変数に Nonce を設定します。上の例だと、設定する値は、`5cb058b9-cde8-2dc5-308c-072ffec5c63d` になります。

```bash
export REKEY_NONCE=
```

```bash
vault operator rekey -nonce $REKEY_NONCE $(gpg --decrypt /root/work/vault-handson-public/operator-encrypted-key-share/zucchini_unseal_key.dat)
```

以下の様な出力がレスポンスされ、Vault は、新しい Base64 エンコードされ暗号化されたキーシェアをレスポンスします。

```console
gpg: encrypted with 4096-bit RSA key, ID 4E354A14B1549748, created 2024-05-28
      "Zucchini (Zucchini is a Vault PGP user) <zucchini@handson.dev>"

Key 1 fingerprint: 2ff45f1233ac39cb2781114ce9b7f34123f61320; value: wcFMA041ShSxV...MvR8BtXnhS2i

Operation nonce: 5cb058b9-cde8-2dc5-308c-072ffec5c63d

The encrypted unseal keys are backed up to "core/unseal-keys-backup" in the
storage backend. Remove these keys at any time using "vault operator rekey
-backup-delete". Vault does not automatically remove these keys.

Vault unseal keys rekeyed with 1 key shares and a key threshold of 1. Please
securely distribute the key shares printed above. When Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.
```

# References

- [PGP encrypted key shares](https://developer.hashicorp.com/vault/tutorials/operations/pgp-encrypted-key-shares)