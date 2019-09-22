//
//  scenes_keeper.m
//  iVim
//
//  Created by Terry Chou on 4/23/19.
//  Copyright © 2019 Boogaloo. All rights reserved.
//

#import "vim.h"
#import "iVim-Swift.h"
#import <Foundation/Foundation.h>

#define TONSSTRING(chars) [[NSString alloc] initWithUTF8String:(const char *)(chars)]
#define TOCHARS(str) (char_u *)[(str) UTF8String]


/*
 * create directory at path if not exist yet
 */
static NSString *create_dir_at(NSString *path) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path
      withIntermediateDirectories:YES
                       attributes:NULL
                            error:NULL];
    }
    
    return path;
}

static NSString *subpath_under(NSString *name, NSString *parent_dir) {
    return [parent_dir stringByAppendingPathComponent:name];
}

static NSString *create_subdir(NSString *name, NSString *parent_dir) {
    return create_dir_at(subpath_under(name, parent_dir));
}

static BOOL is_path_under(NSString *path, NSString *parent_dir) {
    return [path hasPrefix:parent_dir];
}

/*
 * get full path of given path
 */

NSString *ivim_full_path(NSString *path) {
    char_u buf[MAXPATHL];
    if (vim_FullName(TOCHARS(path), buf, MAXPATHL, TRUE) == FAIL) {
        return path;
    }
    
    return TONSSTRING(buf);
}

/*
 * path of application prefix
 */
static NSString *app_dir(void) {
    static NSString *dir;
    if (!dir) {
        // need the "/." part, otherwise cannot fully expand it
        NSString *path = [NSString stringWithFormat:@"%@/.",
                          NSHomeDirectory()];
        dir = ivim_full_path(path);
//        NSLog(@"app dir: %@", dir);
    }
    
    return dir;
}

/*
 * path of root directory of all scenes related files
 */
static NSString *scenes_dir(void) {
    static NSString *dir;
    if (!dir) {
        dir = create_subdir(@"scenes", [NSFileManager safeTmpDir]);
    }
    
    return dir;
}

static char_u *path_relative_to_app(char_u *ffname) {
    return shorten_fname(ffname, TOCHARS(app_dir()));
}

static NSString *full_path_to_app(NSString *path) {
    return [app_dir() stringByAppendingPathComponent:path];
}

/*
 * path for temp scene files subdirectory
 *
 * temp scene files are those made temporarily
 * for buffers without associated files
 */
static NSString *temp_scenes_dir(void) {
    static NSString *dir;
    if (!dir) {
        dir = create_subdir(@"temp", scenes_dir());
    }
    
    return dir;
}

/*
 * path for buffer scene files subdirectory
 *
 * buffer scene files are those
 * for edited buffers with associated files
 */
static NSString *buffer_scenes_dir(void) {
    static NSString *dir;
    if (!dir) {
        dir = create_subdir(@"buffer", scenes_dir());
    }
    
    return dir;
}

/*
 * clean a directory at path
 *
 * an empty directory will be created
 */
static void clean_dir(NSString *path) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *oldCwd = [fm currentDirectoryPath];
    [fm removeItemAtPath:path error:NULL];
    [fm createDirectoryAtPath:path
  withIntermediateDirectories:YES
                   attributes:NULL
                        error:NULL];
    [fm changeCurrentDirectoryPath:oldCwd];
}

/*
 * get path of the session file
 * scenes_dir/session.vim
 */
static NSString *session_file_path(void) {
    static NSString *path;
    if (!path) {
        path = subpath_under(@"session.vim", scenes_dir());
    }
    
    return path;
}

/*
 * last application prefix file path
 *
 * it records the application prefix of last time using
 */
static NSString *last_app_prefix_file_path(void) {
    static NSString *path;
    if (!path) {
        path = subpath_under(@"lastapppre", scenes_dir());
    }
    
    return path;
}

/*
 * swap files list path
 *
 * this file will record all the swap file's full path
 * one path per line
 */
static NSString *swap_file_list_path(void) {
    static NSString *path;
    if (!path) {
        path = subpath_under(@"swapfiles", scenes_dir());
    }

    return path;
}

