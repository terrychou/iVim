//
//  VimViewController+ExternalKeyboard.swift
//  iVim
//
//  Created by Terry on 8/28/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

private let keysToModify = "abcdefghijklmnopqrstuvwxyz`1234567890-=~!@#$%^&*()_+[]\\{}|;':\",./<>?"

extension VimViewController {
    override var keyCommands: [UIKeyCommand]? {
        return self.externalKeys
    }
    
    func generateExternalKeys() -> [UIKeyCommand] {
        var keys = [UIKeyCommand]()
        keys += [UIKeyInputEscape,
                 UIKeyInputUpArrow,
                 UIKeyInputDownArrow,
                 UIKeyInputLeftArrow,
                 UIKeyInputRightArrow].map { self.keyCommand(input: $0) }
        keys += self.keyCommands(keys: keysToModify, modifierFlags: [[.control]])
        
        return keys
    }
    
    private func keyCommand(input: String, modifierFlags: UIKeyModifierFlags = [], title: String? = nil) -> UIKeyCommand {
        let re = UIKeyCommand(input: input, modifierFlags: modifierFlags, action: #selector(self.keyCommandTriggered(_:)))
        re.discoverabilityTitle = title
        
        return re
    }
    
    private func keyCommands(keys: String, modifierFlags: [UIKeyModifierFlags]) -> [UIKeyCommand] {
        var re = [UIKeyCommand]()
        for c in keys.characters {
            for mf in modifierFlags {
                re.append(self.keyCommand(input: String(c), modifierFlags: mf))
            }
        }
        
        return re
    }
    
    func keyCommandTriggered(_ sender: UIKeyCommand) {
        switch sender.modifierFlags.rawValue {
        case 0:
            switch sender.input {
            case UIKeyInputEscape: self.pressESC()
            case UIKeyInputUpArrow: self.pressArrow("Up")
            case UIKeyInputDownArrow: self.pressArrow("Down")
            case UIKeyInputLeftArrow: self.pressArrow("Left")
            case UIKeyInputRightArrow: self.pressArrow("Right")
            default: break
            }
        case UIKeyModifierFlags.control.rawValue:
            self.ctrlButton?.tryRestore()
            self.addToInputBuffer(sender.input.uppercased().ctrlModified)
        default: break
        }
    }
}
