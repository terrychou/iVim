//
//  AppDelegate.swift
//  iVim
//
//  Created by Lars Kindler on 27/10/15.
//  Refactored by Terry
//  Copyright © 2015 Boogaloo. All rights reserved.
//

import UIKit
import ios_system

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var isLaunchedByURL = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        self.logToFile()
        self.registerUserDefaultsValues()
//        Start Vim!
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
            if scene_keeper_add_pending_url_task({
                _ = VimURLHandler(url: url)?.open()
            }) {
                handleNow = false
            }
        }
        
        return !handleNow || VimURLHandler(url: url)?.open() ?? false
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        gPIM.willEnterForeground()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scenes_keeper_stash();
        gPIM.didEnterBackground()
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
    
    private func setupPython(withResourcePath resPath: String) {
        numPythonInterpreters = 2
        let libPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory,
                                                          .userDomainMask,
                                                          true)[0]
        let libHome = libPath + "/python/site-packages"
//        vim_setenv("PYTHONHOME", resPath + "/python" + ":" + libHome)
        vim_setenv("PYTHONHOME", resPath + "/python")
        vim_setenv("PYTHONPATH", libHome)
        // setup pip: install into the writable one
        vim_setenv("PIP_TARGET", libHome)
        vim_setenv("PIP_DISABLE_PIP_VERSION_CHECK", "yes")
        vim_setenv("PIP_NO_COLOR", "yes")
    }
    
    @objc func VimStarter() {
        guard let vimPath = Bundle.main.resourcePath else { return }
        initializeEnvironment() // for ios_system
        let runtimePath = vimPath + "/runtime"
        vim_setenv("VIM", vimPath)
        vim_setenv("VIMRUNTIME", runtimePath)
        let workingDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        vim_setenv("HOME", workingDir)
        self.setupPython(withResourcePath: vimPath)
        FileManager.default.changeCurrentDirectoryPath(workingDir)
        var args = ["vim"]
        if !scenes_keeper_restore_prepare() {
            gSVO.showError("failed to auto-restore")
        } else if let spath = scene_keeper_valid_session_file_path() {
            let rCmd = "silent! source \(spath) | " +
            "silent! idocuments session"
            args += ["-c", rCmd]
        }
        args += LaunchArgumentsParser().parse()
        var argv = args.map { strdup($0) }
        VimMain(Int32(args.count), &argv)
        argv.forEach { free($0) }
    }
}
