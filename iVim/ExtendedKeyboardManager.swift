//
//  ExtendedKeyboardManager.swift
//  iVim
//
//  Created by Terry Chou on 2018/5/2.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import UIKit

let gEKM = ExtendedKeyboardManager.shared
private typealias EKButtons = [[EKKeyOption]]

final class ExtendedKeyboardManager: NSObject {
    @objc static let shared = ExtendedKeyboardManager()
    private override init() {}
    
    private weak var controller: VimViewController!
    lazy var extendedBar: OptionalButtonsBar = {
        let newBar = self.newBar()
        self.sandbox = newBar.buttons //initialize sandbox
        
        return newBar
    }()
    private var sandbox: EKButtons! //operate on it before confirmation
    private lazy var modifiers = EKModifiersArranger()
}

extension ExtendedKeyboardManager {
    func registerController(_ c: VimViewController) {
        self.controller = c
    }
    
    @objc func setKeyboard(with cmdArg: String, confirmed: Bool) {
        NSLog("isetekbd: \"\(cmdArg)\"")
        let item = cmdArg.trimmingCharacters(in: .whitespaces)
        do {
            try self.sourceItem(item)
        } catch EKError.info(let msg) {
            self.showError(msg)
        } catch {
            NSLog("[system] failed to generate operations")
        }
        if confirmed {
            self.confirmChanges()
        }
    }
    
    private func confirmChanges() {
        self.extendedBar.buttons = self.sandbox
        self.extendedBar.updateButtons()
        self.modifiers.clear()
    }
    
    private func undoChanges() {
        self.sandbox = self.extendedBar.buttons
    }
}

extension ExtendedKeyboardManager {
    func handleModifiers(with text: String) -> Bool {
        let ms = self.modifiers.query()
        guard !ms.isEmpty else { return false }
        let t = text == "\n" ? "CR" : text
        let mStr = ms.modifierString
//        NSLog("modifier string: \(mStr)")
        self.controller.insertSpecialName("<\(mStr)\(t)>")
        
        return true
    }
    
    func modifiersString(byCombining list: [String]) -> String {
        return self.modifiers.query().union(list).modifierString
    }
    
    private func modifierKey(title: String, key: EKModifierKey) -> EKKeyOption {
        let action: Action = { [unowned self] b in
            self.modifiers.update(for: b, with: key.keyString)
        }
        
        return EKKeyOption(title: title, action: action, isSticky: true)
    }
}

private extension Set where Element: StringProtocol {
    var modifierString: String {
        return self.reduce("") { $0 + $1 + "-" }
    }
}

extension ExtendedKeyboardManager {
    private func insertText(_ text: String) {
        self.controller.insertText(text)
    }
    
    private func pressArrow(_ key: Int32) {
        self.controller.pressArrow(key)
    }
    
    private func inputOption(for key: String, title: String? = nil) -> EKKeyOption {
        return EKKeyOption(title: title ?? key, action: { [unowned self] _ in
            self.insertText(key)
        })
    }
    
    private func press(modified: String, action: () -> Void) {
        if self.handleModifiers(with: modified) { return }
        action()
    }
    
    private func specialKey(type: EKSpecialKey, title: String) -> EKKeyOption {
        let action: Action
        switch type {
        case .esc:
            action = { [unowned self] _ in
                self.press(modified: "Esc",
                           action: self.controller.pressESC)
            }
        case .up:
            action = { [unowned self] _ in
                self.press(modified: "Up") {
                    self.pressArrow(keyUP)
                }
            }
        case .down:
            action = { [unowned self] _ in
                self.press(modified: "Down") {
                    self.pressArrow(keyDOWN)
                }
            }
        case .left:
            action = { [unowned self] _ in
                self.press(modified: "Left") {
                    self.pressArrow(keyLEFT)
                }
            }
        case .right:
            action = { [unowned self] _ in
                self.press(modified: "Right") {
                    self.pressArrow(keyRIGHT)
                }
            }
        case .tab:
            action = { [unowned self] _ in
                self.press(modified: "Tab") {
                    self.insertText(keyTAB.unicoded)
                }
            }
        }
        
        return EKKeyOption(title: title, action: action)
    }
    
