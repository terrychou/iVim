//
//  ios_term.m
//  iVim
//
//  Created by Terry Chou on 11/30/19.
//  Copyright © 2019 Boogaloo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ios_system/ios_system.h>
#import "vim.h"
#include <pthread.h>
#import <ivish/ivish.h>


static void log_failure(const char *attempt, char_u *cmd);
static const char *sid_from_session_id(NSString *session_id)
{
    return [session_id cStringUsingEncoding:NSUTF8StringEncoding];
}

typedef NSMutableDictionary<NSString *, id> ProcessInfo;
typedef NSMutableDictionary<NSString *, ProcessInfo *> ProcessTable;
static NSString *kProcessInfoSessionID = @"PISessionID";
static NSString *kProcessInfoExitCode = @"PIExitCode";
static NSString *kProcessInfoSAHandler = @"PISAHandler";
typedef void (^SessionSwitchTask)(NSString *sessionID);

static dispatch_queue_t barrier_queue(void)
{
    static dispatch_queue_t queue;
    if (queue == nil) {
        queue = dispatch_queue_create("com.terrychou.ivim.cmdsbarrier", DISPATCH_QUEUE_CONCURRENT);
    }
    
    return queue;
}

static ProcessTable *process_table(void)
{
    static ProcessTable *table;
    if (table == nil) {
        table = [ProcessTable dictionary];
    }
    
    return table;
}

static NSString *key_for_pid(pid_t pid)
{
    return [NSString stringWithFormat:@"%ld", (long)pid];
}

static id safe_entry_of(NSMutableDictionary *dic,
                        NSString *key,
                        id (^ __nullable new_entry_maker)(void))
{
    id ret = dic[key];
    if (ret == nil && new_entry_maker) {
        ret = new_entry_maker();
        dic[key] = ret;
    }
    
    return ret;
}

static void change_process_table_safely(void (^task)(ProcessTable *table))
{
    dispatch_barrier_async(barrier_queue(), ^{
        task(process_table());
    });
}

static void read_process_table_safely(void (^task)(ProcessTable * table))
{
    dispatch_sync(barrier_queue(), ^{
        task(process_table());
    });
}

static BOOL has_process(pid_t pid)
{
    __block BOOL ret = NO;
    read_process_table_safely(^(ProcessTable *table) {
        ret = (table[key_for_pid(pid)] != nil);
    });
    
    return ret;
}

static void change_process_info_safely(pid_t pid, void (^task)(ProcessInfo *info))
{
    change_process_table_safely(^(ProcessTable *table) {
        NSString *key = key_for_pid(pid);
        ProcessInfo *info = table[key];
        if (info == nil) {
            info = [ProcessInfo dictionary];
            table[key] = info;
        }
        task(info);
    });
}

static void read_process_info_safely(pid_t pid, void (^task)( ProcessInfo *info))
{
    read_process_table_safely(^(ProcessTable *table) {
        ProcessInfo *info = table[key_for_pid(pid)];
        if (info != nil) {
            task(info);
        }
    });
}

static void delete_process_info(pid_t pid)
{
    change_process_table_safely(^(ProcessTable *table) {
        table[key_for_pid(pid)] = nil;
    });
}

static NSNumber *process_exit_code(pid_t pid)
{
    __block NSNumber *ret = nil;
    read_process_info_safely(pid, ^(ProcessInfo *info) {
        ret = info[kProcessInfoExitCode];
    });
    
    return ret;
}

static void switch_to_session_for_pid_safely(pid_t pid,
                                             SessionSwitchTask task)
{
    
    static NSString *currentSessionID;
    @synchronized (currentSessionID) {
        __block NSString *session_id = nil;
        read_process_info_safely(pid, ^(ProcessInfo *info) {
            session_id = info[kProcessInfoSessionID];
        });
        if (session_id == nil) {
            session_id = [[NSUUID UUID] UUIDString];
            change_process_info_safely(pid, ^(ProcessInfo *info) {
                info[kProcessInfoSessionID] = session_id;
            });
        }
        if (![currentSessionID isEqualToString:session_id]) {
            ios_switchSession(sid_from_session_id(session_id));
            currentSessionID = session_id;
        }
        task(session_id);
    }
}

static void update_process_exit_code(pid_t pid)
{
    switch_to_session_for_pid_safely(pid, ^(NSString *sessionID) {
        change_process_info_safely(pid, ^(ProcessInfo *info) {
            info[kProcessInfoExitCode] = [NSNumber numberWithInt:ios_getCommandStatus()];
        });
    });
}

