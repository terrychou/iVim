//
//  ctags_ios.m
//  ctagsios
//
//  Created by Terry on 9/14/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <setjmp.h>

static jmp_buf _ctags_j_buf;
static int _ctags_offset = 1;
static const char * _stdout_fn = NULL;
static const char * _stderr_fn = NULL;
FILE * ctags_stdout;
FILE * ctags_stderr;

extern void ctags_exit(int ret) {
    longjmp(_ctags_j_buf, ret + _ctags_offset);
}

extern int ctags_vprintf(const char * restrict format, va_list ap) {
    FILE * fp = ctags_stdout;
    if (fp == NULL) {
        return -1;
    }
    
    return vfprintf(fp, format, ap);
}

extern int ctags_printf(const char * restrict format, ...) {
    va_list ap;
    va_start(ap, format);
    int ret = ctags_vprintf(format, ap);
    va_end(ap);
    
    return ret;
}

extern int ctags_puts(const char * s) {
    if (ctags_stdout == NULL) {
        return -1;
    }
    int ret = fputs(s, ctags_stdout);
    fputc('\n', ctags_stdout);
    
    return ret;
}

extern int ctags_putchar(int c) {
    if (ctags_stdout == NULL) {
        return -1;
    }
    
    return fputc(c, ctags_stdout);
}

extern const char * ctags_tmpdir(void) {
    return [NSTemporaryDirectory() UTF8String];
}

extern char * ctags_overlap_strcpy(char * dst, char * src) {
    char * tmp = (char *)malloc((size_t)(strlen(src) + 1) * sizeof(char));
    strcpy(tmp, src);
    strcpy(dst, tmp);
    free(tmp);
    
    return dst;
}

static char * tmpfile_with_name(const char * name) {
    char * template = (char *)[[NSString stringWithFormat:@"%@%s.XXXXXX",
                                NSTemporaryDirectory(), name] UTF8String];
    return mktemp(template);
}

static const char * assign_ctags_stream(FILE ** stream, const char * tmp_name) {
    char * tmpf = tmpfile_with_name(tmp_name);
    *stream = fopen(tmpf, "a+");
    
    return tmpf;
}

static NSString * get_contents_of_file(const char * path, FILE ** fp) {
    NSString * file = [NSString stringWithUTF8String:path];
    fflush(*fp);
    NSString * contents = [[NSString alloc]
                           initWithContentsOfFile:file
                           encoding:NSUTF8StringEncoding error:NULL];
    fclose(*fp);
    *fp = NULL;
    [[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
    
    return contents;
}

extern NSArray * call_ctags(int argc, char ** argv) {
    int j_ret = setjmp(_ctags_j_buf);
    if (!j_ret) {
        _stdout_fn = assign_ctags_stream(&ctags_stdout, "ctags_stdout");
        _stderr_fn = assign_ctags_stream(&ctags_stderr, "ctags_stderr");
        ctags_main(argc, argv);
    } else {
        ctags_clean_up();
//        printf("ctags main done.\n");
    }
    NSString * stdout_contents = get_contents_of_file(_stdout_fn, &ctags_stdout);
    NSString * stderr_contents = get_contents_of_file(_stderr_fn, &ctags_stderr);
    _stdout_fn = NULL;
    _stderr_fn = NULL;
    NSArray * result = [NSArray arrayWithObjects:
                        stdout_contents,
                        stderr_contents,
                        nil];
    
    return result;
}
