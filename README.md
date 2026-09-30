# dotfiles

Macの設定とHomebrewのパッケージ一覧を管理します。移行アシスタントでアカウントや書類を移し、このリポジトリからMacの設定とアプリを復元します。

## 新しいMacのセットアップ

1. Apple AccountとMac App Storeにサインインします。移行アシスタントを使う場合は、先に移行を完了してください。
2. 1Passwordアプリをインストールしてサインインし、設定の「開発者」から[1Password CLI連携](https://developer.1password.com/docs/cli/app-integration/)を有効にします。セットアップ時に認証を求められたら、1Passwordで許可してください。CLI本体はセットアップスクリプトがHomebrewからインストールします。
3. age秘密鍵のファイル全体を、1Passwordの「書類」としてタイトル `chezmoi-encrypt-key.txt` で保存します。タイトルが同じ書類を複数作らないでください。スクリプトは秘密鍵の形式と公開鍵コメントを確認します。鍵をGitHubやiCloud Driveには置きません。
4. スクリプトを確認して実行します。

   ```zsh
   curl -fsSL https://raw.githubusercontent.com/kuuumo/dotfiles/master/setup-mac.zsh -o /tmp/setup-mac.zsh
   less /tmp/setup-mac.zsh
   zsh /tmp/setup-mac.zsh
   ```

スクリプトはHomebrewと1Password CLIを準備し、1Passwordから鍵を取得して `~/.chezmoi-encrypt-key.txt` にアクセス権を本人だけにして配置します。既存の鍵も1Passwordの内容に更新し、設定を復号できることを確認します。復号できなければ、既存の鍵を元に戻します。鍵の内容は画面に表示しません。

その後、chezmoiを準備します。既存の管理元は未コミットの変更がなくmaster上の場合だけGitHubから更新します。適用前に復号結果と差分を確認します。適用するとBrewfileにある項目をインストールしますが、Brewfileにないものは削除しません。復元に失敗したら同じスクリプトを再実行してください。

移行した `~/.config/chezmoi/chezmoi.toml` はそのまま使います。`[git]` の `autoCommit` と `autoPush` が有効なら、新しいMacでも自動コミット・プッシュが続くため、実行前に確認してください。

## Brewfileの更新

Macで使う一覧は `~/.config/brewfile/Brewfile`、chezmoiの管理元は `private_dot_config/brewfile/Brewfile` です。初回適用後、新しいターミナルを開くと、`brew` や `mas` からの追加・削除が両方に反映されます。

- GUIからApp Storeアプリを変更したら、復元が完了した正本のMacで `brewfile_sync_current_state` を実行します。現在の一覧を記録するだけで、アプリのインストールや削除はしません。GUIで入れたアプリも `mas` がSpotlightで認識すれば記録されますが、漏れたものは手動登録してください。復元途中のMacでは未導入の項目が一覧から消えることがあります。
- 変更を他のMacへ反映するときは、差分を確認してGitHubへコミット・プッシュします。

古い `~/Brewfile` は使いません。
