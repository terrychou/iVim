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
    
    @objc func VimStarter() {
        guard self.customizeEnv() else { return }
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

extension AppDelegate { // env setup
    private func customizeEnv() -> Bool {
            guard let resPath = Bundle.main.resourcePath else { return false }
            // for ios_system
            initializeEnvironment()
            
            // setup vim
            let runtimePath = resPath + "/runtime"
            vim_setenv("VIM", resPath)
            vim_setenv("VIMRUNTIME", runtimePath)
            let docDir = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                             .userDomainMask,
                                                             true)[0]
            vim_setenv("HOME", docDir)
            FileManager.default.changeCurrentDirectoryPath(docDir)
            
            // setup python
            self.setupPython(withResourcePath: resPath)
            
            // no color for ls
            unsetenv("CLICOLOR")
            
            return true
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
            vim_setenv("PYTHONIOENCODING", "utf-8")
            // setup pip: install into the writable one
            vim_setenv("PIP_TARGET", libHome)
            vim_setenv("PIP_DISABLE_PIP_VERSION_CHECK", "yes")
            vim_setenv("PIP_NO_COLOR", "yes")
            vim_setenv("PIP_PROGRESS_BAR", "pretty")
        }
}
