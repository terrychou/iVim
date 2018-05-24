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
        let types = ["public.item", "public.folder", "public.directory"]
        let picker = UIDocumentPickerViewController(documentTypes: types, in: mode)
        if #available(iOS 11, *) {
            picker.allowsMultipleSelection = true
        }
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
    
    @objc func pickDocument() {
        self.showPicker(in: .open)
    }
    
    @objc func importDocument() {
        self.showPicker(in: .import)
    }
    
    private func handle(url: URL, in mode: UIDocumentPickerMode) {
        var urlMode: VimURLMode?
        switch mode {
        case .open:
            urlMode = .open
        case .import:
            urlMode = .copy
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