typedef NSMutableDictionary<NSString *, NSString *> EnvCache;
static EnvCache *child_env(void)
{
    static EnvCache *env;
    if (env == nil) {
        env = [EnvCache dictionary];
    }
    
    return env;
}

static NSString *env_str_from(const char *cstr)
{
    return [NSString stringWithUTF8String:cstr];
}

static const char *env_cstr_from(NSString *str)
{
    return [str UTF8String];
}

static void deploy_env_cache(EnvCache *cache)
{
    for (NSString *key in cache) {
        setenv(env_cstr_from(key),
               env_cstr_from(cache[key]),
               1);
    }
    [cache setDictionary:@{}];
}

void ios_term_setenv(const char *name, const char *value)
{
    EnvCache *env = child_env();
    [env setValue:env_str_from(value)
           forKey:env_str_from(name)];
}

typedef NSArray<NSNumber *> SignalList;
static SignalList *signals_cared_about(void)
{
    static SignalList *signals;
    if (signals == nil) {
        signals = @[
            @SIGINT,
        ];
    }
    
    return signals;
}

static NSString *key_for_signal(int sig)
{
    return [NSString stringWithFormat:@"%d", sig];
}

typedef void (*signal_handler)(int);
static void try_signal_handler(int sig, void (^task)(signal_handler))
{
    struct sigaction sa;
    if (sigaction(sig, NULL, &sa) >= 0 &&
        sa.sa_handler != SIG_IGN &&
        sa.sa_handler != SIG_DFL) {
//        NSLog(@"got signal handler: %p", sa.sa_handler);
        task(sa.sa_handler);
    }
}

void ios_term_register_process_signal_handlers(pid_t pid)
{
    static pid_t previous_pid = -1;
    if (has_process(previous_pid)) {
        // there is a previous process
//        NSLog(@"update handler for pid: %d", previous_pid);
        NSMutableDictionary *table = [NSMutableDictionary dictionary];
        int sig;
        for (NSNumber *signal in signals_cared_about()) {
            sig = [signal intValue];
            try_signal_handler(sig, ^(signal_handler handler) {
                [table
                 setValue:[NSValue valueWithPointer:handler]
                 forKey:key_for_signal(sig)];
            });
        }
        if ([table count] > 0) {
            change_process_info_safely(previous_pid, ^(ProcessInfo *info) {
                info[kProcessInfoSAHandler] = table;
            });
        }
    }
    previous_pid = pid;
//    NSLog(@"set new previous pid: %d", pid);
}

static signal_handler handler_for_pid(pid_t pid, int sig)
{
    __block signal_handler handler = nil;
    read_process_info_safely(pid, ^(ProcessInfo *info) {
        NSDictionary *table = info[kProcessInfoSAHandler];
        if (table != nil) {
            handler = [table[key_for_signal(sig)] pointerValue];
        }
    });
    
    return handler;
}

// --------------- ivish callbacks ------------------
void shell_cmds_matching(const char *pat, void (^task)(NSString *));
static NSArray<NSString *>  * _Nonnull ivish_available_cmds(NSString * _Nullable pattern)
{
    NSMutableArray<NSString *> *ret = [NSMutableArray array];
    shell_cmds_matching([pattern UTF8String], ^(NSString *cmd) {
        if ([cmd length] > 0) {
            [ret addObject:cmd];
        }
    });
    
    return ret;
}

static void run_ex_command(NSString * _Nonnull cmd)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        do_cmdline_cmd((char_u *)[cmd UTF8String]);
    });
}

static NSArray<NSString *> * _Nonnull ivish_expand_filenames(NSString * _Nonnull pattern)
{
    int fcount;
    int fi;
    char_u **fnames;
    char_u *pat = (char_u *)[pattern UTF8String];
    int flags = EW_DIR|EW_FILE|EW_ADDSLASH|EW_SILENT;
    NSMutableArray<NSString *> *ret = [NSMutableArray array];
    
    if (gen_expand_wildcards(1, &pat, &fcount, &fnames, flags) == OK &&
        fcount > 0) {
        for (fi = 0; fi < fcount; fi++) {
            [ret addObject:
             [NSString stringWithUTF8String:(char *)fnames[fi]]];
        }
        FreeWild(fcount, fnames);
    }
    
    return ret;
}

