//
//  VimViewController+ExtendedKeyboard.swift
//  iVim
//
//  Created by Terry on 7/19/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

extension VimViewController {
//    private func inputOption(for key: String) -> ButtonOption {
//        return ButtonOption(title: key, action: { _ in self.insertText(key) })
//    }
    
//    private func keyOption(for title: String, key: Int32) -> ButtonOption {
//        return ButtonOption(title: title, action: { _ in self.insertText(key.unicoded) })
//    }
    
//    private func feedKeysOption(for title: String, keys: String) -> ButtonOption {
//        return ButtonOption(title: title, action: { _ in gFeedKeys(keys) })
//    }
    
//    private func markedTextConflictOption(for title: String, action: Action?) -> ButtonOption {
//        return ButtonOption(title: title, action: { b in
//        })
//    }
    
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
    
//    func press(modifiedText: String, action: () -> Void) {
//        if self.handleModifiers(with: modifiedText) { return }
//        action()
//    }
    
//    private var buttons: [[ButtonOption]] {
//        return [
//            [
//                ButtonOption(title: "esc", action: { _ in
//                    self.press(modifiedText: "Esc", action: self.pressESC)
//                }),
//                ButtonOption(title: "ctrl", action: { b in
//                    guard self.ctrlButton != b else { return }
//                    self.ctrlButton = b
//                }, isSticky: true)],
//            [
//                ButtonOption(title: "tab", action: { _ in self.press(modifiedText: "Tab") { self.insertText(keyTAB.unicoded) } }),
//                ButtonOption(title: "↓", action: { _ in self.press(modifiedText: "Down") { self.pressArrow(keyDOWN) } }),
//                ButtonOption(title: "←", action: { _ in self.press(modifiedText: "Left") { self.pressArrow(keyLEFT) } }),
//                ButtonOption(title: "→", action: { _ in self.press(modifiedText: "Right") { self.pressArrow(keyRIGHT) } }),
//                ButtonOption(title: "↑", action: { _ in self.press(modifiedText: "Up") { self.pressArrow(keyUP) } }) ],
//            [
//                self.inputOption(for: "0"),
//                self.inputOption(for: "1"),
//                self.inputOption(for: "2"),
//                self.inputOption(for: "3"),
//                self.inputOption(for: "4") ],
//            [
//                self.inputOption(for: "5"),
//                self.inputOption(for: "6"),
//                self.inputOption(for: "7"),
//                self.inputOption(for: "8"),
//                self.inputOption(for: "9") ],
//            [
//                self.inputOption(for: "="),
//                self.inputOption(for: "+"),
//                self.inputOption(for: "-"),
//                self.inputOption(for: "*"),
//                self.inputOption(for: "%") ],
//            [
//                self.inputOption(for: ","),
//                self.inputOption(for: "("),
//                self.inputOption(for: ")"),
//                self.inputOption(for: "<"),
//                self.inputOption(for: ">") ],
//            [
//                self.inputOption(for: "."),
//                self.inputOption(for: "{"),
//                self.inputOption(for: "}"),
//                self.inputOption(for: "["),
//                self.inputOption(for: "]") ],
//            [
//                self.inputOption(for: ";"),
//                self.inputOption(for: "'"),
//                self.inputOption(for: "\""),
//                self.inputOption(for: "^"),
//                self.inputOption(for: "$") ],
//            [
//                self.inputOption(for: "!"),
//                self.inputOption(for: "@"),
//                self.inputOption(for: "#"),
//                self.inputOption(for: "&"),
//                self.inputOption(for: "_") ],
//            [
//                self.inputOption(for: ":"),
//                self.inputOption(for: "/"),
//                self.inputOption(for: "\\"),
//                self.inputOption(for: "?"),
//                self.inputOption(for: "|") ]
//        ]
//    }
    
    override var inputAccessoryView: UIView? {
        return self.shouldShowExtendedBar ?
            ExtendedKeyboardManager.shared.extendedBar : nil
    }
    
//    func newExtendedBar() -> OptionalButtonsBar {
//        let bounds = self.view.bounds
//        let height: CGFloat = UIDevice.current.isPhone ? 58 : 72
//        let bar = OptionalButtonsBar(frame: CGRect(x: 0, y: 0, width: bounds.width, height: height))
//        bar.autoresizingMask = [.flexibleWidth]
//        bar.setButtons(with: self.buttons)
//        bar.backgroundColor = UIColor(white: 0.860, alpha: 1)
//
//        return bar
//    }
}
