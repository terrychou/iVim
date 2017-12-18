//
//  VimViewController+UITextInput.swift
//  iVim
//
//  Created by Terry on 5/31/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

private let kUDDictationNormalModeTarget = "kUDDictationNormalModeTarget"

extension VimViewController {
    private var currentText: String? {
        return self.markedInfo?.text
    }
    
    private var currentTextLength: Int {
        return self.currentText?.nsLength ?? 0
    }
    
    func text(in range: UITextRange) -> String? {
        //print(#function)
        if self.isInDictation { return self.dictationHypothesis }
        guard let range = range as? VimTextRange else { return nil }
        
        return self.currentText?.nsstring.substring(with: range.nsrange)
    }
    
    func replace(_ range: UITextRange, withText text: String) {
        //print(#function)
        self.updateDictationHypothesis(with: text)
    }
    
    var selectedTextRange: UITextRange? {
        get {
            //print(#function)
            return VimTextRange(range: self.markedInfo?.selectedRange)
        }
        set {
            //print(#function)
            guard let nv = newValue as? VimTextRange else { return }
            self.markedInfo?.selectedRange = nv.nsrange
        }
    }
    
    var markedTextRange: UITextRange? {
        //print(#function)
        return self.markedInfo?.range
    }
    
    var markedTextStyle: [AnyHashable : Any]? {
        get { return nil }
        set { return }
    }
    
    private func handleNormalMode(_ text: String?) -> Bool {
        guard let text = text, !text.isEmpty else { return true }
        guard !self.isNormalPending else { return false }
        if !self.handleModifiers(with: text) {
            gAddNonCSITextToInputBuffer(self.escapingText(text))
            switch text {
            case "f", "F", "t", "T", "r": self.isNormalPending = true
            default: break
            }
        }
        self.resetKeyboard()
        
        return true
    }
    
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        //print(#function)
        if is_in_normal_mode() && self.handleNormalMode(markedText) {
            return
        }
        if self.markedInfo == nil {
            self.markedInfo = MarkedInfo()
            self.becomeFirstResponder()
        }
        self.markedInfo?.didGetMarkedText(markedText, selectedRange: selectedRange, pending: self.isNormalPending)
        self.flush()
        self.markNeedsDisplay()
    }
    
    func unmarkText() {
        //print(#function)
        guard let info = self.markedInfo else { return }
        if self.isNormalPending {
            gAddNonCSITextToInputBuffer(info.text)
            self.isNormalPending = false
        }
        self.markedInfo?.didUnmark()
        self.markedInfo = nil
    }
    
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        //print(#function)
        guard let fp = fromPosition as? VimTextPosition,
            let tp = toPosition as? VimTextPosition else { return nil }

        return VimTextRange(start: fp, end: tp)
    }
    
    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        //print(#function)
        guard let p = position as? VimTextPosition else { return nil }
        let loc = p.location
        let new = loc + offset
        guard new >= 0 && new <= self.currentTextLength else { return nil }
        
        return VimTextPosition(location: new)
    }
    
    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        //print(#function)
        let newOffset: Int
        switch direction {
        case .left, .up: newOffset = offset
        case .right, .down: newOffset = -offset
        }
        
        return self.position(from: position, offset: newOffset)
    }
    
    var beginningOfDocument: UITextPosition {
        //print(#function)
        return VimTextPosition(location: 0)
    }
    
    var endOfDocument: UITextPosition {
        //print(#function)
        return VimTextPosition(location: self.currentTextLength)
    }
    
    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        //print(#function)
        let lhp = (position as? VimTextPosition)?.location
        let rhp = (other as? VimTextPosition)?.location
        guard lhp != rhp else { return .orderedSame }
        if lhp == nil {
            return .orderedAscending
        } else if rhp == nil {
            return .orderedDescending
        } else if lhp! < rhp! {
            return .orderedAscending
        } else {
            return .orderedDescending
        }
    }
    
    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        //print(#function)
        guard let fp = from as? VimTextPosition,
            let tp = toPosition as? VimTextPosition else { return 0 }
        
        return tp.location - fp.location
    }
    
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        //print(#function)
        guard let vtr = range as? VimTextRange else { return nil }
        let r = vtr.nsrange
        let newLoc: Int
        switch direction {
        case .up, .left: newLoc = r.location
        case .down, .right: newLoc = r.location + r.length
        }
        
        return VimTextPosition(location: newLoc)
    }
    
    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        //print(#function)
        guard let p = position as? VimTextPosition else { return nil }
        let oldLoc = p.location
        let newLoc: Int
        switch direction {
        case .up, .left: newLoc = oldLoc - 1
        case .down, .right: newLoc = oldLoc
        }
        
        return VimTextRange(location: newLoc, length: 1)
    }
    
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> UITextWritingDirection {
        //print(#function)
        return .leftToRight
    }
    
    func setBaseWritingDirection(_ writingDirection: UITextWritingDirection, for range: UITextRange) {
        //print(#function)
        return
    }
    
    func firstRect(for range: UITextRange) -> CGRect {
        //print(#function)
        return .zero
    }
    
    func caretRect(for position: UITextPosition) -> CGRect {
        //print(#function)
        return .zero
    }
    
    func closestPosition(to point: CGPoint) -> UITextPosition? {
        //print(#function)
        return nil
    }
    
    func selectionRects(for range: UITextRange) -> [Any] {
        //print(#function)
        return []
    }
    
    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        //print(#function)
        return nil
    }
    
    func characterRange(at point: CGPoint) -> UITextRange? {
        //print(#function)
        return nil
    }
    
    var inputDelegate: UITextInputDelegate? {
        get { return nil }
        set { return }
    }
    
    var tokenizer: UITextInputTokenizer {
        //print(#function)
        return self.textTokenizer
    }
    
    var textInputView: UIView {
        //print(#function)
        return self.vimView!
    }
    
    func cancelCurrentMarkedText() {
        self.markedInfo?.cancelled = true
        self.resetKeyboard()
    }
}