static ivish_callbacks_t ivish_callbacks = {
    ivish_available_cmds,
    run_ex_command,
    char2cells,
    ivish_expand_filenames,
};

// --------------- /ivish callbacks ------------------

typedef void (^ __nullable CommandCompletion)(void);
static void ios_term_run(char_u *name,
                              pid_t pid,
                              void (^task)(void),
                              CommandCompletion completion,
                              int in_fd,
                              int out_fd,
                              int err_fd)
{
    // return session ID if succeeded; nil otherwise.
    static dispatch_queue_t cmd_queue;
    if (cmd_queue == NULL) {
        cmd_queue = dispatch_queue_create(
                        "com.terrychou.ivim.cmds",
                        DISPATCH_QUEUE_CONCURRENT);
    }
    FILE *in_file = nil;
    FILE *out_file = nil;
    FILE *err_file = nil;
//    NSLog(@"pid: %d", pid);
//    NSLog(@"in fd: %d", in_fd);
//    NSLog(@"out fd: %d", out_fd);
//    NSLog(@"err fd: %d", err_fd);
    // setup input stream
    if ((in_file = fdopen(in_fd, "rb")) == NULL) {
        log_failure("open stdin stream", name);
        return;
    }
    // setup output stream
    if ((out_file = fdopen(out_fd, "wb")) == NULL) {
        log_failure("open stdout stream", name);
        fclose(in_file);
        return;
    }
    // setup error stream
    if (err_fd == out_fd) {
        err_file = out_file;
    } else if (err_fd >= 0) {
        if ((err_file = fdopen(err_fd, "wb")) == NULL) {
            log_failure("open stderr stream", name);
            fclose(in_file);
            fclose(out_file);
            return;
        }
    }
    
    BOOL is_ivish = (strstr((char *)name, "ivish") != NULL);
    // start command asynchronously
    dispatch_async(cmd_queue, ^{
        __block NSString *session_id = nil;
        switch_to_session_for_pid_safely(pid, ^(NSString *sessionID) {
            session_id = sessionID;
            thread_stdin = nil;
            thread_stdout = nil;
            thread_stderr = nil;
            if (is_ivish) {
                ios_setContext(&ivish_callbacks);
            }
            ios_setStreams(in_file, out_file, err_file);
            deploy_env_cache(child_env());
        });
        task();
        fclose(in_file);
        if (err_file != out_file) {
            fclose(err_file);
        }
        fclose(out_file);
        if (completion) {
            completion();
        }
        update_process_exit_code(pid);
        ios_closeSession(sid_from_session_id(session_id));
    });
}

void ios_term_run_shell_cmd(char_u *cmd,
                            pid_t pid,
                            int toshell_fd,
                            int fromshell_fd)
{
    ios_term_run(cmd,
                 pid,
                 ^{ ios_system((char *)cmd); },
                 nil,
                 toshell_fd,
                 fromshell_fd,
                 fromshell_fd);
}

int ios_term_null_fd(void)
{
    return [[NSFileHandle fileHandleWithNullDevice] fileDescriptor];
}

static char *replacing_in(const char *ori,
                          const char *old,
                          const char *new)
{
    char *ret = (char *)ori;
    int i;
    int cnt = 0;
    size_t old_len = strlen(old);
    size_t new_len = strlen(new);
    
    // count old occurrences
    for (i = 0; ori[i] != '\0'; i++) {
        if (strncmp(&ori[i], new, new_len) == 0) {
            // if new word found first, don't count it
            i += new_len - 1;
        } else if (strncmp(&ori[i], old, old_len) == 0) {
            cnt++;
            // jump to after the matched old
            i += old_len - 1;
        }
    }
    
    // if found any, do the replacement
    if (cnt > 0) {
        // allocate memory for the result
        ret = (char *)malloc(i + cnt * (new_len - old_len) + 1);
        i = 0;
        while (*ori) {
            if (strncmp(ori, new, new_len) == 0) {
                strcpy(&ret[i], new);
                i += new_len;
                ori += new_len;
            } else if (strncmp(ori, old, old_len) == 0) {
                strcpy(&ret[i], new);
                i += new_len;
                ori += old_len;
            } else {
                ret[i++] = *ori++;
            }
        }
        ret[i] = '\0';
    }
    
    return ret;
}

char_u *ios_term_translate_msg(char_u *msg)
{
    return (char_u *)replacing_in((char *)msg, "\n", "\r\n");
}

