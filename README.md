# iVim

iVim is a project that brings the vim editor to the iOS system.

Type `:help ios` in iVim for more detailed information.

## Features

### Font management

Besides some system and embedded monospace fonts, iVim allows users to import and use their own custom fonts.
Also, iVim provides commands for more intuitive and efficient font management.

### Extended keyboard

By introducing compact buttons, iVim covers as many keys as possible in its extended keyboard, so that users can input symbols without switching among key groups.

### Multistage language input

iVim adds support to multistage input languages such as Chinese or Japanese. 

### Sharing

Through sharing, iVim makes its editing power available to more apps.
Via the share extension, iVim can import text or text files from, or export to other apps.
Via the document picker, users can also import or edit text files in iCloud Drive or documents providers, without leaving iVim.


## How to install it

### App Store
iVim is now on [App Store](https://itunes.apple.com/us/app/ivim/id1266544660?mt=8)

### Source code
To download iVim and the associated frameworks, after you've cloned it, type:
```bash
 ./get_frameworks.sh
``` 
This will download precompiled frameworks for `ios_system` (including Python and Lua) and TeX. Then, compile: 

1. Open iVim.xcodeproj in Xcode
2. In General > Identity of target iVim and iVimShare, change their bundle identities to your own unique ones, and select your Apple ID to sign them. As to the App Group, it requires a paid Apple ID. If yours is, change the App Group identifier for these two targets to your own; if not, just turn them off (the only difference is that you cannot share text to iVim when it is off)
3. Connect your device via USB to your computer, and select it as the Destination of iVim
4. Run iVim, Xcode will install it onto your device
5. A free Apple ID may need to do this every 7 days

### Modifications

This is a fork of https://github.com/terrychou/iVim
The modification is that you *can* call shell commands (a first for iOS). 

There are many limitations, obviously. The main one is that shell commands can only act (read files, create files, etc) inside iVim sandbox. The other is that you need to redirect the output: "!ls" produces nothing, "!ls > result" does. Commands sent by iVim plugins do this naturally, but it also applies to commands you write yourself.

There is only a small number of shell commands available. They come from the [ios_system](https://github.com/holzschu/ios_system) package, which you will have to download separately. 

The most useful commands are: 
- rmdir (not available otherwise), 
- grep (to operate on log files), 
- gzip/gunzip, which lets you edit gzipped files directly. 
- curl, for editing remote files (try `:e sftp://name@host/~/config` )

Additional commands are available from my ports of [python](https://github.com/holzschu/python_ios), [lua](https://github.com/holzschu/lua_ios) and [TeX](https://github.com/holzschu/lib-tex). These only provide the commands. You will need to download the auxiliary files (python modules, TeX formats and style files) yourself, inside iVim file system.

## Giants' shoulders

iVim was inspired by and based on 3 projects:
1. [vim - the official Vim repository](https://github.com/vim/vim)
2. [Vim port from Applidium](https://github.com/applidium/Vim)
3. [VimIOS - A port of Vim to iOS 9+](https://github.com/larki/VimIOS)

Without them, iVim wouldn't begin.

Also, without violating the copyright of Vim, feel free to make modifications to meet your own needs.
