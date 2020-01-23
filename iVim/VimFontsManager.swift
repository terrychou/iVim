//
//  VimFontsManager.swift
//  iVim
//
//  Created by Terry on 5/9/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

extension FileManager {
    func url(for subdirectoryName: String?,
             under parentSearchPathDirectory: SearchPathDirectory,
             in parentSearchPathDomain: SearchPathDomainMask = .userDomainMask) -> URL? {
        do {
            let parent = try self.url(
                for: parentSearchPathDirectory,
                in: parentSearchPathDomain,
                appropriateFor: nil,
                create: true)
            let path: URL
            if let subname = subdirectoryName {
                path = parent.appendingPathComponent(subname)
            } else {
                path = parent
            }
            return try self.createDirectoryIfNecessary(path)
        } catch {
            return nil
        }
    }
    
    func createDirectoryIfNecessary(_ url: URL) throws -> URL {
        if !self.fileExists(atPath: url.path) {
            try self.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        return url
    }
}

private let userFontsURL: URL? = FileManager.default.url(for: "Fonts", under: .libraryDirectory)
private let defaultFontSize = CGFloat(14)
private let systemFontsFile = "systemFonts"

let gFM = VimFontsManager.shared

final class VimFontsManager: NSObject {
    @objc static let shared = VimFontsManager()
    private override init() {
        super.init()
        self.registerFonts()
    }
    
    var name = ""
    var size = defaultFontSize
    var fonts = [FontInfo]()
    var cache = [String: FontCache]()
}

extension VimFontsManager {
    private func registerSystemFonts() {
        guard let url = Bundle.main.url(forResource: systemFontsFile, withExtension: "plist"),
            let names = NSArray(contentsOf: url) as? [String] else { return }
        for n in names {
            let i = FontInfo(name: n, type: .system)
            self.fonts.append(i)
            self.cache[n] = FontCache(postScriptName: n)
        }
        self.name = names[0]
    }
    
    private func registerUserFonts() {
        guard let path = userFontsURL else { return }
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path.path)
            for f in contents {
                let i = FontInfo(name: f, type: .user)
                self.fonts.append(i)
            }
        } catch {
            NSLog("Failed to register user fonts: \(error)")
        }
    }
    
    fileprivate func registerFonts() {
        self.registerSystemFonts()
        self.registerUserFonts()
    }
    
    private var printableAvailableFonts: String {
        var s = "Available fonts:"
        for (i, f) in self.fonts.enumerated() {
            let isCurrent = f.name == self.name
            s += "\n\t\(isCurrent ? "*" : "")\(i + 1)"
                + "\t\(f.type.abrivation)"
                + "\t\(f.name)"
                + "\(isCurrent ? "\t\(self.size)" : "")"
        }
        
        return s
    }
    
    @objc func showAvailableFonts(withCommand cmd: String?) {
        gSVO.showContent(self.printableAvailableFonts, withCommand: cmd)
    }
    
    private func setGUIFont(_ info: String) {
        do_cmdline_cmd("set guifont=\(info.spaceEscaped)")
    }
    
    private func infoForKey(_ key: String) -> FontInfo? {
        return self.fonts.first { $0.name.hasPrefix(key) }
    }
    
    private func infoAtIndex(_ index: Int) -> FontInfo? {
        let i = index - 1
        if i >= 0 && i < self.fonts.count {
            return self.fonts[i]
        } else {
            return nil
        }
    }
    
    private func showErrorForFontName(_ n: String) {
        let err = n.int == nil ? "matching '\(n)'" : "at index \(n)"
        gSVO.showError("Cannot find font \(err)")
    }
    
    @objc func selectFont(with arg: String) {
        let args = arg.components(separatedBy: .whitespaces)
        let size = args.count > 1 ? args[1].cgFloat : nil
        
        let n = args[0]
        let name: String?
        if n == "_" {
            name = self.name
        } else if let i = n.int {
            name = self.infoAtIndex(i)?.name
        } else {
            name = self.infoForKey(n)?.name
        }
        
        if size == self.size && (name == nil || name == self.name) {
            return
        }
        
        if name == nil && size == nil {
            self.showErrorForFontName(n)
        } else {
            let s = size != nil ? ":h\(Int(size!))" : ""
            self.setGUIFont("\(name ?? self.name)\(s)")
        }
    }
    
    @objc func deleteFont(with arg: String) {
        let info: FontInfo?
        if let i = arg.int {
            info = self.infoAtIndex(i)
        } else {
            info = self.infoForKey(arg)
        }
        guard let i = info else { return self.showErrorForFontName(arg) }
        guard i.type == .user else {
            return gSVO.showError("Font '\(i.name)' is not an user font")
        }
        self.deleteFont(with: i)
    }
    
    private func deleteFont(with info: FontInfo) {
        guard let i = self.fonts.firstIndex(where: { $0 == info }),
            let path = userFontsURL?.appendingPathComponent(info.name)
            else { return }
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            gSVO.showError("Failed to delete font '\(info.name)'")
            return
        }
        self.fonts.remove(at: i)
        if self.name == info.name { //if the deleted font was in use, change to the first font
            self.selectFont(with: "1")
        }
        self.uncacheUserFont(with: info.name)
        gSVO.showMessage("Deleted font '\(info.name)'")
    }
    
    private func uncacheUserFont(with name: String) {
        guard let url = self.cache[name]?.url else { return }
        var err: Unmanaged<CFError>?
        if !CTFontManagerUnregisterFontsForURL(url, .none, &err) {
            let e = err?.nsError
            NSLog("failed to unregister font '\(name)': " +
                "\(e?.localizedDescription ?? "unknown reason")")
        }
        self.cache[name] = nil
    }
}

