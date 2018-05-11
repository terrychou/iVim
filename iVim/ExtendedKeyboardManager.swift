//
//  ExtendedKeyboardManager.swift
//  iVim
//
//  Created by Terry Chou on 2018/5/2.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import UIKit

let gEKM = ExtendedKeyboardManager.shared
typealias EKButtons = [[EKKeyOption]]
private typealias EKButtonPair = (Int, EKButtonInfo?)

private enum EKMode {
    case compose
    //   compose: this mode is for experimenting and composing
    //   configuration files. Each editing item will update
    //   the bar immediately and be recorded into the editing
    //   history. As a result, you can edit the bar more
    //   conveniently: using *undo* to undo one item; *redo* to
    //   redo one item; *export* to export items so far to a
    //   configuration file for future sourcing.
    case normal
    //   normal: this is for editing on the command line without
    //   history records.
    //   The bar will not be updated until the next *apply*
    //   operation. The editing items will not be recorded
    //   therefore all history-related operations will not work
    //   in this mode.
    case source
    //   source: it is like .normal and indicates that it is
    //   during a sourcing.
}

final class ExtendedKeyboardManager: NSObject {
    @objc static let shared = ExtendedKeyboardManager()
    private override init() {}
    
    private weak var controller: VimViewController!
    lazy var extendedBar: OptionalButtonsBar = {
        let newBar = self.newBar()
        self.sandbox = newBar.buttons // initialize sandbox
        
        return newBar
    }()
    private var sandbox: EKButtons! // operate on it before confirmation
    private lazy var modifiers = EKModifiersArranger()
    
    private lazy var history = EKEditingHistory()
    private var mode: EKMode = .normal
    private var operationsCount: Int = 0 // record the amount of operations for each item
    private var allowedInHistory = true
}

extension ExtendedKeyboardManager {
    func registerController(_ c: VimViewController) {
        self.controller = c
    }
    
    @objc func setKeyboard(with cmdArg: String, confirmed: Bool) {
        NSLog("isetekbd: \"\(cmdArg)\"")
        let item = cmdArg.trimmingCharacters(in: .whitespaces)
        self.allowedInHistory = true // allowed by default
        do {
            try self.sourceItem(item)
            self.addHistory(with: item)
            if confirmed || self.isComposing {
                self.confirmChanges()
            }
        } catch EKError.info(let msg) {
            self.showError(msg)
        } catch {
            NSLog("[system] failed to generate operations \(error)")
        }
    }
    
    private func confirmChanges() {
        self.extendedBar.buttons = self.sandbox
        self.extendedBar.updateButtons()
        self.modifiers.clear()
    }
}

extension ExtendedKeyboardManager {
    private var isComposing: Bool {
        return self.mode == .compose
    }
    
    private var isSourcing: Bool {
        return self.mode == .source
    }
    
    private var isSingleOperation: Bool {
        return self.operationsCount == 1
    }
    
