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
    private var isLaunchedByURL = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        self.logToFile()
        self.registerUserDefaultsValues()
        //Start Vim!
        self.performSelector(
            onMainThread: #selector(self.VimStarter),
            with: nil,
            waitUntilDone: false)
        self.doPossibleCleaning()
        self.isLaunchedByURL = launchOptions?[.url] != nil

        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        var handleNow = true
        if self.isLaunchedByURL {
            self.isLaunchedByURL = false
            if scene_keeper_add_pending_bookmark(url.bookmark) {
                handleNow = false
            }
        }
        var result = true
        if handleNow {
            result = VimURLHandler(url: url)?.open() ?? false
        }
        
        return result
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        scenes_keeper_stash();
        gPIM.willResignActive()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        gPIM.didBecomeActive()
    }
    
//    private func logToFile() {
//        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
//        let file = path + "/NSLog.log"
//        freopen(file, "a+", stderr)
//    }
    
    private func doPossibleCleaning() {
        DispatchQueue.main.async {
            scenes_keeper_clear_all()
        }
    }
    
    private func registerUserDefaultsValues() {
        register_auto_restore_enabled()
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
            let rCmd = "silent! source \(spath) | silent! idocuments session"
            args += ["-c", rCmd]
        }
        var argv = args.map { strdup($0) }
        VimMain(Int32(args.count), &argv)
        argv.forEach { free($0) }
    }
}
