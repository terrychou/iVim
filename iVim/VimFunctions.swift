//
//  VimFunctions.swift
//  iVim
//
//  Created by Terry on 5/10/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

func showContent(_ content: String, withCommand cmd: String?) {
    let keptCmd = cmd != nil ? ":\(cmd!)\n" : ""
    do_cmdline_cmd("echo \"\(keptCmd)\(content)\"")
}

func showError(_ err: String) {
    do_cmdline_cmd("echoerr \"\(err)\"")
}

func showMessage(_ msg: String) {
    do_cmdline_cmd("echomsg \"\(msg)\"")
}

func gFeedKeys(_ keys: String, for times: Int = 1) {
    do_cmdline_cmd("call feedkeys(\"\(keys * times)\")")
}

func gAddTextToInputBuffer(_ text: String, for times: Int = 1) {
    let s = text * times
    add_to_input_buf(s, Int32(s.utf8Length))
}

func gAddNonCSITextToInputBuffer(_ text: String) {
    add_to_input_buf_csi(text, Int32(text.utf8Length))
}

func gInputESC() {
    gAddTextToInputBuffer(keyESC.unicoded)
}

func gOpenFile(at url: URL) {
    let openCmd = is_current_buf_new() ? "edit" : "tabedit"
    do_cmdline_cmd("\(openCmd) \(url.path.spaceEscaped)")
    gInputESC()
    DispatchQueue.main.async {
        do_cmdline_cmd("redraw!")
    }
}

func *(_ string: String, times: Int) -> String {
    var result = ""
    for _ in 0..<times { result += string }
    
    return result
}
