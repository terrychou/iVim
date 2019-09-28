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
        return ivim_full_path(FileManager.ivimDirURL.path)
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
    lazy var mirrorURL: URL = FileManager.default.mirrorURL(for: self.subRootPath)
    lazy var lastUpdatedURL: URL = self.mirrorURL
        .deletingLastPathComponent()
        .appendingPathComponent(".lastupdated")
    
    private init(origin: URL, bookmark: Data?, ticket: String) {
        self.origin = origin
        self.bookmark = bookmark
        self.ticket = ticket
        self.subRootPath = ticket + "/" + origin.lastPathComponent
        super.init()
    }
    
    convenience init(origin: URL, task: MirrorReadyTask?) {
        self.init(origin: origin,
                  bookmark: origin.bookmark,
                  ticket: UUID().uuidString)
        self.createMirror()
        self.addTask(task)
    }
    
    convenience init?(ticket: String) {
        if let bm = FileManager.default.mirrorBookmark(for: ticket),
            let ori = bm.resolvedURL {
            self.init(origin: ori, bookmark: bm, ticket: ticket)
        } else {
            return nil
        }
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
    
    private var lastUpdatedDate: Date? {
        guard let ts = try? String(contentsOf: self.lastUpdatedURL,
                                   encoding: .utf8),
            let ti = TimeInterval(ts) else { return nil }
        return Date(timeIntervalSince1970: ti)
    }
    
    private func guessLastUpdatedDate() -> Date {
        // this is called when no .lastupdated file exists
        // use the content modification date of the mirror URL
        // use current date even if the above is not available
        let date = self.mirrorURL.contentModifiedDate() ?? Date()
        self.updatedDate = date
        
        return date
    }
    
    private var updatedDate: Date {
        get {
            return self.lastUpdatedDate ?? self.guessLastUpdatedDate()
        }
        set {
            do {
                try "\(newValue.timeIntervalSince1970)".write(
                    to: self.lastUpdatedURL,
                    atomically: true,
                    encoding: .utf8)
            } catch {
                NSLog("failed to write last updated time: \(error)")
            }
        }
    }
    
    private func createMirror() {
        self.origin.coordinatedRead(for: self, onError: {
            NSLog("failed to create mirror: \($0)")
        }) { [unowned self] oURL in
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
    
    func updateMirror(completion: @escaping () -> Void) {
        self.origin.coordinatedRead(for: self, onError: {
            NSLog("failed to refer to origin url: \($0)")
        }) { [unowned self] oURL in
            guard let ocmDate = oURL.contentModifiedDate() else { return }
            let ud = self.updatedDate
            if ocmDate > ud {
                self.read(completion: completion)
            } else if self.mirrorURL.isDirectory {
                guard let list = FileManager.default.enumerator(at: oURL,
                    includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
                var shouldUpdate = false
                for case let file as URL in list {
                    if let cmDate = file.contentModifiedDate(),
                        cmDate > ud {
//                        NSLog("newer file: \(file.path), date: \(cmDate.timeIntervalSince1970)")
                        shouldUpdate = true
                        break
                    }
                }
                if shouldUpdate {
                    self.read(completion: completion)
                }
            }
        }
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
    private func update(from src: URL, to dst: URL) {
        do {
            try Data(contentsOf: src).write(to: dst)
            self.updateUpdatedDate()
        } catch {
            NSLog("Failed to write file: \(error)")
        }
    }
    
    private func updateUpdatedDate() {
        self.updatedDate = Date()
    }
    
    private func read(subpath: String? = nil,
                      completion: (() -> Void)? = nil) {
        self.origin.coordinatedRead(for: self, onError: {
            NSLog("failed to read: \($0)")
        }) { [unowned self] url in
            var oURL = url
            var mURL = self.mirrorURL
            if let sp = subpath {
                oURL = oURL.appendingPathComponent(sp)
                mURL = mURL.appendingPathComponent(sp)
            }
            let fm = FileManager.default
            do {
                if mURL.isDirectory {
                    let oldCwd = fm.currentDirectoryPath
                    // the dir to be removed could be the currnt directory
                    // in that case, it needs to be restored manually
                    // afterwards, otherwise vim would work incorrectly
                    if mURL.isReachable() {
                        try fm.removeItem(at: mURL)
                    }
                    try fm.copyItem(at: oURL, to: mURL)
                    fm.changeCurrentDirectoryPath(oldCwd)
                    self.updateUpdatedDate()
                } else {
                    self.update(from: oURL, to: mURL)
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
        self.origin.coordinatedWrite(for: self, onError: {
            NSLog("failed to write for subpath \(subpath): \($0)")
        }) { [unowned self] url in
            NSLog("write")
            let si = self.subitem(for: subpath)
            let src = self.mirrorURL.appendingPathComponent(si)
            var dst = url.appendingPathComponent(si)
            self.update(from: src, to: dst)
            // sync mtime
            do {
                try dst.setResourceValues(
                    src.resourceValues(forKeys: [.contentModificationDateKey]))
//                NSLog("src cmd: \(String(describing: src.contentModifiedDate()?.timeIntervalSince1970))")
            } catch {
                NSLog("failed to sync mtime: \(error)")
            }
//            NSLog("after write: \(self.updatedDate.timeIntervalSince1970)")
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
        self.origin.coordinatedWrite(for: self, onError: {
            NSLog("failed to remove item for subpath \(subpath): \($0)")
        }) { [unowned self] url in
            let si = self.subitem(for: subpath)
            self.removeSubitem(in: url, for: si)
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
        self.origin.coordinatedWrite(for: self, onError: {
            NSLog("failed to rename item from \(old) to \(new): \($0)")
        }) { [unowned self] url in
            let osi = self.subitem(for: old)
            let nsi = self.subitem(for: new)
            self.renameSubitem(in: url, from: osi, to: nsi)
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
        self.origin.coordinatedWrite(for: self, onError: {
            NSLog("failed to add item at subpath \(subpath): \($0)")
        }) { [unowned self] url in
            let si = self.subitem(for: subpath)
            self.addSubitem(in: url, for: si)
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
    
    private func tryUpdate(subpath: String? = nil,
                           completion: () -> Void) {
        self.origin.coordinatedRead(for: self, onError: {
            NSLog("failed to read while trying to update: \($0)")
        }) { [unowned self] url in
            var mURL = self.mirrorURL
            var oURL = url
            if let sp = subpath {
                mURL.appendPathComponent(sp)
                oURL.appendPathComponent(sp)
            }
            if let od = oURL.contentModifiedDate(),
                let md = mURL.contentModifiedDate() {
//                NSLog("od: \(od.timeIntervalSince1970), md: \(md.timeIntervalSince1970)")
                if od > md {
                    completion()
                }
            }
        }
        
    }
    
    func presentedItemDidChange() {
        NSLog("presented did change")
        // the content modification date not updated yet
        // when entering this, may be due to the fact that
        // this is called before the writing is done?
        self.read {
            gPIM.reloadBufferForMirror(at: self.mirrorURL)
        }
    }
    
    private func subpathFrom(externalURL url: URL) -> String? {
        let op = self.origin.path
        var si = op.startIndex
        var range: Range<String.Index>?
        while let r = op.range(of: "/", range: si..<op.endIndex) {
            if let fr = url.path.range(of: op[r.lowerBound...]) {
                range = fr
                break
            }
            si = r.upperBound
        }
        var result: String?
        if let r = range {
            result = url.path[r.upperBound...]
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            NSLog("failed to get mirror path for \(url.path)")
        }
        
        return result
    }
    
    func presentedSubitemDidChange(at url: URL) {
        NSLog("presented subitem did change \(url.path)")
        if let sp = self.subpathFrom(externalURL: url) {
            self.tryUpdate(subpath: sp) {
                self.read(subpath: sp) {
                    let mURL = self.mirrorURL.appendingPathComponent(sp)
                    gPIM.reloadBufferForMirror(at: mURL)
                    NSLog("reloaded \(mURL.path)")
                }
            }
        }
    }
    
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        defer { completionHandler(nil) }
        gPIM.removePickInfo(for: self.origin, updateUI: true)
    }
}

extension URL {
    typealias CoordOperation = (NSFileCoordinator, NSErrorPointer) -> Void
    typealias CoordError = (Error) -> Void
    typealias CoordAccessor = (URL) -> Void
    private func coordinated(presenter: NSFilePresenter,
                             onError: CoordError?,
                             operation: CoordOperation) {
        guard self.startAccessingSecurityScopedResource() else { return }
        defer { self.stopAccessingSecurityScopedResource() }
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        let error: NSErrorPointer = nil
        operation(coordinator, error)
        if let err = error?.pointee {
            onError?(err)
        }
    }
    
    func coordinatedRead(for presenter: NSFilePresenter,
                         options: NSFileCoordinator.ReadingOptions = [],
                         onError: CoordError? = nil,
                         accessor: CoordAccessor) {
        self.coordinated(presenter: presenter, onError: onError) {
            coord, error in
            coord.coordinate(readingItemAt: self,
                             options: options,
                             error: error,
                             byAccessor: accessor)
        }
    }
    
    func coordinatedWrite(for presenter: NSFilePresenter,
                          options: NSFileCoordinator.WritingOptions = [],
                          onError: CoordError? = nil,
                          accessor: CoordAccessor) {
        self.coordinated(presenter: presenter, onError: onError) {
            coord, error in
            coord.coordinate(writingItemAt: self,
                             options: options,
                             error: error,
                             byAccessor: accessor)
        }
    }
    
    var bookmark: Data? {
        guard self.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { self.stopAccessingSecurityScopedResource() }
        do {
            return try self.bookmarkData()
        } catch {
            NSLog("Failed to create bookmark for \(self): \(error)")
            return nil
        }
    }
    
    private func mapThrower<T>(_ thrower: () throws -> T,
                               secured: Bool,
                               name: String) -> T? {
        if secured && !self.startAccessingSecurityScopedResource() {
            return nil
        }
        defer {
            if secured {
                self.stopAccessingSecurityScopedResource()
            }
        }
        var result: T?
        do {
            result = try thrower()
        } catch {
            NSLog("failed to \(name): \(error)")
        }
        
        return result
    }
    
    func resourceValue(for key: URLResourceKey,
                       secured: Bool = false) -> URLResourceValues? {
        return self.mapThrower({ try self.resourceValues(forKeys: [key]) },
                               secured: secured,
                               name: "get resource value for key '\(key)'")
    }
    
    var isDirectory: Bool {
        return self.resourceValue(for: .isDirectoryKey)?.isDirectory ?? false
    }
    
    func isReachable(secured: Bool = false) -> Bool {
        return self.mapThrower({ try self.checkResourceIsReachable() },
                               secured: secured,
                               name: "check reachability") ?? false
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

