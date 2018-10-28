/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				   iOS port by Romain Goyet
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */
/*
 * gui_ios.m
 *
 * Support for the iOS GUI. Most of the iOS code resides in this file.
 */

#import "vim.h"
#import "iVim-Swift.h"
#import <AudioToolbox/AudioToolbox.h>

//int getCTRLKeyCode(NSString * s) {
//    if([s isEqualToString:@"["])
//        return ESC;
//    if([s isEqualToString:@"]"])
//        return Ctrl_RSB;
//    if([s isEqualToString:@"A"])
//        return Ctrl_A;
//    if([s isEqualToString:@"B"])
//        return Ctrl_B;
//    if([s isEqualToString:@"C"])
//        return Ctrl_C;
//    if([s isEqualToString:@"D"])
//        return Ctrl_D;
//    if([s isEqualToString:@"E"])
//        return Ctrl_E;
//    if([s isEqualToString:@"F"])
//        return Ctrl_F;
//    if([s isEqualToString:@"G"])
//        return Ctrl_G;
//    if([s isEqualToString:@"H"])
//        return Ctrl_H;
//    if([s isEqualToString:@"I"])
//        return Ctrl_I;
//    if([s isEqualToString:@"J"])
//        return Ctrl_J;
//    if([s isEqualToString:@"K"])
//        return Ctrl_K;
//    if([s isEqualToString:@"L"])
//        return Ctrl_L;
//    if([s isEqualToString:@"M"])
//        return Ctrl_M;
//    if([s isEqualToString:@"N"])
//        return Ctrl_N;
//    if([s isEqualToString:@"O"])
//        return Ctrl_O;
//    if([s isEqualToString:@"P"])
//        return Ctrl_P;
//    if([s isEqualToString:@"Q"])
//        return Ctrl_Q;
//    if([s isEqualToString:@"R"])
//        return Ctrl_R;
//    if([s isEqualToString:@"S"])
//        return Ctrl_S;
//    if([s isEqualToString:@"T"])
//        return Ctrl_T;
//    if([s isEqualToString:@"U"])
//        return Ctrl_U;
//    if([s isEqualToString:@"V"])
//        return Ctrl_V;
//    if([s isEqualToString:@"W"])
//        return Ctrl_W;
//    if([s isEqualToString:@"X"])
//        return Ctrl_X;
//    if([s isEqualToString:@"Y"])
//        return Ctrl_Y;
//    if([s isEqualToString:@"Z"])    
//        return Ctrl_Z;
//    return 0;
//    
//}

//int get_ctrl_modified_key(const char * c) {
//    return Ctrl_chr(*c);
//}
//
//int get_alt_modified_key(const char * c) {
//    return Meta(*c);
//}
extern NSArray * call_ctags(int, char **);

NSInteger const keyCAR = CAR;
NSInteger const keyESC = ESC;
NSInteger const keyTAB = TAB;
NSInteger const keyBS = K_BS;
NSInteger const keyF1 = 0x7E;
NSInteger const keyUP = K_UP;
NSInteger const keyDOWN = K_DOWN;
NSInteger const keyLEFT = K_LEFT;
NSInteger const keyRIGHT = K_RIGHT;
NSInteger const mouseDRAG = MOUSE_DRAG;
NSInteger const mouseLEFT = MOUSE_LEFT;
NSInteger const mouseRELEASE = MOUSE_RELEASE;

/*
 * put special key char *key* (TERMCAP2KEY) into the input buffer
 */
void input_special_key(int key) {
    char_u s[3] = {CSI, K_SECOND(key), K_THIRD(key)};
    add_to_input_buf(s, 3);
}

/*
 * put a special <> *name* (such as <C-W>) into the input buffer
 */
void input_special_name(const char * name) {
    char_u * n = (char_u *)name;
    char_u re[6];
    int len = trans_special(&n, re, TRUE);
    for (int i = 0; i < len; i += 3) {
        if (re[i] == K_SPECIAL) { re[i] = CSI; }
    }
    add_to_input_buf(re, len);
}

//NSString *lookupStringConstant(NSString *constantName) {
//    void ** dataPtr = CFBundleGetDataPointerForName(CFBundleGetMainBundle(), (__bridge CFStringRef)constantName);
//    return (__bridge NSString *)(dataPtr ? *dataPtr : nil);
//}


#define RGB(r,g,b)	((r) << 16) + ((g) << 8) + (b)
#define ARRAY_LENGTH(a) (sizeof(a) / sizeof(a[0]))
#define TONSSTRING(chars) [[NSString alloc] initWithUTF8String:(const char *)chars]
#define TOCHARS(str) (char_u *)[str UTF8String]
/*
 * expand tilde (home directory) for *path*
 * the original path will be returned if
 * it is unnecessary to expand or the expanding failed.
 *
 * The NSString's expandingTildeInPath method will not
 * work because the HOME path is different in vim
 */
NSString * expand_tilde_of_path(NSString * path) {
    if (path == nil || ![path hasPrefix:@"~"]) {
        return path;
    }
    char_u * p = TOCHARS(path);
    int len = (int)STRLEN(p) + MAXPATHL + 1;
    char_u buf[len];
    expand_env(p, buf, len);
    
    return TONSSTRING(buf);
}

/*
 * get the absolute path of *path*
 */
static NSString * full_path_of_path(const char * path) {
    if (path == NULL) { return nil; }
    NSString * p = TONSSTRING(path);
    NSString * res = nil;
    if ([p isAbsolutePath]) {
        res = expand_tilde_of_path(p);
    } else {
        NSString * cwd = [[NSFileManager defaultManager] currentDirectoryPath];
        NSURL * cwdURL = [NSURL fileURLWithPath:cwd];
        NSURL * resURL = [NSURL fileURLWithPath:p relativeToURL:cwdURL];
        res = [resURL path];
    }
    res = [res stringByStandardizingPath];
    
    return res;
//    char_u buf[MAXPATHL];
//    if (vim_FullName((char_u *)path, buf, MAXPATHL, TRUE) == FAIL) {
//        return nil;
//    }
//
//    return TONSSTRING(buf);
}

/*
 * get the current sourcing file name
 */
NSString * get_current_sourcing_name(void) {
    return sourcing_name == NULL ? nil : TONSSTRING(sourcing_name);
}

/*
 * to get the write event for files
 */
void mch_ios_post_buffer_write(buf_T * buf, char_u * fname) {
    NSString * path = full_path_of_path((char *)fname);
    if (path == NULL) { return; }
    [[PickInfoManager shared] writeFor:path];
}

/*
 * to get the file remove event
 */
void mch_ios_post_file_remove(const char * file) {
    NSString * p = full_path_of_path(file);
    if (p == NULL) { return; }
    [[PickInfoManager shared] removeFor:p];
}

/*
 * to get the file rename event
 */
void mch_ios_post_item_rename(const char * old, const char * new) {
    NSString * op = full_path_of_path(old);
    NSString * np = full_path_of_path(new);
    if (op == NULL || np == NULL) { return; }
    [[PickInfoManager shared] renameFrom:op to:np];
}

/*
 * to get the make directory event
 */
void mch_ios_post_dir_make(const char * path) {
    NSString * p = full_path_of_path(path);
    if (p == NULL) { return; }
    [[PickInfoManager shared] mkdirFor:p];
}

/*
 * to get the remove directory event
 */
void mch_ios_post_dir_remove(const char * path) {
    NSString * p = full_path_of_path(path);
    if (p == NULL) { return; }
    [[PickInfoManager shared] rmdirFor:p];
}

/*
 * help function to judge whether *buf* belongs to mirror at *path*
 */
