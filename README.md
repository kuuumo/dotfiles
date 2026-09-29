# dotfiles

このリポジトリは、Macのユーザー設定とHomebrewのインストール一覧を管理します。

Macを買い替えるときは、移行アシスタントで現在のユーザー環境を移すのが基本です。chezmoiは設定ファイルの保管と再適用に、BrewfileはHomebrewや対応するApp Storeアプリの再インストールに使います。

## 管理対象

- chezmoiの管理元は `~/.local/share/chezmoi`、設定の反映先は各ユーザー設定ファイルです。
- 現在のHomebrew一覧は `~/.config/brewfile/Brewfile` です。管理元では `private_dot_config/brewfile/Brewfile` にあります。
- 最新のchezmoi設定を適用して新しいターミナルを開くと、Homebrewの `brew install` / `brew uninstall` などによる一覧の変更を管理元のBrewfileにも反映します。
- GUIからApp Storeアプリを追加・削除した後は、正本にするMacで `brewfile_sync_current_state` を実行します。この処理はそのMacのインストール状態を一覧に記録するだけで、アプリをインストールまたは削除しません。
- `brewfile_sync_current_state` は実行したMacの全パッケージ一覧を作り直します。移行先の復元が終わる前に実行すると、まだ入っていないパッケージがBrewfileから消えるため、移行元のMacで使います。
- 一覧の更新はGitHubへの保存を行いません。別のMacでも使う場合は、変更を確認してから管理元リポジトリへコミット・プッシュします。

## 新しいMacを用意したとき

この手順は、新しいMacを設定する本人向けです。初回は「移行前の準備」から「移行アシスタント」または「初期状態から設定」まで進み、以後は「日常の更新」を必要なときに参照します。

### 移行前に現在のMacで行うこと

1. GUIからApp Storeアプリを追加・削除した場合は、`brewfile_sync_current_state` を実行します。
2. `chezmoi cd` で管理元リポジトリに移動し、`git status --short` で変更を確認します。Brewfileや設定ファイルの必要な変更をコミットし、GitHubへプッシュします。
3. chezmoiの暗号化設定と秘密鍵を安全な場所に保管します。秘密鍵はこのリポジトリやiCloud Driveに置きません。

このMacのchezmoi設定ではGitの自動コミット・自動プッシュが有効です。移行アシスタントが `~/.config/chezmoi/chezmoi.toml` も転送した場合は、chezmoiを使う前に `[git]` の `autoCommit` と `autoPush` を確認してください。新しいMacで自動反映を望まない場合は、この2項目を削除するか `false` にします。

### 移行アシスタントを使う場合

1. 新しいMacの初期設定で移行アシスタントを使い、現在のユーザーアカウント、アプリ、書類、設定を転送します。
2. Apple Accountでサインインし、Mac App Storeも利用できる状態にします。
3. ターミナルを開き直し、Homebrewとchezmoiが使えることを確認します。どちらかがなければ、初期状態から設定する手順にあるコマンドでインストールします。移行アシスタントでHomebrewの各パッケージが正常に使えるとは限らないため、不足があればBrewfileから補います。
4. chezmoiの暗号化設定と秘密鍵が移行されたことを確認します。見つからない場合は、安全な保管先から戻し、`chezmoi apply` を実行する前に復号できる状態にします。
5. chezmoiの管理元がない場合は `chezmoi init kuuumo` を実行します。続けて `chezmoi diff` で適用予定の差分を確認し、問題なければ `chezmoi apply` を実行します。
6. Homebrewのパッケージが不足していれば、下の「Brewfileから復元する」手順を実行します。

### 新しいMacを初期状態から設定する場合