__attribute__ ((optnone)) pid_t ios_term_waitpid(pid_t pid,
                                                 int *stat_loc,
                                                 int options)
{
    pid_t ret = pid;
    NSNumber *exit_code = nil;
    if (options && WNOHANG) {
        // WNOHANG: just check that the process is still running:
        exit_code = process_exit_code(pid);
        if (exit_code == nil) {
            // the process is still running
            ret = 0;
        }
    } else {
        // Wait until the process is terminated:
        while (exit_code == nil) {
            exit_code = process_exit_code(pid);
        }
    }
    if (exit_code != nil) {
        if (stat_loc) {
            *stat_loc = W_EXITCODE([exit_code intValue], 0);
        }
        // process exited, delete its info from process table
        delete_process_info(pid);
    }
    
    return ret;
}

static void log_failure(const char *attempt, char_u *cmd) {
    NSLog(@"failed to %s for shell command '%s'.", attempt, cmd);
}

static NSDictionary *cmd_personalities() {
    static NSDictionary *pts;
    if (pts == nil) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"commandPersonalities"
                                                         ofType:@"plist"];
        NSError *err = nil;
        NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&err];
        if (!err) {
            pts = [NSPropertyListSerialization propertyListWithData:data
                                                            options:NSPropertyListImmutable
                                                             format:NULL
                                                              error:&err];
        }
        if (err) {
            NSLog(@"failed to read command personalities: %@", err);
        }
    }
    
    return pts;
}

static BOOL try_sigaction_handler(int sig, pid_t pid) {
    __block BOOL ret = NO;
    signal_handler handler = handler_for_pid(pid, sig);
    if (handler != nil) {
        handler(sig);
        ret = YES;
    } else {
        try_signal_handler(sig, ^(signal_handler handler) {
            handler(sig);
            ret = YES;
        });
    }
    
    return ret;
}

typedef void (^EchoCharAction)(char_u c);
typedef void (^EchoStringAction)(char_u *s, int len);

static void handle_interrupt(pid_t pid,
                             int *need_write,
                             int *got_eof,
                             char_u *ta_buf,
                             int i,
                             int *nbytes,
                             EchoCharAction echo_char) {
    NSString *prog_name = [NSString stringWithCString:ios_progname()
                                             encoding:NSUTF8StringEncoding];
    NSString *int_action = (cmd_personalities()[prog_name] ?: @{})[@"intaction"];
    NSLog(@"interrupt command '%@': '%@'", prog_name, int_action);
    if ([int_action isEqualToString:@"thread_kill"]) {
        pthread_kill(ios_getThreadId(pid), SIGINT);
    } else if ([int_action isEqualToString:@"handler_func"] ||
               [int_action isEqualToString:@"handler_func_nl"]) {
        try_sigaction_handler(SIGINT, pid);
        if ([int_action isEqualToString:@"handler_func_nl"]) {
            echo_char('\n');
            ta_buf[i] = '\n';
            *nbytes = 1;
            *need_write = TRUE;
        }
    } else if ([int_action isEqualToString:@"thread_cancel"]) {
        pthread_cancel(ios_getThreadId(pid));
    } else if ([int_action isEqualToString:@"end_of_file"]) {
        *got_eof = TRUE;
        *need_write = TRUE;
    } else {
        if (!try_sigaction_handler(SIGINT, pid)) {
            pthread_cancel(ios_getThreadId(pid));
        }
    }
}

