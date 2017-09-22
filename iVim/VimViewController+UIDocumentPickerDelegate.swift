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
        let types = ["public.text"]
        let picker = UIDocumentPickerViewController(documentTypes: types, in: mode)
        picker.delegate = self
        self.switchExtendedBarTemporarily(hide: true)
        self.present(picker, animated: true, completion: nil)
    }
    
    private func switchExtendedBarTemporarily(hide: Bool) {
//        gui_focus_change(!hide)
        guard self.extendedBarTemporarilyHidden != hide else { return }
        self.extendedBarTemporarilyHidden = self.shouldShowExtendedBar
        self.shouldShowExtendedBar = !hide
        self.reloadInputViews()
    }
    
    func pickDocument() {
        self.showPicker(in: .open)
    }
    
    func importDocument() {
        self.showPicker(in: .import)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
//        NSLog("picked url: \(url)")
        self.switchExtendedBarTemporarily(hide: false)
        switch controller.documentPickerMode {
        case .open:
            gPIM.addPickInfo(for: url, task: {
                gOpenFile(at: $0)
            })
        case .import:
            guard let p = FileManager.default.safeMovingItem(from: url, into: URL.documentsDirectory) else { break }
            gOpenFile(at: p)
        default: break
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print(urls)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.switchExtendedBarTemporarily(hide: false)
        NSLog("document picker cancelled")
    }
}
