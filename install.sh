#!/usr/bin/env bash
#
# install.sh: put the rc files in this repository to work.
#
# Usage:
#   ./install.sh            install everything
#   ./install.sh --dry-run  show what would happen, change nothing
#   ./install.sh --no-omz   skip installing oh-my-zsh

set -eu

FILES=".bashrc .zshrc .vimrc .gdbinit"
OMZ_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

DRY_RUN=0
INSTALL_OMZ=1
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=1 ;;
        --no-omz)    INSTALL_OMZ=0 ;;
        -h|--help)    sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          echo "unknown option: $arg  (try --help)" >&2; exit 1 ;;
    esac
done

REPO_DIR="$(cd "$(dirname "$0")" && pwd -P)"
STAMP="$(date +%Y%m%d-%H%M%S)"

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "        would run: $*"
    else
        "$@"
    fi
}

install_file() {
    local src="$REPO_DIR/$1"
    local dest="$HOME/$1"

    if [ ! -e "$src" ]; then
        echo "skip      .$1  (no $1 in this repo)"
        return
    fi

    if [ -f "$dest" ] && [ ! -L "$dest" ] && cmp -s "$src" "$dest"; then
        echo "ok        .$1"
        return
    fi

    if [ -e "$dest" ] \vert{}\vert{} [ -L "$dest" ]; then
        local bak="$dest.backup-$STAMP" n=1
        while [ -e "$bak" ] \vert{}\vert{} [ -L "$bak" ]; do
            bak="$dest.backup-$STAMP-$n"; n=$((n + 1))
        done
        echo "backup    .$1  ->${bak##*/}"
        run mv "$dest" "$bak"
    fi

    echo "copy      $1  ->  ~/$1"
    run cp "$src" "$dest"
}

setup_gitconfig() {
    local src="$REPO_DIR/.gitconfig"
    local dest="$HOME/.gitconfig.rc"

    if [ ! -e "$src" ]; then
        echo "skip      gitconfig  (no gitconfig in this repo)"
        return
    fi

    if git config -f "$src" --get user.name >/dev/null 2>&1 ||
       git config -f "$src" --get user.email >/dev/null 2>&1; then
        echo "WARNING   $src has a [user] section."
        return
    fi

    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        echo "ok        .gitconfig.rc"
    else
        echo "copy      .gitconfig  ->  ~/.gitconfig.rc"
        run cp "$src" "$dest"
    fi

    if git config --global --get-all include.path 2>/dev/null | grep -qxF "$dest"; then
        echo "ok        .gitconfig.rc  (already included)"
    else
        echo "include   .gitconfig.rc  (added to ~/.gitconfig)"
        run git config --global --add include.path "$dest"
    fi
}

install_omz() {
    if ! command -v zsh >/dev/null 2>&1; then
        echo "skip      oh-my-zsh  (zsh is not installed)"
        return
    fi

    if [ -d "${ZSH:-$HOME/.oh-my-zsh}" ]; then
        echo "ok        oh-my-zsh  (already installed)"
        return
    fi

    local fetch
    if command -v curl >/dev/null 2>&1; then
        fetch="curl -fsSL"
    elif command -v wget >/dev/null 2>&1; then
        fetch="wget -qO-"
    else
        return
    fi

    echo "install   oh-my-zsh"
    if [ "$DRY_RUN" -eq 1 ]; then
        return
    fi

    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/omz-install.XXXXXX")"
    if ! $fetch "$OMZ_URL" > "$tmp"; then
        rm -f "$tmp"
        return
    fi

    KEEP_ZSHRC=yes sh "$tmp" --unattended
    rm -f "$tmp"
}

echo "Installing from $REPO_DIR"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run: nothing will be changed)"
echo

for f in $FILES; do
    install_file "$f"
done

setup_gitconfig

if [ "$INSTALL_OMZ" -eq 1 ]; then
    install_omz
fi

echo
echo "Done. Open a new terminal to load everything."
