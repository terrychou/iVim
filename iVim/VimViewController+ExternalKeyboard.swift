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
private let kUDOptionMapping = "kUDOptionMapping"

extension VimViewController {
    override var keyCommands: [UIKeyCommand]? {
        switch self.currentCapslockDst {
        case .none:
            return self.isOptionMappingEnabled ?
                VimViewController.externalKeysWithOption :
                VimViewController.externalKeys
        case .esc: return VimViewController.capslockToEsc
        case .ctrl: return VimViewController.capslockToCtrl
        }
    }
    
    private var shouldRemapCapslock: Bool {
        guard let lang = self.textInputMode?.primaryLanguage else { return false }

        return lang.hasPrefix("en") || lang.hasPrefix("dictation")
    }
    
    func registerExternalKeyboardNotifications(to nfc: NotificationCenter) {
        nfc.addObserver(self, selector: #selector(self.keyboardDidChange(_:)), name: .UITextInputCurrentInputModeDidChange, object: nil)
        nfc.addObserver(self, selector: #selector(self.appDidBecomeActive(_:)), name: .UIApplicationDidBecomeActive, object: nil)
    }
    
    @objc func appDidBecomeActive(_ notification: Notification) {
        self.updateCapslockDst()
    }
    
    @objc func keyboardDidChange(_ notification: Notification) {
        self.updateCapslockDst()
    }
    
    private func updateCapslockDst() {
        let dst = self.shouldRemapCapslock ? self.capslockDestination : .none
        guard self.currentCapslockDst != dst else { return }
        DispatchQueue.main.async {
            if dst == .none {
                gSVO.showErrContent("[caps lock] mapping DISABLED.")
            } else {
                gSVO.showContent("[caps lock] mapping to [\(dst.rawValue)]", withCommand: nil)
            }
        }
        self.currentCapslockDst = dst
    }
    
    private static let externalKeys: [UIKeyCommand] =
        VimViewController.keyCommands(
            inputs: specialKeys,
            modifierFlags: [[], .control, .command, .alternate, .shift]) +
        VimViewController.keyCommands(
            keys: alphabetaKeys + numericKeys + symbolKeys,
            modifierFlags: [.control, .command]) +
        VimViewController.keyCommands(
            keys: escapedKeys,
            modifierFlags: [.control, .command, .alternate, .shift])
    
    private static let optionKeys: [UIKeyCommand] =
        VimViewController.keyCommands(
            keys: alphabetaKeys + numericKeys + symbolKeys,
            modifierFlags: [.alternate])
    
    private static let externalKeysWithOption: [UIKeyCommand] =
        VimViewController.externalKeys +
        VimViewController.optionKeys
    
    private static let capslockToEsc: [UIKeyCommand] =
        VimViewController.externalKeys +
        VimViewController.optionKeys +
        VimViewController.keyCommands(keys: alphabetaKeys, modifierFlags: [[]]) +
        [VimViewController.keyCommand(input: "", modifierFlags: .alphaShift)]
    
    private static let capslockToCtrl: [UIKeyCommand] =
        VimViewController.capslockToEsc +
        VimViewController.keyCommands(inputs: specialKeys, modifierFlags: [.alphaShift]) +
        VimViewController.keyCommands(
            keys: alphabetaKeys + numericKeys + symbolKeys + escapedKeys,
            modifierFlags: [.alphaShift])
    
    private var isOptionMappingEnabled: Bool {
        return UserDefaults.standard.bool(forKey: kUDOptionMapping)
    }
    
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
            guard let input = command.input else { return }
            switch input {
            case UIKeyInputEscape: self.pressESC()
            case UIKeyInputUpArrow: self.pressArrow(keyUP)
            case UIKeyInputDownArrow: self.pressArrow(keyDOWN)
            case UIKeyInputLeftArrow: self.pressArrow(keyLEFT)
            case UIKeyInputRightArrow: self.pressArrow(keyRIGHT)
            default: self.insertText(input)
            }
        } else if flags.contains(.alphaShift) {
            self.handleCapsLock(with: command)
        } else {
            var modifiers = [String]()
            if flags.contains(.command) {
                modifiers.append("D")
            }
            if flags.contains(.control) {
                modifiers.append("C")
            }
            var hasOption = false
            if flags.contains(.alternate) {
                hasOption = true
                modifiers.append("A")
            }
            if flags.contains(.shift) {
                modifiers.append("S")
            }
            //combine with modifiers from the extended keyboard
            var keys = gEKM.modifiersString(byCombining: modifiers)
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
            default:
                let l = command.input ?? ""
                if hasOption && !self.isOptionMappingEnabled {
                    self.insertText(l)
                    return
                }
                keys.append(l)
            }
            self.insertSpecialName("<\(keys)>")
        }
    }
    
    enum CapsLockDestination: String {
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
        var newInput = command.input ?? ""
        var newModifierFlags = command.modifierFlags
        newModifierFlags.remove(.alphaShift)
        if dst == .esc {
            newInput = UIKeyInputEscape
        } else {
            if newInput.isEmpty { return }
            newModifierFlags.formUnion(.control)
        }
        let newCommand = VimViewController.keyCommand(input: newInput, modifierFlags: newModifierFlags)
        self.handleKeyCommand(newCommand)
    }
    
    private func triggerReservedKeyCommand(input: String, modifierFlags: UIKeyModifierFlags) {
        let kc = VimViewController.keyCommand(input: input, modifierFlags: modifierFlags)
        self.keyCommandTriggered(kc)
    }
    
    override func copy(_ sender: Any?) {
        //handle <D-c>
        self.triggerReservedKeyCommand(input: "c", modifierFlags: .command)
    }
    
    override func cut(_ sender: Any?) {
        //handle <D-x>
        self.triggerReservedKeyCommand(input: "x", modifierFlags: .command)
    }
    
    override func paste(_ sender: Any?) {
        //handle <D-v>
        self.triggerReservedKeyCommand(input: "v", modifierFlags: .command)
    }
    
    override func selectAll(_ sender: Any?) {
        //handle <D-a>
        self.triggerReservedKeyCommand(input: "a", modifierFlags: .command)
    }
}
