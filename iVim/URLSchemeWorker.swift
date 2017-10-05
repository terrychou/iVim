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
    case newtab
    
    init?(url: URL) {
        guard let host = url.host else { return nil }
        self.init(rawValue: host)
    }
}

extension URLCommand {
    func invoke(with url: URL, info: Any?) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        switch self {
        case .newtab: self.doNewtab(components)
        }
    }
    
    private func text(of file: String) -> String? {
        guard let c = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: gAppGroup) else { return nil }
        let url = c.appendingPathComponent(file)
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            try FileManager.default.removeItem(at: url)
            return text
        } catch {
            NSLog("Failed to read temp file: \(error)")
            return nil
        }
    }
    
    private func doNewtab(_ components: URLComponents) {
        guard let fn = components.firstQueryValue(for: "file"),
            let t = self.text(of: fn) else { return }
        if !is_current_buf_new() {
            do_cmdline_cmd("tabnew")
        }
        do_cmdline_cmd("normal! i\(t)")
        gEnsureSuccessfulOpen()
    }
}

extension URLComponents {
    func firstQueryValue(for key: String) -> String? {
        return self.queryItems?.first { $0.name == key }?.value
    }
}