/*
 * buffer associated files list path
 *
 * this file record mappings between original files
 * and backup buffer files
 *
 * format:
 * buffer file name
 * original file path relative to Documents
 */
static NSString *buffer_mapping_list_path(void) {
    static NSString *path;
    if (!path) {
        path = subpath_under(@"mappings", buffer_scenes_dir());
    }
    
    return path;
}

/*
 * mirrored files list path
 *
 * this file records all buffered mirror paths
 * used to recover pickinfos for mirrors in
 * auto-restore prepare
 */

static NSString *mirrored_files_list_path(void) {
    static NSString *path;
    if (!path) {
        path = subpath_under(@"mirroredfiles", scenes_dir());
    }
    
    return path;
}

/*
 * generate file name for scene caches
 * according to the buffer's number
 */
static NSString *filename_for(buf_T *buf) {
    return [NSString stringWithFormat:@"%d", buf->b_fnum];
}

static int write_buf(buf_T *buf, NSString *to_path) {
    msg_silent++;
    int ret = buf_write(buf, TOCHARS(to_path), NULL,
                        (linenr_T)1, buf->b_ml.ml_line_count,
                        NULL, FALSE, TRUE, FALSE, FALSE);
    msg_silent--;
    
    return ret;
}

/*
 * whether do auto restore or not
 */
static NSString *kUDAutoRestoreEnable = @"kUDAutoRestoreEnable";
static BOOL should_auto_restore(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kUDAutoRestoreEnable];
}

void register_auto_restore_enabled(void) {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{kUDAutoRestoreEnable: @YES}];
}

/*
 * cache buffer without associated file
 */
static int cache_temp_buffer(buf_T *buf) {
    char_u *fname = buf->b_fname;
    char_u *sfname = buf->b_sfname;
    if (!fname) {
        NSString *uuid = [[NSUUID UUID] UUIDString];
        NSString *new_path = subpath_under(uuid, temp_scenes_dir());
        fname = TOCHARS(new_path);
        sfname = TOCHARS(new_path);
    }
    
    msg_silent++;
    int ret = buf_write(buf, fname, sfname,
                        (linenr_T)1, buf->b_ml.ml_line_count,
                        NULL, FALSE, TRUE, TRUE, FALSE);
    msg_silent--;
    
    return ret;
}

/*
 * cache buffer with associated file
 *
 * add entries to buffer scene files list
 */
static void cache_associated_buffer(buf_T *buf, FILE *fp) {
    NSString *bname = filename_for(buf);
    NSString *bpath = subpath_under(bname, buffer_scenes_dir());
    if (!write_buf(buf, bpath)) {
        NSLog(@"failed to write buffer to %@", bpath);
        return;
    }
    // record it into mapping file
    fputs([bname UTF8String], fp);
    fputc('\n', fp);
    fputs((char *)path_relative_to_app(buf->b_ffname), fp);
    fputc('\n', fp);
}

/*
 * cache buffer to the scenes directory
 */
static void cache_buffer(buf_T *buf, FILE *buffer_list) {
    if (!buf->b_ffname ||
        is_path_under(TONSSTRING(buf->b_ffname), temp_scenes_dir())) {
        cache_temp_buffer(buf);
    } else {
        cache_associated_buffer(buf, buffer_list);
    }
}

/*
 * last application prefix
 *
 * need to record the application prefix of last using
 * store it in file scenes_dir/lastapppre
 */
static void record_content_to(NSString *content,
                              NSString *path,
                              NSString *name) {
    NSError *err;
    if (![content writeToFile:path
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:&err]) {
        NSLog(@"failed to record %@: %@", name, [err localizedDescription]);
    }
}

static NSString *content_of_record_at_path(NSString *path) {
    return [NSString stringWithContentsOfFile:path
                                     encoding:NSUTF8StringEncoding
                                        error:NULL];
}

static void record_last_app_prefix(void) {
    record_content_to(app_dir(),
                      last_app_prefix_file_path(),
                      @"last app prefix");
}

static NSString *last_app_prefix(void) {
    return content_of_record_at_path(last_app_prefix_file_path());
}