    private var defaultButtons: EKButtons {
        return [
            [
                self.specialKey(type: .esc, title: "esc"),
                self.modifierKey(title: "ctrl", key: .control) ],
            [
                self.specialKey(type: .tab, title: "tab"),
                self.specialKey(type: .down, title: "↓"),
                self.specialKey(type: .left, title: "←"),
                self.specialKey(type: .right, title: "→"),
                self.specialKey(type: .up, title: "↑") ],
            [
                self.inputOption(for: "0"),
                self.inputOption(for: "1"),
                self.inputOption(for: "2"),
                self.inputOption(for: "3"),
                self.inputOption(for: "4") ],
            [
                self.inputOption(for: "5"),
                self.inputOption(for: "6"),
                self.inputOption(for: "7"),
                self.inputOption(for: "8"),
                self.inputOption(for: "9") ],
            [
                self.inputOption(for: "="),
                self.inputOption(for: "+"),
                self.inputOption(for: "-"),
                self.inputOption(for: "*"),
                self.inputOption(for: "%") ],
            [
                self.inputOption(for: ","),
                self.inputOption(for: "("),
                self.inputOption(for: ")"),
                self.inputOption(for: "<"),
                self.inputOption(for: ">") ],
            [
                self.inputOption(for: "."),
                self.inputOption(for: "{"),
                self.inputOption(for: "}"),
                self.inputOption(for: "["),
                self.inputOption(for: "]") ],
            [
                self.inputOption(for: ";"),
                self.inputOption(for: "'"),
                self.inputOption(for: "\""),
                self.inputOption(for: "^"),
                self.inputOption(for: "$") ],
            [
                self.inputOption(for: "!"),
                self.inputOption(for: "@"),
                self.inputOption(for: "#"),
                self.inputOption(for: "&"),
                self.inputOption(for: "_") ],
            [
                self.inputOption(for: ":"),
                self.inputOption(for: "/"),
                self.inputOption(for: "\\"),
                self.inputOption(for: "?"),
                self.inputOption(for: "|") ]
        ]
    }
    
    private func newBar() -> OptionalButtonsBar {
        let width: CGFloat = 100
        let height: CGFloat = UIDevice.current.isPhone ? 58 : 72
        let bar = OptionalButtonsBar(frame: CGRect(x: 0, y: 0, width: width, height: height))
        bar.autoresizingMask = [.flexibleWidth]
        bar.setButtons(with: self.defaultButtons)
        bar.backgroundColor = UIColor(white: 0.860, alpha: 1)
        
        return bar
    }
}

extension ExtendedKeyboardManager {
    private func showError(_ msg: String) {
        gSVO.showError(msg.escaping("\""))
    }
    
    private func edit(with operation: EKOperationInfo) throws {
        switch operation.op {
        case .append: try self.doAppend(for: operation)
        case .insert: try self.doInsert(for: operation)
        case .remove: try self.doRemove(for: operation)
        case .replace: try self.doReplace(for: operation)
        case .apply: try self.doApply(for: operation)
        case .clear: try self.doClear(for: operation)
        case .default: try self.doDefault(for: operation)
        case .source: try self.doSource(for: operation)
//        default: NSLog("Not implemented yet.")
        }
    }
    
    private func doRemove(for op: EKOperationInfo) throws {
        guard let bLocs = op.locations else {
            throw EKError.info("[remove] no target locations")
        }
        let bCnt = self.sandbox.count
        for bl in bLocs.locations.sorted(by: >) {
            if bl < 0 || bl >= bCnt {
                throw EKError.info("[remove] invalid button location \(bl)")
            }
            if let b = op.buttons?.dict?[bl], let kLocs = b.locations {
                var keys = self.sandbox[bl]
                let kCnt = keys.count
                for kl in kLocs.locations.sorted(by: >) {
                    if kl < 0 || kl >= kCnt {
                        throw EKError.info("[remove] invalid key location \(kl) on button \(bl) ")
                    }
                    keys.remove(at: kl)
                }
                self.sandbox[bl] = keys
            } else {
                self.sandbox.remove(at: bl)
            }
        }
    }
    
