#!/usr/bin/env zsh

set -euo pipefail

readonly homebrew_install_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
readonly default_age_identity="$HOME/.chezmoi-encrypt-key.txt"
readonly default_age_recipient="age1yd7l6ys8ads6tgradk06un7sg3aye80lufqjkcua6zhqftlh2scqlrvh0d"
readonly age_identity_document_name="chezmoi-encrypt-key.txt"

fail() {
  print -u2 -- "エラー: $*"
  exit 1
}

identity_backup_path=""
identity_replacement_pending=false

rollback_age_identity() {
  local exit_status=$?
  if [[ "$identity_replacement_pending" == true ]]; then
    if [[ -n "$identity_backup_path" && -f "$identity_backup_path" ]]; then
      mv -f "$identity_backup_path" "$default_age_identity"
      chmod 600 "$default_age_identity"
    else
      rm -f "$default_age_identity"
    fi
  fi
  return "$exit_status"
}

trap rollback_age_identity EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "このスクリプトはmacOS用です。"
fi

config_dir="$HOME/.config/chezmoi"
config_file="$config_dir/chezmoi.toml"
has_chezmoi_config=false
for extension in toml yaml json jsonc; do
  if [[ -f "$config_dir/chezmoi.$extension" ]]; then
    has_chezmoi_config=true
    break
  fi
done

install_homebrew_if_missing() {
  if command -v brew >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/brew ]] || [[ -x /usr/local/bin/brew ]]; then
    return
  fi

  print "Homebrewをインストールします。インストーラーの案内に従ってください。"
  local installer_path
  installer_path="$(mktemp "${TMPDIR:-/tmp}/homebrew-install.XXXXXX")" || fail "一時ファイルを作成できません。"

  if ! curl -fsSL "$homebrew_install_url" -o "$installer_path"; then
    rm -f "$installer_path"
    fail "Homebrewのインストーラーを取得できませんでした。"
  fi

  if ! /bin/bash "$installer_path"; then
    rm -f "$installer_path"
    fail "Homebrewのインストールに失敗しました。"
  fi

  rm -f "$installer_path"
}

install_homebrew_if_missing

local_brew="$(command -v brew 2>/dev/null || true)"
if [[ -z "$local_brew" && -x /opt/homebrew/bin/brew ]]; then
  local_brew="/opt/homebrew/bin/brew"
elif [[ -z "$local_brew" && -x /usr/local/bin/brew ]]; then
  local_brew="/usr/local/bin/brew"
fi
[[ -n "$local_brew" ]] || fail "Homebrewが見つかりません。"

brew_shellenv="eval \"\$($local_brew shellenv)\""
if ! grep -Fqx "$brew_shellenv" "$HOME/.zprofile" 2>/dev/null; then
  printf '\n%s\n' "$brew_shellenv" >> "$HOME/.zprofile"
fi
eval "$("$local_brew" shellenv)"

if [[ -L "$default_age_identity" || ( -e "$default_age_identity" && ! -f "$default_age_identity" ) ]]; then
  fail "$default_age_identity は通常のファイルではありません。内容を確認してください。"
fi

op_path="$(command -v op 2>/dev/null || true)"
if [[ -z "$op_path" ]]; then
  print "1Password CLIをHomebrewからインストールします。"
  brew install --cask 1password-cli || fail "1Password CLIをインストールできませんでした。"
  op_path="$(command -v op 2>/dev/null || true)"
fi
[[ -n "$op_path" ]] || fail "1Password CLIの op コマンドが見つかりません。"

op_version="$("$op_path" --version 2>/dev/null || true)"
case "$op_version" in
  2.*) ;;
  *) fail "1Password CLI 2が必要です。CLIを更新してから再実行してください。" ;;
esac

identity_download="$(mktemp "$HOME/.chezmoi-encrypt-key.XXXXXX")" || fail "一時ファイルを作成できません。"
chmod 600 "$identity_download"
if ! "$op_path" document get "$age_identity_document_name" --out-file "$identity_download" --file-mode 0600 --force; then
  rm -f "$identity_download"
  fail "1Passwordから鍵を取得できませんでした。1Passwordアプリへサインインし、CLI連携を有効にして、タイトルが $age_identity_document_name の書類を確認してください。"
fi

