#! /bin/bash
set -e

SOURCE_DIR=$(realpath "$(dirname "$0")")
DEFAULT_INSTALL_LOCALTION="$XDG_CONFIG_HOME/lite-xl/plugins"

cd "$SOURCE_DIR"
cp --verbose --force -t "$DEFAULT_INSTALL_LOCALTION" src/*.lua