static BOOL buf_belongs_to_path(buf_T * buf, NSString * path) {
    return buf->b_ffname != NULL &&
        [TONSSTRING(buf->b_ffname) hasPrefix:path];
}

/*
 * reload buffer representing file in mirror *path*
 */
void ivim_reload_buffer_for_mirror(NSString * path) {
    buf_T * buf = nil;
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
        if (buf_belongs_to_path(buf, path) &&
            !mch_isdir(buf->b_ffname)) {
            buf_reload(buf, buf->b_orig_mode);
        }
    }
}

static int hex_digit(int c) {
    if (VIM_ISDIGIT(c))
        return c - '0';
    c = TOLOWER_ASC(c);
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    return -1000;
}

static AppDelegate * appDelegate(void) {
    static AppDelegate * appDelegate = nil;
    if (appDelegate == nil) {
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    }
    
    return appDelegate;
}

static VimViewController * shellViewController(void) {
    static VimViewController * controller = nil;
    if (controller == nil) {
        controller = (VimViewController*)[[appDelegate() window] rootViewController];
    }
    
    return controller;
}

static VimView * shellView(void) {
    static VimView * view;
    if (view == nil) {
        view = [shellViewController() vimView];
    }
    
    return view;
}

static NSString * bundle_info_for_name(NSString * name) {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:name];
}

/*
 * gui version info line
 */
char_u * gui_version_info(void) {
    static char_u * info;
    if (info == NULL) {
        NSString * name = bundle_info_for_name(@"CFBundleName");
        NSString * version = bundle_info_for_name(@"CFBundleShortVersionString");
        NSString * build = bundle_info_for_name((NSString *)kCFBundleVersionKey);
        NSString * line = [NSString stringWithFormat:@"%@ version %@(%@)", name, version, build];
        info = TOCHARS(line);
    }
    
    return info;
}

//CGColorRef CGColorCreateFromVimColor(guicolor_T color)  {
//    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//    int red = (color & 0xFF0000) >> 16;
//    int green = (color & 0x00FF00) >> 8;
//    int blue = color & 0x0000FF;
//    CGFloat rgb[4] = {(float)red/0xFF, (float)green/0xFF, (float)blue/0xFF, 1.0f};
//    CGColorRef cgColor = CGColorCreate(colorSpace, rgb);
//    CGColorSpaceRelease(colorSpace);
//    return cgColor;
//}

#pragma mark -
#pragma mark Vim C functions
/* 
 * Copy string and avoid the compiler from checking the destination size
 */
char * istrcpy(char * dst, char * src) {
    char * tmp = dst;
    return strcpy(tmp, src);
}

/*
 * Show error message *err_msg*
 */
static void show_error_message(NSString * err_msg) {
    NSString * arg = [NSString stringWithFormat:@"echoerr \"%@\"", err_msg];
    do_cmdline_cmd(TOCHARS(arg));
}

/* 
 * Declarations for ex command functions
 */
static void ex_ifont(exarg_T *);
static void ex_ideletefont(exarg_T *);
static void ex_idocuments(exarg_T *);
static void ex_ishare(exarg_T *);
static void ex_ictags(exarg_T *);
static void ex_iolddocs(exarg_T *);
static void ex_iopenurl(exarg_T *);
static void ex_isetekbd(exarg_T *);
//static void ex_ifontsize(exarg_T * eap);

/*
 * Extended ex commands dispatcher
 */
void ex_ios_cmds(exarg_T * eap) {
    switch (eap->cmdidx) {
        case CMD_ifont:
            ex_ifont(eap);
            break;
        case CMD_ideletefont:
            ex_ideletefont(eap);
            break;
        case CMD_iolddocs:
            ex_iolddocs(eap);
            break;
        case CMD_iopenurl:
            ex_iopenurl(eap);
            break;
        case CMD_ishare:
            ex_ishare(eap);
            break;
        case CMD_idocuments:
            ex_idocuments(eap);
            break;
        case CMD_ictags:
            ex_ictags(eap);
            break;
        case CMD_isetekbd:
            ex_isetekbd(eap);
            break;
        default:
            break;
    }
}

/*
 * Handling function for command *ifont*
 */

static void ex_ifont(exarg_T * eap) {
    NSString * arg = TONSSTRING(eap->arg);
    if ([arg length] == 0) {
        NSString * cmd = TONSSTRING(eap->cmd);
        [[VimFontsManager shared] showAvailableFontsWithCommand:cmd];
    } else {
        [[VimFontsManager shared] selectFontWith:arg];
    }
}

/*
 * Handling function for command *ideletefont*
 */
static void ex_ideletefont(exarg_T * eap) {
    NSString * arg = TONSSTRING(eap->arg);
    if ([arg length] == 0) {
        [[VimFontsManager shared] showAvailableFontsWithCommand:TONSSTRING(eap->cmd)];
    } else {
        [[VimFontsManager shared] deleteFontWith:arg];
    }
}

/*
 * get the string value of an expression *expr*
 */
static NSString * string_value_of_tv(typval_T *);

static NSString * string_value_of_tv(typval_T * tv) {
    char_u * s = tv->vval.v_string;
    if (s == NULL) {
        return @"";
    }
    
    return TONSSTRING(s);
}

static NSString * force_string_value_of_tv(typval_T * tv) {
    switch (tv->v_type) {
        case VAR_NUMBER:
            return [NSString stringWithFormat:@"%d", tv->vval.v_number];
            break;
        case VAR_FLOAT:
            return [NSString stringWithFormat:@"%f", tv->vval.v_float];
            break;
        case VAR_STRING:
            return string_value_of_tv(tv);
            break;
        default:
            return @"";
            break;
    }
}

NSString * string_value_of_expr(const char * expr) {
    typval_T * ret = eval_expr((char_u *)expr, NULL);
    if (ret == NULL) {
        return @"";
    }
    
    return force_string_value_of_tv(ret);
}

/*
 * translate the tv value to Cocoa compatible
 */
static id value_of_tv(typval_T *);
static NSDictionary * dict_value_of_tv(typval_T *);
static NSArray * list_value_of_tv(typval_T *);

static id value_of_tv(typval_T * tv) {
    switch (tv->v_type) {
        case VAR_STRING:
            return string_value_of_tv(tv);
            break;
        case VAR_NUMBER:
            return [NSNumber numberWithInt:tv->vval.v_number];
            break;
        case VAR_FLOAT:
            return [NSNumber numberWithDouble:tv->vval.v_float];
            break;
        case VAR_LIST:
            return list_value_of_tv(tv);
            break;
        case VAR_DICT:
            return dict_value_of_tv(tv);
            break;
        default:
            return NULL;
            break;
    }
}

/*
 * translate vim dict to NSDictionary
 */
static dictitem_T * dict_item_from_hash_item(hashitem_T * hi) {
    static dictitem_T dumdi;
    return (dictitem_T *)(hi->hi_key - (dumdi.di_key - (char_u *)&dumdi));
}

static NSDictionary * dict_value_of_tv(typval_T * tv) {
    dict_T * dict = tv->vval.v_dict;
    if (dict == NULL) {
        return NULL;
    }
    int todo = (int)dict->dv_hashtab.ht_used;
    hashitem_T * hi;
    dictitem_T * di;
    NSString * key;
    id value;
    NSMutableDictionary * ret = [NSMutableDictionary dictionary];
    for (hi = dict->dv_hashtab.ht_array; todo > 0; ++hi) {
        if (HASHITEM_EMPTY(hi)) {
            continue;
        }
        --todo;
        di = dict_item_from_hash_item(hi);
        key = TONSSTRING(&di->di_key);
        value = value_of_tv(&di->di_tv);
        [ret setValue:value forKey:key];
    }
    
    return ret;
}

/*
 * translate vim list to NSArray
 */
