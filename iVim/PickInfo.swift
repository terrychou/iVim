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
    let mirrorURL: URL
    private lazy var mirrorWatcher: FilesystemItemWatcher = FilesystemItemWatcher(url: self.mirrorURL, delegate: self)
    private lazy var mirrorTrasher: MirrorTrasher = MirrorTrasher(mirror: self.mirrorURL, presenter: self)
    private var _updatedDate: Date?
    lazy var lastUpdatedURL: URL = self.mirrorURL
        .deletingLastPathComponent()
        .appendingPathComponent(".lastupdated")
    
    private init(origin: URL, bookmark: Data?, ticket: String) {
        self.origin = origin
        self.bookmark = bookmark
        self.ticket = ticket
        self.mirrorURL = FileManager.default.mirrorURL(
            for: ticket + "/" + origin.lastPathComponent)
        super.init()
    }
    
    convenience init(origin: URL, task: MirrorReadyTask?) {
        self.init(origin: origin,
                  bookmark: origin.bookmark,
                  ticket: UUID().uuidString)
        self.createMirror()
        self.initUpdatedDate()
        self.startWatchingMirror()
        self.addTask(task)
    }
    
    convenience init?(ticket: String) {
        if let bm = FileManager.default.mirrorBookmark(for: ticket),
            let ori = bm.resolvedURL {
            self.init(origin: ori, bookmark: bm, ticket: ticket)
            self.initUpdatedDate()
            self.startWatchingMirror()
        } else {
            return nil
        }
    }
    
    deinit {
        self.stopWatchingMirror()
    }
}

private let pathSeparator = CharacterSet(charactersIn: "/")

private extension StringProtocol {
    var trimmingPathSeparator: String {
        return self.trimmingCharacters(in: pathSeparator)
    }
}

extension PickInfo: FilesystemItemWatcherDelegate {
    func startWatchingMirror() {
        self.mirrorWatcher.start()
    }
    
    func stopWatchingMirror() {
        self.mirrorWatcher.stop()
    }
    
    private func subpathFromMirrorURL(_ url: URL) -> String? {
        let mPath = self.mirrorURL.path
        let path = url.path
        var result: String?
        if let mr = mPath.range(of: self.ticket),
            let ur = path.range(of: mPath[mr.lowerBound...]) {
            result = path[ur.upperBound...].trimmingPathSeparator
        }
        
        return result
    }
    
    private func itemIsNewerThanLastUpdate(at url: URL) -> Bool {
        return url.contentModifiedDate().map {
            $0 > self.updatedDate
        } ?? false
    }
    
    func itemDidChange() {
        if self.itemIsNewerThanLastUpdate(at: self.mirrorURL) {
            // this change may be caused by a former update
            self.write()
        }
    }
    
    func itemDidRename(to newURL: URL) {
        // it does NOT make sense to rename the root
        // of a mirror, in this case, rename it back
        NSLog("attempt to rename mirror root to \(newURL)")
        do {
            self.mirrorWatcher.stop()
            try FileManager.default.moveItem(at: newURL,
                                             to: self.mirrorURL)
            self.mirrorWatcher.start()
        } catch {
            NSLog("failed to restore mirror root name: \(error)")
        }
    }
    
    func subitemDidChange(at url: URL) {
        guard self.itemIsNewerThanLastUpdate(at: url),
            let sp = self.subpathFromMirrorURL(url) else { return }
        var shouldUpdate = true
        if !url.isDirectory {
            let mURL = self.mirrorURL.appendingPathComponent(sp)
            if !file_is_in_buffer_list(mURL.path) {
                // ignore files not in buffer list, e.g. swap files
                shouldUpdate = false
            }
        }
        if shouldUpdate {
            self.write(for: sp)
        }
    }
    