if ! grep -Eq '^AGE-SECRET-KEY-1[0-9A-Z]+$' "$identity_download" || ! grep -Fqx "# public key: $default_age_recipient" "$identity_download"; then
  rm -f "$identity_download"
  fail "1Passwordから取得した鍵が、このリポジトリのage受信者と一致しません。正しい鍵ファイルを確認してください。"
fi

if [[ -f "$default_age_identity" ]]; then
  identity_backup_path="$(mktemp "$HOME/.chezmoi-encrypt-key.backup.XXXXXX")" || {
    rm -f "$identity_download"
    fail "既存の鍵を退避する一時ファイルを作成できません。"
  }
  if ! cp -p "$default_age_identity" "$identity_backup_path"; then
    rm -f "$identity_backup_path" "$identity_download"
    identity_backup_path=""
    fail "既存の鍵を安全に退避できませんでした。"
  fi
fi

identity_replacement_pending=true
if ! mv -f "$identity_download" "$default_age_identity"; then
  rm -f "$identity_download"
  fail "1Passwordから取得した鍵を配置できませんでした。"
fi
chmod 600 "$default_age_identity"

if ! command -v chezmoi >/dev/null 2>&1; then
  brew install chezmoi
fi

if [[ "$has_chezmoi_config" == false ]]; then
  chmod 600 "$default_age_identity"
  mkdir -p "$config_dir"
  (
    umask 077
    cat > "$config_file" <<TOML
encryption = "age"

[age]
identity = "$default_age_identity"
recipient = "$default_age_recipient"
TOML
  )
  chmod 600 "$config_file"
fi

source_dir="$(chezmoi source-path)"
if [[ -e "$source_dir/.git" ]]; then
  remote_url="$(git -C "$source_dir" remote get-url origin 2>/dev/null)" || fail "既存の管理元にoriginリモートがありません。"
  case "$remote_url" in
    git@github.com:kuuumo/dotfiles|git@github.com:kuuumo/dotfiles.git|https://github.com/kuuumo/dotfiles|https://github.com/kuuumo/dotfiles.git|ssh://git@github.com/kuuumo/dotfiles|ssh://git@github.com/kuuumo/dotfiles.git) ;;
    *) fail "既存の管理元がkuuumo/dotfilesではありません: $remote_url" ;;
  esac

  current_branch="$(git -C "$source_dir" branch --show-current)"
  [[ "$current_branch" == "master" ]] || fail "管理元をmasterへ切り替えてから再実行してください。現在のブランチ: $current_branch"
  if [[ -n "$(git -C "$source_dir" status --porcelain)" ]]; then
    git -C "$source_dir" status --short
    fail "管理元に未コミットの変更があります。差分を確認してから再実行してください。"
  fi

  print "既存の管理元をGitHubのmasterに合わせます。"
  git -C "$source_dir" pull --ff-only origin master
elif [[ -e "$source_dir" ]]; then
  fail "$source_dir がGit管理元ではありません。内容を確認してから再実行してください。"
else
  chezmoi init kuuumo
fi

source_dir="$(chezmoi source-path)"
[[ -f "$source_dir/run_once_after_install_brew.sh" ]] || fail "Brewfile復元スクリプトが見つかりません: $source_dir"

print "暗号化された設定を復号できるか確認します。"
if ! chezmoi cat "$HOME/.zshrc" >/dev/null; then
  fail "1Passwordから取得した鍵で設定を復号できませんでした。既存の鍵がある場合は元に戻しました。"
fi

identity_replacement_pending=false
if [[ -n "$identity_backup_path" ]]; then
  rm -f "$identity_backup_path"
  identity_backup_path=""
fi

print
print "適用予定の変更を確認してください。"
chezmoi diff
print
print -n "この設定を適用してBrewfileのアプリを復元しますか? [y/N] "
if ! read -r answer; then
  fail "入力を読み取れませんでした。"
fi
case "$answer" in
  y|Y|yes|YES|Yes) ;;
  *)
    print "適用を中止しました。"
    exit 0
    ;;
esac

DOTFILES_SKIP_BREWFILE_RESTORE=1 chezmoi apply
source_dir="$(chezmoi source-path)"
zsh "$source_dir/run_once_after_install_brew.sh"

print "Macのセットアップが完了しました。新しいターミナルを開いてください。"