    private func doInsert(for op: EKOperationInfo) throws {
        guard let bLocs = op.locations else {
            throw EKError.info("[insert] no target locations")
        }
        guard let newBtns = op.buttons?.array else {
            throw EKError.info("[insert] no new buttons")
        }
        if bLocs.locations.count != newBtns.count {
            throw EKError.info("[insert] new buttons size not match")
        }
        let bCnt = self.sandbox.count
        for (i, bl) in bLocs.locations.enumerated() {
            if bl < 0 || bl > bCnt {
                throw EKError.info("[insert] invalid button location \(bl)")
            }
            let btn = newBtns[i]
            if let kLocs = btn.locations { //insert keys
                guard let newKeys = btn.keys?.array else {
                    throw EKError.info("[insert] no new keys")
                }
                if kLocs.locations.count != newKeys.count {
                    throw EKError.info("[insert] new keys size not match")
                }
                var keys = self.sandbox[bl]
                let kCnt = keys.count
                for (i, kl) in kLocs.locations.enumerated() {
                    if kl < 0 || kl > kCnt {
                        throw EKError.info("[insert] invalid key location \(kl) on button \(bl)")
                    }
                    keys.insert(try self.newKey(for: newKeys[i]), at: kl)
                }
                self.sandbox[bl] = keys
            } else { //insert button
                self.sandbox.insert(try self.newButton(for: btn), at: bl)
            }
        }
    }
    
    private func doAppend(for op: EKOperationInfo) throws {
        // *append* appends buttons or keys to specific buttons
        //
        // 1. when the operation node doesn't have the *locations*
        // property, it means appending buttons only. All the buttons
        // in the *buttons* array will be appended to the end of
        // existing bar orderly;
        //
        // 2. when the *locations* property presents, it contains the
        // indexes of buttons to which the new keys will be appended.
        // The new keys for each key-appending button are available
        // in the *buttons* array: the first button node's *keys*
        // will be appended to the button located by the first location
        // in *location*, the second button node the second location,
        // and go on... The extra button nodes, if there is any, will
        // be treated as buttons appended to the bar. It will be an
        // error if the size of *locations* is bigger than that of the
        // buttons in *buttons*
        
        guard let btns = op.buttons?.array, !btns.isEmpty else {
            throw EKError.info("[append] no buttons")
        }
        if let bLocs = op.locations?.locations { // append keys for some buttons
            guard btns.count >= bLocs.count else {
                throw EKError.info("[append] not enough button infos for keys-appending")
            }
            for (i, bl) in bLocs.enumerated() {
                guard let newKeys = btns[i].keys?.array else {
                    continue
                }
                if bl < 0 || bl >= self.sandbox.count {
                    throw EKError.info("[append] invalid button location \(bl)")
                }
                var keys = self.sandbox[bl]
                for nk in newKeys {
                    keys.append(try self.newKey(for: nk))
                }
                self.sandbox[bl] = keys
            }
            let extraBtns = Array(btns[bLocs.count...])
            try self.appendButtons(for: extraBtns)
        } else { // append only buttons
            try self.appendButtons(for: btns)
        }
    }
    
    private func appendButtons(for buttons: [EKButtonInfo]) throws {
        guard buttons.count > 0 else { return }
        for b in buttons {
            let nb = try self.newButton(for: b)
            self.sandbox.append(nb)
        }
    }
    
    private func doReplace(for op: EKOperationInfo) throws {
        // *replace* replaces buttons or keys of specific buttons
        //
        // 1. *locations* of each node indicates the item to be replaced.
        // This property must present in an operation node, or there is no
        // targets for this operation.
        //
        // 2. when there is no *locations* property in a button node, it
        // means this button is one of the replacing targets of this
        // operation.
        //
        // 3. when the *locations* property appears in a button node, it
        // means that the keys at those locations in this button will be
        // replaced with keys in the *keys* property.
        //
        // 4. an error will emerge if the substitution items (items in
        // *buttons* or *keys*) size is less than that of *locations*.
        
        guard let bLocs = op.locations?.locations, bLocs.count > 0 else {
            throw EKError.info("[replace] no target button locations")
        }
        guard let subBtns = op.buttons?.array, subBtns.count >= bLocs.count else {
            throw EKError.info("[replace] not enough substitution buttons")
        }
        for (i, bl) in bLocs.enumerated() {
            if bl < 0 || bl >= self.sandbox.count {
                throw EKError.info("[replace] invalid button location \(bl)")
            }
            let subBtn = subBtns[i]
            if let kLocs = subBtn.locations?.locations, kLocs.count > 0 { // replace keys on the button
                guard let subKeys = subBtn.keys?.array, subKeys.count >= kLocs.count else {
                    throw EKError.info("[replace] not enough substitution keys on button \(bl)")
                }
                var keys = self.sandbox[bl]
                let kCnt = keys.count
                for (i, kl) in kLocs.enumerated() {
                    if kl < 0 || kl >= kCnt {
                        throw EKError.info("[replace] invalid key location \(kl) on button \(bl)")
                    }
                    let subKey = try self.newKey(for: subKeys[i])
                    keys.replaceSubrange(kl..<kl + 1, with: [subKey])
                }
                self.sandbox[bl] = keys
            } else { // replace the button
                let newBtn = try self.newButton(for: subBtn)
                self.sandbox.replaceSubrange(bl..<bl + 1, with: [newBtn])
            }
        }
    }
    