static NSArray * list_value_of_tv(typval_T * tv) {
    list_T * list = tv->vval.v_list;
    if (list == NULL) {
        return NULL;
    }
    NSMutableArray * ret = [NSMutableArray array];
    listitem_T * li;
    for (li = list->lv_first; li != NULL; li = li->li_next) {
        id value = value_of_tv(&li->li_tv);
        [ret addObject:value];
    }
    
    return ret;
}

/*
 * get Cocoa object of expression *expr*
 */
id object_of_expr(const char * expr) {
    typval_T * tv = eval_expr((char_u *)expr, NULL);
    
    return tv != NULL ? value_of_tv(tv) : NULL;
}

/*
 * Handling function for command *iolddocs*
 */
static void ex_iolddocs(exarg_T * eap) {
    NSString * arg = TONSSTRING(eap->arg);
    [[OldDocumentsManager shared] runCommandWith:arg
                                            bang:eap->forceit];
}

/*
 * Handling function for command *iopenurl*
 */
static void ex_iopenurl(exarg_T * eap) {
    NSString * arg = TONSSTRING(eap->arg);
    [[[URLOpener alloc] initWithPath:arg] open];
}

/*
 * Handling function for command *idocuments*
 */
static void ex_idocuments(exarg_T * eap) {
    NSString * arg = TONSSTRING(eap->arg);
    if ([arg length] == 0 || [arg isEqualToString:@"open"]) {
        [shellViewController() pickDocument];
    } else if ([arg isEqualToString:@"import"]) {
        [shellViewController() importDocument];
    }
}

/*
 * Handling function for command *ictags*
 */
static void execute_ctags(NSString *);
static NSArray * ctags_args(NSString *);
static void ex_ictags(exarg_T * eap) {
    execute_ctags(TONSSTRING(eap->cmd));
}

static NSArray * ctags_args(NSString * cmdline) {
    NSArray * splited = [[[CommandTokenizer alloc] initWithLine:cmdline] run];
    NSMutableArray * args = [NSMutableArray array];
    for (NSString * i in splited) {
        char_u * pat = (char_u *)[i UTF8String];
        if (mch_has_wildcard(pat)) {
            char_u ** filenames;
            int filecnt;
            gen_expand_wildcards(1, &pat, &filecnt, &filenames,
                                 EW_DIR | EW_FILE | EW_SILENT);
            for (int i = 0; i < filecnt; ++i) {
                [args addObject:TONSSTRING(filenames[i])];
            }
            FreeWild(filecnt, filenames);
        } else {
            [args addObject:i];
        }
    }
    
    return args;
}

static void execute_ctags(NSString * cmdline) {
    NSArray * args = ctags_args(cmdline);
    int argc = (int)[args count];
    char * argv[argc + 1];
    argv[0] = "ictags";
    for (int i = 1; i < argc; ++i) {
        argv[i] = (char *)[args[i] UTF8String];
    }
    argv[argc] = NULL;
    NSArray * ret = call_ctags(argc, argv);
    NSString * info = nil;
    NSString * cmdfmt = nil;
    NSString * norcmd = @"echo \"%@\"";
    if ([ret[0] length] != 0) {
        info = ret[0];
    } else if ([ret[1] length] != 0) {
        info = ret[1];
        cmdfmt = [NSString stringWithFormat:@"echohl ErrorMsg | %@ | echohl None", norcmd];
    } else {
        info = @"ictags DONE";
    }
    if (cmdfmt == nil) {
        cmdfmt = norcmd;
    }
    NSString * escapedInfo = [info stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString * cmd = [NSString stringWithFormat:cmdfmt, escapedInfo];
    do_cmdline_cmd(TOCHARS(cmd));
}

/*
 * Handling function for command *isetekbd*
 */
static void ex_isetekbd(exarg_T * eap) {
    NSString * arg = TONSSTRING(eap->arg);
    BOOL forced = eap->forceit == TRUE;
    [[ExtendedKeyboardManager shared] setKeyboardWith:arg
                                               forced:forced];
}

/*
 * Get current working directory
 */
char_u * get_working_directory(void) {
    char_u * re = alloc(MAXPATHL);
    mch_dirname(re, MAXPATHL);
    
    return re;
}

/*
 * Share file
 */
void share_file(NSString * path) {
    NSURL * url = [NSURL fileURLWithPath:path];
    if ([url checkResourceIsReachableAndReturnError:nil]) {
        [shellViewController() showShareSheetWithUrl:url text:nil];
    } else {
        NSString * errMsg = [NSString stringWithFormat:@"file %@ not exist!", path];
        show_error_message(errMsg);
    }
}

/*
 * Get text from *line1* through *line2*
 */
NSString * get_text_between(linenr_T line1, linenr_T line2) {
    NSMutableString * re = [[NSMutableString alloc] init];
    for (linenr_T l = line1; l <= line2; l++) {
        char_u * lt = ml_get(l);
        [re appendString:TONSSTRING(lt)];
        [re appendString:@"\n"];
    }
    
    return re;
}

/*
 * Handling function for command *ishare*
 */
static void ex_ishare(exarg_T * eap) {
    NSString * arg = TONSSTRING(eap->arg);
    if (eap->addr_count > 0) {
        NSString * text = get_text_between(eap->line1, eap->line2);
//        NSLog(@"share text: %@", text);
        [shellViewController() showShareSheetWithUrl:nil text:text];
    } else if ([arg length] == 0 || [arg isEqualToString:@"%"]) {
        char_u * ff = curbuf->b_ffname;
        if (ff != NULL) {
            share_file(TONSSTRING(ff));
        } else {
            show_error_message(@"Current buffer not saved yet!");
        }
    } else {
        NSString * path = arg;
        if (![path hasPrefix:@"/"]) {
            char_u * cwd = get_working_directory();
            if (cwd != NULL) {
                path = [TONSSTRING(cwd) stringByAppendingPathComponent:path];
            }
        }
        share_file(path);
    }
}

void move_cursor(char_u direction, long times) {
    if (times <= 0)
        return;
    char_u key[] = {CSI, 'k', direction};
    if (State & NORMAL)
        return;
    for(; times > 0; --times)
        add_to_input_buf(key, (int)sizeof(key));
}

/*
 * Move cursor left in insert mode for *times* times
 */
void move_cursor_left(long times) {
    move_cursor('l', times);
}

/*
 * Move cursor right in insert mode for *times* times
 */
void move_cursor_right(long times) {
    move_cursor('r', times);
}

/*
 * Number of cells for character *c*
 */
int cells_for_character(char_u * c) {
    return ptr2cells(c);
}

/*
 * If current buffer is new
 */
BOOL is_current_buf_new(void) {
    return (curbuf->b_ffname == NULL && !curbuf->b_changed);
}

/*
 * If file at *path* is in buffer list
 */
BOOL file_is_in_buffer_list(NSString * path) {
    buf_T * buf = nil;
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
        if (buf->b_ffname != NULL &&
            [TONSSTRING(buf->b_ffname) isEqualToString: path]) {
            return YES;
        }
    }
    
    return NO;
}

/*
 * Jump to the first window with the buffer at *path*
 * return YES if a window is found; NO otherwise
 */

BOOL jump_to_window_with_buffer(NSString * path) {
    tabpage_T * tp = nil;
    win_T * wp = nil;
    win_T * fwp = nil;
    char_u * b_name = nil;
    for (tp = first_tabpage; tp != NULL; tp = tp->tp_next) {
        fwp = tp->tp_firstwin;
        if (fwp == NULL) {
            fwp = firstwin;
        }
        for (wp = fwp; wp != NULL; wp = wp->w_next) {
            b_name = wp->w_buffer->b_ffname;
            if (b_name != NULL &&
                [TONSSTRING(b_name) isEqualToString:path]) {
                goto_tabpage_win(tp, wp);
                do_cmdline_cmd((char_u *)"redraw!");
                return YES;
            }
        }
    }
    
    return NO;
}

