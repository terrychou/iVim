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
 * path of application prefix
 */
static NSString *app_dir(void) {
    static NSString *dir;
    if (!dir) {
        dir = [NSTemporaryDirectory() stringByDeletingLastPathComponent];
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

static NSString *relative_path_of(NSString *path, NSString *to) {
    NSArray<NSString *> *pcomps = [path pathComponents];
    NSArray<NSString *> *tcomps = [to pathComponents];
    NSUInteger pcount = [pcomps count];
    NSUInteger tcount = [tcomps count];
    NSUInteger count = pcount > tcount ? tcount : pcount;
    NSUInteger i, j;
    for (i = 0; i < count; i++) {
        if (![pcomps[i] isEqualToString:tcomps[i]]) {
            break;
        }
    }
    NSMutableArray<NSString *> *rcomps = [NSMutableArray array];
    NSUInteger ups = tcount - i;
    if ([tcomps[tcount - 1] isEqualToString:@"/"]) { // when the base dir ends with /
        ups -= 1;
    }
    for (j = 0; j < ups; j++) {
        [rcomps addObject:@".."];
    }
    for (; i < pcount; i++) {
        [rcomps addObject:pcomps[i]];
    }
    
    return [NSString pathWithComponents:rcomps];
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
    [fm removeItemAtPath:path error:NULL];
    [fm createDirectoryAtPath:path
  withIntermediateDirectories:YES
                   attributes:NULL
                        error:NULL];
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
 * Get current working directory
 */
static NSString * get_working_directory(void) {
    char_u *cwd = alloc(MAXPATHL);
    NSString *re = nil;
    if (mch_dirname(cwd, MAXPATHL)) {
        re = TONSSTRING(cwd);
    }
    free(cwd);
    
    return re;
}

/*
 * get path relative to current working directory
 */
NSString *path_relative_to_cwd(NSString *path) {
    return relative_path_of(path, get_working_directory());
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
        new_path = relative_path_of(new_path, get_working_directory());
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
static void record_last_app_prefix(void) {
    NSError *err;
    if (![app_dir() writeToFile:last_app_prefix_file_path()
                     atomically:YES
                       encoding:NSUTF8StringEncoding
                          error:&err]) {
        NSLog(@"failed to record last app prefix: %@",
              [err localizedDescription]);
    }
}

static NSString *last_app_prefix(void) {
    return [NSString stringWithContentsOfFile:last_app_prefix_file_path()
                                     encoding:NSUTF8StringEncoding
                                        error:NULL];
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
    NSString *swaplist = swap_file_list_path();
    NSString *bufferlist = buffer_mapping_list_path();
    FILE *slp;
    FILE *bmlp = NULL;
    if ((slp = fopen([swaplist UTF8String], "w")) == NULL) {
        NSLog(@"failed to create swap file list");
        return;
    }
    if(should_restore && (bmlp = fopen([bufferlist UTF8String], "w")) == NULL) {
        NSLog(@"failed to create buffer mapping list");
        fclose(slp);
        return;
    }
    NSMutableArray<NSValue *> *changed_bufs = [NSMutableArray array];
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
        // record swap file paths
//        if (buf->b_ffname) {
//            NSLog(@"buffer file %s", buf->b_ffname);
//        }
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
    
    if (!should_restore) {
        return;
    }
    fclose(bmlp);
    // make session
    record_last_app_prefix();
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
 * remove all recorded swap files
 */
static void remove_swap_files(void) {
    NSString *path = swap_file_list_path();
    FILE *slp;
    if ((slp = fopen([path UTF8String], "r")) == NULL) {
        NSLog(@"no swap list file found");
        return;
    }
    char *spath;
    size_t length;
    NSString *nsspath;
    NSFileManager *fm = [NSFileManager defaultManager];
    while ((spath = fgetln(slp, &length))) {
        // this works only when each line ends with a \n
        spath = strtok(spath, "\n");
        nsspath = TONSSTRING(spath);
        nsspath = full_path_to_app(nsspath);
//        NSLog(@"remove swap file: %@", nsspath);
        if ([fm fileExistsAtPath:nsspath]) {
            [fm removeItemAtPath:nsspath error:NULL];
        }
    }
    fclose(slp);
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
 *
 * absolute file paths may change due to
 * application re-installation, the old ones need correcting to
 * current application prefix to make session restoration work
 * properly
 */
static NSString *uuid_regex = @"[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}";

static NSUInteger correct_content(NSMutableString *content, NSString *old, NSString *new) {
    NSMutableString *regex = [NSMutableString stringWithString:old];
    [regex replaceOccurrencesOfString:uuid_regex
                           withString:uuid_regex
                              options:NSRegularExpressionSearch
                                range:NSMakeRange(0, [old length])];
    
    return [content replaceOccurrencesOfString:regex
                                    withString:new
                                       options:NSRegularExpressionSearch
                                         range:NSMakeRange(0, [content length])];
}

static void correct_session_file(void) {
    NSString *lap = last_app_prefix();
    if (!lap) {
        return;
    }
    NSString *cap = app_dir();
    if ([lap isEqualToString:cap]) { // application prefix did not change
        return;
    }
    
    NSError *err;
    NSString *spath = session_file_path();
    NSMutableString *scontent = [NSMutableString stringWithContentsOfFile:spath
                                                                 encoding:NSUTF8StringEncoding
                                                                    error:&err];
    if (!scontent) {
        NSLog(@"failed to read session file: %@",
              [err localizedDescription]);
        return;
    }
    // corrent possible application data paths
    NSUInteger replaced = correct_content(scontent, lap, cap);
    
    // correct possible runtime paths
    NSString *crp = TONSSTRING(mch_getenv("VIMRUNTIME"));
    replaced += correct_content(scontent, crp, crp);
    
    NSLog(@"%lu paths in session file corrected.", (unsigned long)replaced);
    if (replaced > 0 && ![scontent writeToFile:spath
                                    atomically:YES
                                      encoding:NSUTF8StringEncoding
                                         error:&err]) {
        NSLog(@"failed to write session file: %@",
              [err localizedDescription]);
    }
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
static void temporarily_sub(NSString *bpath, NSString *opath) {
    [[PickInfoManager shared] addPickInfoAt:opath update:YES];
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
    if (should_auto_restore()) {
        correct_session_file();
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

static void add_pickinfos_for_mirrors(void) {
    buf_T *buf;
    PickInfoManager *pim = [PickInfoManager shared];
    NSString *fpath;
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
        if (buf->b_ffname) {
            fpath = TONSSTRING(buf->b_ffname);
            if (fpath) {
                [pim addPickInfoAt:fpath update:YES];
            }
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

static NSData * pendingBookmark = nil;
static BOOL post_done = NO;

BOOL scene_keeper_add_pending_bookmark(NSData * bm) {
    BOOL added = NO;
    if (should_auto_restore() && !post_done) {
        pendingBookmark = bm;
        added = YES;
    }
    
    return added;
}

static void open_pending_bookmark(void) {
    if (pendingBookmark) {
        [[PickInfoManager shared] handleBookmark:pendingBookmark];
        pendingBookmark = nil;
    }
}

static void clean_leftover_items(void) {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSString *mdir = [[[NSFileManager defaultManager] mirrorDirectoryURL] path];
        remove_leftover_items_under(@[temp_scenes_dir(), mdir]);
        open_pending_bookmark();
    });
}

void scenes_keeper_restore_post(void) {
    if (!post_done) {
        post_done = YES;
        if (should_auto_restore()) {
            enumerate_buffer_mappings(restore_origin);
            add_pickinfos_for_mirrors();
            unlist_dir_buffers();
            clean_leftover_items();
        }
    }
}

void scenes_keeper_clear_all(void) {
    if (should_auto_restore()) { // do not clear if need to restore
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm cleanMirrorFiles];
    if ([fm fileExistsAtPath:session_file_path()]) {
        clean_dir(scenes_dir());
    }
}

/*
 * valid session file path
 *
 * "valid" in it exists
 */
NSString *scene_keeper_valid_session_file_path(void) {
    if (!should_auto_restore()) {
        return nil;
    }
    NSString *path = session_file_path();
    
    return [[NSFileManager defaultManager] fileExistsAtPath:path] ?
    path : nil;
}
