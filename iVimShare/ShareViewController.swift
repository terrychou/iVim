//
//  ShareViewController.swift
//  iVimShare
//
//  Created by Terry on 7/22/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit
import Social
import MobileCoreServices

extension NSItemProvider {
    func getItem<T>(for typeUTI: CFString,
                    options: [AnyHashable: Any]? = nil,
                    task: @escaping (T?) -> Void) {
        let uti = typeUTI as String
        guard self.hasItemConformingToTypeIdentifier(uti) else {
            return task(nil)
        }
        self.loadItem(forTypeIdentifier: uti, options: options) {
            rst, err in
            if let e = err {
                NSLog("failed to load item '\(uti)': \(e.localizedDescription)")
            }
            task(rst as? T)
        }
    }
    
    func getItemSynchronously<T>(for typeUTI: CFString,
                                 options: [AnyHashable: Any]? = nil,
                                 semaphore: DispatchSemaphore? = nil,
                                 task: @escaping (T) -> Void) {
        let sema = semaphore ?? DispatchSemaphore(value: 0)
        self.getItem(for: typeUTI, options: options) { (rst: T?) in
            if let r = rst {
                task(r)
            }
            sema.signal()
        }
        sema.wait()
    }
}

class ShareViewController: SLComposeServiceViewController {
    var isValid = true
    var itemsCollected = false
    var urls = [URL]()
    var text = ""
    var configItems = [SLComposeSheetConfigurationItem]()
    var currentAction: ShareAction?

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        if !self.itemsCollected {
            if let items = self.extensionContext?.inputItems as? [NSExtensionItem] {
                DispatchQueue.global(qos: .userInitiated).async {
                    self.collectItems(items)
                    DispatchQueue.main.async {
                        self.update()
                        self.validateContent()
                    }
                }
            }
            self.itemsCollected = true
        }
        
        return self.isValid
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        guard let action = self.currentAction else { return }
        self.run(action: action)
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return self.configItems
    }
}

extension ShareViewController {
    private func collectItems(_ items: [NSExtensionItem]) {
        // Note: DON'T call this function on main thread, or it freezes
        // collect two types of items:
        //    1) text
        //    2) file url
        let sema = DispatchSemaphore(value: 0)
        for item in items {
            if let providers = item.attachments {
                for p in providers {
                    p.getItemSynchronously(for: kUTTypeFileURL, semaphore: sema) {
                        self.urls.append($0)
                    }
                    p.getItemSynchronously(for: kUTTypeText, semaphore: sema) {
                        self.text.append($0 as String)
                    }
                }
            }
        }
    }
    
    private func setTitleOfPostButton(to newTitle: String) {
        self.navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = newTitle
    }
    
    private func update() {
        // update with collected items so far
        self.isValid = true
        self.configItems = []
        if !self.text.isEmpty {
            // sharing text
            self.updateConfigItems(with: ShareTextAction.allActions)
        } else if self.urls.count > 0 {
            // sharing files
            self.updateConfigItems(with: ShareFileAction.allActions)
        } else {
            self.isValid = false
        }
        self.reloadConfigurationItems()
    }
}

extension ShareViewController {
    func run(action: ShareAction) {
        guard let schemeURL = action.schemeURL() else { return }
        if let textAction = action as? ShareTextAction {
            switch textAction {
            case .text:
                textAction.setData(self.contentText ?? "")
            }
        } else if let fileAction = action as? ShareFileAction {
            switch fileAction {
            case .content:
                fileAction.setData(self.contentText ?? "")
            }
        }
        self.open(url: schemeURL)
    }
}

extension ShareViewController: ActionDataProvider {    
    func title(for action: ShareAction) -> String? {
        var result: String?
        if let textAction = action as? ShareTextAction {
            switch textAction {
            case .text: result = "Sharing Selected Text"
            }
        } else if let fileAction = action as? ShareFileAction {
            let name: String
            switch fileAction {
            case .content: name = "Sharing Content of"
            }
            let count = self.urls.count
            result = "\(name) \(count > 1 ? "\(count) Files" : self.urls[0].lastPathComponent)"
        }
        
        return result
    }
    
    private func textSharingHandler() {
        var text = self.text
        if text.isEmpty && self.urls.count > 0 {
            for url in self.urls {
                do {
                    let content = try String(contentsOf: url)
                    text.append(content)
                } catch {
                    let textView = self.textView!
                    var attrs = textView.typingAttributes
                    attrs[.foregroundColor] = UIColor.red
                    textView.attributedText = NSAttributedString(
                        string: "ERROR: failed to get text content from file '\(url.lastPathComponent)'",
                        attributes: attrs)
                    self.isValid = false
                    self.setTitleOfPostButton(to: "Invalid")
                    return self.validateContent()
                }
            }
        }
        // show text to be shared
        self.textView?.text = text
        // set post button title
        self.setTitleOfPostButton(to: "Share")
    }
    
    func handler(for action: ShareAction) -> SLComposeSheetConfigurationItemTapHandler? {
        var result: SLComposeSheetConfigurationItemTapHandler?
        if let textAction = action as? ShareTextAction {
            switch textAction {
            case .text: result = self.textSharingHandler
            }
        } else if let fileAction = action as? ShareFileAction {
            switch fileAction {
            case .content: result = self.textSharingHandler
            }
        }
        
        return result
    }
    
    private func updateConfigItems(with actions: [ShareAction]) {
        let items = actions.compactMap { $0.configItem(with: self) }
        self.configItems = items
        // treat the first item as the default one
        items.first?.tapHandler?()
    }
}

extension ShareViewController {
    func open(_ url: URL, options: [String : Any] = [:], completionHandler completion: ((Bool) -> Void)? = nil) {
        return
    }
    
    @objc func openURL(_ url: URL) -> Bool {
        return false
    }
    
    func open(url: URL) {
        var responder: UIResponder? = self as UIResponder
        let selector: Selector = #selector(openURL(_:))
        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                responder!.perform(selector, with: url)
                return
            }
            responder = responder?.next
        }
    }
}
