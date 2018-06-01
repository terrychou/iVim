//
//  URLOpener.swift
//  iVim
//
//  Created by Terry Chou on 16/03/2018.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import UIKit

final class URLOpener: NSObject {
    let path: String
    
    @objc init(path: String) {
        self.path = path
        super.init()
    }
    
    @objc func open() {
        let realizer = URLRealizer(urlString: self.path)
        do {
            if let url = try realizer.run() {
                self.open(url)
            } else {
                gSVO.showError("invalid path")
            }
        } catch let URLRealizingError.syntax(msg, pos) {
            let pointed = self.path.pointing(at: pos).escaping("\\")
            let errMsg = msg + ": " + pointed
            gSVO.showError(errMsg)
        } catch {
            NSLog("System failure during realizing path: \(error)")
        }
    }
    
    private func open(_ url: URL) {
        let app = UIApplication.shared
        let failure = { gSVO.showError("failed to open URL: \(url)") }
        if #available(iOS 10, *) {
            app.open(url, options: [:]) {
                if !$0 { failure() }
            }
        } else {
            if !app.openURL(url) {
                failure()
            }
        }
    }
}

extension String {
    func pointing(at i: Int) -> String {
        let idx = self.index(self.startIndex, offsetBy:i)
        let new = ">\(self[idx])<"
        
        return self.replacingCharacters(in: idx...idx, with: new)
    }
}
