//
//  URLRealizer.swift
//  iVim
//
//  Created by Terry Chou on 15/03/2018.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import Foundation

private let openTokenChar = Character("{")
private let closeTokenChar = Character("}")
private let backslash = Character("\\")

enum URLRealizingError: Error {
    case syntax(String, Int)
}

struct URLRealizer {
    let urlString: String
}

extension URLRealizer {
    private enum Mode {
        case normal
        case token
        case backslash
    }
    
    func run() throws -> URL? {
        var result = ""
        var token = ""
        var modes = Stack<(Mode, Int)>()
        var pos = 0
        modes.push((.normal, pos))
        for c in self.urlString {
            let mode = modes.top()!.0
            switch mode {
            case .normal:
                switch c {
                case openTokenChar:
                    modes.push((.token, pos))
                    token = ""
                case closeTokenChar:
                    throw URLRealizingError.syntax("token open character { expected", pos)
                case backslash:
                    modes.push((.backslash, pos))
                default:
                    result.append(c)
                }
            case .token:
                switch c {
                case openTokenChar:
                    throw URLRealizingError.syntax("nested token not allowed", pos)
                case closeTokenChar:
                    result.append(self.value(for: token))
                    modes.pop()
                case backslash:
                    modes.push((.backslash, pos))
                default:
                    token.append(c)
                }
            case .backslash:
                modes.pop()
                switch modes.top()!.0 {
                case .normal:
                    result.append(c)
                case .token:
                    token.append(c)
                case .backslash:
                    break //should never come here
                }
            }
            pos += 1
        }
        if modes.count > 1 {
            let m = modes.top()!
            switch m.0 {
            case .token:
                throw URLRealizingError.syntax("token close character } expected", m.1)
            case .backslash:
                throw URLRealizingError.syntax("unfinished character escaping", m.1)
            case .normal:
                break //should never come here
            }
        }
        
        return URL(string: result)
    }
    
    private func value(for token: String) -> String {
        return ArgumentToken(token: token).value
    }
}
