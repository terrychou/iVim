//
//  ArgumentToken.swift
//  iVim
//
//  Created by Terry Chou on 15/03/2018.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import Foundation

enum ArgumentTokenEscape: String {
    case user = "U"
    case password = "PW"
    case host = "H"
    case path = "PT"
    case query = "Q"
    case fragment = "F"
    
    init?(name: String) {
        let n = name.isEmpty ? "Q" : name.uppercased()
        self.init(rawValue: n)
    }
    
    var allowed: CharacterSet {
        switch self {
        case .user: return .urlUserAllowed
        case .password: return .urlPasswordAllowed
        case .host: return .urlHostAllowed
        case .path: return .urlPathAllowed
        case .query: return .urlQueryAllowed
        case .fragment: return .urlFragmentAllowed
        }
    }
    
    func escape(_ text: String) -> String {
        return text.addingPercentEncoding(withAllowedCharacters: self.allowed) ?? text
    }
}

private let escapeSeparator = "^["

struct ArgumentToken {
    let text: String
    let escape: ArgumentTokenEscape
    
    init(token: String) {
        let components = token.components(separatedBy: escapeSeparator)
        let e = components.count > 1 ?
            ArgumentTokenEscape(name: components.last!.trimmingCharacters(in: .whitespaces)) : nil
        self.escape = e ?? .query
        self.text = e != nil ? components.dropLast().joined(separator: escapeSeparator) : token
    }
    
    var value: String {
        let evaluated = string_value_of_expr(self.text)!
        return self.escape.escape(evaluated)
    }
}
