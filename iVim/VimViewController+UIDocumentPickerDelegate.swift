//
//  VimViewController+UIDocumentPickerDelegate.swift
//  iVim
//
//  Created by Terry on 7/1/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

extension VimViewController: UIDocumentPickerDelegate {
    private func showPicker(in mode: UIDocumentPickerMode) {
        let types = ["public.text", "public.data"]
        let picker = UIDocumentPickerViewController(documentTypes: types, in: mode)
        picker.delegate = self
        self.switchExtendedBarTemporarily(hide: true)
        self.present(picker, animated: true, completion: nil)
    }
    
    private func switchExtendedBarTemporarily(hide: Bool) {
        guard #available(iOS 11.0, *),
            self.extendedBarTemporarilyHidden != hide else { return }
        self.extendedBarTemporarilyHidden = self.shouldShowExtendedBar
        self.shouldShowExtendedBar = !hide
        self.reloadInputViews()
    }
    
    private func executeCommand(command: String) {
        // Hard part: scan the command for mirror URLs
        // check if they are in PickInfoManager table
        // replace them with origin URLs
        //      All mirror URLs have this origin:
        let mirrorOriginPath: String = FileManager.default.mirrorDirectoryURL.path
        let currentDirectory = FileManager.default.currentDirectoryPath // Were are we right now?
        // Separate the command into space-separated components:
        var editedCommand = command
        let argumentList: Array = command.components(separatedBy: " ")
        for argument in argumentList {
            let argumentLocation = currentDirectory.appending("/".appending(argument))
            if argumentLocation.hasPrefix(mirrorOriginPath) {
                // Found one!
                let argumentURL = URL(fileURLWithPath: argumentLocation)
                let originPath = gPIM.getOriginURL(mirror: argumentURL)
                if (!originPath.isEmpty) {
                    editedCommand = editedCommand.replacingOccurrences(of: argument, with: originPath)
                }
            }
        }
        // we send it to blinkshell:
        var path: String
        // concatenate everything into a single string. BlinkShell will do the parsing.
        path = "blinkshell://"
        path = path.appending(editedCommand.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlFragmentAllowed)!)
        let commandURL = URL(string: path)
        DispatchQueue.main.async {
            UIApplication.shared.open(commandURL!, options: [:], completionHandler: nil)
        }
    }
    
    @objc func pickDocument() {
        self.showPicker(in: .open)
    }

    @objc func execute(command: String) {
        self.executeCommand(command: command)
    }

    
    @objc func importDocument() {
        self.showPicker(in: .import)
    }
    
    private func handle(url: URL, in mode: UIDocumentPickerMode) {
        var urlMode: VimURLMode?
        switch mode {
        case .open: urlMode = .open
        case .import: urlMode = .copy
        default: break
        }
        _ = VimURLHandler(url: url, nonLocalMode: urlMode)?.open()
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        self.switchExtendedBarTemporarily(hide: false)
        self.handle(url: url, in: controller.documentPickerMode)
    }
    
    //only available since iOS 11
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.switchExtendedBarTemporarily(hide: false)
        let mode = controller.documentPickerMode
        for url in urls {
            self.handle(url: url, in: mode)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.switchExtendedBarTemporarily(hide: false)
//        NSLog("document picker cancelled")
    }
}
