//
//  PickInfo.swift
//  iVim
//
//  Created by Terry on 7/8/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import Foundation

extension FileManager {
    var tempDirectoryURL: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
    
    var mirrorDirectoryURL: URL {
        return self.tempDirectoryURL.appendingPathComponent("Openbox")
    }
    
    func cleanMirrorFiles() {
        guard self.fileExists(atPath: self.mirrorDirectoryURL.path) else { return }
        do {
            try self.removeItem(at: self.mirrorDirectoryURL)
        } catch {
            NSLog("Failed to clean mirror files: \(error)")
        }
    }
}

typealias MirrorReadyTask = (URL) -> Void

final class PickInfo {
    var origin: URL
    var bookmark: Data?
    let ticket: String
    var presenter: DocumentPresenter!
    var mirrorURL: URL
    var updatedDate: Date!
    var pendingTasks: [MirrorReadyTask]? = []
    
    init(origin: URL) {
        self.origin = origin
        self.bookmark = origin.bookmark
        self.ticket = UUID().uuidString
        let subpath = self.ticket + "/" + self.origin.lastPathComponent
        self.mirrorURL = FileManager.default.mirrorDirectoryURL.appendingPathComponent(subpath)
        self.presenter = DocumentPresenter(url: self.origin, mirrorURL: self.mirrorURL)
        self.createMirror()
        self.updatedDate = Date()
    }
    
    deinit {
        self.deleteMirror()
    }
}

extension PickInfo {
    private func createMirror() {
        guard let p = self.presenter else { return }
        self.origin.coordinatedRead(for: p) { [unowned self] url, err in
            guard let oURL = url else {
                if let e = err { NSLog("Failed to read original file: \(e)") }
                return
            }
            let mURL = self.mirrorURL
            let fm = FileManager.default
            do {
                try fm.createDirectory(
                    at: mURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try fm.copyItem(at: oURL, to: mURL)
                DispatchQueue.main.async {
                    self.pendingTasks?.forEach { $0(mURL) }
                    self.pendingTasks = nil
                }
            } catch {
                NSLog("Failed to create mirror: \(error)")
            }
        }
    }
    
    func write(for filename: String) {
        self.presenter?.write(for: filename)
    }
    
    func removeItem(for name: String) {
        self.presenter?.removeItem(for: name)
    }
    
    func rename(from old: String, to new: String) {
        self.presenter?.rename(from: old, to: new)
    }
    
    func addItem(for name: String) {
        self.presenter?.addItem(for: name)
    }
    
    func updateMirror() -> Bool {
//        NSLog("origin date: \(self.origin.contentModifiedDate(secured: true)!)")
//        NSLog("updated date: \(self.updatedDate)")
        guard let oCntDate = self.origin.contentModifiedDate(secured: true),
            oCntDate > self.updatedDate else { return false } //original content has been modified
        self.presenter?.read()
        
        return true
    }
    
    func updateOrigin(to newURL: URL) {
        self.origin = newURL
        self.bookmark = newURL.bookmark
        self.presenter?.url = newURL
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
            if self.pendingTasks == nil {
                t(self.mirrorURL)
            } else {
                self.pendingTasks!.append(t)
            }
        }
    }
}
