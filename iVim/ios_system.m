//
//  ios_system.m
//
//  Created by Nicolas Holzschuch on 17/11/2017.
//  Copyright © 2017 N. Holzschuch. All rights reserved.
//

#import <Foundation/Foundation.h>

// ios_system(cmd): Executes the command in "cmd". The goal is to be a drop-in replacement for system(), as much as possible.
// We assume cmd is the command. If vim has prepared '/bin/sh -c "(command -arguments) < inputfile > outputfile",
// it is easier to remove the "/bin/sh -c" part before calling ios_system than inside ios_system.
// See example in os_unix.c
//
// ios_executable(cmd): returns true if the command is one of the commands defined in ios_system, and can be executed.
// This is because mch_can_exe (called by executable()) checks for the existence of binaries with the same name in the
// path. Our commands don't exist in the path. 

#include <pthread.h>

#define FILE_UTILITIES   // file_cmds_ios
#define ARCHIVE_UTILITIES // libarchive_ios
#define SHELL_UTILITIES  // shell_cmds_ios
#define TEXT_UTILITIES  // text_cmds_ios

#ifdef FILE_UTILITIES
// Most useful file utilities (file_cmds_ios)
extern int ls_main(int argc, char *argv[]);
extern int touch_main(int argc, char *argv[]);
extern int rm_main(int argc, char *argv[]);
extern int cp_main(int argc, char *argv[]);
extern int ln_main(int argc, char *argv[]);
extern int mv_main(int argc, char *argv[]);
extern int mkdir_main(int argc, char *argv[]);
extern int rmdir_main(int argc, char *argv[]);
// Useful
extern int du_main(int argc, char *argv[]);
extern int df_main(int argc, char *argv[]);
extern int chksum_main(int argc, char *argv[]);
extern int compress_main(int argc, char *argv[]);
extern int gzip_main(int argc, char *argv[]);
// Most likely useless in a sandboxed environment, but provided nevertheless
extern int chmod_main(int argc, char *argv[]);
extern int chflags_main(int argc, char *argv[]);
extern int chown_main(int argc, char *argv[]);
extern int stat_main(int argc, char *argv[]);
#endif
#ifdef ARCHIVE_UTILITIES
// from libarchive:
extern int tar_main(int argc, char **argv);
#endif
#ifdef SHELL_UTILITIES
extern int date_main(int argc, char *argv[]);
extern int env_main(int argc, char *argv[]);     // does the same as printenv
extern int hostname_main(int argc, char *argv[]);
extern int id_main(int argc, char *argv[]); // also groups, whoami
extern int printenv_main(int argc, char *argv[]);
extern int pwd_main(int argc, char *argv[]);
extern int uname_main(int argc, char *argv[]);
extern int w_main(int argc, char *argv[]); // also uptime
#endif
#ifdef TEXT_UTILITIES
extern int cat_main(int argc, char *argv[]);
extern int grep_main(int argc, char *argv[]);
extern int wc_main(int argc, char *argv[]);
#endif

typedef struct _functionParameters {
    int argc;
    char** argv;
    int (*function)(int ac, char** av);
} functionParameters;

static void* run_function(void* parameters) {
    functionParameters *p = (functionParameters *) parameters;
    p->function(p->argc, p->argv);
    return NULL;
}

// Apple utilities:
// #include "file_cmds_ios.h"
// #include "shell_cmds_ios.h"
// #include "text_cmds_ios.h"
// #include "network_cmds_ios.h"
// Other utilities
// #include "curl_ios.h"
// #include "libarchive_ios.h"
// #include "Python_ios.h"
// #include "lua_ios.h"
// #include "texlive_ios.h"

static NSDictionary *commandList = nil;