static void simple_readline(char_u *ta_buf,
                            int len,
                            NSMutableString *line,
                            pid_t pid,
                            int out_fd,
                            EchoCharAction echo_char,
                            EchoStringAction echo_str,
                            void (^after_echo_action)(void),
                            void (^got_eof_action)(void)) {
    int c;
    int i;
    int got_eof = FALSE;
    int need_write = FALSE;
    
    /* replace K_BS by <BS> and K_DEL by <DEL> */
    for (i = 0; i < len; ++i) {
        if (ta_buf[i] == CSI && len - i > 2) {
            c = TERMCAP2KEY(ta_buf[i + 1], ta_buf[i + 2]);
            if (c == K_DEL || c == K_KDEL || c == K_BS) {
                mch_memmove(ta_buf + i + 1, ta_buf + i + 3,
                            (size_t)(len - i - 2));
                if (c == K_DEL || c == K_KDEL)
                    ta_buf[i] = DEL;
                else
                    ta_buf[i] = Ctrl_H;
                len -= 2;
            }
        }
        else if (ta_buf[i] == '\r')
            ta_buf[i] = '\n';
        if (has_mbyte)
            i += (*mb_ptr2len_len)(ta_buf + i, len - i) - 1;
    }
    
    // echo the typed characters
    int nbytes;
    for (i = 0; i < len; ++i) {
        nbytes = 0;
        if (ta_buf[i] == Ctrl_C || ta_buf[i] == intr_char) {
            echo_char(Ctrl_C);
            handle_interrupt(pid,
                             &need_write,
                             &got_eof,
                             ta_buf,
                             i,
                             &nbytes,
                             echo_char);
        } else if (ta_buf[i] == Ctrl_D) {
            need_write = TRUE;
            got_eof = TRUE;
            echo_char(ta_buf[i]);
            break;
        } else if (ta_buf[i] == '\n') {
            need_write = TRUE;
            nbytes = 1;
            echo_char('\n');
        } else if (ta_buf[i] == '\b') {
            NSUInteger ll = [line length];
            if (ll == 0) {
                continue;
            }
            NSRange lastChar = NSMakeRange(ll - 1, 1);
            NSRange lastComposed = [line rangeOfComposedCharacterSequencesForRange:lastChar];
            NSString *lc = [line substringWithRange:lastComposed];
            char_u *cs = (char_u *)[lc cStringUsingEncoding:NSUTF8StringEncoding];
            int n = ptr2cells(cs);
            while (n > 0) {
                echo_char('\b');
                echo_char(' ');
                echo_char('\b');
                n--;
            }
            // this remove the shown char
//            echo_char(' ');
//            echo_char('\b');
            // remove it from the storage
            [line deleteCharactersInRange:lastComposed];
        } else if (has_mbyte) {
            int l = (*mb_ptr2len)(ta_buf + i);
            echo_str(ta_buf + i, l);
            nbytes = l;
        } else {
            echo_char(ta_buf[i]);
            nbytes = 1;
        }
        if (nbytes > 0) {
            NSString *new = [[NSString alloc]
                             initWithBytes:ta_buf + i
                             length:nbytes
                             encoding:NSUTF8StringEncoding];
            if (new != nil) {
                [line appendString:new];
            }
            if (nbytes > 1) {
                i += nbytes - 1;
            }
        }
    }
    after_echo_action();
    
//    NSLog(@"line: '%@'", line);
    // write to the external cmd
    if (need_write && out_fd >= 0) {
        write(out_fd,
              [line cStringUsingEncoding:NSUTF8StringEncoding],
              (size_t)[line lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
        [line setString:@""];
        if (got_eof) {
            close(out_fd);
            got_eof_action();
        }
    }
}

void ios_term_readline(char_u *ta_buf, int len,
                       int *got_int,
                       pid_t pid, int *toshell_fd) {
    static NSMutableString *line;
    if (line == nil) {
        line = [NSMutableString string];
    }
    simple_readline(ta_buf,
                    len,
                    line,
                    pid,
                    *toshell_fd,
                    ^(char_u c) { // echo char action
        switch (c) {
            case Ctrl_C:
                *got_int = TRUE;
            case Ctrl_D:
                msg_outtrans_len(&c, 1);
                break;
            default:
                msg_putchar(c);
                break;
        }
    }, ^(char_u *s, int len) { // echo string action
        msg_outtrans_len(s, len);
    }, ^{ // after echo action
        windgoto(msg_row, msg_col);
        out_flush();
    }, ^{ // got eof action
        *toshell_fd = -1;
    });
}

typedef NSMutableDictionary ChannelInfo;
typedef NSMutableDictionary<NSString *, ChannelInfo *> ChannelInfoTable;
static NSString *kChannelInfoReadline = @"CIReadline";
static NSString *kChannelInfoEchoFd = @"CIEchoFd";
static NSString *kChannelInfoPID = @"CIProcessID";
static NSString *kChannelInfoProgName = @"CIProgName";

static ChannelInfoTable *channel_info_table(void)
{
    static ChannelInfoTable *table;
    if (table == nil) {
        table = [NSMutableDictionary dictionary];
    }
    
    return table;
}

static NSString *key_for_channel(channel_T *channel)
{
    return [NSString stringWithFormat:@"%p", channel];
}

static NSMutableDictionary *info_for_channel(channel_T *channel)
{
    return safe_entry_of(channel_info_table(),
                         key_for_channel(channel),
                         ^{ return [ChannelInfo dictionary]; });
}

static NSMutableString *readline_for_channel(channel_T *channel)
{
    return safe_entry_of(info_for_channel(channel),
                         kChannelInfoReadline,
                         ^{ return [NSMutableString string]; });
}

//static pid_t pid_for_channel(channel_T *channel)
//{
//    NSNumber *num = info_for_channel(channel)[kChannelInfoPID];
//
//    return num != nil ? [num intValue] : -1;
//}

static void delete_info_for_channel_key(NSString *key)
{
    [channel_info_table() removeObjectForKey:key];
}

static NSString *command_term_mode(NSString *cmd)
{
    return [[cmd_personalities() valueForKey:cmd]
            valueForKey:@"termmode"] ?: @"line";
}

static BOOL is_terminal_channel(channel_T *channel)
{
    buf_T *buffer = channel->ch_part[PART_OUT].ch_bufref.br_buf;
    
    return (buffer != NULL && buffer->b_term != NULL);
}

static void set_info_for_channel(channel_T *channel,
                                 NSDictionary *info)
{
    for (NSString *key in info) {
        [info_for_channel(channel) setValue:info[key] forKey:key];
    }
}

int ios_execv(const char *path, char* const argv[]);
void ios_term_cmd_execv(const char *path,
                        char * const argv[],
                        pid_t pid,
                        int in_fd,
                        int out_fd,
                        int err_fd,
                        channel_T *channel)
{
    CommandCompletion completion = nil;
    if (channel != NULL) {
        NSString *key = key_for_channel(channel);
        completion = ^{ delete_info_for_channel_key(key); };
        set_info_for_channel(channel, @{
            kChannelInfoPID: [NSNumber numberWithInt:pid],
            kChannelInfoEchoFd: [NSNumber numberWithInt:out_fd],
        });
    }
    ios_term_run((char_u *)path,
                 pid,
                 ^{ ios_execv(path, argv); },
                 completion,
                 in_fd,
                 out_fd,
                 err_fd);
}

static BOOL should_handle_input_for_channel(channel_T *channel)
{
    ChannelInfo *ci = info_for_channel(channel);
    __block NSString *progname = ci[kChannelInfoProgName];
    if (progname == nil) {
        pid_t pid = channel->ch_job->jv_pid;
        switch_to_session_for_pid_safely(pid, ^(NSString *sessionID) {
            progname = [NSString stringWithUTF8String:ios_progname()];
        });
        ci[kChannelInfoProgName] = progname;
    }
    if (progname == nil) {
        NSLog(@"failed to retrieve program name.");
        return NO;
    }
    if(![command_term_mode(progname) isEqualToString:@"line"]) {
        // only handle for term mode "line"
        return NO;
    }
    
    return YES;
}

static int echo_fd_for_channel(channel_T *channel)
{
    return [info_for_channel(channel)[kChannelInfoEchoFd] intValue];
}

int ios_term_handle_channel_input(channel_T *channel,
                                  char_u *buf,
                                  size_t len)
{
    // return OK if handled, otherwise FAIL
    // leave non-term channel alone
    if (!is_terminal_channel(channel) ||
        !should_handle_input_for_channel(channel)) {
        return FAIL;
    }
    
    NSMutableString *line = readline_for_channel(channel);
    char_u *ta_buf = (char_u *)malloc(len + MAX(len, 100));
    vim_strncpy(ta_buf, buf, len);
    int out_fd = echo_fd_for_channel(channel);
    pid_t pid = channel->ch_job->jv_pid;
    switch_to_session_for_pid_safely(pid, ^(NSString *sessionID) {
        simple_readline(ta_buf,
                        (int)len,
                        line,
                        pid,
                        channel->ch_part[PART_IN].ch_fd,
                        ^(char_u c) { // echo char action
            switch (c) {
                case Ctrl_C:
                case Ctrl_D:
                    write(out_fd, transchar(c), 2);
                    break;
                case '\n':
                    write(out_fd, "\r\n", 2);
                    break;
                default:
                    write(out_fd, &c, 1);
                    break;
            }
        }, ^(char_u *s, int len) { // echo string action
            write(out_fd, s, len);
        }, ^{ // after echo action
            // nothing to do
        }, ^{ // got eof action
            // nothing to do
        });
    });
    free(ta_buf);
    
    return OK;
}
