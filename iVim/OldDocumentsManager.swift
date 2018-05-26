//
//  OldDocumentsManager.swift
//  iVim
//
//  Created by Terry Chou on 2018/5/22.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import UIKit
import CoreData

let gODM = OldDocumentsManager.shared
private let oldDocsLimit = 100
private typealias IndexedDocument = (Int, OldDocument)
private typealias EnumerateTask = (IndexedDocument) -> Bool //return true to stop the enumeration

final class OldDocumentsManager: NSObject {
    @objc static let shared = OldDocumentsManager()
    private override init() {
        super.init()
        self.setup()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private let context = gCDS.context
    private var documents = [OldDocument]()
}

extension OldDocumentsManager {
    private var fetchRequest: NSFetchRequest<OldDocument> {
        return OldDocument.fetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "modifiedAt", ascending: false)])
    }
    
    private func initOldDocuments() {
        let request = self.fetchRequest
        do {
            self.documents = try self.context.fetch(request: request)
        } catch {
            NSLog("failed to fetch old documents: \(error)")
        }
    }
    
    private func setup() {
        self.registerNotifications()
        self.initOldDocuments()
    }
    
    private func registerNotifications() {
        let nfc = NotificationCenter.default
        nfc.addObserver(self,
                        selector: #selector(self.willResignActive),
                        name: .UIApplicationWillResignActive,
                        object: nil)
    }
    
    @objc func willResignActive() {
        self.wrapUp()
    }
    
    @objc func wrapUp() {
        self.trimDocuments()
        self.save()
    }
    
    private func trimDocuments() {
        let count = self.documents.count
        guard count > oldDocsLimit else { return }
        self.removeEntries(at: Array(oldDocsLimit..<count))
    }
}

extension OldDocumentsManager {
    func save() {
        do {
            try self.context.saveIfChanged()
        } catch {
            NSLog("failed to save old documents: \(error)")
        }
    }
    
    func addURL(_ url: URL) {
        let index = self.documents.index { $0.path == url.path }
        let top: OldDocument
        if let i = index { //existing one
            top = self.documents.remove(at: i)
        } else { //new one
            top = self.context.insertNew(OldDocument.self)
            top.path = url.path
            top.bookmark = url.bookmark
        }
        top.touch() //update the modification date
        self.documents.insert(top, at: 0) //move it to top
    }
    
    private func removeEntries(at indexes: [Int], save: Bool = false) {
        for i in indexes.sorted(by: >) {
            self.documents.remove(at: i).delete()
        }
        if save {
            self.save()
        }
    }
    
    func showOldDocuments(for pattern: String? = nil,
                          ignoreCase: Bool = false,
                          negate: Bool = false,
                          onlyFirst: Bool = false) {
        gSVO.showContent(self.printableDocuments(for: pattern,
                                                 ignoreCase: ignoreCase,
                                                 negate: negate,
                                                 onlyFirst: onlyFirst),
                         withCommand: nil)
    }
    
    private func showErr(operation: String, message: String) {
        let op = operation.isEmpty ? "" : ":\(operation)"
        gSVO.showError("[old docs\(op)] \(message)")
    }
    
    private var upperBound: Int {
        return min(self.documents.count, oldDocsLimit)
    }
    
    private func realEnumerate(matcher: ((String?) -> Bool)? = nil,
                               negate: Bool,
                               task: EnumerateTask) {
        for i in 0..<self.upperBound {
            let doc = self.documents[i]
            if let m = matcher,
                negate == m(doc.path) { //negate ? m(doc.path) : !m(doc.path)
                continue
            }
            if task((i, doc)) {
                break
            }
        }
    }
    
    private func enumerate(pattern: String?,
                           ignoreCase: Bool,
                           negate: Bool,
                           task: @escaping EnumerateTask) {
        if let p = pattern {
            ivim_match_regex(p, ignoreCase) {
                self.realEnumerate(matcher: $0!,
                                   negate: negate,
                                   task: task)
            }
        } else {
            self.realEnumerate(negate: negate,
                               task: task)
        }
    }
    
    private func printableDocuments(for pattern: String?,
                                    ignoreCase: Bool,
                                    negate: Bool,
                                    onlyFirst: Bool) -> String {
        var result = ""
        self.enumerate(pattern: pattern,
                       ignoreCase: ignoreCase,
                       negate: negate) { i, doc in
            result += "\(i + 1): \(doc.path)\n"
            return onlyFirst
        }
        
        return result
    }
    
    private func openDocument(at i: Int) {
        guard (0..<self.upperBound).contains(i) else {
            self.showErr(operation: "open",
                         message: "invalid document number \(i + 1)")
            return
        }
        let od = self.documents[i]
        let eurl = URL(fileURLWithPath: od.path)
        let url = gPIM.hasEntry(for: eurl) ?
            eurl : od.bookmark?.resolvedURL
        guard let u = url else {
            self.showErr(operation: "open",
                         message: "failed to open document at \(eurl)")
            return
        }
        gPIM.addPickInfo(for: u) {
            gSVO.openFile(at: $0)
        }
        od.path = u.path //update the path no matter what
        self.addURL(u) //move it to first
    }
    