1. macOSの初期設定を終え、Apple Accountでサインインします。App Storeアプリも復元する場合は、Mac App Storeにもサインインします。
2. Homebrewをインストールし、`PATH` に追加します。

   ```zsh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   if [[ -x /opt/homebrew/bin/brew ]]; then
     brew_shellenv='eval "$(/opt/homebrew/bin/brew shellenv)"'
     grep -Fqx "$brew_shellenv" "$HOME/.zprofile" 2>/dev/null || printf '\n%s\n' "$brew_shellenv" >> "$HOME/.zprofile"
     eval "$(/opt/homebrew/bin/brew shellenv)"
   elif [[ -x /usr/local/bin/brew ]]; then
     brew_shellenv='eval "$(/usr/local/bin/brew shellenv)"'
     grep -Fqx "$brew_shellenv" "$HOME/.zprofile" 2>/dev/null || printf '\n%s\n' "$brew_shellenv" >> "$HOME/.zprofile"
     eval "$(/usr/local/bin/brew shellenv)"
   fi
   ```

   このコマンドはHomebrew公式のインストールスクリプトを実行します。[Homebrew公式手順](https://brew.sh/)
3. 旧Macまたは安全な保管先からchezmoiの暗号化設定と秘密鍵を戻します。`~/.config/chezmoi/chezmoi.toml` には既存の `encryption` と `[age]` の設定を使い、秘密鍵を設定済みの場所に置きます。秘密鍵が使えない状態では、暗号化された設定ファイルを適用できません。
4. chezmoiをインストールし、リポジトリを初期化します。

   ```zsh
   brew install chezmoi
   chezmoi init kuuumo
   ```

5. `chezmoi diff` で適用内容を確認します。確認後に `chezmoi apply` を実行します。初回適用では、後処理スクリプトがBrewfileを使ってHomebrewパッケージを復元します。

### Brewfileから復元する

chezmoiの初回適用では、次の処理を行います。

1. brew-fileをインストールします。
2. `~/.config/brewfile/Brewfile` からHomebrewのFormulaとCaskをインストールします。
3. `mas` を使える状態にした後、Brewfileに記載されたApp Storeアプリをインストールします。

この処理はchezmoiの `run_once_after_` スクリプトで行います。スクリプトの内容を変更すると、次回の `chezmoi apply` でもう一度実行されます。実行内容はBrewfileに記載されたもののインストールで、既存のパッケージを削除しません。

移行アシスタント後に不足分だけ補う場合は、ターミナルで次を実行します。

```zsh
brew install rcmdnk/file/brew-file
brew-file install --file "$HOME/.config/brewfile/Brewfile" --no-repo --appstore 0 --yes
brew-file install --file "$HOME/.config/brewfile/Brewfile" --no-repo --appstore 1 --yes
```

この手順はBrewfileにあるものをインストールします。Brewfileにないパッケージやアプリは削除しません。

## 日常の更新

- 最新のchezmoi設定を適用したターミナルでFormulaやCaskを追加・削除すると、brew-file連携が現在のBrewfileとchezmoiの管理元へ変更を反映します。
- GUIからApp Storeアプリを追加・削除したら、`brewfile_sync_current_state` を実行します。
- 一覧変更を他のMacにも反映する場合は、chezmoiの管理元で変更を確認し、必要なファイルをGitHubへコミット・プッシュします。
- `brew file clean` はBrewfileにないパッケージを削除するため、新しいMacの復元手順では使いません。
- ホーム直下にある古い `~/Brewfile` はこの手順では使いません。正本は `~/.config/brewfile/Brewfile` です。

## 用語

- **chezmoiの管理元**: Gitで管理する設定ファイルの原本です。通常は `~/.local/share/chezmoi` にあります。
- **Brewfile**: Homebrewや対応するApp Storeアプリの一覧です。このMacでは `~/.config/brewfile/Brewfile` を使います。
- **age秘密鍵**: 暗号化した設定ファイルを復号する鍵です。GitリポジトリやiCloud Driveには置かず、安全な保管先から必要なMacへ戻します。

手順どおりに進まない場合は、該当コマンドのエラーと `chezmoi doctor` の結果を確認します。共有・記録するときは、秘密鍵や個人情報を含めないでください。

## 参考資料

- [Apple：移行アシスタントで新しいMacへ転送する](https://support.apple.com/en-gb/102613)
- [Apple：iCloudで同期するアプリを選ぶ](https://support.apple.com/en-gb/118225)
- [chezmoi：スクリプトの実行順序](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/)
- [chezmoi：ageによる暗号化](https://www.chezmoi.io/user-guide/encryption/age/)
- [brew-file：brew-wrapでBrewfileを自動更新する](https://homebrew-file.readthedocs.io/en/latest/brew-wrap.html)
- [brew-file](https://github.com/rcmdnk/homebrew-file)