extension VimFontsManager {
    private var currentPostScriptName: String {
        return self.postScriptName(for: self.name)!
    }
    
    private func parseFontInfo(_ fi: String) -> (String, CGFloat?) {
        guard let r = fi.range(of: ":h") else { return (fi, nil) }
        let n = String(fi[..<r.lowerBound])
        let s = String(fi[r.upperBound...]).cgFloat
        
        return (n, s)
    }
    
    private func fontInfo(with info: String?) -> (String, CGFloat) {
        guard let i = info else { return (self.currentPostScriptName, self.size) }
        let (n, s) = self.parseFontInfo(i)
        let postScriptName: String
        if let fn = self.postScriptName(for: n) {
            self.name = n
            postScriptName = fn
        } else {
            postScriptName = self.currentPostScriptName
        }
        if let s = s {
            self.size = s
        }
        
        return (postScriptName, self.size)
    }
    
    private func prepareUserFont(with name: String) -> String? {
        guard let fontURL = userFontsURL?.appendingPathComponent(name) else { return nil }
        let url = fontURL as CFURL
        // to overcome the CGFontCreate hanging bug:
        // http://stackoverflow.com/a/40256390/723851
        _ = UIFont()
        var err: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url, .none, &err) {
            let e = err?.nsError
            if e?.isCTFontManagerError(.alreadyRegistered) != true {
                NSLog("failed to register font '\(name)': " +
                    "\(e?.localizedDescription ?? "unknown reason")")
                return nil
            }
        }
        var ret: String?
        if let ds = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor] {
            for d in ds {
                if let n = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String {
                    ret = n
                    if n.hasSuffix("Regular") {
                        break
                    }
                }
            }
        }
        if let psName = ret {
            self.cache[name] = FontCache(postScriptName: psName,
                                         url: url)
        }
        
        return ret
    }
    
    private func postScriptName(for name: String) -> String? {
        if let cached = self.cache[name]?.postScriptName { return cached }
        guard let info = self.fonts.first(where: { $0.name == name }) else { return nil }
        
        return self.prepareUserFont(with: info.name)
    }
    
    func initializeFont(_ info: String?) -> (CTFont, CGFloat, CGFloat, CGFloat, CGFloat) {
        let (fn, fs) = self.fontInfo(with: info)
        let rawFont = CTFontCreateWithName(fn as CFString, fs, nil)
        
        var glyph = CTFontGetGlyphWithName(rawFont, "0" as CFString)
        var advances = CGSize.zero
        CTFontGetAdvancesForGlyphs(rawFont, .horizontal, &glyph, &advances, 1)
        
        let ascent = CTFontGetAscent(rawFont)
        let descent = CTFontGetDescent(rawFont)
        let leading = CTFontGetLeading(rawFont)
        let padding = CGFloat(0)
        let advances_width = advances.width
        let char_ascent = ascent + padding
        let char_width = floor(advances_width)
        let char_height = ascent + descent + leading + padding * 2
        
        let scaleX: CGFloat = char_width / advances_width
        let scaleY: CGFloat = -scaleX
        var transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        
        return (CTFontCreateCopyWithAttributes(rawFont, fs, &transform, nil),
                char_ascent, descent, char_width, char_height)
    }
}

