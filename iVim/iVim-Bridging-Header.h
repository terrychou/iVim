//
//  iVim-Bridging-Header.h
//  iVim
//
//  Created by Terry on 7/21/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

#ifndef iVim_Bridging_Header_h
#define iVim_Bridging_Header_h

#import <Foundation/Foundation.h>

int const keyCAR;
int const keyESC;
int const keyTAB;
int const keyBS;
int const keyF1;
int const keyUP;
int const keyDOWN;
int const keyLEFT;
int const keyRIGHT;
int const mouseLEFT;
int const mouseDRAG;
int const mouseRELEASE;

void input_special_key(int key);
void input_special_name(const char * name);

NSString * expand_tilde_of_path(NSString * path);

NSString * get_current_sourcing_name(void);

void ivim_reload_buffer_for_mirror(NSString * path);

NSString * string_value_of_expr(const char * expr);
id object_of_expr(const char * expr);

int VimMain(int argc, char ** argv);
void gui_resize_shell(int pixel_width, int pixel_height);
void gui_update_cursor(int force, int clear_selection);
void gui_undraw_cursor();
void gui_send_mouse_event(int button,int x,int y, int repeated_click, unsigned int modifiers);
void maybe_intro_message(void);
//void gui_focus_change(BOOL);

int vim_setenv(const unsigned char *name, const unsigned char *value);
int do_cmdline_cmd(const unsigned char *cmd);

void add_to_input_buf(const unsigned char  *s, int len);
void add_to_input_buf_csi(const unsigned char *s, int len);

int input_available(void);

void move_cursor_left(long times);
void move_cursor_right(long times);

int cells_for_character(const unsigned char * c);

BOOL is_current_buf_new(void);
BOOL file_is_in_buffer_list(NSString * path);
BOOL jump_to_window_with_buffer(NSString * path);
BOOL clean_buffer_for_mirror_path(NSString * path);
BOOL is_in_normal_mode(void);
NSString * get_pattern_from_line(NSString * line);
void ivim_match_regex(NSString * pattern, BOOL ignore_case, void (^worker)(BOOL (^matcher)(NSString *)));

void gui_ios_init_bg_color(void);

#endif /* iVim_Bridging_Header_h */
