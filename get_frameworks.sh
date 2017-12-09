#!/bin/bash

HHROOT="https://github.com/holzschu"

(cd "${BASH_SOURCE%/*}/Frameworks"
# ios_system
echo "Downloading frameworks"
curl -OL $HHROOT/iVim/releases/download/v0.1/frameworks.tar.gz
( tar xvzf frameworks.tar.gz && rm frameworks.tar.gz ) || { echo "ios_system failed to download"; exit 1; }
)

# Optional: get also sources for Python and Lua:
( # Python_ios
cd "${BASH_SOURCE%/*}/.."
git clone https://github.com/holzschu/python_ios
cd "python_ios"
sh ./getPackages.sh
)
( # lua_ios 
cd "${BASH_SOURCE%/*}/.."
git clone https://github.com/holzschu/lua_ios
cd "lua_ios"
sh ./get_lua_source.sh
)

