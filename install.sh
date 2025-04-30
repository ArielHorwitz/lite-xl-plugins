#! /bin/bash
set -e

SOURCE_DIR=$(realpath "$(dirname "$0")")
DEFAULT_INSTALL_LOCALTION="$XDG_CONFIG_HOME/lite-xl/plugins"

cp --verbose --force "$SOURCE_DIR/bookmarks.lua" "$DEFAULT_INSTALL_LOCALTION"
