//
//  VimViewController+ExtendedKeyboard.swift
//  iVim
//
//  Created by Terry on 7/19/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

extension VimViewController {
    func pressArrow(_ key: Int32) {
        if self.markedInfo != nil {
            self.resetKeyboard()
            self.unmarkText()
        } else if self.dictationHypothesis != nil {
            self.resetKeyboard()
        } else {
            input_special_key(key)
        }
    }
    
    func pressESC() {
        if self.markedInfo != nil {
            self.cancelCurrentMarkedText()
        } else if self.dictationHypothesis != nil {
            self.cleanupDictationHypothesis()
            self.resetKeyboard()
        } else {
            self.insertText(keyESC.unicoded)
        }
    }
    
    override var inputAccessoryView: UIView? {
        return self.shouldShowExtendedBar ?
            ExtendedKeyboardManager.shared.inputView : nil
    }
}
