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

extension VimViewController {
    override var keyCommands: [UIKeyCommand]? {
//        NSLog(self.textInputMode?.primaryLanguage ?? "none")
        return VimViewController.externalKeys
    }
    
    static let externalKeys: [UIKeyCommand] =
        [VimViewController.keyCommand(
            input: "",
            modifierFlags: .alphaShift)] +
        VimViewController.keyCommands(
            inputs: specialKeys,
            modifierFlags: [[], .control, .alternate, .command, .alphaShift]) +
        VimViewController.keyCommands(
            keys: alphabetaKeys + numericKeys + symbolKeys,
            modifierFlags: [.control, .alternate, .command, .alphaShift]) +
        VimViewController.keyCommands(
            keys: escapedKeys,
            modifierFlags: [.control, .alternate, .command, .shift, .alphaShift])
    
//    static let baseExternalKeys: [UIKeyCommand] =
//        VimViewController.keyCommands(
//            inputs: specialKeys,
//            modifierFlags: [[], .control, .alternate, .command]) +
//        VimViewController.keyCommands(
//            keys: numericKeys,
//            modifierFlags: [.control, .alternate, .command]) +
//        VimViewController.keyCommands(
//            keys: escapedKeys,
//            modifierFlags: [.control, .alternate, .command, .shift])
//    
//    static let generalExternalKeys: [UIKeyCommand] =
//        VimViewController.keyCommands(
//            keys: numericKeys,
//            modifierFlags: [[]]) +
//        VimViewController.keyCommands(
//            keys: alphabetaKeys + symbolKeys,
//            modifierFlags: [[], .control, .alternate, .command]) +
//        VimViewController.keyCommands(
//            keys: alphabetaKeys,
//            modifierFlags: [.shift])
//    
//    static let nonMultistageKeys: [UIKeyCommand] =
//        VimViewController.baseExternalKeys +
//        VimViewController.generalExternalKeys
//    
//    static let multistageKeys: [UIKeyCommand] =
//        VimViewController.baseExternalKeys
    
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
        for c in keys.characters {
            self.add(input: String(c), modifierFlags: modifierFlags, to: &re)
        }
        
        return re
    }
    
    func keyCommandTriggered(_ sender: UIKeyCommand) {
//        DispatchQueue.main.async {
            self.handleKeyCommand(sender)
//        }
    }
        
    private func handleKeyCommand(_ command: UIKeyCommand) {
        let flags = command.modifierFlags
        if flags.rawValue == 0 {
            switch command.input {
            case UIKeyInputEscape: self.pressESC()
            case UIKeyInputUpArrow: self.pressArrow(keyUP)
            case UIKeyInputDownArrow: self.pressArrow(keyDOWN)
            case UIKeyInputLeftArrow: self.pressArrow(keyLEFT)
            case UIKeyInputRightArrow: self.pressArrow(keyRIGHT)
            default: self.insertText(command.input)
            }
        } else if flags.contains(.alphaShift) {
            self.handleCapsLock(with: command)
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
            case UIKeyInputEscape: keys.append("Esc")
            case UIKeyInputUpArrow: keys.append("Up")
            case UIKeyInputDownArrow: keys.append("Down")
            case UIKeyInputLeftArrow: keys.append("Left")
            case UIKeyInputRightArrow: keys.append("Right")
            case "\t": keys.append("Tab")
            case "\r": keys.append("CR")
            default: keys.append(command.input)
            }
            gFeedKeys(keys.escaped)
        }
    }
    
    private enum CapsLockDestination: String {
        case none
        case esc
        case ctrl
    }
    
    private var capslockDestination: CapsLockDestination {
        return UserDefaults.standard.string(forKey: kUDCapsLockMapping).map
            { CapsLockDestination(rawValue: $0)! } ?? .none
    }
    
    private func handleCapsLock(with command: UIKeyCommand) {
        let dst = self.capslockDestination
        var newInput = command.input
        var newModifierFlags = command.modifierFlags
        newModifierFlags.remove(.alphaShift)
        switch dst {
        case .esc: newInput = UIKeyInputEscape
        case .ctrl: newModifierFlags.formUnion(.control)
        case .none: break
        }
        let newCommand = VimViewController.keyCommand(input: newInput, modifierFlags: newModifierFlags)
        self.handleKeyCommand(newCommand)
    }
}
