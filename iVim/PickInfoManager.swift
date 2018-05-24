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
    private func setup() {
        self.registerNotifications()
    }
    
    private func registerNotifications() {
        let nfc = NotificationCenter.default
        nfc.addObserver(self,
                        selector: #selector(self.didBecomeActive),
                        name: .UIApplicationDidBecomeActive,
                        object: nil)
        nfc.addObserver(self,
                        selector: #selector(self.willResignActive),
                        name: .UIApplicationWillResignActive,
                        object: nil)
    }
}

extension PickInfoManager {
    @objc func didBecomeActive() {
        NSLog("become active")
        self.table.values.forEach {
            NSFileCoordinator.addFilePresenter($0)
            self.updateInfo($0)
        }
    }
    
    @objc func willResignActive() {
        NSLog("resign active")
        self.wrapUp()
    }
    
    @objc func wrapUp() {
        self.table.values.forEach {
            NSFileCoordinator.removeFilePresenter($0)
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
            NSFileCoordinator.addFilePresenter(pi)
        }
    }
    
    func removePickInfo(for url: URL, updateUI: Bool = false) {
        guard let pi = self.table[url] else { return }
        self.localTable[pi.ticket] = nil
        NSFileCoordinator.removeFilePresenter(pi)
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
    
    func hasEntry(for url: URL) -> Bool {
        return self.table[url] != nil
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

extension PickInfoManager {
    @objc func write(for path: String) {
        PickInfoManager.serialQ.async {
            guard let i = self.info(
                for: path,
                isRootEditable: true) else { return }
            i.info.write(for: i.subpath)
        }
    }
    
    @objc func remove(for path: String) {
        PickInfoManager.serialQ.async {
            guard let i = self.info(for: path) else { return }
            i.info.removeItem(for: i.subpath)
        }
    }
    
    @objc func rename(from old: String, to new: String) {
        PickInfoManager.serialQ.async {
            let oi = self.info(for: old)
            let ni = self.info(for: new)
            if oi?.info === ni?.info { //within the same mirror or none
                oi?.info.rename(from: oi!.subpath, to: ni!.subpath)
            } else {
                ni?.info.addItem(for: ni!.subpath) //move into new mirror
                oi?.info.removeItem(for: oi!.subpath) //move out of old mirror
            }
        }
    }
    
    @objc func mkdir(for path: String) {
        PickInfoManager.serialQ.async {
            guard let i = self.info(for: path) else { return }
            i.info.addItem(for: i.subpath)
        }
    }
    
    @objc func rmdir(for path: String) {
        PickInfoManager.serialQ.async {
            guard let i = self.info(for: path) else { return }
            i.info.removeItem(for: i.subpath)
        }
    }
    
    private func ticket(for subpath: String) -> String? {
        var result = ""
        for c in subpath {
            if c == "/" { break }
            result.append(c)
        }
        
        return result
    }
    
    private func info(for path: String, isRootEditable: Bool = false) -> (info: PickInfo, subpath: String)? {
        guard let subpath = FileManager.default.mirrorSubpath(for: path),
            let ticket = self.ticket(for: subpath),
            let info = self.localTable[ticket] else { return nil }
        let srp = info.subRootPath
        if isRootEditable && subpath == srp {
            return (info, subpath)
        }
        
        return subpath.hasPrefix(srp + "/") ? (info, subpath) : nil
    }
}
