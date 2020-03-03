//
//  VimViewBackend.swift
//  iVim
//
//  Created by Terry Chou on 2018/9/17.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import UIKit

typealias VimColor = UInt32

private extension NSAttributedString.Key {
    static let foregroundColorFromContext = NSAttributedString.Key(
        kCTForegroundColorFromContextAttributeName as String)
}

private extension CTFont {    
    func copy(with traits: CTFontSymbolicTraits) -> CTFont? {
        return CTFontCreateCopyWithSymbolicTraits(
            self, 0.0, nil, traits, traits)
    }
}

extension VimView {
    typealias StringAttributes = [NSAttributedString.Key: Any]
    
    @objc func setFgColor(_ color: VimColor) {
        self.fgColor = color
    }
    
    @objc func setBgColor(_ color: VimColor) {
        self.bgColor = color
    }
    
    @objc func setSpecialColor(_ color: VimColor) {
        self.spColor = color
    }
    
    private typealias DrawTask = (CGContext) -> CGRect
    private func draw(_ task: DrawTask) {
        self.ctx.saveGState()
        let rect = task(self.ctx)
        self.ctx.restoreGState()
        self.markRectNeedsDisplay(rect)
    }
    
    @objc func fillAll(with color: VimColor) {
        self.fillRect(self.bounds, with: color)
    }
    
    @objc func fillRect(_ rect: CGRect, with color: VimColor) {
        self.draw { ctx in
            ctx.setFillVimColor(color)
            ctx.fill(rect)
            
            return rect
        }
    }
    
    @objc func strokeRect(_ rect: CGRect, with color: VimColor) {
//        print("stroke rect", rect, color)
        self.draw { ctx in
            ctx.setStrokeVimColor(color)
            ctx.stroke(rect)
            
            return rect
        }
    }
    
    private struct Flags: OptionSet {
        let rawValue: UInt8
        
        static let transparent = Flags(rawValue: 1)
        static let bold = Flags(rawValue: 2)
        static let underline = Flags(rawValue: 4)
        static let undercurl = Flags(rawValue: 8)
        static let italic = Flags(rawValue: 16)
        static let cursor = Flags(rawValue: 32)
        static let strikethrough = Flags(rawValue: 64)
    }
    
    private func font(for flags: inout Flags) -> CTFont {
        var ret = self.font!
        var traits: CTFontSymbolicTraits = []
        if flags.contains(.bold) {
            traits.formUnion(.traitBold)
        }
        if flags.contains(.italic) {
            traits.formUnion(.traitItalic)
        }
        if traits != [] {
            if let ef = self.fontCache[traits] {
                ret = ef
            } else if let n = ret.copy(with: traits) {
                ret = n
                self.fontCache[traits] = n
            } else if flags.contains(.italic) {
                // use underline if italic not available
                flags.formUnion(.underline)
            }
//            } else {
//                NSLog("failed to get font with traits \(traits)")
//            }
        }
        
        return ret
    }
    