/*
 * clean buffers for mirror at *path*
 * return true if deletion succeeded
 */
BOOL clean_buffer_for_mirror_path(NSString * path) {
    buf_T * buf = nil;
    BOOL result = NO;
    for (buf = firstbuf; buf != NULL; buf = buf->b_next) {
        if (buf_belongs_to_path(buf, path)) {
            close_buffer(NULL, buf, DOBUF_DEL, 0);
            close_windows(buf, TRUE);
            if (buf == curbuf) {
                do_cmdline_cmd((char_u *)"enew");
            }
            result = YES;
        }
    }
    
    return result;
}

/*
 * If currently in normal mode
 */
BOOL is_in_normal_mode(void) {
    return State & NORMAL;
}

/*
 * Get the regex pattern from *line*
 * return last_search_pat() if itself isn't a valid pattern
 */
NSString * get_pattern_from_line(NSString * line) {
    char_u * p;
    char_u * s;
    p = skip_vimgrep_pat(TOCHARS(line), &s, NULL);
    if (p == NULL || (s != NULL && *s == NUL)) {
        s = last_search_pat();
    }
    
    return s != NULL ? TONSSTRING(s) : nil;
}

/*
 *
 */

void ivim_match_regex(NSString * pattern, BOOL ignore_case, void (^worker)(BOOL (^matcher)(NSString *))) {
    regmatch_T regmatch;
    regmatch.regprog = NULL;
    regmatch.regprog = vim_regcomp(TOCHARS(pattern), RE_MAGIC);
    if (regmatch.regprog == NULL) {
        return;
    }
    regmatch.rm_ic = ignore_case;
    regmatch_T * rmp = &regmatch;
    BOOL (^m)(NSString *) = ^(NSString * line) {
        return (BOOL)vim_regexec(rmp, TOCHARS(line), 0);
    };
    worker(m);
    vim_regfree(regmatch.regprog);
}

/*
 * Parse the GUI related command-line arguments.  Any arguments used are
 * deleted from argv, and *argc is decremented accordingly.  This is called
 * when vim is started, whether or not the GUI has been started.
 * NOTE: This function will be called twice if the Vim process forks.
 */

    void
gui_mch_prepare(int *argc, char **argv)
{
//    NSLog(@"Prepare");
}


/*
 * Check if the GUI can be started.  Called before gvimrc is sourced.
 * Return OK or FAIL.
 */
    int
gui_mch_init_check(void)
{
//    printf("%s\n",__func__);  
    return OK;
}

static BOOL bg_color_ready = NO;

static void gui_ios_sync_bg_color(BOOL is_init) {
//    CGColorRef color = CGColorCreateFromVimColor(gui.def_back_pixel);
    [shellViewController() setBackgroundColor:(uint32_t)gui.def_back_pixel
                                       isInit:is_init];
}

/*
 * Initialize background color for shell view controller when there are safe areas
 * the background color is not valid until gui_mch_init is called
 */
void gui_ios_init_bg_color(void) {
    if (!bg_color_ready) { return; }
    gui_ios_sync_bg_color(YES);
}

/*
 * Initialise the GUI.  Create all the windows, set up all the call-backs etc.
 * Returns OK for success, FAIL when the GUI can't be started.
 */
    int
gui_mch_init(void)
{
//    printf("%s\n",__func__);
    set_option_value((char_u *)"termencoding", 0L, (char_u *)"utf-8", 0);
    
    gui_mch_def_colors();
    
    set_normal_colors();

    gui_check_colors();
    gui.def_norm_pixel = gui.norm_pixel;
    gui.def_back_pixel = gui.back_pixel;
    
    bg_color_ready = YES;
    if (shellViewController()) {
        gui_ios_init_bg_color();
    }

//#ifdef FEAT_GUI_SCROLL_WHEEL_FORCE
   // gui.scroll_wheel_force = 1;
    //gui
//#endif

    return OK;
}



    void
gui_mch_exit(int rc)
{
//    printf("%s\n",__func__);
    //save old documents
    [[OldDocumentsManager shared] wrapUp];
    
    //unregister file presenters
    [[PickInfoManager shared] wrapUp];
}


/*
 * Open the GUI window which was created by a call to gui_mch_init().
 */
    int
gui_mch_open(void)
{
    //    printf("%s\n",__func__);
    [shellView() resizeShell];
    
    return OK;
}


// -- Updating --------------------------------------------------------------


/*
 * Catch up with any queued X events.  This may put keyboard input into the
 * input buffer, call resize call-backs, trigger timers etc.  If there is
 * nothing in the X event queue (& no timers pending), then we return
 * immediately.
 */
    void
gui_mch_update(void)
{
    // This function is called extremely often.  It is tempting to do nothing
    // here to avoid reduced frame-rates but then it would not be possible to
    // interrupt Vim by presssing Ctrl-C during lengthy operations (e.g. after
    // entering "10gs" it would not be possible to bring Vim out of the 10 s
    // sleep prematurely).  Furthermore, Vim sometimes goes into a loop waiting
    // for keyboard input (e.g. during a "more prompt") where not checking for
    // input could cause Vim to lock up indefinitely.
    //
    // As a compromise we check for new input only every now and then. Note
    // that Cmd-. sends SIGINT so it has higher success rate at interrupting
    // Vim than Ctrl-C.

//    printf("%s\n",__func__);  
}


/* Flush any output to the screen */
    void
gui_mch_flush(void)
{
    // This function is called way too often to be useful as a hint for
    // flushing.  If we were to flush every time it was called the screen would
    // flicker.
//    printf("%s\n",__func__);
   [shellViewController() flush];
}


/*
 * GUI input routine called by gui_wait_for_chars().  Waits for a character
 * from the keyboardk.
 *  wtime == -1	    Wait forever.
 *  wtime == 0	    This should never happen.
 *  wtime > 0	    Wait wtime milliseconds for a character.
 * Returns OK if a character was found to be available within the given time,
 * or FAIL otherwise.
 */
//TODO: Move to VC
    int
gui_mch_wait_for_chars(int wtime)
{
    return [shellViewController() waitForChars:wtime];
}


// -- Drawing ---------------------------------------------------------------


/*
 * Clear the whole text window.
 */
void
gui_mch_clear_all(void)
{
//    printf("%s\n",__func__);
    [shellView() fillAllWith:(uint32_t)gui.back_pixel];
}


/*
 * Clear a rectangular region of the screen from text pos (row1, col1) to
 * (row2, col2) inclusive.
 */
    void
gui_mch_clear_block(int row1, int col1, int row2, int col2)
{
    
    CGRect rect = CGRectMake(FILL_X(col1),
                             FILL_Y(row1),
                             FILL_X(col2+1)-FILL_X(col1),
                             FILL_Y(row2+1)-FILL_Y(row1));
    [shellView() fillRect:rect with:(uint32_t)gui.back_pixel];
}


void gui_mch_draw_string(int row, int col, char_u *s, int len, int flags) {
    if (s == NULL || len <= 0) {
        return;
    }

    //NSLog(@"Draw %s ", s);
    CGFloat left = FILL_X(col);
    CGFloat top = FILL_Y(row);
    CGFloat right;
    if (has_mbyte) {
        right = FILL_X(col + mb_string2cells(s, len));
    } else {
        right = FILL_X(col + len) + (col + len == Columns);
    }
    CGFloat bottom = FILL_Y(row + 1);
    CGRect rect = CGRectMake(left, top, right - left, bottom - top);
    
    NSString * string = [[NSString alloc] initWithBytes:s length:len encoding:NSUTF8StringEncoding];
    if (string == nil) {
        return;
    }
    
    [shellView() drawString: string
                      pos_x: TEXT_X(col)
                      pos_y: TEXT_Y(row)
                       rect: rect
                p_antialias: true
                transparent: flags & DRAW_TRANSP
                  underline: flags & DRAW_UNDERL
                  undercurl: flags & DRAW_UNDERC
                     cursor: flags & DRAW_CURSOR];
}


