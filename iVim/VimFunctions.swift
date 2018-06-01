//
//  VimFunctions.swift
//  iVim
//
//  Created by Terry on 5/10/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

let gSVO = SafeVimOperations.shared

final class SafeVimOperations {
    static let shared = SafeVimOperations()
    private init() {}
    typealias VimOperation = () -> Void
    private(set) var started = false
    private var pending = [VimOperation]()
    private let queue = DispatchQueue(label: "com.terrychou.ivim.svo.serial")
    
    func run(operation: @escaping VimOperation) {
        if self.started {
            operation()
        } else {
            self.queue.async {
                self.pending.append(operation)
            }
        }
    }
    
    private func showIntro() {
        guard is_current_buf_new() else { return }
        maybe_intro_message()
        do_cmdline_cmd("normal H")
    }
    
    func markStart() {
        guard !self.started else { return }
        self.queue.async {
            self.started = true
            for o in self.pending {
                DispatchQueue.main.async {
                    o()
                }
            }
            if self.pending.isEmpty {
                DispatchQueue.main.async {
                    self.showIntro()
                }
            }
            self.pending.removeAll()
        }
    }
    
    func showContent(_ content: String, withCommand cmd: String?) {
        self.run {
            let keptCmd = cmd != nil ? ":\(cmd!)\n" : ""
            do_cmdline_cmd("echo \"\(keptCmd)\(content)\"")
        }
    }
    
    func showErrContent(_ content: String) {
        self.run {
            do_cmdline_cmd("echohl ErrorMsg | echo \"\(content)\" | echohl None")
        }
    }
    
    func showError(_ err: String) {
        self.run {
            do_cmdline_cmd("echoerr \"\(err)\"")
        }
    }
    
    func showMessage(_ msg: String) {
        self.run {
            do_cmdline_cmd("echomsg \"\(msg)\"")
        }
    }
    
    func openFile(at url: URL) {
        self.run {
            if jump_to_window_with_buffer(url.path) {
//                NSLog("already opened")
                return
            }            
            let isNewBuf = is_current_buf_new()
            let openCmd = isNewBuf ? "edit" : "tabedit"
            let path = url.path.spaceEscaped
            do_cmdline_cmd("\(openCmd) \(path)")
            gEnsureSuccessfulOpen()
            if url.isDirectory {
                do_cmdline_cmd("lcd \(path)")
            }
        }
    }
}

func gFeedKeys(_ keys: String, for times: Int = 1, mode: String? = nil) {
    let mp = mode != nil ? ", '\(mode!)'" : ""
    do_cmdline_cmd("call feedkeys(\"\(keys * times)\"\(mp))")
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

func gEnsureSuccessfulOpen() {
    gFeedKeys("\\<Esc>H", mode: "n")
}

func *(_ string: String, times: Int) -> String {
    var result = ""
    for _ in 0..<times { result += string }
    
    return result
}
