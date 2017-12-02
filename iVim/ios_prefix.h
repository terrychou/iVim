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
#define MACOS_X_UNIX 1
#define ALWAYS_USE_GUI 1
#define FEAT_GUI 1
#define FEAT_GUI_SCROLL_WHEEL_FORCE 1
#define FEAT_GUI_IOS 1
#define FEAT_BROWSE
#define TARGET_OS_IPHONE 1
#define MODIFIED_BY "Boogaloo"

int VimMain(int argc, char *argv[]);

#define IOS 1
#define IOS_FUNCTION 1

extern int ctags_main(int, char **);
extern void ctags_clean_up(void);

#endif /* ios_prefix_h */
