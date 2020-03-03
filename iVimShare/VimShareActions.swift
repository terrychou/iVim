//
//  VimShareActions.swift
//  iVimShare
//
//  Created by Terry Chou on 12/26/19.
//  Copyright © 2019 Boogaloo. All rights reserved.
//

import Foundation


let gShareCommand = "shareextension"

protocol ShareAction {
    var userDefaultsKey: String? { get }
    var name: String { get }
    init?(name: String)
    
    static var allActions: [ShareAction] { get }
    func setData(_ data: Any)
    func getData<T>() -> T?
}

extension ShareAction where Self: RawRepresentable, Self.RawValue == String {
    var name: String {
        return self.rawValue
    }
    
    init?(name: String) {
        self.init(rawValue: name)
    }
    
    var userDefaultsKey: String? {
        return "SE\(self.name)"
    }
}

extension ShareAction where Self: CaseIterable {
    static var allActions: [ShareAction] {
        return self.allCases.map { $0 }
    }
}

extension ShareAction {
    func setData(_ data: Any) {
        if let key = self.userDefaultsKey {
            let ud = UserDefaults.appGroup
            ud.set(data, forKey: key)
            ud.synchronize()
        }
    }
    
    func getData<T>() -> T? {
        var result: T?
        if let key = self.userDefaultsKey,
            let obj = UserDefaults.appGroup.object(forKey: key) {
            result = obj as? T
        }
        
        return result
    }
}

enum ShareFileAction: String, CaseIterable, ShareAction {
    case content = "sharefilescontent" // share content of file with iVim
}

enum ShareTextAction: String, CaseIterable, ShareAction {
    case text = "sharetext" // share selected text
}