private extension Unmanaged where Instance == CFError {
    var nsError: NSError? {
        return (self.takeRetainedValue() as Error) as NSError
    }
}

private extension NSError {
    func isCTFontManagerError(_ err: CTFontManagerError) -> Bool {
        return (self.domain == kCTFontManagerErrorDomain as String) &&
            self.code == err.rawValue
    }
}

extension VimFontsManager {
    func importFont(from url: URL?, isMoving: Bool, removeOriginIfFailed: Bool) -> Bool {
        guard let src = url, let fontsDir = userFontsURL else { return false }
        let fileName = src.lastPathComponent
        let dst = fontsDir.appendingPathComponent(fileName)
        let fm = FileManager.default
        var succeeded = false
        do {
            if isMoving {
                try fm.moveItem(at: src, to: dst)
            } else {
                if src.startAccessingSecurityScopedResource() {
                    try fm.copyItem(at: src, to: dst)
                    src.stopAccessingSecurityScopedResource()
                } else {
                    NSLog("Failed to access security scoped resource")
                }
            }
            if fm.fileExists(atPath: dst.path) {
                let fi = FontInfo(name: fileName, type: .user)
                self.fonts.append(fi)
                succeeded = true
            } else {
                NSLog("failed to find font file '\(fileName)' after its manipulation")
            }
        } catch {
            NSLog("failed to \(isMoving ? "MOVE" : "COPY") font: \(error)")
        }
        if succeeded {
            gSVO.showMessage("Imported font \\\"\(fileName)\\\"")
        } else {
            if removeOriginIfFailed {
                do {
                    try fm.removeItem(at: src)
                } catch {
                    NSLog("Failed to delete font: \(error)")
                }
            }
            gSVO.showError("Failed to import font \\\"\(fileName)\\\"")
        }
        
        return succeeded
    }
}

enum FontType {
    case system
    case user
    
    var abrivation: String {
        switch self {
        case .system: return "s"
        case .user: return "u"
        }
    }
}

struct FontInfo {
    let name: String
    let type: FontType
}

func ==(lfi: FontInfo, rfi: FontInfo) -> Bool {
    return lfi.type == rfi.type && lfi.name == rfi.name
}

struct FontCache {
    let postScriptName: String
    let url: CFURL?
    
    init(postScriptName: String, url: CFURL? = nil) {
        self.postScriptName = postScriptName
        self.url = url
    }
}

extension String {
    private var number: NSNumber? {
        return NumberFormatter().number(from: self)
    }
    
    var cgFloat: CGFloat? {
        return self.number.flatMap { CGFloat(truncating: $0) }
    }
    
    var int: Int? {
        return self.number as? Int
    }
}

extension URL {
    var isSupportedFont: Bool {
        switch self.pathExtension {
        case "ttf", "otf", "ttc": return true
        default: return false
        }
    }
}
