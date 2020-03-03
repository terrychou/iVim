//
//  ios_prefix.h
//  iVim
//
//  Created by Terry on 7/21/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

#ifndef ios_prefix_h
#define ios_prefix_h

#import <Availability.h>
#import <TargetConditionals.h>

#define OK 1
#define IVIM 1
#define HAVE_DIRENT_H 1
#define HAVE_STDARG_H 1
#define HAVE_OPENDIR 1
//#define MACOS_X_UNIX 1
#define MACOS_X_DARWIN 1
#define HAVE_ISNAN 1
#define HAVE_ISINF 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_SYS_TIME_H 1
#define ALWAYS_USE_GUI 1
#define FEAT_GUI 1
#define FEAT_GUI_SCROLL_WHEEL_FORCE 1
#define FEAT_GUI_IOS 1
#define FEAT_BROWSE
#define FEAT_JOB_CHANNEL 1
#define FEAT_TERMINAL 1
#define FEAT_TERMGUICOLORS 1
#define HAVE_SYS_POLL_H 1
#define TARGET_OS_IPHONE 1
#define FEAT_LUA 1
#define DYNAMIC_LUA "yes"
#define DYNAMIC_LUA_DLL "lua_ios.framework/lua_ios"
#define FEAT_PYTHON3 1
#define DYNAMIC_PYTHON3 1
#define DYNAMIC_PYTHON3_DLL "pythonB.framework/pythonB"
#define MODIFIED_BY "Boogaloo"

// for libvterm to display emoji correctly (vim: 6d0826d)
#define INLINE ""
#define VSNPRTINTF vim_vsnprintf
#define IS_COMBINING_FUNCTION utf_iscomposing_uint
#define WCWIDTH_FUNCTION utf_uint2cells
#define _CRT_SECURE_NO_WARNINGS 1

int VimMain(int argc, char *argv[]);

#define IOS 1
#define IOS_FUNCTION 1

extern int ctags_main(int, char **);
extern void ctags_clean_up(void);

#endif /* ios_prefix_h */