    @objc func drawString(_ string: NSString,
                          pos_x: CGFloat, pos_y: CGFloat,
                          rect: CGRect, p_antialias: Bool,
                          flags: UInt8) {
//        NSLog("draw '\(string)' at \(rect)")
        var f = Flags(rawValue: flags)
        self.draw { ctx in
            if !f.contains(.transparent) {
                ctx.setFillVimColor(self.bgColor)
                ctx.fill(rect)
            }
            ctx.setShouldAntialias(p_antialias)
            ctx.setAllowsAntialiasing(p_antialias)
            ctx.setShouldSmoothFonts(p_antialias)
            ctx.setCharacterSpacing(0)
            ctx.setTextDrawingMode(.fill)
            ctx.setFillVimColor(self.fgColor)
            let range = NSMakeRange(0, string.length)
            var offset = CGFloat(0)
            var totalCells = 0
            let attr: StringAttributes = [
                .font: self.font(for: &f),
                .foregroundColorFromContext: true,
            ]
            string.enumerateSubstrings(
                in: range,
                options: .byComposedCharacterSequences) { (c, _, _, _) in
                    guard let c = c else { return }
                    let a = NSAttributedString(string: c,
                                               attributes: attr)
                    let l = CTLineCreateWithAttributedString(a)
                    ctx.textPosition = CGPoint(x: pos_x + offset,
                                               y: pos_y)
                    CTLineDraw(l, ctx)
                    let cells = cells_for_character(c)
                    totalCells += Int(cells)
                    offset += CGFloat(cells) * self.char_width
            }
            
            if f.contains(.underline) {
                self.drawUnderline(x: pos_x,
                                   y: pos_y,
                                   cells: totalCells,
                                   in: ctx)
            } else if f.contains(.undercurl) {
                self.drawUndercurl(x: pos_x,
                                   y: pos_y,
                                   cells: totalCells,
                                   in: ctx)
            }
            
//            if f.contains(.cursor) {
//                NSLog("draw cursor \(self.fgColor)")
//                ctx.setBlendMode(.difference)
//                ctx.fill(rect)
//            }
            
            return rect
        }
    }
    
    private func drawUnderline(x: CGFloat, y: CGFloat,
                               cells: Int, in ctx: CGContext) {
        let rect = CGRect(x: x,
                          y: y + 0.4 * self.char_descent,
                          width: CGFloat(cells) * self.char_width,
                          height: 1)
        ctx.setFillVimColor(self.spColor)
        ctx.fill(rect)
    }
    
    private func drawUndercurl(x: CGFloat, y: CGFloat,
                               cells: Int, in ctx: CGContext) {
        var x = x
        let y = y + 1
        let w = self.char_width
        let h = 0.5 * self.char_descent
        ctx.move(to: CGPoint(x: x, y: y))
        for _ in 0..<cells {
            ctx.addCurve(
                to: CGPoint(x: x + 0.5 * w, y: y + h),
                control1: CGPoint(x: x + 0.25 * w, y: y),
                control2: CGPoint(x: x + 0.25 * w, y: y + h))
            ctx.addCurve(
                to: CGPoint(x: x + w, y: y),
                control1: CGPoint(x: x + 0.75 * w, y: y + h),
                control2: CGPoint(x: x + 0.75 * w, y: y))
            x += w
        }
        ctx.setStrokeVimColor(self.spColor)
        ctx.strokePath()
    }
    
    @objc func copyRect(from src: CGRect, to target: CGRect) {
//        NSLog("copy rect \(src) \(target)")
        self.draw { ctx in
            var image: CGImage?
            ctx.saveGState()
            image = ctx.makeImage()
            ctx.restoreGState()
            guard let img = image else { return .zero }
            var rect = self.bufferBounds
            rect.origin.x = target.origin.x - src.origin.x
            rect.origin.y = target.origin.y - src.origin.y
            
            ctx.clip(to: target)
            ctx.setBlendMode(.copy)
            ctx.draw(img, in: rect)
            
            return target
        }
    }
}

private extension CGContext {
    func setFillVimColor(_ color: VimColor) {
        self.setFillColor(red: color.red,
                          green: color.green,
                          blue: color.blue,
                          alpha: color.alpha)
    }
    
    func setStrokeVimColor(_ color: VimColor) {
        self.setStrokeColor(red: color.red,
                            green: color.green,
                            blue: color.blue,
                            alpha: color.alpha)
    }
}

extension VimColor {
    private func colorComponent(byShifting bits: UInt8) -> CGFloat {
        return CGFloat((self >> bits) & 0xff) / 255.0
    }
    
    var red: CGFloat {
        return self.colorComponent(byShifting: 16)
    }
    
    var green: CGFloat {
        return self.colorComponent(byShifting: 8)
    }
    
    var blue: CGFloat {
        return self.colorComponent(byShifting: 0)
    }
    
    var alpha: CGFloat {
        return 1.0
    }
}
