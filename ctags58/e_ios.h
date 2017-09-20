//
//  e_ios.h
//  ctagsios
//
//  Created by Terry on 9/12/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

#ifndef e_ios_h
#define e_ios_h

#define STDC_HEADERS 1
#define HAVE_CLOCK 1
#define INTERNAL_SORT 1
#define HAVE_STDLIB_H 1
#define HAVE_FCNTL_H 1
#define HAVE_UNISTD_H 1
#define HAVE_FGETPOS 1
#define HAVE_SYS_STAT_H 1
#define HAVE_STRNCASECMP 1
#define HAVE_SETENV 1
#define HAVE_OPENDIR 1
#define TMPDIR ctags_tmpdir()
#define HAVE_REGEX 1
#define HAVE_REGCOMP 1
#define HAVE_FNMATCH 1
#define HAVE_MKSTEMP 1
#define HAVE_STRERROR 1

#ifdef IOS_FUNCTION

#define IOSEXIT ctags_exit
#define CTAGSSTDOUT ctags_stdout
#define CTAGSSTDERR ctags_stderr
#define CTAGSPRINTF ctags_printf
#define CTAGSVPRINTF ctags_vprintf
#define CTAGSPUTS ctags_puts
#define CTAGSPUTCHAR ctags_putchar

#else

#define IOSEXIT exit
#define CTAGSSTDOUT stdout
#define CTAGSSTDERR stderr
#define CTAGSPRINTF printf
#define CTAGSVPRINTF vprintf
#define CTAGSPUTS puts
#define CTAGSPUTCHAR putchar

#endif

#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <strings.h>
#ifdef HAVE_OPENDIR
#include <dirent.h>
#endif
#ifdef HAVE_FNMATCH
#include <fnmatch.h>
#endif

extern FILE * ctags_stdout;
extern FILE * ctags_stderr;
extern void ctags_exit(int);
extern int ctags_vprintf(const char * restrict, va_list);
extern int ctags_printf(const char * restrict, ...);
extern int ctags_puts(const char *);
extern int ctags_putchar(int);
extern const char * ctags_tmpdir(void);

#endif /* e_ios_h */