    /*
     * Handle the case when the arguments are integer indexes
     *
     * It will open target documents, or delete them when *bang*
     *
     * return false if the first argument is not integer, meaning
     * arguments are not handled here.
     */
    private func handleIndexes(from arg: String, bang: Bool) -> Bool {
        let cps = arg.components(separatedBy: .whitespaces)
        guard let fa = cps.first, Int(fa) != nil else {
            return false
        }
        var invalidIndexes = ""
        var toRemove = [Int]()
        for a in cps {
            if let i = Int(a) {
                if !bang { //open
                    self.openDocument(at: i - 1)
                } else { //remove
                    toRemove.append(i - 1)
                }
            } else {
                invalidIndexes += a + ", "
            }
        }
        if toRemove.count > 0 {
            self.removeEntries(at: toRemove, save: true)
        }
        if !invalidIndexes.isEmpty {
            self.showErr(operation: bang ? "remove" : "open",
                         message: "invalid document index(es): \(invalidIndexes.dropLast(2))")
        }
        
        return true
    }
    
    /*
     * Handle the case when the argument is a regex pattern
     *
     * It uses the vim regex pattern to filter the old documents
     * entries. When there is no flags given, it will only try and
     * match the first entry and stop. And the operation for it is
     * to open the document.
     *
     * When *bang*, it will remove the matched entries.
     *
     * There are several flags (not in vim) will change the behavior
     * if present:
     *    1. g: it means to match all entries and treat all the matched as
     *    the arguments
     *    2. p: it means, rather than open or remove the target, to print
     *    all the matched entries. *bang* will stop working when it
     *    presents
     *    3. i: it will ignore case for the pattern
     *    4. n: it treats entries NOT match pattern as the arguments
     * Note that repetitive or invalid flags will be ignored
     *
     * An error shows when the given pattern is invalid.
     *
     * return false if the argument is not handled by it
     */
    private func handlePattern(from arg: String, bang: Bool) -> Bool {
        guard let pat = get_pattern_from_line(arg) else {
            self.showErr(operation: bang ? "remove" : "open",
                         message: "invalid pattern")
            return false
        }
        let flagStr = arg.removingPrefixPattern(pat)
        let flags = OldDocumentPatternFlags(flagStr)
        let onlyFirst = !flags.contains(.global)
        let ignoreCase = flags.contains(.ignorecase)
        let negate = flags.contains(.negate)
        if flags.contains(.print) { //do printing and return
            self.showOldDocuments(for: pat,
                                  ignoreCase: ignoreCase,
                                  negate: negate,
                                  onlyFirst: onlyFirst)
            return true
        }
        if !bang { //open document(s)
            self.enumerate(pattern: pat,
                           ignoreCase: ignoreCase,
                           negate: negate) { i, _ in
                self.openDocument(at: i)
                return onlyFirst
            }
        } else { //remove documents
            var toRemove = [Int]()
            self.enumerate(pattern: pat,
                           ignoreCase: ignoreCase,
                           negate: negate) { i, _ in
                toRemove.append(i)
                return onlyFirst
            }
            self.removeEntries(at: toRemove, save: true)
        }
        
//        NSLog("flags string: \(flagStr)")
//        NSLog("flags: \(flags)")
        
        return true
    }
    
    @objc func runCommand(with argument: String, bang: Bool) {
        guard !argument.isEmpty else {
            self.showOldDocuments()
            return
        }
        if self.handleIndexes(from: argument, bang: bang) {
            return
        }
        if self.handlePattern(from: argument, bang: bang) {
            return
        }
    }
}

private struct OldDocumentPatternFlags: OptionSet {
    let rawValue: Int
    
    static let global = OldDocumentPatternFlags(rawValue: 1 << 0)
    static let print = OldDocumentPatternFlags(rawValue: 1 << 1)
    static let ignorecase = OldDocumentPatternFlags(rawValue: 1 << 2)
    static let negate = OldDocumentPatternFlags(rawValue: 1 << 3)
}

private extension OldDocumentPatternFlags {
    init(_ string: String) {
        var flags: OldDocumentPatternFlags = []
        for c in string {
            switch c {
            case "g": flags.insert(.global)
            case "p": flags.insert(.print)
            case "i": flags.insert(.ignorecase)
            case "n": flags.insert(.negate)
            default: break
            }
        }
        self = flags
    }
}

private extension String {
    func removingPrefixPattern(_ pat: String) -> String {
        guard let range = self.range(of: pat) else { return self }
        let dlen = self.distance(from: self.startIndex,
                                 to: range.lowerBound)
        let i = self.index(range.upperBound, offsetBy: dlen)
        
        return String(self[i...])
    }
}
