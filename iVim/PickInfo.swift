//
//  PickInfo.swift
//  iVim
//
//  Created by Terry on 7/8/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import Foundation

extension FileManager {
    private static let mirrorMark = "com.terrychou.ivim.mirrormark"
    
    private static let cachedMirrorDirectoryURL = URL(
        fileURLWithPath: FileManager.safeTmpDir,
        isDirectory: true)
        .appendingPathComponent("Openbox")
        .appendingPathComponent(FileManager.mirrorMark)
    
    private static let ivimDirURL: URL = {
        let fm = FileManager.default
        var url = fm.urls(
            for: .libraryDirectory,
            in: .userDomainMask)[0]
            .resolvingSymlinksInPath()
            .appendingPathComponent("ivim")
        do {
            _ = try fm.createDirectoryIfNecessary(url)
            let alreadyExcluded = url.resourceValue(
                for: .isExcludedFromBackupKey)?
                .isExcludedFromBackup ?? false
            if !alreadyExcluded {
                var rvalues = URLResourceValues()
                rvalues.isExcludedFromBackup = true
                try url.setResourceValues(rvalues)
                NSLog("excluded from back up")
            }
        } catch {
            fatalError("failed to prepare ivimdir: \(error)")
        }
        
        return url
    }()
    
    @objc static let safeTmpDir: String = {
        let otmp = NSTemporaryDirectory()
        let ntmp = otmp.nsstring.resolvingSymlinksInPath
        let new = FileManager.ivimDirURL.path
        
        return otmp.replacingOccurrences(of: ntmp, with: new)
    }()
    
    @objc var mirrorDirectoryURL: URL {
        return FileManager.cachedMirrorDirectoryURL
    }
    
    @objc func cleanMirrorFiles() {
        let unmarked = self.mirrorDirectoryURL.deletingLastPathComponent()
        guard self.fileExists(atPath: unmarked.path) else { return }
        do {
            try self.removeItem(at: unmarked)
        } catch {
            NSLog("Failed to clean mirror files: \(error)")
        }
    }
    
    func mirrorURL(for subpath: String) -> URL {
        return self.mirrorDirectoryURL.appendingPathComponent(subpath)
    }
    
    func mirrorSubpath(for path: String) -> String? {
        guard let range = path.range(of: FileManager.mirrorMark),
            range.upperBound != path.endIndex else { return nil }
        let start = path.index(after: range.upperBound)
        
        return String(path[start...])
    }
    
    func mirrorBookmarkURL(for ticket: String) -> URL {
        return self.mirrorDirectoryURL
            .appendingPathComponent(ticket)
            .appendingPathComponent(".bookmark")
    }
    
    func mirrorBookmark(for ticket: String) -> Data? {
        let url = self.mirrorBookmarkURL(for: ticket)
        do {
            return try Data.init(contentsOf: url)
        } catch (let err) {
            NSLog("failed to read bookmark " +
                "for mirror \(ticket):" +
                "\(err.localizedDescription)")
            return nil
        }
    }
}

typealias MirrorReadyTask = (URL) -> Void

final class PickInfo: NSObject {
    var origin: URL
    var bookmark: Data?
    let ticket: String
    let subRootPath: String
    var updatedDate: Date!
    lazy var mirrorURL: URL = FileManager.default.mirrorURL(for: self.subRootPath)
    
    init(origin: URL, task: MirrorReadyTask?) {
        self.origin = origin
        self.bookmark = origin.bookmark
        self.ticket = UUID().uuidString
        self.subRootPath = self.ticket + "/" + self.origin.lastPathComponent
        super.init()
        self.createMirror()
        self.addTask(task)
        self.updateUpdatedDate()
    }
    
    init?(ticket: String) {
        guard let bookmark = FileManager.default.mirrorBookmark(for: ticket),
            let origin = bookmark.resolvedURL else {
                return nil
        }
        self.origin = origin
        self.bookmark = bookmark
        self.ticket = ticket
        self.subRootPath = self.ticket + "/" +
            self.origin.lastPathComponent
        super.init()
        self.updateUpdatedDate()
    }
    
    deinit {
        self.deleteMirror()
    }
}

extension PickInfo {
    private func storeMirrorBookmark() {
        guard let bm = self.bookmark else { return }
        do {
            try bm.write(
                to: FileManager.default.mirrorBookmarkURL(for: self.ticket),
                options: .atomic)
        } catch (let err) {
            NSLog("failed to store bookmark " +
                "for mirror \(self.ticket):" +
                "\(err.localizedDescription)")
        }
    }
    
