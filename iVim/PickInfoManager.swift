//
//  PresentersManager.swift
//  iVim
//
//  Created by Terry on 6/29/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import Foundation

let gPIM = PickInfoManager.shared

final class PickInfoManager {
    static let shared = PickInfoManager()
    private init() { self.setup() }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    fileprivate var table = [URL: PickInfo]()
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
        self.table.values.forEach { pi in
            NSFileCoordinator.addFilePresenter(pi.presenter)
        }
    }
    
    @objc func willResignActive() {
        NSLog("resign active")
        self.table.values.forEach {
            NSFileCoordinator.removeFilePresenter($0.presenter)
        }
    }
}

extension PickInfoManager {
    func addPickInfo(for url: URL, task: MirrorReadyTask?) {
        if let existing = self.table[url] {
            existing.addTask(task)
        } else {
            let pi = PickInfo(origin: url)
            pi.addTask(task)
            self.table[url] = pi
            NSFileCoordinator.addFilePresenter(pi.presenter)
        }
    }
    
    func removePickInfo(for url: URL) {
        guard let pi = self.table[url] else { return }
        pi.deleteMirror()
        NSFileCoordinator.removeFilePresenter(pi.presenter)
        self.table[url] = nil
    }
    
    func updateURL(_ url: URL, for newURL: URL) {
        guard url != newURL, let old = self.table[url] else { return }
        old.origin = newURL
        self.table[newURL] = old
        self.table[url] = nil
    }
}
