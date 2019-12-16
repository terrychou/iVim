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


static void log_failure(const char *attempt, char_u *cmd);

void ios_term_run_cmd(char_u *cmd, int toshell_fd, int fromshell_fd) {
    static dispatch_queue_t cmd_queue;
    if (cmd_queue == NULL) {
        cmd_queue = dispatch_queue_create(
                        "com.terrychou.ivim.shellcmds",
                        DISPATCH_QUEUE_CONCURRENT);
    }
    FILE *stdin_file = nil;
    FILE *stdout_file = nil;
    
    // setup stdin
    if ((stdin_file = fdopen(toshell_fd, "rb")) == NULL) {
        log_failure("open stdin stream", cmd);
        return;
    }
    
    // setup stdout & stderr
    if ((stdout_file = fdopen(fromshell_fd, "wb")) == NULL) {
        log_failure("open stdout stream", cmd);
        fclose(stdin_file);
        return;
    }
    
    // start running cmd
    dispatch_async(cmd_queue, ^{
        const char *sid = [[[NSUUID UUID] UUIDString] cStringUsingEncoding:NSUTF8StringEncoding];
        ios_switchSession(sid);
        thread_stdin = nil;
        thread_stdout = nil;
        thread_stderr = nil;
        ios_setStreams(stdin_file, stdout_file, stdout_file);
        ios_system((char *)cmd);
//        fclose(stdin_file);
//        fclose(stdout_file);
        ios_closeSession(sid);
    });
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

static BOOL try_sigaction_handler(int sig) {
    BOOL ret = NO;
    struct sigaction sa;
    if (sigaction(sig, NULL, &sa) >= 0 &&
        sa.sa_handler != SIG_IGN &&
        sa.sa_handler != SIG_DFL) {
        sa.sa_handler(sig);
        ret = YES;
    }
    
    return ret;
}

void ios_term_interrupt(pid_t pid,
                        int *need_write,
                        int *got_eof,
                        char_u *ta_buf,
                        int i,
                        int *nbytes) {
    NSString *prog_name = [NSString stringWithCString:ios_progname()
                                             encoding:NSUTF8StringEncoding];
    NSString *int_action = (cmd_personalities()[prog_name] ?: @{})[@"intaction"];
    NSLog(@"interrupt command '%@': '%@'", prog_name, int_action);
    if ([int_action isEqualToString:@"thread_kill"]) {
        pthread_kill(ios_getThreadId(pid), SIGINT);
    } else if ([int_action isEqualToString:@"handler_func"] ||
               [int_action isEqualToString:@"handler_func_nl"]) {
        try_sigaction_handler(SIGINT);
        if ([int_action isEqualToString:@"handler_func_nl"]) {
            msg_putchar('\n');
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
        if (!try_sigaction_handler(SIGINT)) {
            pthread_cancel(ios_getThreadId(pid));
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
            *got_int = TRUE;
            msg_outtrans_len(ta_buf + i, 1);
            ios_term_interrupt(pid, &need_write, &got_eof, ta_buf, i, &nbytes);
        } else if (ta_buf[i] == Ctrl_D) {
            need_write = TRUE;
            got_eof = TRUE;
            msg_outtrans_len(ta_buf + i, 1);
            break;
        } else if (ta_buf[i] == '\n') {
            need_write = TRUE;
            msg_putchar(ta_buf[i]);
            nbytes = 1;
        } else if (ta_buf[i] == '\b') {
            NSUInteger ll = [line length];
            if (ll == 0) {
                continue;
            }
            NSRange lastChar = NSMakeRange(ll - 1, 1);
            NSRange lastComposedChar = [line rangeOfComposedCharacterSequencesForRange:lastChar];
            NSString *lc = [line substringWithRange:lastComposedChar];
            char_u *cs = (char_u *)[lc cStringUsingEncoding:NSUTF8StringEncoding];
            int n = ptr2cells(cs);
            while (n > 0) {
                msg_putchar('\b');
                n--;
            }
            // this remove the shown char
            msg_putchar(' ');
            msg_putchar('\b');
            // remove it from the storage
            [line deleteCharactersInRange:lastComposedChar];
        } else if (has_mbyte) {
            int l = (*mb_ptr2len)(ta_buf + i);
            msg_outtrans_len(ta_buf + i, l);
            nbytes = l;
        } else {
            msg_outtrans_len(ta_buf + i, 1);
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
    windgoto(msg_row, msg_col);
    out_flush();
    
//    NSLog(@"line: '%@'", line);
    // write to the external cmd
    if (need_write && *toshell_fd >= 0) {
        write(*toshell_fd,
              [line cStringUsingEncoding:NSUTF8StringEncoding],
              (size_t)[line lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
        line = nil;
        if (got_eof) {
            close(*toshell_fd);
            *toshell_fd = -1;
        }
    }
}