/*
 * helper function for correcting absolute paths in files
 *
 * absolute file paths may change due to
 * application re-installation, the old ones need correcting to
 * current application prefix to make session restoration work
 * properly
 */
static NSString *uuid_regex = @"[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}";

static NSUInteger replace_occurrences_in(NSMutableString *content,
                                         NSString *regex,
                                         NSString *replacement) {
    return [content replaceOccurrencesOfString:regex
                                    withString:replacement
                                       options:NSRegularExpressionSearch
                                         range:NSMakeRange(0, [content length])];
}

static NSString *regex_for_old(NSString *old) {
    NSMutableString *regex = [NSMutableString stringWithString:old];
    replace_occurrences_in(regex, uuid_regex, uuid_regex);
    
    return regex;
}

typedef NSUInteger (^AbsolutePathsCorrector)(NSMutableString *);
typedef void (^CorrectTask)(AbsolutePathsCorrector);

static void correct_absolute_paths_with(CorrectTask task) {
    NSString *lap = last_app_prefix();
    if (!lap) {
        return;
    }
    NSString *cap = app_dir();
    if ([lap isEqualToString:cap]) { // application prefix did not change
        return;
    }
    NSString *app_data_regex = regex_for_old(lap);
    NSString *crp = TONSSTRING(mch_getenv("VIMRUNTIME"));
    NSString *runtime_regex = regex_for_old(crp);
    AbsolutePathsCorrector corrector = ^(NSMutableString *content){
        // corrent possible application data paths
        NSUInteger ret = replace_occurrences_in(content,
                                                app_data_regex,
                                                cap);
        // correct possible runtime paths
        ret += replace_occurrences_in(content,
                                      runtime_regex,
                                      crp);
        return ret;
    };
    task(corrector);
}

static void correct_absolute_paths_in_file(NSString *(*path_block)(void)) {
    correct_absolute_paths_with(^(AbsolutePathsCorrector corrector) {
        NSError *err;
        NSString *path = path_block();
        if (!path) {
            return;
        }
        NSMutableString *content = [NSMutableString
                                    stringWithContentsOfFile:path
                                    encoding:NSUTF8StringEncoding
                                    error:&err];
        if (!content) {
            NSLog(@"failed to read file: %@", [err localizedDescription]);
            return;
        }
        NSUInteger replaced = corrector(content);
        NSLog(@"%lu paths corrected in file %@", (unsigned long)replaced, path);
        if (replaced > 0 && ![content writeToFile:path
                                       atomically:YES
                                         encoding:NSUTF8StringEncoding
                                            error:&err]) {
            NSLog(@"failed to write file: %@", [err localizedDescription]);
        }
    });
}

/*
 * handle viminfo file
 */

/*
 * path of viminfo file
 *
 * could be nil
 */
static char_u *full_viminfo_path(void) {
    char_u *path = NULL;
    if (use_viminfo != NULL) {
        path = use_viminfo;
    } else if ((path = find_viminfo_parameter('n')) == NULL ||
               *path == NUL) {
        path = (char_u *)VIMINFO_FILE;
    }
    expand_env(path, NameBuff, MAXPATHL);
    path = NameBuff;
    char_u buf[MAXPATHL];
    if (vim_FullName(path, buf, MAXPATHL, TRUE) != FAIL) {
        path = buf;
    }
    
    return vim_strsave(path);
}

/*
 * path of file recording last viminfo path
 */
static NSString *last_viminfo_path_file_path(void) {
    static NSString *path;
    if (!path) {
        path = subpath_under(@"lastviminfopath", scenes_dir());
    }
    
    return path;
}

/*
 * record last viminfo file path
 */
static void record_last_viminfo_path(void) {
    char_u *vpath = full_viminfo_path();
    char_u *rpath = path_relative_to_app(vpath);
    if (!rpath) {
        return;
    }
    record_content_to(TONSSTRING(rpath),
                      last_viminfo_path_file_path(),
                      @"last viminfo path");
    vim_free(vpath);
}

/*
 * last viminfo path
 */
