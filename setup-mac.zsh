#!/usr/bin/env zsh

set -euo pipefail

readonly homebrew_install_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
readonly default_age_identity="$HOME/.chezmoi-encrypt-key.txt"
readonly default_age_recipient="age1yd7l6ys8ads6tgradk06un7sg3aye80lufqjkcua6zhqftlh2scqlrvh0d"

fail() {
  print -u2 -- "エラー: $*"
  exit 1
}

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

if [[ ! -r "$default_age_identity" ]]; then
  fail "age秘密鍵を $default_age_identity に戻してから再実行してください。"
fi
chmod 600 "$default_age_identity"

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
chezmoi cat "$HOME/.zshrc" >/dev/null

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
