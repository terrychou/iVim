//
//  VimShareAction+Host.swift
//  iVim
//
//  Created by Terry Chou on 12/26/19.
//  Copyright © 2019 Boogaloo. All rights reserved.
//

import Foundation


extension ShareAction {
    func removeData() {
        guard let key = self.userDefaultsKey else { return }
        UserDefaults.appGroup.removeObject(forKey: key)
    }
    
    func newWithText() {
        guard let text: String = self.getData() else {
            NSLog("failed to get text for \(self.name)")
            return
        }
        if !is_current_buf_new() {
            do_cmdline_cmd("tabnew")
        }
        do_cmdline_cmd("normal! i\(text)")
        gEnsureSuccessfulOpen()
        self.removeData()
    }
}

extension ShareTextAction {
    func run() {
        switch self {
        case .text:
            self.newWithText()
        }
    }
}

extension ShareFileAction {
    func run() {
        switch self {
        case .content:
            self.newWithText()
        }
    }
}