    func subitemWasDeleted(at url: URL) {
        guard let sp = self.subpathFromMirrorURL(url) else { return }
        self.remove(for: sp)
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
    
    private func initUpdatedDate() {
        _ = self.updatedDate
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
            return self._updatedDate ??
                self.lastUpdatedDate ??
                self.guessLastUpdatedDate()
        }
        set {
            do {
                try "\(newValue.timeIntervalSince1970)".write(
                    to: self.lastUpdatedURL,
                    atomically: true,
                    encoding: .utf8)
                self._updatedDate = newValue
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
    private func update(from src: URL, to dst: URL) throws {
        try Data(contentsOf: src).write(to: dst)
        self.updateUpdatedDate()
    }
    
    private func updateUpdatedDate() {
        self.updatedDate = Date()
    }
    
    private func read(subpath: String? = nil,
                      completion: (() -> Void)? = nil) {
        self.origin.coordinatedRead(for: self, onError: {
            NSLog("failed to read: \($0)")
        }) { [unowned self] url in
            NSLog("read")
            var oURL = url
            var mURL = self.mirrorURL
            if let sp = subpath {
                oURL.appendPathComponent(sp)
                mURL.appendPathComponent(sp)
            }
            let fm = FileManager.default
            do {
                let mirrorExists = fm.fileExists(atPath: mURL.path)
                let isDir = (mirrorExists ? mURL : oURL).isDirectory
                if isDir {
                    let oldCwd = fm.currentDirectoryPath
                    // the dir to be removed could be the currnt directory
                    // in that case, it needs to be restored manually
                    // afterwards, otherwise vim would work incorrectly
                    if mirrorExists {
                        try fm.removeItem(at: mURL)
                    }
                    try fm.copyItem(at: oURL, to: mURL)
                    fm.changeCurrentDirectoryPath(oldCwd)
                    self.updateUpdatedDate()
                } else {
                    try self.update(from: oURL, to: mURL)
                }
            } catch {
                NSLog("failed to read file: \(error)")
            }
            completion?()
        }
    }
    
    private func write(for subpath: String? = nil) {
        self.origin.coordinatedWrite(for: self, onError: {
            NSLog("failed to write: \($0)")
        }) { [unowned self] url in
            NSLog("write")
            var src = self.mirrorURL
            var dst = url
            if let sp = subpath {
                src.appendPathComponent(sp)
                dst.appendPathComponent(sp)
            }
            do {
                if src.isDirectory {
                    let fm = FileManager.default
                    if subpath == nil {
                        // need to remove the existing dir
                        // only when it is for the root dir
                        // which actually may never happen
                        //
                        // the write operation would trigger
                        // sometimes when the dst is an existing
                        // subdirectory. In this case, not update
                        // and the following copying would fail
                        // as a good error
                        try fm.removeItem(at: dst)
                        NSLog("removed root mirror dir: \(dst)")
                    }
                    try fm.copyItem(at: src, to: dst)
                    self.updateUpdatedDate()
                } else {
                    try self.update(from: src, to: dst)
                }
            } catch {
                NSLog("error during writing: \(error)")
            }
        }
    }
    
    private func remove(for subpath: String? = nil) {
        // backup to trash before deleting on the external app
        let dfm = FileManager.default
        self.origin.coordinatedRead(for: self, onError: {
            NSLog("failed to read to trash: \($0)")
        }) { url in
            var src = url
            if let sp = subpath {
                src.appendPathComponent(sp)
            }
            if !src.fileExists() {
                return
            }
            do {
                try self.trash(itemAt: src, subpath: subpath)
                // now try the deleting
                self.origin.coordinatedWrite(for: self, onError: {
                    NSLog("failed to remove: \($0)")
                }) { url in
                    var target = url
                    if let sp = subpath {
                        target.appendPathComponent(sp)
                    }
                    do {
                        try dfm.removeItem(at: target)
                        self.updateUpdatedDate()
                    } catch let err as NSError {
                        NSLog("failed to remove: \(err.localizedDescription)")
                    }
                }
            } catch {
                NSLog("failed to backup before removing: \(error)")
            }
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
    
    private func tryUpdate(subpath: String? = nil) {
        self.origin.coordinatedRead(for: self, onError: {
            NSLog("failed to read while trying to update: \($0)")
        }) { [unowned self] url in
            var mURL = self.mirrorURL
            var oURL = url
            if let sp = subpath {
                mURL.appendPathComponent(sp)
                oURL.appendPathComponent(sp)
            }
            let fm = FileManager.default
            var shouldRead = true
            let mirrorExists = mURL.fileExists()
            var reloadURL = mURL.deletingLastPathComponent()
            if !oURL.fileExists() { // deleted
                do {
                    if mirrorExists {
                        if mURL.isDirectory &&
                            fm.currentDirectoryPath.hasPrefix(
                                mURL.appendingPathComponent("").path) {
                            // if it is the parent of cwd, change
                            // cwd to its parent first
                            fm.changeCurrentDirectoryPath(
                                mURL.deletingLastPathComponent().path)
                        }
                        try fm.removeItem(at: mURL) // cwd???
                        self.updateUpdatedDate()
                        gPIM.reloadBufferForMirror(at: reloadURL)
                    }
                } catch {
                    NSLog("failed to remove: \(error.localizedDescription)")
                }
                shouldRead = false
            } else if mirrorExists { // update
                if let od = oURL.contentModifiedDate(),
                    let md = mURL.contentModifiedDate() {
                    if od <= md {
                        shouldRead = false
                    }
                }
                reloadURL = mURL
            } // else new
            if shouldRead {
                self.read(subpath: subpath) {
                    gPIM.reloadBufferForMirror(at: reloadURL)
                }
            }
        }
    }
    
    func presentedItemDidChange() {
        NSLog("presented did change")
        self.tryUpdate()
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
            result = url.path[r.upperBound...].trimmingPathSeparator
        } else {
            NSLog("failed to get mirror path for \(url.path)")
        }
        
        return result
    }
    
    private func tryUpdateChange(at url: URL) {
        guard let sp = self.subpathFrom(externalURL: url) else { return }
        self.tryUpdate(subpath: sp)
    }
    
    func presentedSubitemDidChange(at url: URL) {
        NSLog("presented subitem did change \(url.path)")
        self.tryUpdateChange(at: url)
    }
    
    func presentedSubitemDidAppear(at url: URL) {
        NSLog("presented subitem did appear \(url.path)")
        self.tryUpdateChange(at: url)
    }
    
    func accommodatePresentedSubitemDeletion(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        NSLog("\(#function)")
        defer { completionHandler(nil) }
        self.tryUpdateChange(at: url)
    }
    
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        NSLog("\(#function)")
        defer { completionHandler(nil) }
        gPIM.removePickInfo(for: self.origin, updateUI: true)
    }
}

extension PickInfo {
    private static let trashSerialQ = DispatchQueue(label: "com.terrychou.ivim.mirrortrash.serial")
    
    private func trashIndexes(from args: [String]) -> [Int]? {
        let (indexes, invalid) = self.mirrorTrasher.indexes(from: args)
        guard invalid.isEmpty else {
            gSVO.showError("invalid trash indexes: \(invalid.joined(separator: ", ").escaping("\""))")
            return nil
        }
        
        return indexes
    }
    
    private func trash(itemAt src: URL, subpath: String?) throws {
        var err: Error?
        PickInfo.trashSerialQ.sync {
            do {
                try self.mirrorTrasher.trash(itemAt: src,
                                             subpath: subpath)
            } catch {
                err = error
            }
        }
        try err.map { throw $0 }
    }
    
    func listTrashContents(with args: [String]) {
        PickInfo.trashSerialQ.sync {
            guard let indexes = self.trashIndexes(from: args) else { return }
            let cts = self.mirrorTrasher.contents(for: indexes)
            gSVO.showContent(cts, withCommand: nil)
        }
    }
    
    func restoreTrash(with args: [String]) {
        PickInfo.trashSerialQ.sync {
            guard let indexes = self.trashIndexes(from: args) else { return }
            self.origin.coordinatedWrite(for: self, onError: {
                NSLog("failed to write to restore trash: \($0)")
            }) { url in
                self.mirrorTrasher.restore(itemsAt: indexes, for: url)
            }
        }
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
    
    private func mapThrower<T>(_ thrower: () throws -> T?,
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
        return self.mapThrower(
            { try self.resourceValues(forKeys: [key]) },
            secured: secured,
            name: "get resource value for key '\(key)'")
    }
    
    var isDirectory: Bool {
        return self.resourceValue(for: .isDirectoryKey)?.isDirectory ?? false
    }
    
    func fileExists(secured: Bool = false) -> Bool {
        return self.mapThrower(
            { FileManager.default.fileExists(atPath: self.path) },
            secured: secured,
            name: "test file existance") ?? false
    }
    
//    func isReachable(secured: Bool = false) -> Bool {
//        return self.mapThrower(self.checkResourceIsReachable,
//                               secured: secured,
//                               name: "check reachability") ?? false
//    }
    
    func contentModifiedDate(secured: Bool = false) -> Date? {
        return self.mapThrower(
            { try FileManager.default.attributesOfItem(atPath: self.path)[.modificationDate] as? Date },
            secured: secured,
            name: "get content modification date")
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

final class MirrorTrasher {
    private let mirrorURL: URL
    private weak var presenter: PickInfo?
    private var items = [MirrorTrashItem]()
    private lazy var url: URL = self.mirrorURL
        .deletingLastPathComponent()
        .appendingPathComponent(".trash")
    private lazy var inventoryURL: URL = self.url
        .appendingPathComponent(".inventory")
    
    init(mirror: URL, presenter: PickInfo?) {
        self.mirrorURL = mirror
        self.presenter = presenter
        self.items = self.initItems()
    }
}

private extension UnsafeMutablePointer where Pointee == CChar {
    var trimmedNewline: String {
        return String(cString: self).trimmingCharacters(in: .newlines)
    }
}

extension MirrorTrasher {
    private func openInventoryFile(
        in mode: String) -> UnsafeMutablePointer<FILE>? {
        let intpath = self.inventoryURL.path
        let result = fopen(intpath, mode)
        if result == nil {
            NSLog("failed to open inventory file in mode '\(mode)': \(intpath)")
        }
        
        return result
    }
    
    private func initItems() -> [MirrorTrashItem] {
        guard let fd = self.openInventoryFile(in: "r") else { return [] }
        var line: UnsafeMutablePointer<CChar>?
        var len: Int = 0
        var items = [MirrorTrashItem]()
        while getline(&line, &len, fd) > 0 {
            let subpath = line!.trimmedNewline
            free(line!)
            line = nil
            if getline(&line, &len, fd) > 0,
                let ti = TimeInterval(line!.trimmedNewline) {
                let date = Date(timeIntervalSince1970: ti)
                items.append(MirrorTrashItem(subpath: subpath,
                                             trashedAt: date))
                free(line!)
                line = nil
            } else {
                NSLog("broken trash inventory file: \(self.url.path)")
                break
            }
        }
        fclose(fd)
        
        return items
    }
    
    private func write(item: MirrorTrashItem,
                       to fd: UnsafeMutablePointer<FILE>) {
        fputs(item.subpath + "\n", fd)
        fputs("\(item.trashedAt.timeIntervalSince1970)\n", fd)
    }
    
    private func addItem(_ item: MirrorTrashItem) {
        guard let fd = self.openInventoryFile(in: "a") else { return }
        self.write(item: item, to: fd)
        fclose(fd)
        self.items.append(item)
    }
    
    private func updateInventory() {
        guard let fd = self.openInventoryFile(in: "w") else { return }
        for item in self.items {
            self.write(item: item, to: fd)
        }
        fclose(fd)
    }
    
    func indexes(from args: [String]) -> ([Int], [String]) {
        var result = [Int]()
        var invalid = [String]()
        let count = self.items.count
        let irange = 0..<count
        for arg in args {
            if let i = Int(arg),
                irange.contains(count - i) {
                result.append(count - i)
            } else {
                invalid.append(arg)
            }
        }
        
        return (result, invalid)
    }
    
    private func safelyCopyItem(at src: URL, to dst: URL) throws {
        let dfm = FileManager.default
        try dfm.createDirectory(at: dst.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        try dfm.copyItem(at: src, to: dst)
    }
    
    func trash(itemAt src: URL, subpath: String?) throws {
        var tsp = UUID().uuidString + "/" + self.mirrorURL.lastPathComponent
        if let sp = subpath {
            tsp = tsp.nsstring.appendingPathComponent(sp)
        }
        let dst = self.url.appendingPathComponent(tsp)
        try self.safelyCopyItem(at: src, to: dst)
        let item = MirrorTrashItem(subpath: tsp, trashedAt: Date())
        self.addItem(item)
    }
    
    private func restore(item: MirrorTrashItem, for origin: URL) throws {
        let src = self.url.appendingPathComponent(item.subpath)
        let dst = origin.appendingPathComponent(
            item.originalSubpath.deletingFirstPathComponent())
        try self.safelyCopyItem(at: src, to: dst)
        // notify presented subitem update manually
        // because sometimes it won't do it automatically
        self.presenter?.presentedSubitemDidChange(at: dst)
    }
    
    func restore(itemsAt indexes: [Int], for origin: URL) {
        var succeeded = Set<Int>()
        for i in indexes {
            let item = self.items[i]
            do {
                try self.restore(item: item, for: origin)
                succeeded.insert(i)
            } catch {
                gSVO.showError("failed to restore item '\(item.originalSubpath)': \(error.localizedDescription.escaping("\""))")
            }
        }
        if !succeeded.isEmpty {
            // remove successfully restored items
            for i in succeeded.sorted(by: >) {
                self.items.remove(at: i)
            }
            self.updateInventory()
        }
    }
    
    func contents(for indexes: [Int]) -> String {
        var result = ""
        let count = self.items.count
        let total = indexes.isEmpty ? count : indexes.count
        result = "\(total) trash item(s) found" +
            (total > 0 ? ":\n\n" : ".")
        if !indexes.isEmpty {
            for (i, item) in indexes.map({ (count - $0, self.items[$0]) }) {
                result += "\(i)\t\(item.description)\n"
            }
        } else {
            for (i, item) in self.items.reversed().enumerated() {
                result += "\(i + 1)\t\(item.description)\n"
            }
        }
        
        return result
    }
}

private extension String {
    func deletingFirstPathComponent() -> String {
        let comps = self.split(
            separator: "/",
            maxSplits: 1,
            omittingEmptySubsequences: false)

        return comps.count > 1 ? String(comps[1]) : ""
    }
}

struct MirrorTrashItem {
    let subpath: String
    let trashedAt: Date
}

extension MirrorTrashItem {
    private static let dateFormatter: DateFormatter = {
        let result = DateFormatter()
        result.dateStyle = .short
        result.timeStyle = .medium
        
        return result
    }()
    
    var originalSubpath: String {
        return self.subpath.deletingFirstPathComponent()
    }
    
    var description: String {
        return "\(MirrorTrashItem.dateFormatter.string(from: self.trashedAt))\t\(self.originalSubpath)"
    }
}
