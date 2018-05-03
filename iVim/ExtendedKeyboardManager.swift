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
    
    private weak var ctrlButton: OptionalButton?
    private var ctrlEnabled: Bool {
        return self.ctrlButton?.isOn(withTitle: "ctrl") ?? false
    }
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
    }
    
    private func undoChanges() {
        self.sandbox = self.extendedBar.buttons
    }
}

extension ExtendedKeyboardManager {
    func handleModifiers(with text: String) -> Bool {
        if self.ctrlEnabled {
            self.ctrlButton!.tryRestore()
            let t = text == "\n" ? "CR" : text
            self.controller.insertSpecialName("<C-\(t)>")
            return true
        }
        
        return false
    }
    
    func modifiersString(byCombining list: [String]) -> String {
        var s = Set(list)
        if self.ctrlEnabled {
            self.ctrlButton?.tryRestore()
            s.insert("C")
        }
        
        return s.reduce("") { $0 + $1 + "-" }
    }
}

extension ExtendedKeyboardManager {
    private func insertText(_ text: String) {
        self.controller.insertText(text)
    }
    
    private func pressArrow(_ key: Int32) {
        self.controller.pressArrow(key)
    }
    
    private func inputOption(for key: String) -> EKKeyOption {
        return EKKeyOption(title: key, action: { _ in self.insertText(key) })
    }
    
    private func press(modified: String, action: () -> Void) {
        if self.handleModifiers(with: modified) { return }
        action()
    }
    
    private var defaultButtons: EKButtons {
        return [
            [
                EKKeyOption(title: "esc", action: { _ in
                    self.press(modified: "Esc", action: self.controller.pressESC)
                }),
                EKKeyOption(title: "ctrl", action: { b in
                    guard self.ctrlButton != b else { return }
                    self.ctrlButton = b
                }, isSticky: true)],
            [
                EKKeyOption(title: "tab", action: { _ in self.press(modified: "Tab") { self.insertText(keyTAB.unicoded) } }),
                EKKeyOption(title: "↓", action: { _ in self.press(modified: "Down") { self.pressArrow(keyDOWN) } }),
                EKKeyOption(title: "←", action: { _ in self.press(modified: "Left") { self.pressArrow(keyLEFT) } }),
                EKKeyOption(title: "→", action: { _ in self.press(modified: "Right") { self.pressArrow(keyRIGHT) } }),
                EKKeyOption(title: "↑", action: { _ in self.press(modified: "Up") { self.pressArrow(keyUP) } }) ],
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
        case .remove: try self.remove(for: operation)
        default: NSLog("Not implemented yet.")
        }
    }
    
    private func remove(for op: EKOperationInfo) throws {
        guard let locations = op.locations?.locations else {
            throw EKEditingError.info("no locations available for removing buttons")
        }
        for loc in locations.sorted(by: >) {
            if let keys = op.buttons?.dict?[loc] {
                NSLog("remove keys \(keys) of button \(loc)")
            } else {
                let bc = self.sandbox.count
                if loc < 0 || loc >= bc {
                    throw EKEditingError.info("failed to remove button at \(loc)")
                }
                self.sandbox.remove(at: loc)
            }
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

enum EKKeyType: String {
    case command
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
