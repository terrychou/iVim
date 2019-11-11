#!/bin/bash

IOS_SYSTEM_VER="2.4"
HHROOT="https://github.com/holzschu"

(cd "${PWD}/Frameworks"
# ios_system
echo "Downloading ios_system.framework and associated dylibs"
curl -OL $HHROOT/ios_system/releases/download/v$IOS_SYSTEM_VER/release.tar.gz
( tar -xzf release.tar.gz --strip 1 && rm release.tar.gz ) || { echo "ios_system failed to download"; exit 1; }
)
echo "Downloading header file:"
curl -OL $HHROOT/ios_system/releases/download/v$IOS_SYSTEM_VER/ios_error.h 
# We need the sources for Python and Lua, for the headers
# Do not do this is python3_ios and lua_ios are already present
# included by if_lua and if_python.
( # Python_ios
cd "${PWD}/.."
git clone https://github.com/holzschu/python3_ios
cd "python3_ios"
sh ./getPackages.sh
)
( # lua_ios 
cd "${PWD}/.."
git clone https://github.com/holzschu/lua_ios
cd "lua_ios"
sh ./get_lua_source.sh
)
echo "All done. Now open iVim.xcodeproj, enter your Apple ID, and compile"
