//
//  VimViewController+ExtendedKeyboard.swift
//  iVim
//
//  Created by Terry on 7/19/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

extension VimViewController {
    private func inputOption(for key: String) -> ButtonOption {
        return ButtonOption(title: key, action: { _ in self.insertText(key) })
    }
    
    private func keyOption(for title: String, key: Int32) -> ButtonOption {
        return ButtonOption(title: title, action: { _ in self.insertText(key.unicoded) })
    }
    
//    private func feedKeysOption(for title: String, keys: String) -> ButtonOption {
//        return ButtonOption(title: title, action: { _ in gFeedKeys(keys) })
//    }
    
    private func markedTextConflictOption(for title: String, action: Action?) -> ButtonOption {
        return ButtonOption(title: title, action: { b in
            if self.markedInfo != nil {
                self.resetKeyboard()
                self.unmarkText()
            } else {
                action?(b)
            }
        })
    }
    
    private var buttons: [[ButtonOption]] {
        return [
            [
                ButtonOption(title: "esc", action: { _ in
                    if self.markedInfo == nil {
                        self.insertText(keyESC.unicoded)
                    } else {
                        self.cancelCurrentMarkedText()
                    }
                }),
                ButtonOption(title: "ctrl", action: { b in
                    guard self.ctrlButton != b else { return }
                    self.ctrlButton = b
                }, isSticky: true)],
            [
                self.keyOption(for: "tab", key: keyTAB),
                self.markedTextConflictOption(for: "↓", action: { _ in gFeedKeys("Down".escaped) }),
                self.markedTextConflictOption(for: "←", action: { _ in gFeedKeys("Left".escaped) }),
                self.markedTextConflictOption(for: "→", action: { _ in gFeedKeys("Right".escaped) }),
                self.markedTextConflictOption(for: "↑", action: { _ in gFeedKeys("Up".escaped) }) ],
            [
                self.inputOption(for: "0"),
                self.inputOption(for: "1"),
                self.inputOption(for: "2"),
                self.inputOption(for: "3"),
                self.inputOption(for: "4") ],
            [
                self.inputOption(for: "5"),
                self.inputOption(for: "6"),
                self.inputOption(for: "7"),
                self.inputOption(for: "8"),
                self.inputOption(for: "9") ],
            [
                self.inputOption(for: "="),
                self.inputOption(for: "+"),
                self.inputOption(for: "-"),
                self.inputOption(for: "*"),
                self.inputOption(for: "%") ],
            [
                self.inputOption(for: ","),
                self.inputOption(for: "("),
                self.inputOption(for: ")"),
                self.inputOption(for: "<"),
                self.inputOption(for: ">") ],
            [
                self.inputOption(for: "."),
                self.inputOption(for: "{"),
                self.inputOption(for: "}"),
                self.inputOption(for: "["),
                self.inputOption(for: "]") ],
            [
                self.inputOption(for: ";"),
                self.inputOption(for: "'"),
                self.inputOption(for: "\""),
                self.inputOption(for: "^"),
                self.inputOption(for: "$") ],
            [
                self.inputOption(for: "!"),
                self.inputOption(for: "@"),
                self.inputOption(for: "#"),
                self.inputOption(for: "&"),
                self.inputOption(for: "_") ],
            [
                self.inputOption(for: ":"),
                self.inputOption(for: "/"),
                self.inputOption(for: "\\"),
                self.inputOption(for: "?"),
                self.inputOption(for: "|") ]
        ]
    }
    
    override var inputAccessoryView: UIView? {
        return self.shouldShowExtendedBar ? self.extendedBar : nil
    }
    
    func newExtendedBar() -> OptionalButtonsBar {
        let bounds = self.view.bounds
        let height: CGFloat = UIDevice.current.isPhone ? 58 : 72
        let bar = OptionalButtonsBar(frame: CGRect(x: 0, y: 0, width: bounds.width, height: height))
        bar.autoresizingMask = [.flexibleWidth]
        bar.setButtons(with: self.buttons)
        bar.backgroundColor = UIColor(white: 0.860, alpha: 1)
        
        return bar
    }
}