extension VimViewController {
    private enum DictationNormalModeTarget: String {
        case insert
        case cmdline
        case none
    }
    
    private var normalModeTarget: DictationNormalModeTarget {
        guard let v = UserDefaults.standard.string(
            forKey: kUDDictationNormalModeTarget) else { return .insert }
        
        return DictationNormalModeTarget(rawValue: v)!
    }
    
    private func shouldGoOnAfterHandlingDictationInNormalMode() -> Bool {
        guard is_in_normal_mode() else { return true }
        var jumpCmd: String?
        switch self.normalModeTarget {
        case .insert: jumpCmd = "i"
        case .cmdline: jumpCmd = ":"
        case .none: break
        }
        if let jc = jumpCmd {
            gFeedKeys(jc, mode: "n")
            return true
        } else {
            return false
        }
    }
    
    private var isInDictation: Bool {
        return self.dictationHypothesis != nil ||
            (self.textInputMode?.primaryLanguage?.hasPrefix("dictation") ?? false)
    }
    
    private func inputTextWithoutMapping(_ text: String) {
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        gFeedKeys(escaped, mode: "n")
    }
    
    private func updateDictationHypothesis(with text: String) {
        guard self.isInDictation else { return }
        self.cleanupDictationHypothesis(andSet: text)
        if self.shouldGoOnAfterHandlingDictationInNormalMode() {
            self.inputTextWithoutMapping(text)
        }
    }
    
    func cleanupDictationHypothesis(andSet text: String? = nil) {
        if let len = self.dictationHypothesis?.nsLength,
            !is_in_normal_mode() {
            gFeedKeys("\\<BS>", for: len, mode: "n")
        }
        self.dictationHypothesis = text
    }
    
    func insertDictationResult(_ dictationResult: [UIDictationPhrase]) {
        if self.dictationHypothesis == nil { return } //do nothing if cancelled
        guard !dictationResult.isEmpty else { return }
        let text = dictationResult.map { $0.text }.joined()
        self.cleanupDictationHypothesis()
        if !is_in_normal_mode() {
            self.inputTextWithoutMapping(text)
        } else {
            gAddNonCSITextToInputBuffer(text.trimmingCharacters(in: .whitespaces))
        }
    }
    
    func dictationRecordingDidEnd() {
//        NSLog("dictation END")
    }
    
    func dictationRecognitionFailed() {
//        NSLog("dictation FAILED")
        self.cleanupDictationHypothesis()
        DispatchQueue.main.async {
            gSVO.showErrContent("dictation FAILED")
        }
    }
    
    var insertDictationResultPlaceholder: Any {
        return 1
    }
    
    func removeDictationResultPlaceholder(_ placeholder: Any, willInsertResult: Bool) {
        //this method is needed for preventing unclear whitespaces from being inserted
        return
    }
}

class VimTextPosition: UITextPosition {
    var location: Int
    
    init(location: Int) {
        self.location = location
        super.init()
    }
    
    convenience init(position: VimTextPosition) {
        self.init(location: position.location)
    }
}

class VimTextRange: UITextRange {
    var location: Int
    var length: Int
    
    init?(location: Int, length: Int) {
        guard location >= 0 && length >= 0 else { return nil }
        self.location = location
        self.length = length
        super.init()
    }
    
    convenience init?(range: NSRange?) {
        guard let r = range else { return nil }
        self.init(location: r.location, length: r.length)
    }
    
    convenience init?(start: VimTextPosition, end: VimTextPosition) {
        self.init(location: start.location, length: end.location - start.location)
    }
    
    override var start: UITextPosition {
        return VimTextPosition(location: self.location)
    }
    
    override var end: UITextPosition {
        return VimTextPosition(location: self.location + self.length)
    }
    
    override var isEmpty: Bool {
        return self.length == 0
    }
    
    var nsrange: NSRange {
        return NSMakeRange(self.location, self.length)
    }
}

struct MarkedInfo {
    var selectedRange = NSMakeRange(0, 0)
    var text = ""
    var cancelled = false
}

extension MarkedInfo {
    var range: VimTextRange {
        return VimTextRange(location: 0, length: self.text.nsLength)!
    }
    
    private func deleteBackward(for times: Int) {
        gFeedKeys("\\<BS>", for: times, mode: "n")
//        gAddTextToInputBuffer(keyBS.unicoded, for: times)
//        for _ in 0..<times {
//            input_special_key(keyBS)
//        }
    }
    
    func deleteOldMarkedText() {
        guard !self.text.isEmpty else { return }
        let oldLen = self.text.nsLength
        let offset = oldLen - self.selectedRange.location
        move_cursor_right(offset)
        self.deleteBackward(for: oldLen)
    }
    
    mutating func didGetMarkedText(_ text: String?, selectedRange: NSRange, pending: Bool) {
        guard let text = text else { return }
        if !pending {
            self.deleteOldMarkedText()
            gAddNonCSITextToInputBuffer(text)
            let offset = text.nsLength - selectedRange.location
            move_cursor_left(offset)
        }
        self.text = text
        self.selectedRange = selectedRange
    }
    
    mutating func didUnmark() {
        guard self.cancelled else { return }
        self.deleteOldMarkedText()
        self.cancelled = false
    }
}
