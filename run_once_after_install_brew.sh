#!/usr/bin/env zsh

set -euo pipefail

# 初回適用時にHomebrewがPATHにない場合は、標準の配置先からPATHを設定します。
if ! command -v brew >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

if ! command -v brew >/dev/null 2>&1; then
  print -u2 "Homebrewが見つかりません。先にHomebrewをインストールしてください。"
  exit 1
fi

brewfile="$HOME/.config/brewfile/Brewfile"
if [[ ! -f "$brewfile" ]]; then
  print -u2 "Brewfileが見つかりません: $brewfile"
  exit 1
fi

# 管理元のBrewfileはbrew-file形式なので、先にbrew-fileをインストールします。
brew install rcmdnk/file/brew-file

# 先にHomebrewのパッケージを入れ、masを使える状態にしてからApp Storeアプリを入れます。
brew-file install --file "$brewfile" --no-repo --appstore 0 --yes
brew-file install --file "$brewfile" --no-repo --appstore 1 --yes
