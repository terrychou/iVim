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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        self.logToFile()
        //Start Vim!
        self.performSelector(
            onMainThread: #selector(self.VimStarter),
            with: nil,
            waitUntilDone: false)
//        self.cleanMirrors()

        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return VimURLHandler(url: url)?.open() ?? false
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        scenes_keeper_stash();
        gPIM.willResignActive()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        DispatchQueue.main.async {
            if !scenes_keeper_restore_post() {
                gPIM.didBecomeActive()
            }
        }
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
        scenes_keeper_restore_prepare();
        var args = ["vim"] + LaunchArgumentsParser().parse()
        if let spath = scene_keeper_valid_session_file_path() {
            args += ["-S", spath];
        }
        var argv = args.map { strdup($0) }
        VimMain(Int32(args.count), &argv)
        argv.forEach { free($0) }
    }
}
