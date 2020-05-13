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
private let specialKeys = [UIKeyCommand.inputEscape, UIKeyCommand.inputUpArrow, UIKeyCommand.inputDownArrow, UIKeyCommand.inputLeftArrow, UIKeyCommand.inputRightArrow]
private let kUDCapsLockMapping = "kUDCapsLockMapping"
private let kUDOptionMapping = "kUDOptionMapping"
private let kUDKeyRepeating = "kUDKeyRepeating"
private let kUDCtrlToEscOnRelease = "kUDCtrlToEscOnRelease"

extension VimViewController {
    override var keyCommands: [UIKeyCommand]? {
        var keys = [UIKeyCommand]()
        switch self.currentCapslockDst {
        case .none:
            if self.isOptionMappingEnabled {
                keys.append(contentsOf: VimViewController.externalKeysWithOption)
            } else {
                keys.append(contentsOf: VimViewController.externalKeys)
            }
        case .esc: keys.append(contentsOf: VimViewController.capslockToEsc)
        case .ctrl: keys.append(contentsOf: VimViewController.capslockToCtrl)
        }
        if self.isKeyRepeating {
            keys.append(contentsOf: VimViewController.keysForRepeating)
        }
        
        return keys
    }
    
    private var shouldRemapCapslock: Bool {
        return self.currentPrimaryLanguage.map {
            $0.hasPrefix("en") || $0.hasPrefix("dictation")
        } ?? false
    }
    
    static func registerExternalKeyboardUserDefaults() {
        UserDefaults.standard.register(defaults: [
            kUDKeyRepeating: true,
        ])
    }
    
    func registerExternalKeyboardNotifications(to nfc: NotificationCenter) {
        nfc.addObserver(self, selector: #selector(self.keyboardDidChange(_:)), name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
        nfc.addObserver(self, selector: #selector(self.appDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func appDidBecomeActive(_ notification: Notification) {
        self.updateCapslockDst()
    }
    
    @objc func keyboardDidChange(_ notification: Notification) {
        self.updatePrimaryLanguage()
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
    
    private static let keysForRepeating: [UIKeyCommand] =
        VimViewController.keyCommands(
            keys: alphabetaKeys + numericKeys + symbolKeys,
            modifierFlags: [[]]) +
        VimViewController.keyCommands(keys: alphabetaKeys,
                                      modifierFlags: [.shift])
    
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
    
    private var isKeyRepeating: Bool {
        return UserDefaults.standard.bool(forKey: kUDKeyRepeating) &&
            self.shouldRemapCapslock && // also only repeat for english keyboards
            !self.isDuringMultistageInput // don't repeat if inputting accented chars
    }
    
    private var shouldMapCtrlToEscOnRelease: Bool {
        return UserDefaults.standard.bool(forKey: kUDCtrlToEscOnRelease)
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
            if self.capsLockIsBeingPressed {
                var newModifierFlags = sender.modifierFlags
                newModifierFlags.formUnion(.alphaShift)
                let newCommand = VimViewController.keyCommand(input: sender.input ?? "", modifierFlags: newModifierFlags)
                self.handleKeyCommand(newCommand)
            } else {
                self.handleKeyCommand(sender)
            }
        }
    }
        
    private func handleKeyCommand(_ command: UIKeyCommand) {
        let flags = command.modifierFlags
        if flags.rawValue == 0 {
            guard let input = command.input else { return }
            switch input {
            case UIKeyCommand.inputEscape: self.pressESC()
            case UIKeyCommand.inputUpArrow: self.pressArrow(keyUP)
            case UIKeyCommand.inputDownArrow: self.pressArrow(keyDOWN)
            case UIKeyCommand.inputLeftArrow: self.pressArrow(keyLEFT)
            case UIKeyCommand.inputRightArrow: self.pressArrow(keyRIGHT)
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
            case UIKeyCommand.inputEscape?: keys.append("Esc")
            case UIKeyCommand.inputUpArrow?: keys.append("Up")
            case UIKeyCommand.inputDownArrow?: keys.append("Down")
            case UIKeyCommand.inputLeftArrow?: keys.append("Left")
            case UIKeyCommand.inputRightArrow?: keys.append("Right")
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
            newInput = UIKeyCommand.inputEscape
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

    override func pressesBegan(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)
        if #available(iOS 13.4, *) {
            presses.first?.key.map(keyPressed)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if #available(iOS 13.4, *) {
            presses.first?.key.map(keyReleased)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>,
                                   with event: UIPressesEvent?) {
        super.pressesCancelled(presses, with: event)
        if #available(iOS 13.4, *) {
            presses.first?.key.map(keyReleased)
        }
    }

    @available(iOS 13.4, *)
    func keyPressed(_ key: UIKey) {
        switch key.keyCode {
        case .keyboardCapsLock:
            self.capsLockIsBeingPressed = true
            self.onlyCtrlIsBeingPressed = self.currentCapslockDst == .ctrl
        case .keyboardLeftControl, .keyboardRightControl:
            self.onlyCtrlIsBeingPressed = true
        default:
            self.onlyCtrlIsBeingPressed = false
        }
    }

    @available(iOS 13.4, *)
    func keyReleased(_ key: UIKey) {
        switch key.keyCode {
        case .keyboardCapsLock:
            self.capsLockIsBeingPressed = false
            if self.currentCapslockDst == .ctrl {
                self.maybeMapCtrlToEsc()
            }
        case .keyboardLeftControl, .keyboardRightControl:
            self.maybeMapCtrlToEsc()
        default:
            break
        }
    }

    private func maybeMapCtrlToEsc() {
        if self.shouldMapCtrlToEscOnRelease && self.onlyCtrlIsBeingPressed {
            let newCommand = VimViewController.keyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [])
            self.handleKeyCommand(newCommand)
        }
        self.onlyCtrlIsBeingPressed = false
    }
}
