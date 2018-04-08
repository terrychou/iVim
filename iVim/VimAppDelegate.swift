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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
//        self.logToFile()
        //Start Vim!
        self.performSelector(
            onMainThread: #selector(self.VimStarter),
            with: nil,
            waitUntilDone: false)
        self.cleanMirrors()

        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
        return VimURLHandler(url: url)?.open() ?? false
    }
    
//    private func logToFile() {
//        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
//        let file = path + "/NSLog.log"
//        freopen(file, "a+", stderr)
//    }
    
    private func cleanMirrors() {
        DispatchQueue.main.async {
            FileManager.default.cleanMirrorFiles()
        }
    }
    
    @objc func VimStarter() {
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
}