static NSString *last_viminfo_path(void) {
    NSString *path = content_of_record_at_path(last_viminfo_path_file_path());
    if (!path) {
        return nil;
    } else {
        return full_path_to_app(path);
    }
}

/*
 * correct the viminfo file
 */
static const char *correct_line(const char *line,
                                AbsolutePathsCorrector ctr,
                                NSUInteger *replaced) {
    NSMutableString *content = [NSMutableString stringWithUTF8String:line];
    *replaced += ctr(content);
    
    return [content UTF8String];
}

static void correct_viminfo(void) {
    correct_absolute_paths_with(^(AbsolutePathsCorrector corrector) {
        NSString *opath = last_viminfo_path();
        if (!opath) {
            return;
        }
        FILE *op = NULL;
        FILE *tp = NULL;
        if ((op = fopen([opath UTF8String], "r")) == NULL) {
            NSLog(@"failed to open viminfo file %@", opath);
            return;
        }
        NSString *tpath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        if ((tp = fopen([tpath UTF8String], "w")) == NULL) {
            NSLog(@"failed to create temp viminfo file %@", tpath);
            fclose(op);
            return;
        }
        size_t len;
        NSUInteger replaced = 0;
        char *line = fgetln(op, &len);
        const char *result = NULL;
        BOOL decide_category = NO;
        BOOL do_correct = NO;
        while (len > 0) {
            char str[len + 1];
            strncpy(str, line, len);
            str[len] = NUL;
            if (str[0] == '\n') { // empty line
                result = str;
            } else {
                if (decide_category) {
                    switch (str[0]) {
                        case '-': // jumplist
                        case '\'': // file mark
                        case '>': // history of mark
                        case '%': // buffer list
                            do_correct = YES;
//                            NSLog(@"should do correction.");
                            break;
                    }
                    decide_category = NO;
                }
                if (str[0] == '#') { // enter another category
                    do_correct = NO;
                    decide_category = YES;
//                    NSLog(@"enter category %s", str);
                }
                if (do_correct) {
                    result = correct_line(str, corrector, &replaced);
//                    NSLog(@"\"%s\" -> \"%s\"", str, result);
                } else {
                    result = str;
                }
            }
            // write to temp
            // result contains newline if there is
            fputs(result, tp);
            // read next line
            line = fgetln(op, &len);
        }
        fclose(op);
        fclose(tp);
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *err;
        if (replaced > 0) {
            if ([fm removeItemAtPath:opath error:&err]) {
                if ([fm moveItemAtPath:tpath toPath:opath error:&err]) {
                    NSLog(@"%lu paths corrected in viminfo", (unsigned long)replaced);
                } else {
                    NSLog(@"failed to replace original viminfo file: %@",
                          [err localizedDescription]);
                }
            } else {
                NSLog(@"failed to remove original viminfo file: %@",
                      [err localizedDescription]);
            }
        } else {
            if (![fm removeItemAtPath:tpath error:&err]) {
                NSLog(@"failed to remove temp viminfo file: %@",
                      [err localizedDescription]);
            }
        }
    });
}

/*
 * do the stashing according to each existing buffer
 *
 * it still collects swap file paths even when restore is
 * disabled.
 */
