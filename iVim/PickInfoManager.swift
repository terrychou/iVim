//
//  PresentersManager.swift
//  iVim
//
//  Created by Terry on 6/29/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

let gPIM = PickInfoManager.shared

final class PickInfoManager: NSObject {
    @objc static let shared = PickInfoManager()
    static let serialQ = DispatchQueue(label: "com.terrychou.ivim.pickinfomanager",
                                       qos: .background)
    private override init() {
        super.init()
        self.setup()
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private var localTable = [String: PickInfo]()
    private var table = [URL: PickInfo]()
}

extension PickInfoManager {
    fileprivate func setup() {
        self.registerNotifications()
    }
    
    private func registerNotifications() {
        let nfc = NotificationCenter.default
        nfc.addObserver(self, selector: #selector(self.didBecomeActive), name: .UIApplicationDidBecomeActive, object: nil)
        nfc.addObserver(self, selector: #selector(self.willResignActive), name: .UIApplicationWillResignActive, object: nil)
    }
}

extension PickInfoManager {
    @objc func didBecomeActive() {
        NSLog("become active")
        self.table.values.forEach {
            NSFileCoordinator.addFilePresenter($0.presenter)
            self.updateInfo($0)
        }
    }
    
    @objc func willResignActive() {
        NSLog("resign active")
        self.table.values.forEach {
            NSFileCoordinator.removeFilePresenter($0.presenter)
        }
    }
}

private let mirrorDirectoryPath = FileManager.default.mirrorDirectoryURL.path

extension PickInfoManager {
    func addPickInfo(for url: URL, task: MirrorReadyTask?) {
        if let existing = self.table[url] {
            existing.addTask(task)
        } else {
            let pi = PickInfo(origin: url)
            pi.addTask(task)
            self.localTable[pi.ticket] = pi
            self.table[url] = pi
            NSFileCoordinator.addFilePresenter(pi.presenter)
        }
    }
    
    @objc func write(for filename: String) {
        PickInfoManager.serialQ.async {
            self.info(for: filename)?.write(for: filename)
        }
    }
    
    @objc func remove(for filename: String) {
        PickInfoManager.serialQ.async {
            self.info(for: filename)?.removeItem(for: filename)
        }
    }
    
    @objc func rename(from old: String, to new: String) {
        PickInfoManager.serialQ.async {
            let oldTicket = self.ticket(for: old)
            let newTicket = self.ticket(for: new)
            if oldTicket == newTicket { //within the same mirror or none
                guard let ot = oldTicket else { return }
                self.localTable[ot]?.rename(from: old, to: new)
            } else {
                if let nt = newTicket { //move into new mirror
                    self.localTable[nt]?.addItem(for: new)
                }
                if let ot = oldTicket { //move out of old mirror
                    self.localTable[ot]?.removeItem(for: old)
                }
            }
        }
    }
    
    @objc func mkdir(for name: String) {
        PickInfoManager.serialQ.async {
            self.info(for: name)?.addItem(for: name)
        }
    }
    
    @objc func rmdir(for name: String) {
        PickInfoManager.serialQ.async {
            self.info(for: name)?.removeItem(for: name)
        }
    }
    
    private func ticket(for name: String) -> String? {
        guard name.hasPrefix(mirrorDirectoryPath) else { return nil }
        var result = ""
        for c in name.dropFirst(mirrorDirectoryPath.count + 1) {
            if c == "/" { break }
            result.append(c)
        }
        
        return result
    }
    
    private func info(for name: String) -> PickInfo? {
        guard let ticket = self.ticket(for: name) else { return nil }
        
        return self.localTable[ticket]
    }
    
    func removePickInfo(for url: URL, updateUI: Bool = false) {
        guard let pi = self.table[url] else { return }
        self.localTable[pi.ticket] = nil
        NSFileCoordinator.removeFilePresenter(pi.presenter)
        self.table[url] = nil
        if updateUI {
            DispatchQueue.main.async {
                let path = pi.mirrorURL.path
                if clean_buffer_for_mirror_path(path) {
                    do_cmdline_cmd("redraw!")
                }
            }
        }
    }
    
    func reloadBufferForMirror(at url: URL) {
        DispatchQueue.main.async {
            ivim_reload_buffer_for_mirror(url.path)
            do_cmdline_cmd("redraw!")
        }
    }
    
    func updateURL(_ url: URL, for newURL: URL) {
        guard url != newURL, let old = self.table[url] else { return }
        old.updateOrigin(to: newURL)
        self.table[newURL] = old
        self.table[url] = nil
    }
    
    func updateDate(with newDate: Date? = nil, for url: URL) {
        guard let info = self.table[url] else { return }
        let date = newDate ?? Date()
        info.updatedDate = date
    }
    
    /*
     * update after app becomes active again
     * situations include:
     *   1. origin changed: update the contents of the mirror
     *   2. origin renamed: update the origin URL and bookmark data
     *   3. origin deleted: delete the related entry and remove the associated mirror
     */
    func updateInfo(_ info: PickInfo) {
        if info.origin.isReachable(secured: true) {
            if info.updateMirror() {
                NSLog("RELOAD: \(info.mirrorURL)")
                self.reloadBufferForMirror(at: info.mirrorURL)
            }
        } else if let newURL = info.bookmark?.resolvedURL,
            !(newURL.isInTrash || newURL.path == info.origin.path) {
            NSLog("RENAME: \(info.origin) to \(newURL.path)")
            self.updateURL(info.origin, for: newURL)
        } else {
            NSLog("DELETE: \(info.mirrorURL)")
            self.removePickInfo(for: info.origin, updateUI: true)
        }
    }
}
