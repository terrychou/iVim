//
//  VimShareActions+Extension.swift
//  iVimShare
//
//  Created by Terry Chou on 12/26/19.
//  Copyright © 2019 Boogaloo. All rights reserved.
//

import Foundation
import Social


protocol ActionDataProvider: class {
    var currentAction: ShareAction? { get set }
    func title(for action: ShareAction) -> String?
    func handler(for action: ShareAction) -> SLComposeSheetConfigurationItemTapHandler?
}

extension ShareAction {
    func configItem(with provider: ActionDataProvider) -> SLComposeSheetConfigurationItem? {
        guard let title = provider.title(for: self) else { return nil }
        let item = SLComposeSheetConfigurationItem()!
        item.title = title
        if provider.currentAction?.name != self.name {
            // set taphandler if not current selected
            if let handler = provider.handler(for: self) {
                item.tapHandler = {
                    provider.currentAction = self
                    handler()
                    item.tapHandler = nil
                }
            }
        }
        
        return item
    }
    
    func schemeURL() -> URL? {
        let uStr = "\(gSchemeName)://\(gShareCommand)/"
        guard var comps = URLComponents(string: uStr) else { return nil }
        comps.query = "action=" + self.name
        
        return comps.url
    }
}