void scenes_keeper_stash(void) {
    BOOL should_restore = should_auto_restore();
    if (should_restore) {
        clean_dir(buffer_scenes_dir());
    }
    buf_T *buf;
    char_u fspath[MAXPATHL];
    char_u *spath;
    FILE *slp;
    FILE *bmlp = NULL;
    FILE *mflp = NULL;
    NSMutableArray<NSValue *> *changed_bufs = nil;
    NSString *mirrorDir = nil;
    if ((slp = fopen([swap_file_list_path() UTF8String], "w")) == NULL) {
        NSLog(@"failed to create swap file list");
        return;
    }
    if (should_restore) {
        if ((bmlp = fopen([buffer_mapping_list_path() UTF8String], "w")) == NULL) {
            NSLog(@"failed to create buffer mapping list");
            fclose(slp);
            return;
        }
        if ((mflp = fopen([mirrored_files_list_path() UTF8String], "w")) == NULL) {
            NSLog(@"failed to create mirrored files list");
            fclose(slp);
            fclose(bmlp);
            return;
        }
        changed_bufs = [NSMutableArray array];
        mirrorDir = [[[NSFileManager defaultManager] mirrorDirectoryURL] path];
    }
    
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
        // record swap file paths
        if (buf->b_ml.ml_mfp && buf->b_ml.ml_mfp->mf_fname) {
            spath = buf->b_ml.ml_mfp->mf_fname;
            if (!mch_isFullName(spath) &&
                mch_FullName(spath, fspath, MAXPATHL, FALSE) == OK) {
                spath = fspath;
            }
            fputs((char *)path_relative_to_app(spath), slp);
            fputc('\n', slp);
        }
        if (!should_restore) {
            continue;
        }
        // record mirrored file paths
        if (buf->b_ffname && is_path_under(TONSSTRING(buf->b_ffname), mirrorDir)) {
            fputs((char *)path_relative_to_app(buf->b_ffname), mflp);
            fputc('\n', mflp);
        }
        if (buf->b_ffname && mch_isdir(buf->b_ffname)) { // for dir
            if (buf->b_nwindows > 0) {
                // NSLog(@"ddir %d %d", buf->b_p_bl, buf->b_p_swf);
                if (!buf->b_p_bl) {
                    buf->b_p_bl = TRUE;
                    [changed_bufs addObject:[NSValue valueWithPointer:buf]];
                }
            }
        } else if (buf->b_p_bl && buf->b_changed) { // for file
            cache_buffer(buf, bmlp);
        } else if (buf->b_help) { // disable swap file for help buffer
            buf->b_p_swf = FALSE;
        }
    }
    fclose(slp);
    record_last_app_prefix();
    // write viminfo file
    // because iVim rarely has "exit", need to do it manually here
    record_last_viminfo_path();
    do_cmdline_cmd((char_u *)"wviminfo");
    
    if (!should_restore) {
        return;
    }
    fclose(bmlp);
    fclose(mflp);
    // make session
    NSString *cmd = [NSString stringWithFormat:@"mksession! %@",
                     session_file_path()];
    do_cmdline_cmd(TOCHARS(cmd));
    
    // restore changed dir buffers
    for (NSValue *v in changed_bufs) {
        buf = (buf_T *)[v pointerValue];
        buf->b_p_bl = FALSE;
    }
}

/*
 * a general function to deal with files list file
 *
 * a files list file has the following format
 * - each line is a file path, with its app_dir prefix cut
 *
 * it takes the list file *path*, and a *handler* function
 */
static void enumerate_files_list(NSString *path, void (*handler)(NSString *fpath)) {
    FILE *fp;
    if ((fp = fopen([path UTF8String], "r")) == NULL) {
        NSLog(@"failed to open file %@", path);
        return;
    }
    char *apath;
    size_t length;
    NSString *nsapath;
    while ((apath = fgetln(fp, &length))) {
        // this works only when each line ends with a \n
        apath = strtok(apath, "\n");
        nsapath = TONSSTRING(apath);
        nsapath = full_path_to_app(nsapath);
        handler(nsapath);
    }
    fclose(fp);
}

/*
 * remove all recorded swap files
 */
static void remove_swap_file_handler(NSString *path) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        [fm removeItemAtPath:path error:NULL];
    }
}

static void remove_swap_files(void) {
    enumerate_files_list(swap_file_list_path(), remove_swap_file_handler);
}

static NSDate *last_modification_date(NSString *path) {
    return [[[NSFileManager defaultManager]
             attributesOfItemAtPath:path
             error:NULL] objectForKey:NSFileModificationDate];
}

static BOOL is_newer_than(NSString *p1, NSString *p2) {
    // p1 is later than p2
    return [last_modification_date(p1)
            compare:last_modification_date(p2)] == NSOrderedDescending;
}