/*
 * Delete the given number of lines from the given row, scrolling up any
 * text further down within the scroll region.
 */
    void
gui_mch_delete_lines(int row, int num_lines)
{
//    printf("%s\n",__func__);
    CGRect sourceRect = CGRectMake(FILL_X(gui.scroll_region_left),
                                   FILL_Y(row + num_lines),
                                   FILL_X(gui.scroll_region_right + 1) - FILL_X(gui.scroll_region_left),
                                   FILL_Y(gui.scroll_region_bot + 1) - FILL_Y(row + num_lines));
    CGRect targetRect = sourceRect;
    targetRect.origin.y = FILL_Y(row);

//    CGRect targetRect = CGRectMake(FILL_X(gui.scroll_region_left),
//                                   FILL_Y(row),
//                                   FILL_X(gui.scroll_region_right+1) - FILL_X(gui.scroll_region_left),
//                                   FILL_Y(gui.scroll_region_bot+1) - FILL_Y(row + num_lines));

    [shellView() copyRectFrom:sourceRect to:targetRect];
    gui_clear_block(gui.scroll_region_bot - num_lines + 1,
                    gui.scroll_region_left,
                    gui.scroll_region_bot, gui.scroll_region_right);
}


/*
 * Insert the given number of lines before the given row, scrolling down any
 * following text within the scroll region.
 */
    void
gui_mch_insert_lines(int row, int num_lines)
{
//    printf("%s\n",__func__);
    CGRect sourceRect = CGRectMake(FILL_X(gui.scroll_region_left),
                                   FILL_Y(row),
                                   FILL_X(gui.scroll_region_right + 1) - FILL_X(gui.scroll_region_left),
                                   FILL_Y(gui.scroll_region_bot + 1) - FILL_Y(row + num_lines));
    CGRect targetRect = sourceRect;
    targetRect.origin.y = FILL_Y(row + num_lines);

//    CGRect targetRect = CGRectMake(FILL_X(gui.scroll_region_left),
//                                   FILL_Y(row + num_lines),
//                                   FILL_X(gui.scroll_region_right+1) - FILL_X(gui.scroll_region_left),
//                                   FILL_Y(gui.scroll_region_bot+1) - FILL_Y(row + num_lines));
   
    [shellView() copyRectFrom:sourceRect to:targetRect];
    gui_clear_block(row, gui.scroll_region_left,
                    row + num_lines - 1, gui.scroll_region_right);
}

/*
 * Set the current text foreground color.
 */
    void
gui_mch_set_fg_color(guicolor_T color)
{
    [shellView() setFgColor:(uint32_t)color];
//    shellView().fgcolor = CGColorCreateFromVimColor(color);
}


/*
 * Set the current text background color.
 */
    void
gui_mch_set_bg_color(guicolor_T color)
{
    [shellView() setBgColor:(uint32_t)color];
//    shellView().bgcolor = CGColorCreateFromVimColor(color);
}

/*
 * Set the current text special color (used for underlines).
 */
    void
gui_mch_set_sp_color(guicolor_T color)
{
    //    printf("%s\n",__func__);
    [shellView() setSpecialColor:(uint32_t)color];
//    shellView().spcolor = CGColorCreateFromVimColor(color);
}


/*
 * Set default colors.
 */
void gui_mch_def_colors(void) {
    gui.norm_pixel = gui_mch_get_color((char_u *)"white");
    gui.back_pixel = gui_mch_get_color((char_u *)"black");
    gui.def_back_pixel = gui.back_pixel;
    gui.def_norm_pixel = gui.norm_pixel;
}


/*
 * Called when the foreground or background color has been changed.
 */
    void
gui_mch_new_colors(void)
{
//    printf("%s\n",__func__);  
    gui.def_back_pixel = gui.back_pixel;
    gui.def_norm_pixel = gui.norm_pixel;
    gui_ios_sync_bg_color(NO);
}

/*
 * Invert a rectangle from row r, column c, for nr rows and nc columns.
 */
    void
gui_mch_invert_rectangle(int r, int c, int nr, int nc)
{
//    printf("%s\n",__func__);  
}

// -- Menu ------------------------------------------------------------------


/*
 * A menu descriptor represents the "address" of a menu as an array of strings.
 * E.g. the menu "File->Close" has descriptor { "File", "Close" }.
 */
   void
gui_mch_add_menu(vimmenu_T *menu, int idx)
{
//    printf("%s\n",__func__);  
}


/*
 * Add a menu item to a menu
 */
    void
gui_mch_add_menu_item(vimmenu_T *menu, int idx)
{
//    printf("%s\n",__func__);  
}


/*
 * Destroy the machine specific menu widget.
 */
    void
gui_mch_destroy_menu(vimmenu_T *menu)
{
//    printf("%s\n",__func__);  
}


/*
 * Make a menu either grey or not grey.
 */
    void
gui_mch_menu_grey(vimmenu_T *menu, int grey)
{
}


/*
 * Make menu item hidden or not hidden
 */
    void
gui_mch_menu_hidden(vimmenu_T *menu, int hidden)
{
//    printf("%s\n",__func__);  
}


/*
 * This is called when user right clicks.
 */
    void
gui_mch_show_popupmenu(vimmenu_T *menu)
{
//    printf("%s\n",__func__);  
}


/*
 * This is called when a :popup command is executed.
 */
    void
gui_make_popup(char_u *path_name, int mouse_pos)
{
//    printf("%s\n",__func__);  
}


/*
 * This is called after setting all the menus to grey/hidden or not.
 */
    void
gui_mch_draw_menubar(void)
{
}


    void
gui_mch_enable_menu(int flag)
{
}

    void
gui_mch_set_menu_pos(int x, int y, int w, int h)
{
//    printf("%s\n",__func__);  
    
    /*
     * The menu is always at the top of the screen.
     */
}

    void
gui_mch_show_toolbar(int showit)
{
//    printf("%s\n",__func__);  
}




// -- Fonts -----------------------------------------------------------------


/*
 * If a font is not going to be used, free its structure.
 */
    void
gui_mch_free_font(font)
    GuiFont	font;
{
//    printf("%s\n",__func__);  
}


    GuiFont
gui_mch_retain_font(GuiFont font)
{
//    printf("%s\n",__func__);  
    return font;
}


/*
 * Get a font structure for highlighting.
 */
    GuiFont
gui_mch_get_font(char_u *name, int giveErrorIfMissing)
{
//    printf("%s\n",__func__);  

    return NOFONT;
}


#if defined(FEAT_EVAL) || defined(PROTO)
/*
 * Return the name of font "font" in allocated memory.
 * TODO: use 'font' instead of 'name'?
 */
    char_u *
gui_mch_get_fontname(GuiFont font, char_u *name)
{
    return name ? vim_strsave(name) : NULL;
}
#endif


/*
 * Initialise vim to use the font with the given name.	Return FAIL if the font
 * could not be loaded, OK otherwise.
 */
    int
gui_mch_init_font(char_u *font_name, int fontset) {
    VimView * view = shellView();
    NSString * fn = nil;
    if (font_name != NULL) {
        fn = [[NSString alloc] initWithUTF8String:(const char *)font_name];
    }
    gui.norm_font = [view initFont:fn];
    gui.char_ascent = view.char_ascent;
    gui.char_width = view.char_width;
    gui.char_height = view.char_height;
    
    return OK;
}


