#!/bin/bash

IOS_SYSTEM_VER="1.0"
HHROOT="https://github.com/holzschu"

(cd "${BASH_SOURCE%/*}/Frameworks"
# ios_system
echo "Downloading ios_system.framework and associated dylibs"
curl -OL $HHROOT/ios_system/releases/download/v$IOS_SYSTEM_VER/release.tar.gz
( tar -xzf ios_system.framework.tar.gz && rm ios_system.framework.tar.gz && mv release/* . ) || { echo "ios_system failed to download"; exit 1; }
)

# We need the sources for Python and Lua, for the headers
# included by if_lua and if_python.
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
echo "All done. Now open iVim.xcodeproj, enter your Apple ID, and compile"