static void enumerate_buffer_mappings(void (*task)(NSString *bpath, NSString *opath)) {
    NSString *bmpath = buffer_mapping_list_path();
    FILE *fp;
    if ((fp = fopen([bmpath UTF8String], "r")) == NULL) {
        NSLog(@"failed to open buffer mapping file.");
        return;
    }
    char *bpath, *opath;
    size_t len;
    NSString *nsbpath, *nsopath;
    while ((bpath = fgetln(fp, &len))) {
        bpath = strtok(bpath, "\n");
        nsbpath = TONSSTRING(bpath);
        nsbpath = [buffer_scenes_dir() stringByAppendingPathComponent:nsbpath];
        opath = fgetln(fp, &len);
        if (!opath) { // something wrong with the mapping list
            break;
        }
        opath = strtok(opath, "\n");
        nsopath = TONSSTRING(opath);
        nsopath = full_path_to_app(nsopath);
        task(nsbpath, nsopath);
    }
    fclose(fp);
}

/*
 * correct file paths in session files
 */
static void correct_session_file(void) {
    correct_absolute_paths_in_file(session_file_path);
}

/*
 * copy attributes with given keys from one file to another
 */
static void copy_attrs(NSArray<NSFileAttributeKey> *keys, NSString *from_path, NSString *to_path) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err;
    NSDictionary<NSFileAttributeKey, id> *attrs = [fm attributesOfItemAtPath:from_path
                                                                       error:&err];
    if (!attrs) {
        NSLog(@"failed to get attributes from %@: %@",
              from_path, [err localizedDescription]);
        return;
    }
    NSMutableDictionary<NSFileAttributeKey, id> *copied = [NSMutableDictionary dictionary];
    for (NSFileAttributeKey key in keys) {
        copied[key] = attrs[key];
    }
    if (![fm setAttributes:copied
              ofItemAtPath:to_path
                     error:&err]) {
        NSLog(@"failed to set attributes to %@: %@",
              to_path, [err localizedDescription]);
    }
}

/*
 * prepare work before session restore
 *
 * 1. restore possible pickinfos
 *
 * 2. temporarily overwrite the file with its backup except when:
 * the original file is newer than the backup one, which means
 * the original file may be edited at other places
 *
 */
static void restore_pickinfo_handler(NSString *path) {
    [[PickInfoManager shared] addPickInfoAt:path update:YES];
}

static void restore_pickinfos(void) {
    enumerate_files_list(mirrored_files_list_path(), restore_pickinfo_handler);
}

static void temporarily_sub(NSString *bpath, NSString *opath) {
    if (is_newer_than(opath, bpath)) {
        return;
    }
    NSLog(@"sub file %@", opath);
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *temp = [NSString stringWithFormat:@"%@.ori", bpath];
    NSError *err;
    // copy modification time to silent
    // wierd "changed since reading it!" warning
    copy_attrs(@[NSFileModificationDate], opath, bpath);
    if ([fm moveItemAtPath:opath toPath:temp error:&err]) {
        if (![fm moveItemAtPath:bpath toPath:opath error:&err]) {
            NSLog(@"failed to move %@ to %@: %@",
                  bpath, opath, [err localizedDescription]);
        }
    } else {
        NSLog(@"failed to move %@ to %@: %@",
              opath, temp, [err localizedDescription]);
    }
        
}

void scenes_keeper_restore_prepare(void) {
    remove_swap_files();
    correct_viminfo();
    if (should_auto_restore()) {
        correct_session_file();
        restore_pickinfos();
        enumerate_buffer_mappings(temporarily_sub);
    }
}

/*
 * mark buffer associated with path as *changed*
 */
static void mark_path_changed(NSString *path) {
    buf_T *buf;
    char_u *p = TOCHARS(path);
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
        if (buf->b_ffname && STRCMP(buf->b_ffname, p) == 0) {
            buf->b_changed = TRUE;
            ml_setname(buf);
            break;
        }
    }
}

/*
 * post work after session restore
 *
 * exchange back the original files
 */
static void restore_origin(NSString *bpath, NSString *opath) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *temp = [NSString stringWithFormat:@"%@.ori", bpath];
    NSError *err;
    if ([fm fileExistsAtPath:temp]) {
        if ([fm moveItemAtPath:opath toPath:bpath error:&err]) {
            if ([fm moveItemAtPath:temp toPath:opath error:&err]) {
                mark_path_changed(opath);
            } else {
                NSLog(@"failed to move %@ to %@: %@",
                      temp, opath, [err localizedDescription]);
            }
        } else {
            NSLog(@"failed to move %@ to %@: %@",
                  opath, bpath, [err localizedDescription]);
        }
    }
}

