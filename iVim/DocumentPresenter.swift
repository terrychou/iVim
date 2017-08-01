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
        } catch {
            NSLog("Failed to update file: \(error)")
        }
    }
    
    func read(_ completion: (() -> Void)? = nil) {
        self.url.coordinatedRead(for: self) { url, err in
            self.update(from: url, to: self.mirrorURL, err: err)
            completion?()
        }
    }
    
    func write() {
        NSLog("write")
        self.url.coordinatedWrite(for: self) { url, err in
            self.update(from: self.mirrorURL, to: url, err: err)
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
        gPIM.updateURL(self.url, for: newURL)
        self.url = newURL
    }
    
    func presentedItemDidChange() {
        self.read()
    }
    
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        defer { completionHandler(nil) }
        let path = self.mirrorURL.path.spaceEscaped
        if file_is_in_buffer_list(path) {
            do_cmdline_cmd("bdelete! \(path)")
        }
        gPIM.removePickInfo(for: self.url)
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
