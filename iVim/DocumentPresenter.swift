//
//  DocumentPresenter.swift
//  iVim
//
//  Created by Terry on 7/5/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import Foundation

final class DocumentPresenter: NSObject {
    var url: URL
    var mirrorURL: URL
    
    init(url: URL, mirrorURL: URL) {
        self.url = url
        self.mirrorURL = mirrorURL
        super.init()
    }
}

extension DocumentPresenter {
    private func update(from src: URL?, to dst: URL?, err: Error?) {
        if let e = err { return NSLog("Failed to update file: \(e)") }
        guard let s = src, let d = dst else { return }
        do {
            try Data(contentsOf: s).write(to: d)
            self.updateUpdatedDate()
        } catch {
            NSLog("Failed to write file: \(error)")
        }
    }
    
    private func updateUpdatedDate() {
        gPIM.updateDate(for: self.url)
    }
    
    func read(_ completion: (() -> Void)? = nil) {
        self.url.coordinatedRead(for: self) { [unowned self] url, err in
            guard let oURL = url else {
                if let e = err { NSLog("Failed to read original file: \(e)") }
                return
            }
            let mURL = self.mirrorURL
            let fm = FileManager.default
            do {
                if mURL.isDirectory {
                    try fm.removeItem(at: mURL)
                    try fm.copyItem(at: oURL, to: mURL)
                    self.updateUpdatedDate()
                } else {
                    self.update(from: oURL, to: mURL, err: err)
                }
            } catch {
                NSLog("Failed to read file: \(error)")
            }
            completion?()
        }
    }
    
    private func subitem(for filename: String) -> String {
        return String(filename.dropFirst(self.mirrorURL.path.count))
    }
    
    func write(for filename: String) {
        self.url.coordinatedWrite(for: self) { [unowned self] url, err in
            NSLog("write")
            let subitem = self.subitem(for: filename)
            let src = self.mirrorURL.appendingPathComponent(subitem)
            let dst = url?.appendingPathComponent(subitem)
            self.update(from: src, to: dst, err: err)
        }
    }
    
    func removeItem(for name: String) {
        self.url.coordinatedWrite(for: self) { [unowned self] url, err in
            guard let bu = url else { return }
            let si = self.subitem(for: name)
            let t = bu.appendingPathComponent(si)
            do {
                try FileManager.default.removeItem(at: t)
                self.updateUpdatedDate()
            } catch {
                NSLog("Failed to remove item: \(error)")
            }
        }
    }
    
    func rename(from old: String, to new: String) {
        self.url.coordinatedWrite(for: self) { [unowned self] url, err in
            guard let u = url else { return }
            let ou = u.appendingPathComponent(self.subitem(for: old))
            let nu = u.appendingPathComponent(self.subitem(for: new))
            //it is possible that ou == nu, when the root item is renamed
            //but this operation is not permitted
            do {
                try FileManager.default.moveItem(at: ou, to: nu)
                self.updateUpdatedDate()
            } catch {
                NSLog("Failed to rename item: \(error)")
            }
        }
    }
    
    func addItem(for name: String) {
        self.url.coordinatedWrite(for: self) { [unowned self] url, err in
            guard let u = url else { return }
            let si = self.subitem(for: name)
            let src = self.mirrorURL.appendingPathComponent(si)
            let dst = u.appendingPathComponent(si)
            do {
                let fm = FileManager.default
                if dst.isReachable() { //will overwrite the item if it already exists
                    try fm.removeItem(at: dst)
                }
                try fm.copyItem(at: src, to: dst)
                self.updateUpdatedDate()
            } catch {
                NSLog("Failed to add item: \(error)")
            }
        }
    }
}

extension DocumentPresenter: NSFilePresenter {
    static let operationQueue: OperationQueue = OperationQueue()
    
    var presentedItemURL: URL? {
        return self.url
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return DocumentPresenter.operationQueue
    }
    
    func presentedItemDidMove(to newURL: URL) {
        NSLog("moved to \(newURL)")
        gPIM.updateURL(self.url, for: newURL)
    }
    
    func presentedItemDidChange() {
        NSLog("presented did change")
        self.read() //the content modification date of the origin never update here
        gPIM.reloadBufferForMirror(at: self.mirrorURL)
    }
    
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        defer { completionHandler(nil) }
        gPIM.removePickInfo(for: self.url, updateUI: true)
    }
}

extension URL {
    private func coordinated(for presenter: NSFilePresenter, completion: @escaping (URL?, Error?) -> Void, operation: (NSFileCoordinator, NSErrorPointer) -> Void) {
        guard self.startAccessingSecurityScopedResource() else { return completion(nil, nil) }
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        let error: NSErrorPointer = nil
        operation(coordinator, error)
        guard let err = error?.pointee else { return }
        completion(nil, err)
        self.stopAccessingSecurityScopedResource()
    }
    
    func coordinatedRead(for presenter: NSFilePresenter, completion: @escaping (URL?, Error?) -> Void) {
        self.coordinated(for: presenter, completion: completion) { coordinator, error in
            coordinator.coordinate(readingItemAt: self, options: [], error: error) { url in
                completion(url, nil)
                self.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    func coordinatedWrite(for presenter: NSFilePresenter, completion: @escaping (URL?, Error?) -> Void) {
        self.coordinated(for: presenter, completion: completion) { coordinator, error in
            coordinator.coordinate(writingItemAt: self, options: [], error: error) { url in
                completion(url, nil)
                self.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    var bookmark: Data? {
        guard self.startAccessingSecurityScopedResource() else { return nil }
        do {
            let data = try self.bookmarkData()
            self.stopAccessingSecurityScopedResource()
            return data
        } catch {
            NSLog("Failed to create bookmark for \(self): \(error)")
            return nil
        }
    }
    
    private func resourceValue(for key: URLResourceKey, secured: Bool = false) -> URLResourceValues? {
        do {
            if secured && !self.startAccessingSecurityScopedResource() {
                return nil
            }
            let result = try self.resourceValues(forKeys: [key])
            if secured {
                self.stopAccessingSecurityScopedResource()
            }
            return result
        } catch {
            NSLog("Failed to get resource value for key \(key): \(error)")
            return nil
        }
    }
    
    var isDirectory: Bool {
        return self.resourceValue(for: .isDirectoryKey)?.isDirectory ?? false
    }
    
    func isReachable(secured: Bool = false) -> Bool {
        do {
            if secured && !self.startAccessingSecurityScopedResource() {
                return false
            }
            let result = try self.checkResourceIsReachable()
            if secured {
                self.stopAccessingSecurityScopedResource()
            }
            return result
        } catch {
            NSLog("Failed to check reachability: \(error)")
            return false
        }
    }
    
    func contentModifiedDate(secured: Bool = false) -> Date? {
        return self.resourceValue(
            for: .contentModificationDateKey,
            secured: secured)?.contentModificationDate
    }
    
    var isInTrash: Bool {
        return self.deletingLastPathComponent().path.hasSuffix("/.Trash")
    }
}

extension Data {
    var resolvedURL: URL? {
        do {
            var stale = false
            return try URL(resolvingBookmarkData: self, bookmarkDataIsStale: &stale)
        } catch {
            NSLog("Failed to resolve bookmark data: \(error)")
            return nil
        }
    }
}