/*
 * remove items under given directories
 * and not in buffer list
 *
 * all subitem in given directories needs to be uuid
 */
static void remove_leftover_items_under(NSArray<NSString *> *dirs) {
    buf_T *buf;
    NSError *err;
    NSString *path;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<NSString *> *bpaths = [NSMutableArray array];
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
        if (buf->b_ffname) {
            [bpaths addObject:TONSSTRING(buf->b_ffname)];
        }
    }
    NSArray<NSString *> *subitems;
    BOOL to_delete;
    for (NSString *dir in dirs) {
        subitems = [fm contentsOfDirectoryAtPath:dir error:&err];
        if (!subitems) {
            NSLog(@"failed to get contents of dir %@: %@",
                  dir, [err localizedDescription]);
            continue;
        }
        for (NSString *si in subitems) {
            to_delete = YES;
            for (NSString *bpath in bpaths) {
                if ([bpath containsString:si]) {
                    to_delete = NO;
                    break;
                }
            }
            if (to_delete) {
                path = [dir stringByAppendingPathComponent:si];
                if (![fm removeItemAtPath:path
                                    error:&err]) {
                    NSLog(@"failed to remove item %@: %@",
                          path, [err localizedDescription]);
                }
            }
        }
    }
}

/*
 * unlist buffers for dirs
 *
 * buffers for dirs may become listed (can be seen
 * in the buffer list) after session restore, unlist
 * them.
 */
static void unlist_dir_buffers(void) {
    buf_T *buf;
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
        if (buf->b_ffname && mch_isdir(buf->b_ffname)) {
            if (buf->b_p_bl) {
                buf->b_p_bl = FALSE;
            }
        }
    }
}

/*
 * deal with pending URL openning
 *
 * should do this after leftover cleaning
 * otherwise, the newly created mirror might
 * be cleaned by accident
 */

typedef void (^SKPendingURLTask)(void);
static SKPendingURLTask pendingURLTask = nil;
static BOOL post_done = NO;

BOOL scene_keeper_add_pending_url_task(SKPendingURLTask task) {
    BOOL added = NO;
    if (should_auto_restore() && !post_done) {
        pendingURLTask = task;
        added = YES;
    }
    
    return added;
}

static void run_pending_url_task(void) {
    if (pendingURLTask) {
        pendingURLTask();
        pendingURLTask = nil;
    }
}

static void clean_leftover_items(void) {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSString *mdir = [[[NSFileManager defaultManager] mirrorDirectoryURL] path];
        remove_leftover_items_under(@[temp_scenes_dir(), mdir]);
        dispatch_async(dispatch_get_main_queue(), ^{
            run_pending_url_task();
        });
    });
}

void scenes_keeper_restore_post(void) {
    if (!post_done) {
        post_done = YES;
        if (should_auto_restore()) {
            enumerate_buffer_mappings(restore_origin);
            unlist_dir_buffers();
            clean_leftover_items();
        }
    }
}

static void clean_file(NSString *path) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        return; // not exist
    }
    NSError *err;
    if (![fm removeItemAtPath:path error:&err]) {
        NSLog(@"failed to clean file: %@", [err localizedDescription]);
    }
}

void scenes_keeper_clear_all(void) {
    if (should_auto_restore()) { // do not clear if need to restore
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm cleanMirrorFiles];
    if ([fm fileExistsAtPath:session_file_path()]) {
        // clean buffer dir
        clean_dir(buffer_scenes_dir());
        // clean temp dir
        clean_dir(temp_scenes_dir());
        // remove mirrored files list
        clean_file(mirrored_files_list_path());
        // remove session.vim file
        clean_file(session_file_path());
    }
}

/*
 * session file path
 *
 * return nil if not doing auto-restore
 */
NSString *scene_keeper_valid_session_file_path(void) {
    return should_auto_restore() ? session_file_path() : nil;
}
