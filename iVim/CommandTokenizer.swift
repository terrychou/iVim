//
//  CommandTokenizer.swift
//  Locu
//
//  Created by Terry on 2/28/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import Foundation

private let sNormal = CharacterSet(charactersIn: " \"\'\\")
private let sWeakQuotes = CharacterSet(charactersIn: "\"")
private let sStrongQuotes = CharacterSet(charactersIn: "\'")
private let sEscape = CharacterSet()

final class CommandTokenizer: NSObject {
    let line: String
    var modes = Stack<Mode>()
    var acum = ""
    var args = [String]()
    
    @objc init(line: String) {
        self.line = line
    }
    
    enum Mode: String {
        case normal = " "
        case weakQuotes = "\""
        case strongQuotes = "\'"
        case escape = "\\"
        
        var expectingSet: CharacterSet {
            switch self {
            case .normal: return sNormal
            case .weakQuotes: return sWeakQuotes
            case .strongQuotes: return sStrongQuotes
            case .escape: return sEscape
            }
        }
        
        var isPair: Bool {
            switch self {
            case .weakQuotes, .strongQuotes: return true
            default: return false
            }
        }
        
        var allowsEmpty: Bool {
            switch self {
            case .weakQuotes, .strongQuotes: return true
            default: return false
            }
        }
    }
    
    private var mode: Mode {
        return self.modes.top()!
    }
    
    private func tackle(_ scalar: UnicodeScalar) {
        if self.changeMode(for: scalar) { return }
        switch self.mode {
        case .normal: self.append(scalar)
        case .weakQuotes: self.append(scalar)
        case .strongQuotes: self.append(scalar)
        case .escape: self.tackleEscape(scalar)
        }
    }
    
    private func harvest(allowingEmpty: Bool = false) {
        guard allowingEmpty || !self.acum.isEmpty else { return }
        self.args.append(self.acum)
        self.acum = ""
    }
    
    private func changeMode(for scalar: UnicodeScalar) -> Bool {
        let old = self.mode
        guard old.expectingSet.contains(scalar),
            let new = Mode(rawValue: String(scalar)) else { return false }
        if new.isPair && old == new {
            self.modes.pop()
        } else if old != new {
            self.modes.push(new)
        }
        if new != .escape {
            self.harvest(allowingEmpty: old.allowsEmpty)
        }
        
        return true
    }
    
    private func tackleEscape(_ scalar: UnicodeScalar) {
        self.append(scalar)
        self.modes.pop()
    }
    
    private func append(_ scalar: UnicodeScalar) {
        self.acum.unicodeScalars.append(scalar)
    }
    
    @objc func run() -> [String] {
        self.modes.push(.normal)
        for scalar in self.line.unicodeScalars {
            self.tackle(scalar)
        }
        if self.mode == .normal {
            self.harvest()
        }
        
        return self.args
    }
}