    private func createMirror() {
        self.origin.coordinatedRead(for: self) { [unowned self] url, err in
            guard let oURL = url else {
                var log = "failed to read original file"
                if let e = err {
                    log += ": \(e)"
                }
                NSLog(log)
                return
            }
            let mURL = self.mirrorURL
            let fm = FileManager.default
            do {
                try fm.createDirectory(
                    at: mURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try fm.copyItem(at: oURL, to: mURL)
            } catch {
                NSLog("Failed to create mirror: \(error)")
            }
        }
        self.storeMirrorBookmark()
    }
    
    func updateMirror() -> Bool {
//        NSLog("origin date: \(self.origin.contentModifiedDate(secured: true)!)")
//        NSLog("updated date: \(self.updatedDate)")
        guard let oCntDate = self.origin.contentModifiedDate(secured: true),
            oCntDate > self.updatedDate else { return false } //original content has been modified
        self.read()
        
        return true
    }
    
    func updateOrigin(to newURL: URL) {
        self.origin = newURL
        self.bookmark = newURL.bookmark
    }
    
    func deleteMirror() {
        do {
            try FileManager.default.removeItem(
                at: self.mirrorURL.deletingLastPathComponent())
        } catch {
            NSLog("Failed to delete mirror file: \(error)")
        }
    }
    
    func addTask(_ task: MirrorReadyTask?) {
        guard let t = task else { return }
        DispatchQueue.main.async {
            t(self.mirrorURL)
        }
    }
}

extension PickInfo {
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
        self.updatedDate = Date()
    }
    
    func read(_ completion: (() -> Void)? = nil) {
        self.origin.coordinatedRead(for: self) { [unowned self] url, err in
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
    
    private func subitem(for subpath: String) -> String {
        return String(subpath.dropFirst(self.subRootPath.count))
    }
    
    func write(for subpath: String) {
        self.origin.coordinatedWrite(for: self) { [unowned self] url, err in
            NSLog("write")
            let si = self.subitem(for: subpath)
            let src = self.mirrorURL.appendingPathComponent(si)
            let dst = url?.appendingPathComponent(si)
            self.update(from: src, to: dst, err: err)
        }
    }
    
    private func removeSubitem(in url: URL, for name: String) {
        let t = url.appendingPathComponent(name)
        do {
            try FileManager.default.removeItem(at: t)
            self.updateUpdatedDate()
        } catch {
            NSLog("Failed to remove item: \(error)")
        }
    }
    
    func removeItem(for subpath: String) {
        self.origin.coordinatedWrite(for: self) { [unowned self] url, err in
            guard let bu = url else { return }
            let si = self.subitem(for: subpath)
            self.removeSubitem(in: bu, for: si)
        }
    }
    
    private func renameSubitem(in url: URL, from old: String, to new: String) {
        let ou = url.appendingPathComponent(old)
        let nu = url.appendingPathComponent(new)
        do {
            try FileManager.default.moveItem(at: ou, to: nu)
            self.updateUpdatedDate()
        } catch {
            NSLog("Failed to rename item: \(error)")
        }
    }
    
    func rename(from old: String, to new: String) {
        self.origin.coordinatedWrite(for: self) { [unowned self] url, err in
            guard let u = url else { return }
            let osi = self.subitem(for: old)
            let nsi = self.subitem(for: new)
            self.renameSubitem(in: u, from: osi, to: nsi)
        }
    }
    
    private func addSubitem(in url: URL, for name: String) {
        let src = self.mirrorURL.appendingPathComponent(name)
        let dst = url.appendingPathComponent(name)
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
    
    func addItem(for subpath: String) {
        self.origin.coordinatedWrite(for: self) { [unowned self] url, err in
            guard let u = url else { return }
            let si = self.subitem(for: subpath)
            self.addSubitem(in: u, for: si)
        }
    }
}

extension PickInfo: NSFilePresenter {
    static let operationQueue: OperationQueue = OperationQueue()
    
    var presentedItemURL: URL? {
        return self.origin
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return PickInfo.operationQueue
    }
    
    func presentedItemDidMove(to newURL: URL) {
        NSLog("moved to \(newURL)")
        gPIM.updateURL(self.origin, for: newURL)
    }
    
    func presentedItemDidChange() {
        NSLog("presented did change")
        self.read() //the content modification date of the origin never update here
        gPIM.reloadBufferForMirror(at: self.mirrorURL)
    }
    
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        defer { completionHandler(nil) }
        gPIM.removePickInfo(for: self.origin, updateUI: true)
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
    
    func resourceValue(for key: URLResourceKey, secured: Bool = false) -> URLResourceValues? {
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

