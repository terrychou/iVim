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
    private override init() {}
    
    private var localTable = [String: PickInfo]()
    private var table = [URL: PickInfo]()
}

extension PickInfoManager {
    func willEnterForeground() {
        // will NOT be called when app launches
        NSLog("enter foreground")
        self.table.values.forEach {
            NSFileCoordinator.addFilePresenter($0)
            $0.startWatchingMirror()
            self.updateInfo($0)
        }
    }
    
    func didEnterBackground() {
        NSLog("enter background")
        self.wrapUp()
    }
    
    @objc func wrapUp() {
        self.table.values.forEach {
            $0.stopWatchingMirror()
            NSFileCoordinator.removeFilePresenter($0)
        }
    }
}

private let mirrorDirectoryPath = FileManager.default.mirrorDirectoryURL.path

extension PickInfoManager {
    private func addPickInfo(_ pi: PickInfo) {
        self.localTable[pi.ticket] = pi
        self.table[pi.origin] = pi
        NSFileCoordinator.addFilePresenter(pi)
    }
    
    func addPickInfo(for url: URL, task: MirrorReadyTask?) {
        if let existing = self.table[url] {
            existing.addTask(task)
        } else {
            let pi = PickInfo(origin: url, task: task)
            self.addPickInfo(pi)
        }
    }
    
    private func ticket(for path: String) -> String? {
        guard let subpath = FileManager.default.mirrorSubpath(for: path)
            else { return nil }
        var result = ""
        for c in subpath {
            if c == "/" { break }
            result.append(c)
        }

        return result
    }
    
    @objc func addPickInfo(at path: String, update: Bool) {
        guard let ticket = self.ticket(for: path),
            self.localTable[ticket] == nil,
            let pi = PickInfo(ticket: ticket) else {
                return
        }
        self.addPickInfo(pi)
        if update {
            pi.updateMirror {
                NSLog("updated mirror \(ticket)")
            }
        }
    }
    
    @objc func activeMirrorPaths() -> [String] {
        return self.table.values.map { $0.mirrorURL.path }
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
//            do_cmdline_cmd("redraw!")
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
        if info.origin.fileExists(secured: true) {
            info.updateMirror {
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
    @objc func handleTrash(at path: String?, with args: [String]) {
        guard let p = path, let ticket = self.ticket(for: p), let pi = self.localTable[ticket] else {
            gSVO.showError("current buffer is not a mirroring buffer.")
            return
        }
        let subargs = Array(args[1...])
        if args[0] == "trash" { // list trash items
            pi.listTrashContents(with: subargs)
        } else if args[0] == "trash!" {
            pi.restoreTrash(with: subargs)
        }
    }
}
