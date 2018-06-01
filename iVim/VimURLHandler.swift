//
//  VimURLHandler.swift
//  iVim
//
//  Created by Terry on 9/21/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import Foundation

enum VimURLType {
    case scheme
    case font
    case text
    
    init?(url: URL) {
        if URLSchemeWorker.isValid(url) {
            self = .scheme
        } else if url.isSupportedFont {
            self = .font
        } else {
            self = .text
        }
    }
}

enum VimURLMode {
    case local
    case copy
    case open
    
    init?(url: URL) {
        if url.isDecendentOf(URL.inboxDirectory) {
            self = .copy
        } else if url.isDecendentOf(URL.documentsDirectory) {
            self = .local
        } else {
            self = .open
        }
    }
}

extension URL {
    func isDecendentOf(_ url: URL?) -> Bool {
        guard let u = url else { return false }
        let path = self.resolvingSymlinksInPath().path
        
        return path.hasPrefix(u.resolvingSymlinksInPath().path)
    }
}

struct VimURLHandler {
    let url: URL
    let type: VimURLType
    let nonLocalMode: VimURLMode?
}

extension VimURLHandler {
    init?(url: URL?, nonLocalMode: VimURLMode? = nil) {
        guard let u = url, let t = VimURLType(url: u) else { return nil }
        self.init(url: u, type: t, nonLocalMode: nonLocalMode)
    }
    
    func open() -> Bool {
        switch self.type {
        case .scheme: return self.runURLScheme()
        case .font: return self.importFont()
        case .text: return self.importText()
        }
    }
    
    private var mode: VimURLMode? {
        let m = VimURLMode(url: self.url)
        return m == .local ? .local : (self.nonLocalMode ?? m)
    }
    
    private func runURLScheme() -> Bool {
        guard let worker = URLSchemeWorker(url: self.url) else { return false }
        if gSVO.started {
            return worker.run()
        } else {
            gSVO.run { _ = worker.run() }
            return true
        }
    }
    
    private func importFont() -> Bool {
        guard let mode = self.mode else { return false }
        let isMoving: Bool
        let removeOrigin: Bool
        switch mode {
        case .local, .open:
            isMoving = false
            removeOrigin = false
        case .copy:
            isMoving = true
            removeOrigin = true
        }
        
        return gFM.importFont(from: self.url, isMoving: isMoving, removeOriginIfFailed: removeOrigin)
    }
    
    private func importText() -> Bool {
        guard let mode = self.mode else { return false }
        switch mode {
        case .local: gSVO.openFile(at: self.url)
        case .copy:
            guard let path = FileManager.default.safeMovingItem(
                from: self.url,
                into: URL.documentsDirectory) else { return false }
            gSVO.openFile(at: path)
        case .open:
            gODM.addURL(self.url) //only save files in *open* mode
            gPIM.addPickInfo(for: self.url, task: {
                gSVO.openFile(at: $0)
            })
        }
        
        return true
    }
}
