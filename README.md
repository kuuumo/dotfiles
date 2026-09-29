# dotfiles

Macの設定とHomebrewのパッケージ一覧を管理します。移行アシスタントでアカウントや書類を移し、このリポジトリからMacの設定とアプリを復元します。

## 新しいMacのセットアップ

1. Apple AccountとMac App Storeにサインインします。移行アシスタントを使う場合は、先に移行を完了してください。
2. age秘密鍵を1Passwordなどの安全な保管先から `~/.chezmoi-encrypt-key.txt` に戻します。セットアップスクリプトはこのファイルだけを参照し、アクセス権を自分だけに設定します。鍵をGitHubやiCloud Driveには置きません。chezmoiの設定がなければ、スクリプトが作成します。
3. スクリプトを確認して実行します。

   ```zsh
   curl -fsSL https://raw.githubusercontent.com/kuuumo/dotfiles/master/setup-mac.zsh -o /tmp/setup-mac.zsh
   less /tmp/setup-mac.zsh
   zsh /tmp/setup-mac.zsh
   ```

スクリプトはHomebrewとchezmoiを準備し、既存の管理元は未コミットの変更がなくmaster上の場合だけGitHubから更新します。復号と差分を確認してから適用し、Brewfileにある項目をインストールします。Brewfileにないものは削除しません。復元に失敗したら同じスクリプトを再実行してください。

移行した `~/.config/chezmoi/chezmoi.toml` はそのまま使います。`[git]` の `autoCommit` と `autoPush` が有効なら、新しいMacでも自動コミット・プッシュが続くため、実行前に確認してください。

## Brewfileの更新

Macで使う一覧は `~/.config/brewfile/Brewfile`、chezmoiの管理元は `private_dot_config/brewfile/Brewfile` です。初回適用後、新しいターミナルを開くと、`brew` や `mas` からの追加・削除が両方に反映されます。

- GUIからApp Storeアプリを変更したら、復元が完了した正本のMacで `brewfile_sync_current_state` を実行します。現在の一覧を記録するだけで、アプリのインストールや削除はしません。GUIで入れたアプリも `mas` がSpotlightで認識すれば記録されますが、漏れたものは手動登録してください。復元途中のMacでは未導入の項目が一覧から消えることがあります。
- 変更を他のMacへ反映するときは、差分を確認してGitHubへコミット・プッシュします。

古い `~/Brewfile` は使いません。
