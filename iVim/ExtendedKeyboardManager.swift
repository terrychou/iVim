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
    
//    private weak var ctrlButton: OptionalButton?
//    private var ctrlEnabled: Bool {
//        return false
////        return self.ctrlButton?.isOn(withTitle: "ctrl") ?? false
//    }
    
    private lazy var modifiers = EKModifiersArranger()
}

extension ExtendedKeyboardManager {
    func registerController(_ c: VimViewController) {
        self.controller = c
    }
    
    @objc func setKeyboard(with arguments: String, confirmed: Bool) {
        NSLog("isetekbd: \(arguments)")
        if !arguments.isEmpty {
            let o = object_of_expr(arguments)
            let ops = self.operations(from: o)
            //        print(o)
            print(ops)
            //        self.edit(with: self.test)
            self.edit(with: ops)
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
        let ms = self.modifiersString()
        guard !ms.isEmpty else { return false }
        let t = text == "\n" ? "CR" : text
        self.controller.insertSpecialName("<\(ms)\(t)>")
//        if self.ctrlEnabled {
//            self.ctrlButton!.tryRestore()
//            let t = text == "\n" ? "CR" : text
//            self.controller.insertSpecialName("<C-\(t)>")
//            return true
//        }
        
        return true
    }
    
    func modifiersString(byCombining list: [String] = []) -> String {
        let s = Set(list)
//        if self.ctrlEnabled {
//            self.ctrlButton?.tryRestore()
//            s.insert("C")
//        }
        let modifiers = self.modifiers.activeKeyStringSet { mi in
            DispatchQueue.main.async {
                mi.button?.tryRestore()
            }
        }
        
        return s.union(modifiers).reduce("") { $0 + $1 + "-" }
    }
    
    private func modifierKey(title: String, key: EKModifierKey) -> EKKeyOption {
        let action: Action = { [unowned self] b in
            self.modifiers.update(for: b, with: key.keyString)
        }
        
        return EKKeyOption(title: title, action: action, isSticky: true)
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
        return EKKeyOption(title: title ?? key, action: { [unowned self] _ in self.insertText(key) })
    }
    
    private func press(modified: String, action: () -> Void) {
        if self.handleModifiers(with: modified) { return }
        action()
    }
    
    private var defaultButtons: EKButtons {
        return [
            [
                EKKeyOption(title: "esc", action: { [unowned self] _ in
                    self.press(modified: "Esc", action: self.controller.pressESC)
                }),
                self.modifierKey(title: "ctrl", key: .control),
                self.modifierKey(title: "alt", key: .alt)],
            
            [
                EKKeyOption(title: "tab", action: { [unowned self] _ in self.press(modified: "Tab") { self.insertText(keyTAB.unicoded) } }),
                EKKeyOption(title: "↓", action: { [unowned self] _ in self.press(modified: "Down") { self.pressArrow(keyDOWN) } }),
                EKKeyOption(title: "←", action: { [unowned self] _ in self.press(modified: "Left") { self.pressArrow(keyLEFT) } }),
                EKKeyOption(title: "→", action: { [unowned self] _ in self.press(modified: "Right") { self.pressArrow(keyRIGHT) } }),
                EKKeyOption(title: "↑", action: { [unowned self] _ in self.press(modified: "Up") { self.pressArrow(keyUP) } }) ],
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
        case .append: try self.append(for: operation)
        case .insert: try self.insert(for: operation)
        case .remove: try self.remove(for: operation)
        case .replace: try self.replace(for: operation)
//        default: NSLog("Not implemented yet.")
        }
    }
    
    private func remove(for op: EKOperationInfo) throws {
        guard let bLocs = op.locations else {
            throw EKEditingError.info("[remove] no target locations")
        }
        let bCnt = self.sandbox.count
        for bl in bLocs.locations.sorted(by: >) {
            if bl < 0 || bl >= bCnt {
                throw EKEditingError.info("[remove] invalid button location \(bl)")
            }
            if let b = op.buttons?.dict?[bl], let kLocs = b.locations {
                var keys = self.sandbox[bl]
                let kCnt = keys.count
                for kl in kLocs.locations.sorted(by: >) {
                    if kl < 0 || kl >= kCnt {
                        throw EKEditingError.info("[remove] invalid key location \(kl) on button \(bl) ")
                    }
                    keys.remove(at: kl)
                }
                self.sandbox[bl] = keys
            } else {
                self.sandbox.remove(at: bl)
            }
        }
    }
    
    private func insert(for op: EKOperationInfo) throws {
        guard let bLocs = op.locations else {
            throw EKEditingError.info("[insert] no target locations")
        }
        guard let newBtns = op.buttons?.array else {
            throw EKEditingError.info("[insert] no new buttons")
        }
        if bLocs.locations.count != newBtns.count {
            throw EKEditingError.info("[insert] new buttons size not match")
        }
        let bCnt = self.sandbox.count
        for (i, bl) in bLocs.locations.enumerated() {
            if bl < 0 || bl > bCnt {
                throw EKEditingError.info("[insert] invalid button location \(bl)")
            }
            let btn = newBtns[i]
            if let kLocs = btn.locations { //insert keys
                guard let newKeys = btn.keys?.array else {
                    throw EKEditingError.info("[insert] no new keys")
                }
                if kLocs.locations.count != newKeys.count {
                    throw EKEditingError.info("[insert] new keys size not match")
                }
                var keys = self.sandbox[bl]
                let kCnt = keys.count
                for (i, kl) in kLocs.locations.enumerated() {
                    if kl < 0 || kl > kCnt {
                        throw EKEditingError.info("[insert] invalid key location \(kl) on button \(bl)")
                    }
                    keys.insert(try self.newKey(for: newKeys[i]), at: kl)
                }
                self.sandbox[bl] = keys
            } else { //insert button
                self.sandbox.insert(try self.newButton(for: btn), at: bl)
            }
        }
    }
    
    private func append(for op: EKOperationInfo) throws {
        // *append* can append buttons or keys to specific buttons
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
            throw EKEditingError.info("[append] no buttons")
        }
        if let bLocs = op.locations?.locations { // append keys for some buttons
            guard btns.count >= bLocs.count else {
                throw EKEditingError.info("[append] not enough button infos for keys-appending")
            }
            for (i, bl) in bLocs.enumerated() {
                guard let newKeys = btns[i].keys?.array else {
                    continue
                }
                if bl < 0 || bl >= self.sandbox.count {
                    throw EKEditingError.info("[append] invalid button location \(bl)")
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
    
    private func replace(for op: EKOperationInfo) throws {
        // *replace* can replace buttons or keys of specific buttons
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
        
        guard let bLocs = op.locations?.locations else {
            throw EKEditingError.info("[replace] no target button locations")
        }
        guard let subBtns = op.buttons?.array, subBtns.count >= bLocs.count else {
            throw EKEditingError.info("[replace] not enough substitution buttons")
        }
        for (i, bl) in bLocs.enumerated() {
            if bl < 0 || bl >= self.sandbox.count {
                throw EKEditingError.info("[replace] invalid button location \(bl)")
            }
            let subBtn = subBtns[i]
            if let kLocs = subBtn.locations?.locations, kLocs.count > 0 { // replace keys on the button
                guard let subKeys = subBtn.keys?.array, subKeys.count >= kLocs.count else {
                    throw EKEditingError.info("[replace] not enough substitution keys on button \(bl)")
                }
                var keys = self.sandbox[bl]
                let kCnt = keys.count
                for (i, kl) in kLocs.enumerated() {
                    if kl < 0 || kl >= kCnt {
                        throw EKEditingError.info("[replace] invalid key location \(kl) on button \(bl)")
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
    
    private func newButton(for bi: EKButtonInfo) throws -> [EKKeyOption] {
        guard let newKeys = bi.keys?.array else { return [] }
        
        return try newKeys.map { try self.newKey(for: $0) }
    }
    
    private func newKey(for ki: EKKeyInfo) throws -> EKKeyOption {
        switch ki.type {
        case .insert:
            return self.inputOption(for: ki.contents, title: ki.title)
        case .normal:
            throw EKEditingError.info("[imp] not implemented yet")
        case .modifier:
            guard let mk = EKModifierKey(name: ki.contents) else {
                throw EKEditingError.info("[key] invalid key \(ki.contents)")
            }
            return self.modifierKey(title: ki.title, key: mk)
        case .special:
            //TODO implement enum special
            throw EKEditingError.info("[imp] not implemented yet")
        case .command:
            throw EKEditingError.info("[imp] not implemented yet")
//            action = { /* [unowned self] */ _ in
//                let cmd = ki.contents.hasPrefix(":") ? ki.contents : ":" + ki.contents
//                do_cmdline_cmd("normal " + cmd) //TODO not working as expected
//            }
        }
    }
    
    func edit(with operations: [EKOperationInfo]) {
        do {
            for op in operations {
                try self.edit(with: op)
            }
        } catch EKEditingError.info(let i) {
//            NSLog(i)
            self.showError(i)
        } catch {
            NSLog("Failed to edit extended keyboard: \(error)")
        }
    }
    
    private func operations(from object: Any?) -> [EKOperationInfo] {
        var result = [EKOperationInfo]()
        do {
            if let array = object as? NodeArray {
                result = try array.compactMap { try EKOperationInfo(object: $0) }
            } else if let op = try EKOperationInfo(object: object) {
                result.append(op)
            }
        } catch EKEditingError.info(let msg) {
//            NSLog(msg)
            self.showError(msg)
        } catch {
            NSLog("Faild to parse for operations: \(error)")
        }
        
        return result
    }
}

typealias NodeArray = [Any]
typealias NodeDict = [String: Any]

enum EKEditingError: Error {
    case info(String)
}

enum EKModifierKey: String {
    case alt
    case command
    case control
    case meta
    case shift
    
    init?(name: String?) {
        guard let n = name else { return nil }
        self.init(rawValue: n)
    }
    
    var keyString: String {
        switch self {
        case .alt: return "A"
        case .command: return "D"
        case .control: return "C"
        case .meta: return "M"
        case .shift: return "S"
        }
    }
}

enum EKKeyType: String {
    case command
    case insert
    case modifier
    case normal
    case special
    
    init?(name: String?) {
        guard let n = name else { return nil }
        self.init(rawValue: n)
    }
}

private let kType = "type"
private let kTitle = "title"
private let kContents = "contents"

struct EKKeyInfo: EKParseNode {
    let type: EKKeyType
    let title: String
    let contents: String
}

extension EKKeyInfo {
    init?(object: Any?) throws {
        guard let d = object as? NodeDict else {
            throw EKEditingError.info("invalid key node: \(object ?? "nil")")
        }
        guard let tp = EKKeyType(name: d.anyValue(for: kType)) else {
            throw EKEditingError.info("no type for key: \(d)")
        }
        guard let tl: String = d.anyValue(for: kTitle), !tl.isEmpty else {
            throw EKEditingError.info("no title for key: \(d)")
        }
        guard let cnt: String = d.anyValue(for: kContents), !cnt.isEmpty else {
            throw EKEditingError.info("no contents for key: \(d)")
        }
        self.init(type: tp, title: tl, contents: cnt)
    }
}

private let kKeys = "keys"

struct EKButtonInfo: EKParseNode {
    let locations: EKLocationsInfo?
    let keys: EKSubitems<EKKeyInfo>?
}

extension EKButtonInfo {
    init?(object: Any?) throws {
        guard let d = object as? NodeDict else {
            throw EKEditingError.info("invalid button node: \(object ?? "nil")")
        }
        let locs = try EKLocationsInfo(object: d.anyValue(for: kLocations))
        let keys = try EKSubitems<EKKeyInfo>(object: d.anyValue(for: kKeys))
        self.init(locations: locs, keys: keys)
    }
}

enum EKOperation: String {
    case append
    case insert
    case remove
    case replace
    
    init?(name: String?) {
        guard let n = name else { return nil }
        self.init(rawValue: n)
    }
}

struct EKLocationsInfo: EKParseNode {
    let locations: [Int]
}

extension EKLocationsInfo {
    init?(object: Any?) throws {
        if object == nil {
            return nil
        }
        guard let locs = object as? [Int] else {
            throw EKEditingError.info("invalid locations \(object!)")
        }
        self.init(locations: locs)
    }
    
    subscript(_ i: Int) -> Int {
        return self.locations[i]
    }
}

private let kOperation = "operation"
private let kLocations = "locations"
private let kButtons = "buttons"

struct EKOperationInfo {
    let op: EKOperation
    let locations: EKLocationsInfo?
    let buttons: EKSubitems<EKButtonInfo>?
}

extension EKOperationInfo: EKParseNode {
    init?(object: Any?) throws {
        guard let d = object as? NodeDict else {
            throw EKEditingError.info("invalid operation node: \(object ?? "nil")")
        }
        guard let op = EKOperation(name: d.anyValue(for: kOperation)) else {
            throw EKEditingError.info("no valid operation for node: \(d)")
        }
        let locations = try EKLocationsInfo(object: d.anyValue(for: kLocations))
        let buttons = try EKSubitems<EKButtonInfo>(object: d.anyValue(for: kButtons))
        self.init(op: op, locations: locations, buttons: buttons)
    }
}

private extension Dictionary where Key: StringProtocol {
    func anyValue<T>(for key: Key) -> T? {
        return self[key] as? T
    }
}

protocol EKParseNode {
    init?(object: Any?) throws
}

struct EKSubitems<T: EKParseNode>: EKParseNode {
    let array: [T]?
    let dict: [Int: T]?
}

extension EKSubitems {
    init?(object: Any?) throws {
        var array: [T]? = nil
        var dict: [Int: T]? = nil
        if let a = object as? NodeArray {
            array = []
            for e in a {
                if let si = try T(object: e) {
                    array!.append(si)
                }
            }
        } else if let d = object as? NodeDict {
            dict = [:]
            for (k, o) in d {
                if let i = Int(k) {
                    dict![i] = try T(object: o)
                } else {
                    throw EKEditingError.info("invalid location \"\(k)\"")
                }
            }
        }
        self.init(array: array, dict: dict)
    }
}
