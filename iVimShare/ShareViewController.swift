//
//  ShareViewController.swift
//  iVimShare
//
//  Created by Terry on 7/22/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit
import Social

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        self.open(with: self.contentText)
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

}

extension ShareViewController {
    func open(_ url: URL, options: [String : Any] = [:], completionHandler completion: ((Bool) -> Void)? = nil) {
        return
    }
    
    func openURL(_ url: URL) -> Bool {
        return false
    }
    
    private func saveText(_ text: String) -> String? {
        guard let c = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: gAppGroup) else { return nil }
        let name = UUID().uuidString
        let url = c.appendingPathComponent(name)
        do {
            try text.write(to: url, atomically: false, encoding: .utf8)
            return name
        } catch {
            return nil
        }
    }
    
    private func copyText(_ text: String) -> String {
        let p = UIPasteboard.withUniqueName()
        p.string = text
        
        return p.name.rawValue
    }
    
    private func url(with text: String) -> URL? {
        guard let name = self.saveText(text) else { return nil }
        let scheme = "\(gSchemeName)://"
        let path = "newtab/"
        let query = "file=" + name
        var components = URLComponents(string: scheme + path)
        components?.query = query
        
        return components?.url
    }
    
    func open(with text: String) {
        var responder: UIResponder? = self as UIResponder
        let selector: Selector = #selector(openURL(_:))
        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                responder!.perform(selector, with: self.url(with: text))
                return
            }
            responder = responder?.next
        }
    }
}