/*
 * Set the current text font.
 */
    void
gui_mch_set_font(GuiFont font)
{
//    printf("%s\n",__func__);
}


// -- Scrollbars ------------------------------------------------------------

// NOTE: Even though scrollbar identifiers are 'long' we tacitly assume that
// they only use 32 bits (in particular when compiling for 64 bit).  This is
// justified since identifiers are generated from a 32 bit counter in
// gui_create_scrollbar().  However if that code changes we may be in trouble
// (if ever that many scrollbars are allocated...).  The reason behind this is
// that we pass scrollbar identifers over process boundaries so the width of
// the variable needs to be fixed (and why fix at 64 bit when only 32 are
// really used?).

    void
gui_mch_create_scrollbar(
	scrollbar_T *sb,
	int orient)	/* SBAR_VERT or SBAR_HORIZ */
{
//    printf("%s\n",__func__);  
}


    void
gui_mch_destroy_scrollbar(scrollbar_T *sb)
{
//    printf("%s\n",__func__);  
}


    void
gui_mch_enable_scrollbar(
	scrollbar_T	*sb,
	int		flag)
{
//    printf("%s\n",__func__);  
}


    void
gui_mch_set_scrollbar_pos(
	scrollbar_T *sb,
	int x,
	int y,
	int w,
	int h)
{
//    printf("%s\n",__func__);  
}


    void
gui_mch_set_scrollbar_thumb(
	scrollbar_T *sb,
	long val,
	long size,
	long max)
{
//    printf("%s\n",__func__);  
}


// -- Cursor ----------------------------------------------------------------


/*
 * Draw a cursor without focus.
 */
    void
gui_mch_draw_hollow_cursor(guicolor_T color)
{
    int cw = 1;
#ifdef FEAT_MBYTE
    if (mb_lefthalve(gui.row, gui.col)) {
        cw = 2;
    }
#endif
    CGRect rect = CGRectMake(FILL_X(gui.col), FILL_Y(gui.row), cw * gui.char_width, gui.char_height);
//    CGColorRef cgColor = CGColorCreateFromVimColor(color);
//    rect.size.width += 1;
//    rect.size.height += 1;
//    rect.origin.x -= 0.5;
//    rect.origin.y -= 0.5;
    [shellView() strokeRect:rect with:(uint32_t)color];
}


/*
 * Draw part of a cursor, only w pixels wide, and h pixels high.
 */
    void
gui_mch_draw_part_cursor(int w, int h, guicolor_T color)
{
    
    gui_mch_set_fg_color(color);
    
    int    left;
    
#ifdef FEAT_RIGHTLEFT
    /* vertical line should be on the right of current point */
    if (CURSOR_BAR_RIGHT)
        left = FILL_X(gui.col + 1) - w;
    else
#endif
        left = FILL_X(gui.col);
    
    CGRect rect = CGRectMake(left, FILL_Y(gui.row), (CGFloat)w, (CGFloat)h);
    [shellView() fillRect:rect with:(uint32_t)color];
}


/*
 * Cursor blink functions.
 *
 * This is a simple state machine:
 * BLINK_NONE	not blinking at all
 * BLINK_OFF	blinking, cursor is not shown
 * BLINK_ON blinking, cursor is shown
 */

    void
gui_mch_set_blinking(long wait, long on, long off)
{
//    printf("%s\n",__func__);
    VimViewController * vc = shellViewController();
    vc.blink_wait = wait;
    vc.blink_on   = on;
    vc.blink_off  = off;
}


/*
 * Start the cursor blinking.  If it was already blinking, this restarts the
 * waiting time and shows the cursor.
 */
    void
gui_mch_start_blink(void)
{
    [shellViewController() startBlink];
//    printf("%s\n",__func__);
 //   if (gui_ios.blink_timer != nil)
 //       [gui_ios.blink_timer invalidate];
 //   
 //   if (gui_ios.blink_wait && gui_ios.blink_on &&
 //       gui_ios.blink_off && gui.in_focus)
 //   {
 //       gui_ios.blink_timer = [NSTimer scheduledTimerWithTimeInterval: gui_ios.blink_wait / 1000.0
 //                                                              target: gui_ios.view_controller
 //                                                            selector: @selector(blinkCursorTimer:)
 //                                                            userInfo: nil
 //                                                             repeats: NO];
 //       gui_ios.blink_state = BLINK_ON;
 //       gui_update_cursor(TRUE, FALSE);
 //   }
}


/*
 * Stop the cursor blinking.  Show the cursor if it wasn't shown.
 */
    void
gui_mch_stop_blink(void)
{
    [shellViewController() stopBlink];
//    printf("%s\n",__func__);  
//    [gui_ios.blink_timer invalidate];
//    
////    if (gui_ios.blink_state == BLINK_OFF)
////        gui_update_cursor(TRUE, FALSE);
//    
//    gui_ios.blink_state = BLINK_NONE;
//    gui_ios.blink_timer = nil;
}


// -- Mouse -----------------------------------------------------------------


/*
 * Get current mouse coordinates in text window.
 */
    void
gui_mch_getmouse(int *x, int *y)
{
//    printf("%s\n",__func__);  
}


    void
gui_mch_setmouse(int x, int y)
{
//    printf("%s\n",__func__);  
}


    void
mch_set_mouse_shape(int shape)
{
//    printf("%s\n",__func__);  
}

     void
gui_mch_mousehide(int hide)
{
//    printf("%s\n",__func__);  
}


// -- Clip ----
//

static NSString * PboardTypeVim = @"PboardTypeVim";

    void
