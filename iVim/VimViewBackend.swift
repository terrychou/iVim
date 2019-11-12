//
//  VimViewBackend.swift
//  iVim
//
//  Created by Terry Chou on 2018/9/17.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import UIKit

typealias VimColor = UInt32

extension NSAttributedString.Key {
    static let foregroundColorFromContext = NSAttributedString.Key(
        kCTForegroundColorFromContextAttributeName as String)
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
    
    @objc func fillAll(with color: VimColor) {
        self.fillRect(self.bounds, with: color)
    }
    
    @objc func fillRect(_ rect: CGRect, with color: VimColor) {
        self.ctx.saveGState()
        self.ctx.setFillVimColor(color)
        self.ctx.fill(rect)
        self.ctx.restoreGState()
        self.markRectNeedsDisplay(rect)
    }
    
    @objc func strokeRect(_ rect: CGRect, with color: VimColor) {
//        print("stroke rect", rect, color)
        self.ctx.saveGState()
        self.ctx.setStrokeVimColor(color)
        self.ctx.stroke(rect)
        self.ctx.restoreGState()
        self.markRectNeedsDisplay(rect)
    }
    
    @objc func drawString(_ string: NSString,
                          pos_x: CGFloat, pos_y: CGFloat,
                          rect: CGRect, p_antialias: Bool,
                          transparent: Bool, underline: Bool,
                          undercurl: Bool, cursor: Bool) {
//        NSLog("draw '\(string)' at \(rect)")
        self.ctx.saveGState()
        if !transparent {
            self.ctx.setFillVimColor(self.bgColor)
            self.ctx.fill(rect)
        }
        self.ctx.setShouldAntialias(p_antialias)
        self.ctx.setAllowsAntialiasing(p_antialias)
        self.ctx.setShouldSmoothFonts(p_antialias)
        self.ctx.setCharacterSpacing(0)
        self.ctx.setTextDrawingMode(.fill)
        self.ctx.setFillVimColor(self.fgColor)
        let range = NSMakeRange(0, string.length)
        var offset = CGFloat(0)
        var totalCells = 0
        string.enumerateSubstrings(
            in: range,
            options: .byComposedCharacterSequences) { (c, _, _, _) in
                guard let c = c else { return }
                let a = self.attributedString(from: c)
                let l = CTLineCreateWithAttributedString(a)
                self.ctx.textPosition = CGPoint(x: pos_x + offset, y: pos_y)
                CTLineDraw(l, self.ctx)
                let cells = cells_for_character(c)
                totalCells += Int(cells)
                offset += CGFloat(cells) * self.char_width
        }
        
        if underline {
            self.drawUnderline(x: pos_x,
                               y: pos_y,
                               cells: totalCells,
                               in: self.ctx)
        } else if undercurl {
            self.drawUndercurl(x: pos_x,
                               y: pos_y,
                               cells: totalCells,
                               in: self.ctx)
        }
        
        if cursor {
            self.ctx.setBlendMode(.difference)
            self.ctx.fill(rect)
        }
        self.ctx.restoreGState()
        self.markRectNeedsDisplay(rect)
    }
    
    private func attributedString(from string: String) -> NSAttributedString {
        let attributes: StringAttributes = [
            .font: self.font!,
            .foregroundColorFromContext: true,
        ]
        
        return NSAttributedString(string: string, attributes: attributes)
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
        var image: CGImage?
        self.ctx.saveGState()
        image = self.ctx.makeImage()
        self.ctx.restoreGState()
        guard let img = image else { return }
        var rect = self.bufferBounds
        rect.origin.x = target.origin.x - src.origin.x
        rect.origin.y = target.origin.y - src.origin.y
        
        self.ctx.saveGState()
        self.ctx.clip(to: target)
        self.ctx.setBlendMode(.copy)
        self.ctx.draw(img, in: rect)
        self.ctx.restoreGState()
        self.markRectNeedsDisplay(target)
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
