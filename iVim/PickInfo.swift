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
    var subpath: String!
    var presenter: DocumentPresenter!
    lazy var mirrorURL: URL = FileManager.default.mirrorDirectoryURL.appendingPathComponent(self.subpath)
    var source: DispatchSourceFileSystemObject?
    var pendingTasks: [MirrorReadyTask]? = []
    
    init(origin: URL) {
        self.origin = origin
        self.subpath = UUID().uuidString + "/" + self.origin.lastPathComponent
        self.presenter = DocumentPresenter(url: self.origin, mirrorURL: self.mirrorURL)
        self.createMirrorFile()
    }
    
    deinit {
        self.source?.cancel()
        self.deleteMirror()
    }
}

extension PickInfo {
    private func startMonitoring() {
        let fd = open(self.mirrorURL.path, O_EVTONLY)
        guard fd != -1 else { return NSLog("Failed to open file \(self.mirrorURL)") }
        let s = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write)
        s.setEventHandler { [weak self] in
            NSLog("written")
            self?.presenter?.write()
        }
        s.setCancelHandler {
            NSLog("close")
            close(fd)
        }
        self.source = s
        s.resume()
    }
    
    fileprivate func createMirrorFile() {
        guard let p = self.presenter else { return }
        let url = self.mirrorURL
        self.origin.coordinatedRead(for: p) {
            guard let src = $0 else {
                if let e = $1 { NSLog("Failed to read file: \(e)") }
                return
            }
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: src, to: url)
                self.startMonitoring()
                DispatchQueue.main.async {
                    self.pendingTasks?.forEach { $0(url) }
                    self.pendingTasks = nil
                }
            } catch {
                NSLog("Failed to copy file: \(error)")
            }
        }
    }
    
    func deleteMirror() {
        do {
            try FileManager.default.removeItem(at: self.mirrorURL.deletingLastPathComponent())
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