    private func doApply(for op: EKOperationInfo) throws {
        // *apply* applies the pending edits
        //
        // before applying, all the edits will be within the sandbox.
        // The extended bar will not update with the edits until this
        // operation.
        //
        // this operation has the same effects as the bang
        // command (:isetekbd!)
        //
        // no argument is needed
        
        self.confirmChanges()
    }
    
    private func doClear(for op: EKOperationInfo) throws {
        // *clear* removes all existing buttons
        //
        // no argument is needed
        
        self.sandbox.removeAll()
    }
    
    private func doDefault(for op: EKOperationInfo) throws {
        // *default* reverts the buttons to the default ones
        //
        // no argument is needed
        
        self.sandbox = self.defaultButtons
    }
    
    private func doSource(for op: EKOperationInfo) throws {
        // *source* reads the configurations in the given files
        // and does the edits respectively
        //
        // 1. one *source* operation can read a bunch of
        // configuration files and process them orderly. The file
        // paths can be given as a vim string list.
        //
        // 2. the basic unit of a configuration file is a
        // configuration item. One item is a :isetekbd command
        // without the command name. (e.g. "clear" or "remove {...")
        // The *source* operation will process the items one by
        // one, like running one :isetekbd command after another.
        //
        // 3. the configuration file comply with the line continuation
        // rule of vim (:h line-continuation).
        //
        // 4. the *source* operation will stop and cancel the effects
        // of already processed configuration items when it encounters
        // an error in the configuration file.
        //
        // 5. vim style comments are also supported in the configuration
        // file.??? TODO
        
        let paths: [String]
        if let s = op.arguments as? String { // string argument
            paths = CommandTokenizer(line: s).run()
        } else if let l = op.arguments as? [String] {
            paths = l
        } else {
            throw EKError.info("[source] invalid argument")
        }
        guard paths.count > 0 else {
            throw EKError.info("[source] no target files")
        }
        let backup = self.sandbox
        do {
            try paths.forEach { try self.sourceFile(at: $0) }
        } catch { // something is wrong (4.)
            self.sandbox = backup
            throw error
        }
    }
    
    private func sourceFile(at path: String) throws {
        guard let reader = LineReader(file: fopen(path, "r")) else {
            throw EKError.info("[source] failed to open file at \(path)")
        }
        NSLog("source file at: \(path)")
        var item = ""
        var line = ""
        for l in reader {
            line = l.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue } // ignore empty line
            if line.hasPrefix("\\") { // it is a continued line
                item += line.dropFirst()
            } else { // it is a new item
                try self.sourceItem(item)
                item = line
            }
        }
        try self.sourceItem(item) // source the last item
    }
    
    private func sourceItem(_ item: String) throws {
        NSLog("source item: \(item)")
        guard !item.isEmpty else { return }
        let ops = try EKOperationInfo.operations(from: item)
        NSLog("\(ops)")
        try self.edit(with: ops)
    }
    
    private func newButton(for bi: EKButtonInfo) throws -> [EKKeyOption] {
        guard let newKeys = bi.keys?.array else { return [] }
        
        return try newKeys.map { try self.newKey(for: $0) }
    }
    
    private func commandKey(title: String, contents: String) -> EKKeyOption {
        return EKKeyOption(title: title, action: { _ in
            do_cmdline_cmd(contents)
        })
    }
    
    private func newKey(for ki: EKKeyInfo) throws -> EKKeyOption {
        switch ki.type {
        case .insert:
            return self.inputOption(for: ki.contents, title: ki.title)
        case .modifier:
            guard let mk = EKModifierKey(name: ki.contents) else {
                throw EKError.info("[key] invalid key \(ki.contents)")
            }
            return self.modifierKey(title: ki.title, key: mk)
        case .special:
            guard let sk = EKSpecialKey(name: ki.contents) else {
                throw EKError.info("[key] invalid special key \(ki.contents)")
            }
            return self.specialKey(type: sk, title: ki.title)
        case .command:
            return self.commandKey(title: ki.title, contents: ki.contents)
        }
    }
    
    func edit(with operations: [EKOperationInfo]) throws {
        for op in operations {
            try self.edit(with: op)
        }
    }
}
