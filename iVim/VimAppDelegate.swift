//
//  AppDelegate.swift
//  iVim
//
//  Created by Lars Kindler on 27/10/15.
//  Refactored by Terry
//  Copyright © 2015 Boogaloo. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var vimController: VimViewController? {
        return self.window?.rootViewController as? VimViewController
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        FileManager.default.cleanMirrorFiles()
        //Start Vim!
        self.performSelector(
            onMainThread: #selector(self.VimStarter),
            with: nil,
            waitUntilDone: false)
        
        return !self.addPendingWork(with: launchOptions)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
        return self.open(url)
    }
    
    func VimStarter() {
        guard let vimPath = Bundle.main.resourcePath else { return }
        let runtimePath = vimPath + "/runtime"
        vim_setenv("VIM", vimPath)
        vim_setenv("VIMRUNTIME", runtimePath)
        let workingDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        vim_setenv("HOME", workingDir)
        FileManager.default.changeCurrentDirectoryPath(workingDir)
        let args = ["vim"] + LaunchArgumentsParser().parse()
        var argv = args.map { strdup($0) }
        VimMain(Int32(args.count), &argv)
        argv.forEach { free($0) }
    }
    
    private func showIntroMessage() {
        guard is_current_buf_new() else { return }
        maybe_intro_message()
        gAddTextToInputBuffer("gg")
    }
    
    private func addPendingWork(with options: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        if let url = options?[.url] as? URL {
            self.vimController?.pendingWork = {
                _ = self.open(url)
                self.showIntroMessage()
            }
            return true
        } else {
            self.vimController?.pendingWork = { self.showIntroMessage() }
            return false
        }
    }
    
    private func open(_ url: URL?) -> Bool {
        guard let url = url else { return false }
        if URLSchemeWorker.isValid(url) {
            return URLSchemeWorker(url: url)!.run()
        } else if url.isSupportedFont {
            return gFM.importFont(with: url.lastPathComponent)
        } else {
            guard let path = FileManager.default.safeMovingItem(
                from: URL.inboxDirectory?.appendingPathComponent(url.lastPathComponent),
                into: URL.documentsDirectory) else { return false }
            gOpenFile(at: path)
            return true
        }
    }
}

extension String {
    func each(_ closure: (String) -> Void) {
        for digit in self.characters {
            closure(String(digit))
        }
    }
}
