#!/bin/bash

HHROOT="https://github.com/holzschu"

(cd "${BASH_SOURCE%/*}/Frameworks"
# ios_system
echo "Downloading ios_system.framework.zip"
curl -OL $HHROOT/iVim/releases/download/v0.1/frameworks.tar.gz
( tar xvzf frameworks.tar.gz && rm frameworks.tar.gz ) || { echo "ios_system failed to download"; exit 1; }
)