    private func addHistory(with item: String) {
        guard self.isComposing &&
            self.allowedInHistory else { return }
        self.history.add(buttons: self.sandbox,
                         sourceItem: item)
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
    
    private func edit(with op: EKOperationInfo) throws {
        switch op.op {
        case .append: try self.doAppend(for: op)
        case .insert: try self.doInsert(for: op)
        case .remove: try self.doRemove(for: op)
        case .replace: try self.doReplace(for: op)
        case .apply: try self.doApply(for: op)
        case .clear: try self.doClear(for: op)
        case .default: try self.doDefault(for: op)
        case .source: try self.doSource(for: op)
        case .compose: try self.doCompose(for: op)
        case .normal: try self.doNormal(for: op)
        case .undo: try self.doUndo(for: op)
        case .redo: try self.doRedo(for: op)
        case .export: try self.doExport(for: op)
//        default: NSLog("Not implemented yet.")
        }
    }
    
    private func editButton(at i: Int, editing: (inout [EKKeyOption]) throws -> Void) rethrows {
        var button = self.sandbox[i]
        try editing(&button)
        self.sandbox[i] = button
    }
    
    private func doRemove(for op: EKOperationInfo) throws {
        // *remove* deletes buttons or keys on buttons located
        // by the *locations* property
        //
        // 1. the *locations* property (list) of the operation node
        // indicates the locations (0 based) of buttons. It throws
        // an error if this property is empty. Then the optional
        // *buttons* property gives button nodes which will contain
        // its own *locations* property indicating the locations of
        // keys on each button
        //
        // 2. each button in the *buttons* list will match locations
        // in *locations* of the operation node orderly: if there is
        // a match, it will remove the indicated keys on this button;
        // otherwise, this button itself will be removed
        //
        // 3. the locations will be sorted in descendent order before
        // removing: a) it ensures correct removing order (a sooner
        // location would not broke a later one); b) there would not
        // be any removing if any illegal location presents
        
        guard op.hasLocations else {
            throw op.error("no target button locations")
        }
        let bCnt = self.sandbox.count
        try op.forEachLocation(preprocess: {
            $0.sorted { $0.0 > $1.0 } // (3.)
        }) { bLoc, btn in
            guard (0..<bCnt).contains(bLoc) else {
                throw op.error("invalid button location \(bLoc)")
            }
            if let b = btn, b.hasLocations { // remove keys on the button
                try self.editButton(at: bLoc) { keys in
                    let kCnt = keys.count
                    try b.forEachLocation(preprocess: {
                        $0.sorted { $0.0 > $1.0 } // (3.)
                    }) { kLoc, _ in
                        guard (0..<kCnt).contains(kLoc) else {
                            throw op.error("invalid key location \(kLoc) on button \(bLoc)")
                        }
                        keys.remove(at: kLoc)
                    }
                }
            } else { // remove a button
                self.sandbox.remove(at: bLoc)
            }
        }
    }
    
    private func doInsert(for op: EKOperationInfo) throws {
        // *insert* inserts new buttons to specific locations,
        // or new keys to specific locations on a button
        //
        // 1. it treats locations more significantly, meaning
        // the number of new items (buttons or keys) must be greater
        // than or equal to that of the target locations, otherwise
        // an error will be thrown
        //
        // 2. when a button node doesn't have *locations*, it means
        // inserting this new button to the paired location; otherwise,
        // it inserts the new keys generated by *keys* to the exsiting
        // button according to *locations* of the button
        //
        // 3. it processes the locations in the order as they are given,
        // which implies that a later location need to take the result
        // of a sooner one into account. an invalid location will trigger
        // an error
        
        guard op.hasLocations else {
            throw op.error("no target button locations")
        }
        guard op.locationsCount <= op.subitemsCount else { // (1.)
            throw op.error("not enough new buttons")
        }
        let bCnt = self.sandbox.count
        try op.forEachLocation { bLoc, bInfo in
            guard (0...bCnt).contains(bLoc) else {
                throw op.error("invalid button location \(bLoc)")
            }
            let b = bInfo! // available for sure
            if b.hasLocations { // insert new keys (2.)
                guard b.locationsCount <= b.subitemsCount else {
                    throw op.error("not enough new keys")
                }
                try self.editButton(at: bLoc) { keys in
                    let kCnt = keys.count
                    try b.forEachLocation { kLoc, kInfo in
                        guard (0...kCnt).contains(kLoc) else {
                            throw op.error("invalid key location \(kLoc) on button \(bLoc)")
                        }
                        keys.insert(try self.newKey(for: kInfo!), at: kLoc) // (3.)
                    }
                }
            } else { // insert this new button (2.)
                self.sandbox.insert(try self.newButton(for: b), at: bLoc) // (3.)
            }
        }
    }
    
    private func doAppend(for op: EKOperationInfo) throws {
        // *append* appends buttons or keys to specific buttons
        //
        // 1. when the operation node doesn't have the *locations*
        // property, it means appending buttons only. All the buttons
        // in the *buttons* array will be appended to the end of
        // existing bar orderly
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
        
        guard op.hasSubitems else {
            throw op.error("no buttons")
        }
        guard op.locationsCount <= op.subitemsCount else {
            throw op.error("not enough new buttons for target locations")
        }
        let bCnt = self.sandbox.count
        try op.forEachSubitem { bLoc, bInfo in
            if let bl = bLoc { // it is key-appending button (2.)
                guard (0..<bCnt).contains(bl) else {
                    throw op.error("invalid button location \(bl)")
                }
                try self.editButton(at: bl) { keys in
                    let newKeys = try bInfo.subitemsArray.map {
                        try self.newKey(for: $0)
                    }
                    keys.append(contentsOf: newKeys)
                }
            } else { // append buttons to the bar end (1., 2.)
                self.sandbox.append(try self.newButton(for: bInfo))
            }
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
        
        guard op.hasLocations else { // (1.)
            throw op.error("no target button locations")
        }
        guard op.locationsCount <= op.subitemsCount else { // (4.)
            throw op.error("not enough substitution buttons")
        }
        let bCnt = self.sandbox.count
        try op.forEachLocation { bLoc, bInfo in
            guard (0..<bCnt).contains(bLoc) else {
                throw op.error("invalid button location \(bLoc)")
            }
            let b = bInfo! // available for sure
            if b.hasLocations { // replace keys on this button (3.)
                guard b.locationsCount <= b.subitemsCount else {
                    throw op.error("not enough substitution keys on button \(bLoc)")
                }
                try self.editButton(at: bLoc) { keys in
                    let kCnt = keys.count
                    try b.forEachLocation { kLoc, kInfo in
                        guard (0..<kCnt).contains(kLoc) else {
                            throw op.error("invalid key location \(kLoc) on button \(bLoc)")
                        }
                        let newKey = try self.newKey(for: kInfo!)
                        keys.replaceElement(at: kLoc, with: newKey)
                    }
                }
            } else { // replace the button (2.)
                let newButton = try self.newButton(for: b)
                self.sandbox.replaceElement(at: bLoc, with: newButton)
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
    
    private func paths(from op: EKOperationInfo) throws -> [String] {
        let paths: [String]
        if let s = op.arguments as? String { // string argument
            paths = CommandTokenizer(line: s).run()
        } else if let l = op.arguments as? [String] {
            paths = l
        } else {
            throw EKError.info("[\(op.op.name)] invalid argument")
        }
        
        return paths.map { expand_tilde_of_path($0) }
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
        // 5. lines beginning with " will be treated as comments
        
        let paths = try self.paths(from: op)
        guard paths.count > 0 else {
            throw EKError.info("[source] no target files")
        }
        let backup = self.sandbox
        let oldMode = self.mode
        self.mode = .source // set the mode temporarily
        defer { self.mode = oldMode } // restore to old mode anyway
        do {
            try paths.forEach { try self.sourceFile(at: $0) }
        } catch { // something is wrong (4.)
            self.sandbox = backup // restore to state before sourcing
            throw error
        }
    }
    
    private func sourceFile(at path: String) throws {
        guard let reader = LineReader(file: fopen(path, "r")) else {
            throw EKError.info("[source] failed to open file at \(path)")
        }
        NSLog("source file at: \(path)")
        var item = ""
        for line in reader {
            guard let l = self.validLine(from: line) else { continue } // ignore empty line or comments
            if l.hasPrefix("\\") { // it is a continued line
                item += l.dropFirst()
            } else { // it is a new item
                try self.sourceItem(item)
                item = l
            }
        }
        try self.sourceItem(item) // source the last item
    }
    
    private func validLine(from line: String) -> String? {
        let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return l.isEmpty || l.hasPrefix("\"") ? nil : l
    }
    
    private func sourceItem(_ item: String) throws {
        NSLog("source item: \(item)")
        self.operationsCount = 0
        guard !item.isEmpty else { return }
        let ops = try EKOperationInfo.operations(from: item)
        self.operationsCount = ops.count
//        NSLog("\(ops)")
        try self.edit(with: ops)
    }
    
    private func validateComposeOperation(_ op: String) throws {
        // test whether it is a valid compose operation environment
        //
        // 1. it can only run as a single operation, meaning it is
        // an error if the operation is one of several operations of
        // an item
        //
        // 2. it can only run from the command line, meaning it is
        // an error when it is in a file being sourced
        
        guard self.isSingleOperation else {
            throw EKError.info("[\(op)] only allowed as a single operation")
        }
        guard !self.isSourcing else {
            throw EKError.info("[\(op)] not allowed during sourcing")
        }
    }
    
    private func doCompose(for op: EKOperationInfo) throws {
        // *compose* starts the compose mode
        //
        // 1. the .compose mode is described in EKMode
        //
        // 2. this operation should only run in compose env
        //
        // 3. recorded in the editing history as the first item
        //
        // 4. no argument is required
        
        try self.validateComposeOperation("compose") // (2.)
        guard !self.isComposing else {
            throw EKError.info("[compose] already in compose mode")
        }
        self.mode = .compose // history works now
    }
    
    private func doNormal(for op: EKOperationInfo) throws {
        // *normal* starts the normal mode
        //
        // 1. its main use is to end the compose mode
        //
        // 2. it should only run in compose env
        //
        // 3. it will clear the history
        //
        // 4. not recorded in the editing history
        //
        // 5. no argument is required
        
        try self.validateComposeOperation("normal") // (2.)
        guard self.mode != .normal else {
            throw EKError.info("[normal] already in normal mode")
        }
        self.allowedInHistory = false
        self.mode = .normal
        self.history.clear() // clear the history (3., 4.)
    }
    
    private func doUndo(for op: EKOperationInfo) throws {
        // *undo* reverts the bar to the last state
        //
        // 1. it should only run in compose env
        //
        // 2. not recorded in editing history
        //
        // 3. no argument is required
        
        try self.validateComposeOperation("undo") // (1.)
        guard self.isComposing else {
            throw EKError.info("[undo] not in compose mode")
        }
        self.allowedInHistory = false // (2.)
        if let i = self.history.undo() {
            self.sandbox = i.buttons
        } else {
            throw EKError.info("[undo] already at the beginning of history")
        }
    }
    
    private func doRedo(for op: EKOperationInfo) throws {
        // *redo* reverts the last *undo*
        //
        // 1. it should only run in compose env
        //
        // 2. not recorded in editing history
        //
        // 3. no argument is required
        
        try self.validateComposeOperation("redo") // (1.)
        guard self.isComposing else {
            throw EKError.info("[redo] not in compose mode")
        }
        self.allowedInHistory = false // (2.)
        if let i = self.history.redo() {
            self.sandbox = i.buttons
        } else {
            throw EKError.info("[redo] already at the end of history")
        }
    }
    
    private func doExport(for op: EKOperationInfo) throws {
        // *export* exports editing items in current compose session
        // into configuration files, for future use.
        //
        // 1. the editing items to be exported include those which
        // had made the state since the beginning of the current
        // compose session (i.e. items in history[1...index]). If there
        // is no editing item yet, an error will be thrown
        //
        // 2. each editing item will take one line in the outcome
        // file, one blank line will be inserted therefore padding
        // between two items
        //
        // 3. it accepts one or more target paths as its arguments as
        // *source* does. Each path will be tested for existence before
        // exporting. It will be an error if any target path is directory.
        // And any overwrite attempts will also be an error unless it is
        // forced (i.e. "export!")
        //
        // 4. when no target file is given, it prints the result in
        // the command window for review
        //
        // 5. it should only run in the compose env
        //
        // 6. itself will not be recorded in the editing history
        
        try validateComposeOperation("export") // (5.)
        guard self.isComposing else {
            throw EKError.info("[export] not in compose mode")
        }
        self.allowedInHistory = false // (6.)
        
        let paths = try self.paths(from: op)
        // test paths (3.)
        for p in paths {
            var isDir = ObjCBool(false)
            if FileManager.default.fileExists(atPath: p, isDirectory: &isDir) {
                if isDir.boolValue {
                    throw EKError.info("[export] '\(p)' is a directory")
                } else if !op.isForced {
                    throw EKError.info("[export] '\(p)' already exists, use 'export!' to force overwrite")
                }
            }
        }
        
        // generate contents (1.)
        let items = self.history.editingItems()
        guard items.count > 0 else {
            throw EKError.info("[export] not edited yet")
        }
        var contents = ""
        for i in items {
            contents += i + "\n\n" // (2.)
        }
        contents.removeLast(2) // no empty lines at the end
        
        if paths.count > 0 {
            // write to targets
            for p in paths {
                do {
                    try contents.write(toFile: p, atomically: true, encoding: .utf8)
                } catch {
                    NSLog("[export] failed to write to file: \(error)")
                    throw EKError.info("[export] failed to write to file '\(p)'")
                }
            }
        } else { // (4.)
            let opname = "export" + (op.isForced ? "!" : "")
            gSVO.showContent(contents, withCommand: "isetekbd \(opname)")
        }
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
    
    private func edit(with operations: [EKOperationInfo]) throws {
        for op in operations {
            try self.edit(with: op)
        }
    }
}

private extension Array {
    mutating func replaceElement(at i: Index, with newElement: Element) {
        self.replaceSubrange(i..<i + 1, with: [newElement])
    }
}
