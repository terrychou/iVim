//
//  URLSchemeWorker.swift
//  iVim
//
//  Created by Terry on 3/2/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

struct URLSchemeWorker {
    let url: URL
    let info: Any?
    
    init?(url: URL, info: Any? = nil) {
        guard url.scheme == gSchemeName else { return nil }
        self.url = url
        self.info = info
    }
    
    static func isValid(_ url: URL?) -> Bool {
        return url?.scheme == gSchemeName
    }
    
    func run() -> Bool {
        URLCommand(url: self.url)?.invoke(with: self.url, info: self.info)
        return true
    }
}

enum URLCommand: String {
    case shareextension
    
    init?(url: URL) {
        guard let host = url.host else { return nil }
        self.init(rawValue: host)
    }
}

extension URLCommand {
    func invoke(with url: URL, info: Any?) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        switch self {
        case .shareextension: self.doShareExtension(components)
        }
    }
    
    private func doShareExtension(_ components: URLComponents) {
        guard let name = components.firstQueryValue(for: "action") else { return }
        if let textAction = ShareTextAction(name: name) {
            textAction.run()
        } else if let fileAction = ShareFileAction(name: name) {
            fileAction.run()
        } else {
            NSLog("invalid share extension action name '\(name)'")
        }
    }
}

extension URLComponents {
    func firstQueryValue(for key: String) -> String? {
        return self.queryItems?.first { $0.name == key }?.value
    }
}