static void initializeCommandList()
{
    commandList = @{
#ifdef FILE_UTILITIES
                    // Commands from Apple file_cmds:
                    @"ls" : [NSValue valueWithPointer: ls_main],
                    @"touch" : [NSValue valueWithPointer: touch_main],
                    @"rm" : [NSValue valueWithPointer: rm_main],
                    @"cp" : [NSValue valueWithPointer: cp_main],
                    @"ln" : [NSValue valueWithPointer: ln_main],
                    @"link" : [NSValue valueWithPointer: ln_main],
                    @"mv" : [NSValue valueWithPointer: mv_main],
                    @"mkdir" : [NSValue valueWithPointer: mkdir_main],
                    @"rmdir" : [NSValue valueWithPointer: rmdir_main],
                    @"chown" : [NSValue valueWithPointer: chown_main],
                    @"chgrp" : [NSValue valueWithPointer: chown_main],
                    @"chflags": [NSValue valueWithPointer: chflags_main],
                    @"chmod": [NSValue valueWithPointer: chmod_main],
                    @"du"   : [NSValue valueWithPointer: du_main],
                    @"df"   : [NSValue valueWithPointer: df_main],
                    @"chksum" : [NSValue valueWithPointer: chksum_main],
                    @"sum"    : [NSValue valueWithPointer: chksum_main],
                    @"stat"   : [NSValue valueWithPointer: stat_main],
                    @"readlink": [NSValue valueWithPointer: stat_main],
                    @"compress": [NSValue valueWithPointer: compress_main],
                    @"uncompress": [NSValue valueWithPointer: compress_main],
                    @"gzip"   : [NSValue valueWithPointer: gzip_main],
                    @"gunzip" : [NSValue valueWithPointer: gzip_main],
#endif
#ifdef ARCHIVE_UTILITIES
                    // from libarchive:
                    @"tar"    : [NSValue valueWithPointer: tar_main],
#endif
#ifdef SHELL_UTILITIES
                    // Commands from Apple shell_cmds:
                    @"printenv": [NSValue valueWithPointer: printenv_main],
                    @"pwd"    : [NSValue valueWithPointer: pwd_main],
                    @"uname"  : [NSValue valueWithPointer: uname_main],
                    @"date"   : [NSValue valueWithPointer: date_main],
                    @"env"    : [NSValue valueWithPointer: env_main],
                    @"id"     : [NSValue valueWithPointer: id_main],
                    @"groups" : [NSValue valueWithPointer: id_main],
                    @"whoami" : [NSValue valueWithPointer: id_main],
                    @"uptime" : [NSValue valueWithPointer: w_main],
                    @"w"      : [NSValue valueWithPointer: w_main],
#endif
#ifdef TEXT_UTILITIES
                    // Commands from Apple text_cmds:
                    @"cat"    : [NSValue valueWithPointer: cat_main],
                    @"wc"     : [NSValue valueWithPointer: wc_main],
                    @"grep"   : [NSValue valueWithPointer: grep_main],
                    @"egrep"  : [NSValue valueWithPointer: grep_main],
                    @"fgrep"  : [NSValue valueWithPointer: grep_main],
#endif
#ifdef NETWORK_UTILITIES
                    // This doesn't make sense inside iVim environment
                    // Commands from Apple network_cmds:
                    @"ping"  : [NSValue valueWithPointer: ping_main],
#endif
#ifdef CURL_COMMANDS
                    // From curl. curl with ssh requires keys, and thus keys generation / management.
                    // http, https, ftp... should be OK.
                    // Would require some rewriting from the @blinkshell code(?)
                    @"curl"   : [NSValue valueWithPointer: curl_main],
                    // scp / sftp require conversion to curl, rewriting arguments
                    // @"scp"    : [NSValue valueWithPointer: curl_main],
                    // @"sftp"   : [NSValue valueWithPointer: curl_main],
#endif
#ifdef PYTHON_COMMANDS
                    // from python:
                    @"python"  : [NSValue valueWithPointer: python_main],
#endif
#ifdef LUA_COMMANDS
                    // from lua:
                    @"lua"     : [NSValue valueWithPointer: lua_main],
                    @"luac"    : [NSValue valueWithPointer: luac_main],
#endif
#ifdef TEX_COMMANDS
                    // from TeX:
                    // LuaTeX:
                    @"luatex"     : [NSValue valueWithPointer: dllluatexmain],
                    @"lualatex"     : [NSValue valueWithPointer: dllluatexmain],
                    @"texlua"     : [NSValue valueWithPointer: dllluatexmain],
                    @"texluac"     : [NSValue valueWithPointer: dllluatexmain],
                    @"dviluatex"     : [NSValue valueWithPointer: dllluatexmain],
                    @"dvilualatex"     : [NSValue valueWithPointer: dllluatexmain],
                    // pdfTeX
                    @"amstex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"cslatex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"csplain"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"eplain"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"etex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"jadetex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"latex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"mex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"mllatex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"mltex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"etex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"pdfcslatex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"pdfcsplain"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"pdfetex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"pdfjadetex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"pdflatex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"pdftex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"pdfmex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"pdfxmltex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"texsis"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"utf8mex"     : [NSValue valueWithPointer: dllpdftexmain],
                    @"xmltex"     : [NSValue valueWithPointer: dllpdftexmain],
                    // XeTeX:
                    // @"xetex"     : [NSValue valueWithPointer: dllxetexmain],
                    // @"xelatex"     : [NSValue valueWithPointer: dllxetexmain],
                    // BibTeX
                    @"bibtex"     : [NSValue valueWithPointer: bibtex_main],
#endif
                    };
}

