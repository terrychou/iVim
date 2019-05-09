//
//  FilesystemItemWatcher.swift
//  iVim
//
//  Created by Terry Chou on 10/14/19.
//  Copyright © 2019 Boogaloo. All rights reserved.
//

import Foundation


protocol FilesystemItemWatcherDelegate: class {
    func itemDidChange()
    func itemDidRename(to newURL: URL)
    func subitemDidChange(at url: URL)
    func subitemWasDeleted(at url: URL)
}

final class FilesystemItemWatcher: NSObject {
    private static let operationQ = OperationQueue()
    private var itemURL: URL
    private var isWatching = false
    weak var delegate: FilesystemItemWatcherDelegate?
    init(url: URL, delegate: FilesystemItemWatcherDelegate? = nil) {
        self.itemURL = url
        self.delegate = delegate
        super.init()
    }
    
    deinit {
        self.stop()
    }
}

extension FilesystemItemWatcher: NSFilePresenter {
    var presentedItemURL: URL? {
        return self.itemURL
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return FilesystemItemWatcher.operationQ
    }
    
    func presentedItemDidChange() {
//        print("\(#function)")
        self.delegate?.itemDidChange()
    }
    
    func presentedItemDidMove(to newURL: URL) {
//        print("\(#function)")
        self.delegate?.itemDidRename(to: newURL)
    }
    
//    func presentedSubitemDidAppear(at url: URL) {
//        print("\(#function)")
//        print("at: \(url)")
//    }
    
    func presentedSubitemDidChange(at url: URL) {
//        print("\(#function)")
        if FileManager.default.fileExists(atPath: url.path) {
            self.delegate?.subitemDidChange(at: url)
        } else {
            self.delegate?.subitemWasDeleted(at: url)
        }
    }
    
//    func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
//        print("\(#function)")
//        print("from: \(oldURL) to: \(newURL)")
//    }
//
//    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
//        print("\(#function)")
//    }
//
//    func accommodatePresentedSubitemDeletion(at url: URL, completionHandler: @escaping (Error?) -> Void) {
//        print("\(#function)")
//        print("at: \(url)")
//    }
    
    func start() {
        if !self.isWatching {
            NSFileCoordinator.addFilePresenter(self)
            self.isWatching = true
        }
    }
    
    func stop() {
        if self.isWatching {
            NSFileCoordinator.removeFilePresenter(self)
            self.isWatching = false
        }
    }
}