clip_mch_request_selection(VimClipboard *cbd)
{
//    printf("%s\n",__func__);
    UIPasteboard * pb = [UIPasteboard generalPasteboard];
    int motionType = MAUTO;
    NSString * str = nil;
    
    if([pb containsPasteboardTypes:[NSArray arrayWithObject:PboardTypeVim]]) {
        id plist = [pb valueForPasteboardType:PboardTypeVim];
        if([plist isKindOfClass:[NSArray class]] && [plist count] == 2) {
            id obj = [plist objectAtIndex:1];
            if([obj isKindOfClass:[NSString class]]) {
                motionType = [[plist objectAtIndex:0] intValue];
                str = obj;
            }
        }
    }
    
    if(!str) {
        NSString * s = [pb string];
        if(!s) { return; }
        NSMutableString * mstr = [NSMutableString stringWithString:s];
        NSRange range = {0, [mstr length]};
        [mstr replaceOccurrencesOfString:@"\r" withString:@"\n" options:0 range:range];
        str = mstr;
    }
    
    char_u * utf8Str = (char_u *)[str UTF8String];
    if(!utf8Str) { return; }
    
    if(!(motionType == MCHAR || motionType == MLINE || motionType == MBLOCK || motionType == MAUTO)) {
        motionType = MAUTO;
    }
    long len = [str lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    clip_yank_selection(motionType, utf8Str, len, cbd);
}

    void
clip_mch_set_selection(VimClipboard *cbd)
{
//    printf("%s\n",__func__);
    //fill the '*' register if not yet
    cbd->owned = TRUE;
    clip_get_selection(cbd);
    cbd->owned = FALSE;
    
    long_u llen = 0;
    char_u * str = nil;
    int motionType = clip_convert_selection(&str, &llen, cbd);
    if (motionType < 0) {
        return;
    }
    
    if(llen > 0) {
        NSString * string = [[NSString alloc] initWithBytes:str length:llen encoding:NSUTF8StringEncoding];
        UIPasteboard * pb = [UIPasteboard generalPasteboard];
        NSNumber * motion = [NSNumber numberWithInt:motionType];
        NSArray * plist = [NSArray arrayWithObjects:motion, string, nil];
        [pb setValue:plist forPasteboardType:PboardTypeVim];
        [pb setString:string];
    }
    
    vim_free(str);
}

   void
clip_mch_lose_selection(VimClipboard *cbd)
{
//    printf("%s\n",__func__);  
}

    int
clip_mch_own_selection(VimClipboard *cbd)
{
//    printf("%s\n",__func__);  
    return OK;
}


// -- Input Method ----------------------------------------------------------

#if defined(USE_IM_CONTROL)

    void
im_set_position(int row, int col)
{
//    printf("%s\n",__func__);  
}


    void
im_set_control(int enable)
{
//    printf("%s\n",__func__);  
}


    void
im_set_active(int active)
{
//    printf("%s\n",__func__);  
}


    int
im_get_status(void)
{
//    printf("%s\n",__func__);  
}

#endif // defined(USE_IM_CONTROL)





// -- Unsorted --------------------------------------------------------------



/*
 * Adjust gui.char_height (after 'linespace' was changed).
 */
    int
gui_mch_adjust_charheight(void)
{
//    printf("%s\n",__func__);  
    return OK;
}


    void
gui_mch_beep(void)
{
//    printf("%s\n",__func__);
    NSURL * url = [[NSBundle mainBundle] URLForResource:@"beep-07" withExtension:@"wav"];
    if (url != NULL) {
        SystemSoundID sid = 0;
        AudioServicesCreateSystemSoundID((__bridge CFURLRef _Nonnull)(url), &sid);
        AudioServicesPlaySystemSound(sid);
    }
}



#ifdef FEAT_BROWSE
/*
 * Pop open a file browser and return the file selected, in allocated memory,
 * or NULL if Cancel is hit.
 *  saving  - TRUE if the file will be saved to, FALSE if it will be opened.
 *  title   - Title message for the file browser dialog.
 *  dflt    - Default name of file.
 *  ext     - Default extension to be added to files without extensions.
 *  initdir - directory in which to open the browser (NULL = current dir)
 *  filter  - Filter for matched files to choose from.
 *  Has a format like this:
 *  "C Files (*.c)\0*.c\0"
 *  "All Files\0*.*\0\0"
 *  If these two strings were concatenated, then a choice of two file
 *  filters will be selectable to the user.  Then only matching files will
 *  be shown in the browser.  If NULL, the default allows all files.
 *
 *  *NOTE* - the filter string must be terminated with TWO nulls.
 */
    char_u *
gui_mch_browse(
    int saving,
    char_u *title,
    char_u *dflt,
    char_u *ext,
    char_u *initdir,
    char_u *filter)
{
//    printf("%s\n",__func__);

   
//    NSLog(@"title: %s", title);
//    NSString *dir = [NSString stringWithFormat:@"%s", initdir];
//    NSString *file = [NSString stringWithFormat:@"%s", dflt];
//    NSString *path = [dir stringByAppendingString:file];
//
//    NSLog(@"path: %@",path);
//    NSURL *url = [NSURL fileURLWithPath:path];
//
//    [shellViewController() showShareSheetForURL:url mode:@"Share"];

   // UIDocumentInteractionController *controller = [UIDocumentInteractionController interactionControllerWithURL:url];

   // 
   // 
   // int height = gui_ios.view_controller.view.bounds.size.height;
   //
   //[controller presentOptionsMenuFromRect:CGRectMake(0,height-10,10,10) inView:gui_ios.view_controller.view animated: NO];

    return NULL;
}
#endif /* FEAT_BROWSE */



    int
gui_mch_dialog(
    int		type,
    char_u	*title,
    char_u	*message,
    char_u	*buttons,
    int		dfltbutton,
    char_u	*textfield,
    int         ex_cmd)     // UNUSED
{
//    printf("%s\n",__func__);
    
//    NSString *bt = [NSString stringWithFormat:@"%s", buttons];
//
//    if([bt isEqualToString:@"Activity"]) {
//        NSString *path = [NSString stringWithFormat:@"%s", message];
//        NSURL *url = [NSURL fileURLWithPath:path];
//        
//        [shellViewController() showShareSheetForURL:url mode:@"Activity"];
//    }
//    NSLog(@"Confirm title %s", title);
//    NSLog(@"Confirm message %s", message);
//    NSLog(@"Confirm buttons %s", buttons);
//    NSLog(@"Confirm textfield %s", textfield);
    return 4;
}


    void
gui_mch_flash(int msec)
{
//    printf("%s\n",__func__);
//    NSLog(@"flash time: %d", msec);
    NSTimeInterval sec = (NSTimeInterval)msec / (NSTimeInterval)1000;
    [shellViewController() flashForSeconds:sec];
}


guicolor_T
gui_mch_get_color(char_u *name)
{
    int i;
    int r, g, b;
    
    
    typedef struct GuiColourTable
    {
        char	    *name;
        guicolor_T     colour;
    } GuiColourTable;
    
    static GuiColourTable table[] =
    {
        {"Black",       RGB(0x00, 0x00, 0x00)},
        {"DarkGray",    RGB(0xA9, 0xA9, 0xA9)},
        {"DarkGrey",    RGB(0xA9, 0xA9, 0xA9)},
        {"Gray",        RGB(0xC0, 0xC0, 0xC0)},
        {"Grey",        RGB(0xC0, 0xC0, 0xC0)},
        {"LightGray",   RGB(0xD3, 0xD3, 0xD3)},
        {"LightGrey",   RGB(0xD3, 0xD3, 0xD3)},
        {"Gray10",      RGB(0x1A, 0x1A, 0x1A)},
        {"Grey10",      RGB(0x1A, 0x1A, 0x1A)},
        {"Gray20",      RGB(0x33, 0x33, 0x33)},
        {"Grey20",      RGB(0x33, 0x33, 0x33)},
        {"Gray30",      RGB(0x4D, 0x4D, 0x4D)},
        {"Grey30",      RGB(0x4D, 0x4D, 0x4D)},
        {"Gray40",      RGB(0x66, 0x66, 0x66)},
        {"Grey40",      RGB(0x66, 0x66, 0x66)},
        {"Gray50",      RGB(0x7F, 0x7F, 0x7F)},
        {"Grey50",      RGB(0x7F, 0x7F, 0x7F)},
        {"Gray60",      RGB(0x99, 0x99, 0x99)},
        {"Grey60",      RGB(0x99, 0x99, 0x99)},
        {"Gray70",      RGB(0xB3, 0xB3, 0xB3)},
        {"Grey70",      RGB(0xB3, 0xB3, 0xB3)},
        {"Gray80",      RGB(0xCC, 0xCC, 0xCC)},
        {"Grey80",      RGB(0xCC, 0xCC, 0xCC)},
        {"Gray90",      RGB(0xE5, 0xE5, 0xE5)},
        {"Grey90",      RGB(0xE5, 0xE5, 0xE5)},
        {"White",       RGB(0xFF, 0xFF, 0xFF)},
        {"DarkRed",     RGB(0x80, 0x00, 0x00)},
        {"Red",         RGB(0xFF, 0x00, 0x00)},
        {"LightRed",    RGB(0xFF, 0xA0, 0xA0)},
        {"DarkBlue",    RGB(0x00, 0x00, 0x80)},
        {"Blue",        RGB(0x00, 0x00, 0xFF)},
        {"LightBlue",   RGB(0xAD, 0xD8, 0xE6)},
        {"SlateBlue",   RGB(0x6A, 0x5A, 0xCD)},
        {"DarkGreen",   RGB(0x00, 0x80, 0x00)},
        {"Green",       RGB(0x00, 0xFF, 0x00)},
        {"LightGreen",  RGB(0x90, 0xEE, 0x90)},
        {"SeaGreen",    RGB(0x2E, 0x8B, 0x57)},
        {"DarkCyan",    RGB(0x00, 0x80, 0x80)},
        {"Cyan",        RGB(0x00, 0xFF, 0xFF)},
        {"LightCyan",   RGB(0xE0, 0xFF, 0xFF)},
        {"DarkMagenta", RGB(0x80, 0x00, 0x80)},
        {"Magenta",	RGB(0xFF, 0x00, 0xFF)},
        {"LightMagenta",RGB(0xFF, 0xA0, 0xFF)},
        {"Brown",       RGB(0x80, 0x40, 0x40)},
	{"DarkYellow",	RGB(0xBB, 0xBB, 0x00)},
        {"Yellow",      RGB(0xFF, 0xFF, 0x00)},
        {"LightYellow", RGB(0xFF, 0xFF, 0xE0)},
        {"Orange",      RGB(0xFF, 0xA5, 0x00)},
        {"Purple",      RGB(0xA0, 0x20, 0xF0)},
        {"Violet",      RGB(0xEE, 0x82, 0xEE)},
    };
    
    /* is name #rrggbb format? */
    if (name[0] == '#' && STRLEN(name) == 7)
    {
        r = (hex_digit(name[1]) << 4) + hex_digit(name[2]);
        g = (hex_digit(name[3]) << 4) + hex_digit(name[4]);
        b = (hex_digit(name[5]) << 4) + hex_digit(name[6]);
        if (r < 0 || g < 0 || b < 0)
            return INVALCOLOR;
        return RGB(r, g, b);
    }
    
    for (i = 0; i < ARRAY_LENGTH(table); i++)
    {
        if (STRICMP(name, table[i].name) == 0)
            return table[i].colour;
    }
    
    /*
     * Last attempt. Look in the file "$VIMRUNTIME/rgb.txt".
     */
    {
#define LINE_LEN 100
        FILE	*fd;
        char	line[LINE_LEN];
        char_u	*fname;
        
        fname = expand_env_save((char_u *)"$VIMRUNTIME/rgb.txt");
        if (fname == NULL)
            return INVALCOLOR;
        
        fd = fopen((char *)fname, "rt");
        vim_free(fname);
        if (fd == NULL)
            return INVALCOLOR;
        
        while (!feof(fd))
        {
            int	    len;
            int	    pos;
            char    *color;
            
            fgets(line, LINE_LEN, fd);
            len = (int)STRLEN(line);
            
            if (len <= 1 || line[len-1] != '\n')
                continue;
            
            line[len-1] = '\0';
            
            i = sscanf(line, "%d %d %d %n", &r, &g, &b, &pos);
            if (i != 3)
                continue;
            
            color = line + pos;
            
            if (STRICMP(color, name) == 0)
            {
                fclose(fd);
                return (guicolor_T)RGB(r, g, b);
            }
        }
        
        fclose(fd);
    }
    
    
    return INVALCOLOR;
}



/*
 * Return the RGB value of a pixel as long.
 */
    long_u
gui_mch_get_rgb(guicolor_T pixel)
{
//    printf("%s\n",__func__);  
    
    // This is only implemented so that vim can guess the correct value for
    // 'background' (which otherwise defaults to 'dark'); it is not used for
    // anything else (as far as I know).
    // The implementation is simple since colors are stored in an int as
    // "rrggbb".
    return pixel;
}


/*
 * Get the screen dimensions.
 * Understandably, Vim doesn't quite like it when the screen size changes
 * But on the iOS the screen is rotated quite often. So let's just pretend
 * that the screen is actually square, and large enough to contain the
 * actual screen in both portrait and landscape orientations.
 */
    void
gui_mch_get_screen_dimensions(int *screen_w, int *screen_h)
{
    CGSize size = [shellView() bounds].size;
    
    
//    CGSize appSize = [[UIScreen mainScreen] applicationFrame].size;
    int largest_dimension = MAX((int)size.width, (int)size.height);
    *screen_w = largest_dimension;
    *screen_h = largest_dimension;
}


/*
 * Return OK if the key with the termcap name "name" is supported.
 */
    int
gui_mch_haskey(char_u *name)
{
//    printf("%s\n",__func__);  
    return OK;
}


/*
 * Iconify the GUI window.
 */
    void
gui_mch_iconify(void)
{
//    printf("%s\n",__func__);  
    
}


#if defined(FEAT_EVAL) || defined(PROTO)
/*
 * Bring the Vim window to the foreground.
 */
    void
gui_mch_set_foreground(void)
{
//    printf("%s\n",__func__);  
}
#endif



    void
gui_mch_set_shellsize(
    int		width,
    int		height,
    int		min_width,
    int		min_height,
    int		base_width,
    int		base_height,
    int		direction)
{
//    printf("%s\n",__func__);
//    CGSize layerSize = CGLayerGetSize(gui_ios.layer);
//    gui_resize_shell(layerSize.width, layerSize.height);
    [shellView() resizeShell];
}


/*
 * Set the position of the top left corner of the window to the given
 * coordinates.
 */
    void
gui_mch_set_winpos(int x, int y)
{
//    printf("%s\n",__func__);  
}


/*
 * Get the position of the top left corner of the window.
 */
    int
gui_mch_get_winpos(int *x, int *y)
{
//    printf("%s\n",__func__);  
    return OK;
}


    void
gui_mch_set_text_area_pos(int x, int y, int w, int h)
{
//    printf("%s\n",__func__);  
}



#ifdef FEAT_TITLE
/*
 * Set the window title and icon.
 * (The icon is not taken care of).
 */
    void
gui_mch_settitle(char_u *title, char_u *icon)
{
//    int length = STRLEN(title);
//    NSLog(@"%s\n",__func__);
//    NSLog(@"Title %i", length);
}
#endif



    void
gui_mch_toggle_tearoffs(int enable)
{
//    printf("%s\n",__func__);  
}



    void
gui_mch_enter_fullscreen(int fuoptions_flags, guicolor_T bg)
{
//    printf("%s\n",__func__);  
}


    void
gui_mch_leave_fullscreen()
{
//    printf("%s\n",__func__);  
}


    void
gui_mch_fuopt_update()
{
//    printf("%s\n",__func__);  
}





#if defined(FEAT_SIGN_ICONS)
    void
gui_mch_drawsign(int row, int col, int typenr)
{
//    printf("%s\n",__func__);  
}

    void *
gui_mch_register_sign(char_u *signfile)
{
//    printf("%s\n",__func__);  
   return NULL;
}

    void
gui_mch_destroy_sign(void *sign)
{
//    printf("%s\n",__func__);  
}

#endif // FEAT_SIGN_ICONS



// -- Balloon Eval Support ---------------------------------------------------

#ifdef FEAT_BEVAL

    BalloonEval *
gui_mch_create_beval_area(target, mesg, mesgCB, clientData)
    void	*target;
    char_u	*mesg;
    void	(*mesgCB)__ARGS((BalloonEval *, int));
    void	*clientData;
{
//    printf("%s\n",__func__);  

    return NULL;
}

    void
gui_mch_enable_beval_area(beval)
    BalloonEval	*beval;
{
//    printf("%s\n",__func__);  
}

    void
gui_mch_disable_beval_area(beval)
    BalloonEval	*beval;
{
//    printf("%s\n",__func__);  
}

/*
 * Show a balloon with "mesg".
 */
    void
gui_mch_post_balloon(beval, mesg)
    BalloonEval	*beval;
    char_u	*mesg;
{
//    printf("%s\n",__func__);  
}

#endif // FEAT_BEVAL
