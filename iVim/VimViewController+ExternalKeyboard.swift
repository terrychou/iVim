//
//  VimViewController+ExternalKeyboard.swift
//  iVim
//
//  Created by Terry on 8/28/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

private let alphabetaKeys = "abcdefghijklmnopqrstuvwxyz"
private let numericKeys = "1234567890"
private let symbolKeys = "`-=~!@#$%^&*()_+[]\\{}|;':\",./<>?"
private let escapedKeys = "\t\r"
private let specialKeys = [UIKeyInputEscape, UIKeyInputUpArrow, UIKeyInputDownArrow, UIKeyInputLeftArrow, UIKeyInputRightArrow]
private let kUDCapsLockMapping = "kUDCapsLockMapping"
private let KS_MODIFIER : UInt8 = 252
private let MOD_MASK_CMD : UInt8 = 0x80
private let CSI : UInt8 = 0x9b    /* Control Sequence Introducer */



extension VimViewController {
    override var keyCommands: [UIKeyCommand]? {
        return VimViewController.externalKeys
    }
    
    static let externalKeys: [UIKeyCommand] =
        VimViewController.keyCommands(
            inputs: specialKeys,
            modifierFlags: [[], .control, .command, .alternate, .shift]) +
        VimViewController.keyCommands(
            keys: alphabetaKeys + numericKeys + symbolKeys,
            modifierFlags: [.control, .command]) +
        VimViewController.keyCommands(
            keys: escapedKeys,
            modifierFlags: [.control, .command, .alternate, .shift])
    
    private static func keyCommand(input: String, modifierFlags: UIKeyModifierFlags = [], title: String? = nil) -> UIKeyCommand {
        let re = UIKeyCommand(input: input, modifierFlags: modifierFlags, action: #selector(self.keyCommandTriggered(_:)))
        re.discoverabilityTitle = title
        
        return re
    }
    
    private static func add(input: String, modifierFlags: [UIKeyModifierFlags], to commands: inout [UIKeyCommand]) {
        for f in modifierFlags {
            commands.append(self.keyCommand(input: input, modifierFlags: f))
        }
    }
    
    private static func keyCommands(inputs: [String], modifierFlags: [UIKeyModifierFlags]) -> [UIKeyCommand] {
        var re = [UIKeyCommand]()
        for i in inputs {
            self.add(input: i, modifierFlags: modifierFlags, to: &re)
        }
        
        return re
    }
    
    private static func keyCommands(keys: String, modifierFlags: [UIKeyModifierFlags]) -> [UIKeyCommand] {
        var re = [UIKeyCommand]()
        for c in keys {
            self.add(input: String(c), modifierFlags: modifierFlags, to: &re)
        }
        
        return re
    }
    
    @objc func keyCommandTriggered(_ sender: UIKeyCommand) {
        DispatchQueue.main.async {
            self.handleKeyCommand(sender)
        }
    }
        
    private func handleKeyCommand(_ command: UIKeyCommand) {
        let flags = command.modifierFlags
        if flags.rawValue == 0 {
            switch command.input {
            case UIKeyInputEscape?: self.pressESC()
            case UIKeyInputUpArrow?: self.pressArrow(keyUP)
            case UIKeyInputDownArrow?: self.pressArrow(keyDOWN)
            case UIKeyInputLeftArrow?: self.pressArrow(keyLEFT)
            case UIKeyInputRightArrow?: self.pressArrow(keyRIGHT)
            default: break//self.insertText(command.input)
            }
//        } else if flags.contains(.alphaShift) {
//            self.handleCapsLock(with: command)
        } else {
            var keys = ""
            if flags.contains(.command) {
                keys.append("D-")
            }
            if self.ctrlEnabled || flags.contains(.control) {
                self.ctrlButton?.tryRestore()
                keys.append("C-")
            }
            if flags.contains(.alternate) {
                keys.append("A-")
            }
            if flags.contains(.shift) {
                keys.append("S-")
            }
            switch command.input {
            case UIKeyInputEscape?: keys.append("Esc")
            case UIKeyInputUpArrow?: keys.append("Up")
            case UIKeyInputDownArrow?: keys.append("Down")
            case UIKeyInputLeftArrow?: keys.append("Left")
            case UIKeyInputRightArrow?: keys.append("Right")
            case "\t"?: keys.append("Tab")
            case "\r"?: keys.append("CR")
            case "2"? where flags == [.control]: keys.append("@")
            case "6"? where flags == [.control]: keys.append("^")
            default: keys.append(command.input!)
            }
            input_special_name("<\(keys)>")
        }
    }
    

 override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        var vimModifier : UInt8 = 0x00
        vimModifier |= MOD_MASK_CMD
        var result : [UInt8] = []
        switch (action.description) {
            // Still missing: D-n D-z D-a
        case "cut:":
            // D-x
            result = [CSI,KS_MODIFIER,vimModifier,UInt8("x".utf8CString[0])]
            break;
        case "paste:":
            // D-v
            result = [CSI,KS_MODIFIER,vimModifier,UInt8("v".utf8CString[0])]
            break;
        case "copy:":
            // D-c
            result = [CSI,KS_MODIFIER,vimModifier,UInt8("c".utf8CString[0])]
            break;
        default:
            break;
        }
        if (result.count > 0) {
            becomeFirstResponder()
            add_to_input_buf(result, Int32(result.count))
            flush()
            self.markNeedsDisplay()
            return false
        }
        return true
    }
    
//    private enum CapsLockDestination: String {
//        case none
//        case esc
//        case ctrl
//    }
//    
//    private var capslockDestination: CapsLockDestination {
//        return UserDefaults.standard.string(forKey: kUDCapsLockMapping).map
//            { CapsLockDestination(rawValue: $0)! } ?? .none
//    }
//    
//    private func handleCapsLock(with command: UIKeyCommand) {
//        let dst = self.capslockDestination
//        var newInput = command.input
//        var newModifierFlags = command.modifierFlags
//        newModifierFlags.remove(.alphaShift)
//        switch dst {
//        case .esc: newInput = UIKeyInputEscape
//        case .ctrl: newModifierFlags.formUnion(.control)
//        case .none: break
//        }
//        let newCommand = VimViewController.keyCommand(input: newInput, modifierFlags: newModifierFlags)
//        self.handleKeyCommand(newCommand)
//    }
}