int ios_executable(char* inputCmd) {
 // returns 1 if this is one of the commands we define in ios_system, 0 otherwise
    int (*function)(int ac, char** av) = NULL;
    if (commandList == nil) initializeCommandList();
    NSString* commandName = [NSString stringWithCString:inputCmd encoding:NSASCIIStringEncoding];
    function = [[commandList objectForKey: commandName] pointerValue];
    if (function) return 1;
    else return 0;
}


int ios_system(char* inputCmd) {
    char* command;
    // The names of the files for stdin, stdout, stderr
    char* inputFileName = 0;
    char* outputFileName = 0;
    char* errorFileName = 0;
    // Where the symbols "<", ">" or "2>" were.
    // to be replaced by 0x0 later.
    char* outputFileMarker = 0;
    char* inputFileMarker = 0;
    char* errorFileMarker = 0;
    bool  sharedErrorOutput = false;
    int result = 127;
    
    char* cmd = strdup(inputCmd);
    char* maxPointer = cmd + strlen(cmd);
    char* originalCommand = cmd;
    // fprintf(stderr, "Command sent: %s \n", cmd); fflush(stderr);
    if (cmd[0] == '"') {
        // Command was enclosed in quotes (almost always)
        cmd = cmd + 1; // remove starting quote
        cmd[strlen(cmd) - 1] = 0x00; // remove ending quote
        assert(cmd + strlen(cmd) < maxPointer);
    }
    if (cmd[0] == '(') {
        // Standard vim encoding: command between parentheses
        command = cmd + 1;
        char* endCmd = strstr(command, ")"); // remove closing parenthesis
        if (endCmd) {
            endCmd[0] = 0x0;
            assert(endCmd < maxPointer);
            inputFileMarker = endCmd + 1;
        }
    } else command = cmd;
    // Search for input, output and error redirection
    // They can be in any order, although the usual are:
    // command < input > output 2> error, command < input > output 2>&1 or command < input >& output
    // The last two are equivalent. Vim prefers the second.
    // Search for input file "< " and output file " >"
    if (!inputFileMarker) inputFileMarker = command;
    outputFileMarker = inputFileMarker;
    // scan until first "<"
    inputFileMarker = strstr(inputFileMarker, "<");
    // scan until first non-space character:
    if (inputFileMarker) {
        inputFileName = inputFileMarker + 1; // skip past '<'
        // skip past all spaces
        while ((inputFileName[0] == ' ') && strlen(inputFileName) > 0) inputFileName++;
    }
    char *joined = NULL;
    // Must scan in strstr by reverse order of inclusion. So "2>&1" before "2>" before ">"
    joined = strstr (outputFileMarker,"&>"); // both stderr/stdout sent to same file
    if (!joined) joined = strstr (outputFileMarker,"2>&1"); // Same, but expressed differently
    if (joined) sharedErrorOutput = true;
    else {
        // specific name for error file?
        errorFileMarker = strstr(outputFileMarker,"2>");
        if (errorFileMarker) {
            errorFileName = errorFileMarker + 2; // skip past "2>"
            // skip past all spaces:
            while ((errorFileName[0] == ' ') && strlen(errorFileName) > 0) errorFileName++;
        }
    }
    // scan until first ">"
    outputFileMarker = strstr(outputFileMarker, ">");
    if (outputFileMarker) {
        outputFileName = outputFileMarker + 1; // skip past '>'
        while ((outputFileName[0] == ' ') && strlen(outputFileName) > 0) outputFileName++;
    }
    if (errorFileName && (outputFileName == errorFileName)) {
        // we got the same ">" twice, pick the next one ("2>" was before ">")
        outputFileMarker = errorFileName;
        outputFileMarker = strstr(outputFileMarker, ">");
        if (outputFileMarker) {
            outputFileName = outputFileMarker + 1; // skip past '>'
            while ((outputFileName[0] == ' ') && strlen(outputFileName) > 0) outputFileName++;
        }
    }
    if (outputFileName) {
        char* endFile = strstr(outputFileName, " ");
        if (endFile) endFile[0] = 0x00; // end output file name at first space
        assert(endFile < maxPointer);
    }
    if (inputFileName) {
        char* endFile = strstr(inputFileName, " ");
        if (endFile) endFile[0] = 0x00; // end input file name at first space
        assert(endFile < maxPointer);
    }
    if (errorFileName) {
        char* endFile = strstr(errorFileName, " ");
        if (endFile) endFile[0] = 0x00; // end error file name at first space
        assert(endFile < maxPointer);
    }
    // insert chain termination elements at the beginning of each filename.
    // Must be done after the parsing
    if (inputFileMarker) inputFileMarker[0] = 0x0;
    if (outputFileMarker) outputFileMarker[0] = 0x0;
    if (errorFileMarker) errorFileMarker[0] = 0x0;
    // Store previous values of stdin, stdout, stderr:
    FILE* push_stdin = stdin;
    FILE* push_stdout = stdout;
    FILE* push_stderr = stderr;
    if (inputFileName) stdin = fopen(inputFileName, "r");
    if (outputFileName) stdout = fopen(outputFileName, "w");
    if (sharedErrorOutput) stderr = stdout;
    else if (errorFileName) stderr = fopen(errorFileName, "w");
    int argc = 0;
    size_t numSpaces = 0;
    // the number of arguments is *at most* the number of spaces plus one
    char* str = command;
    while(*str) if (*str++ == ' ') ++numSpaces;
    char** argv = (char **)malloc(sizeof(char*) * (numSpaces + 2));
    // n spaces = n+1 arguments, plus null at the end
    str = command;
    while (*str) {
        argv[argc] = str;
        argc += 1;
        if (str[0] == '\'') { // argument begins with a quote.
            // everything until next quote is part of the argument
            argv[argc-1] = str + 1;
            char* end = strstr(argv[argc-1], "'");
            if (!end) break;
            end[0] = 0x0;
            str = end + 1;
        } else {
            // skip to next space:
            char* end = strstr(str, " ");
            if (!end) break;
            end[0] = 0x0;
            str = end + 1;
        }
        assert(argc < numSpaces + 2);
        while (str && (str[0] == ' ')) str++; // skip multiple spaces
    }
    argv[argc] = NULL;
    // Now call the actual command:
    int (*function)(int ac, char** av) = NULL;
    if (commandList == nil) initializeCommandList();
    NSString* commandName = [NSString stringWithCString:argv[0] encoding:NSASCIIStringEncoding];
    function = [[commandList objectForKey: commandName] pointerValue];
    if (function) {
        // We run the function in a thread because there are several
        // points where we can exit from a shell function.
        // Commands call pthread_exit instead of exit
        // thread is attached, could also be un-attached
        result = 0;
        pthread_t _tid;
        functionParameters* params = malloc(sizeof(functionParameters));;
        params->argc = argc;
        params->argv = argv;
        params->function = function;
        pthread_create(&_tid, NULL, run_function, params);
        pthread_join(_tid, NULL);
        free(params);
    } else result = 127;
    free(argv);
    // Still not done: check for executable files with the same name (scripts)
    // hg, diff... are python scripts, for example.
    
    // restore previous values of stdin, stdout, stderr:
    if (inputFileName) fclose(stdin);
    if (outputFileName) fclose(stdout);
    if (!sharedErrorOutput && errorFileName) fclose(stderr);
    stdin = push_stdin;
    stdout = push_stdout;
    stderr = push_stderr;
    free(originalCommand);
    return result;
}
