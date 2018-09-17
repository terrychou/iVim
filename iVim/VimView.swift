//
//  VimView.swift
//  iVim
//
//  Created by Lars Kindler on 31/10/15.
//  Refactored by Terry Chou on 20/07/17
//  Copyright © 2015 Boogaloo. All rights reserved.
//

import UIKit
import CoreText

final class VimView: UIView {
    private var dirtyRect: CGRect = .zero
    private lazy var shellLayer: CGLayer? = {
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let scale = UIScreen.main.scale
        let length = self.shellBounds.width * scale
        let size = CGSize(width: length, height: length)
        let re = CGLayer(context, size: size, auxiliaryInfo: nil)
        re?.context?.scaleBy(x: scale, y: scale)
        
        return re
    }()
    private lazy var shellBounds: CGRect = {
        let ss = UIScreen.main.bounds.size
        let length = max(ss.width, ss.height)
        
        return CGRect(x: 0, y: 0, width: length, height: length)
    }()
    
    @objc var char_ascent = CGFloat(0)
    var char_descent = CGFloat(0)
    @objc var char_width = CGFloat(0)
    @objc var char_height = CGFloat(0)
    
    @objc var bgcolor: CGColor?
    @objc var fgcolor: CGColor?
    @objc var spcolor: CGColor?
    
    override func draw(_ rect: CGRect) {
        guard !rect.equalTo(.zero),
            let context = UIGraphicsGetCurrentContext() else { return }
        self.drawShellLayer(clippedIn: rect, in: context)
        self.dirtyRect = .zero
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.resizeShell()
    }
    
    @objc func resizeShell() {
//        print("Resizing to \(frame)")
        let f = self.frame
        gui_resize_shell(CInt(f.width), CInt(f.height))
    }
    
    private func drawShellLayer(at location: CGPoint? = nil, clippedIn rect: CGRect, in context: CGContext) {
        guard let layer = self.shellLayer else { return }
        context.saveGState()
        context.clip(to: rect)
        var sRect = self.shellBounds
        if let o = location {
            sRect.origin = o
        }
        context.draw(layer, in: sRect)
//        context.beginPath()
//        context.addRect(rect)
//        context.clip()
//        let sRect = location.map { CGRect(origin: $0, size: self.shellBounds.size) } ?? self.shellBounds
//        context.draw(layer, in: sRect)
        context.restoreGState()
    }
    
    @objc func copyRect(from src: CGRect, to target: CGRect) {
        NSLog("copy rect")
        NSLog("src: \(src)")
        NSLog("dst: \(target)")
//        guard let context = self.shellLayer?.context else { return }
        guard let layer = self.shellLayer,
            let context = layer.context else { return }
//        let dstRect = CGRect(x: target.origin.x,
//                             y: target.origin.y,
//                             width: min(target.size.width, src.size.width),
//                             height: min(target.size.height, src.size.height))
//        let location = CGPoint(x: dstRect.origin.x - src.origin.x,
//                               y: dstRect.origin.y - src.origin.y)
//        self.drawShellLayer(at: location, clippedIn: dstRect, in: context)

//        var iLayer: CGLayer?
//        let size = src.size
//        let scale = UIScreen.main.scale
//        UIGraphicsBeginImageContextWithOptions(size, true, 0)
//        let ctx = UIGraphicsGetCurrentContext()!
//        let iSize = CGSize(width: size.width * scale, height: size.height * scale)
//        iLayer = CGLayer(ctx, size: iSize, auxiliaryInfo: nil)!
//        let iContext = iLayer!.context!
//        iContext.saveGState()
//        iContext.clip(to: CGRect(origin: .zero, size: iSize))
//        let offset = CGPoint(x: -src.origin.x * scale, y: -src.origin.y * scale)
////        let rect = CGRect(origin: offset, size: self.shellBounds.size)
////        iContext.draw(layer, in: rect)
//        iContext.draw(layer, at: offset)
//        iContext.restoreGState()
//        UIGraphicsEndImageContext()
        
//        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
//        let bmContext = CGContext(
//        let size = src.size
//        let image: CGImage
//        UIGraphicsBeginImageContextWithOptions(size, true, 0)
//        let ctx = UIGraphicsGetCurrentContext()!
//        ctx.saveGState()
//        ctx.clip(to: CGRect(origin: .zero, size: size))
//        let offset = CGPoint(x: -src.origin.x, y: -src.origin.y)
//        //        let rect = CGRect(origin: offset, size: self.shellBounds.size)
//        //        iContext.draw(layer, in: rect)
//        ctx.draw(layer, at: offset)
//        image = ctx.makeImage()!
//        ctx.restoreGState()
//        UIGraphicsEndImageContext()
        
////        let size = dstRect.size
////        let image: CGImage
////        UIGraphicsBeginImageContextWithOptions(size, true, 0)
////        let bctx = UIGraphicsGetCurrentContext()!
////        bctx.saveGState()
////        bctx.draw(layer, at: CGPoint(x: -src.origin.x, y: -src.origin.y))
////        image = bctx.makeImage()!
////        bctx.restoreGState()
////        UIGraphicsEndImageContext()
//        context.saveGState()
//        let size = self.shellBounds.size
//        let scale = UIScreen.main.scale
//        let newSize = CGSize(width: dstRect.width * scale, height: dstRect.height * scale)
////        UIGraphicsBeginImageContextWithOptions(newSize, true, 0)
////        let aContext = UIGraphicsGetCurrentContext()!
//        let newLayer = CGLayer(context, size: newSize, auxiliaryInfo: nil)!
//        let newContext = newLayer.context!
////        newContext.scaleBy(x: scale, y: scale)
//        newContext.saveGState()
//        newContext.clip(to: CGRect(origin: .zero, size: newSize))
//        let offsetPoint = CGPoint(x: -src.origin.x, y: -(size.height - (src.height + src.origin.y)))
//        newContext.draw(layer, at: offsetPoint)
////        let image = newContext.makeImage()!
////        newContext.flush()
//        newContext.restoreGState()
////        UIGraphicsEndImageContext()
//
////        let newLayer = CGLayer(context, size: layer.size, auxiliaryInfo: nil)!
////        let newContext = newLayer.context!
////        newContext.saveGState()
////        newContext.draw(layer, at: CGPoint(x: 0, y: self.shellBounds.height))
////        newContext.restoreGState()
//
//
////        context.clip(to: dstRect)
//        context.saveGState()
////        let p = CGPoint(x: 0, y: 400)
////        let newRect = CGRect(origin: p, size: dstRect.size)
//        context.setBlendMode(.copy)
////        context.draw(newLayer, at: CGPoint(x: target.origin.x, y: size.height - target.origin.y - target.height))
////        context.flush()
////        context.clear(target)
//        context.clip(to: target)
//        context.draw(iLayer!, in: target)
////        context.draw(image, in: target)
////        context.flush()
//        context.restoreGState()
//        iLayer = nil
        
//        DispatchQueue.global().sync {
        let size = src.size
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        let offset = CGPoint(x: -src.origin.x, y: -src.origin.y)
        let iRect = CGRect(origin: offset, size: self.shellBounds.size)
        let bounds = CGRect(origin: .zero, size: size)
        ctx.clip(to: bounds)
        ctx.draw(layer, in: iRect)
        let image = ctx.makeImage()!
        ctx.restoreGState()
        UIGraphicsEndImageContext()
//        }
        context.saveGState()
        context.clip(to: target)
        context.setBlendMode(.copy)
        context.draw(image, in: target)
        context.restoreGState()

        
//        self.drawShellLayer(at: location, clippedIn: , in: <#T##CGContext#>)
//        context.saveGState()
//        context.clip(to: dstRect)
////        context.setBlendMode(.copy)
//        let newRect = CGRect(origin: location, size: dstRect.size)
//        context.draw(self.shellLayer!, in: newRect)
//        context.restoreGState()
        self.dirtyRect = self.dirtyRect.union(target)
        self.markNeedsDisplay()
//        self.setNeedsDisplay()
    }
    
    func markNeedsDisplay() {
        self.setNeedsDisplay(self.dirtyRect)
    }

    func flush(){
        self.shellLayer?.context?.flush()
        self.markNeedsDisplay()
    }
    
    @objc func fillAll(with color: CGColor) {
        guard let layer = self.shellLayer else { return }
        let rect = CGRect(origin: .zero, size: layer.size)
        self.fillRect(rect, with: color)
    }
    
    @objc func fillRect(_ rect: CGRect, with color: CGColor?) {
        guard let context = self.shellLayer?.context,
            let c = color else { return }
        context.saveGState()
        context.setFillColor(c)
        context.fill(rect)
        context.restoreGState()
        self.dirtyRect = self.dirtyRect.union(rect)
        self.markNeedsDisplay()
    }
    
    @objc func strokeRect(_ rect: CGRect, with color: CGColor?) {
        guard let context = self.shellLayer?.context,
            let c = color else { return }
        context.setStrokeColor(c)
        context.stroke(rect)
        self.dirtyRect = self.dirtyRect.union(rect)
        self.markNeedsDisplay()
    }
    
    private func attributedString(from string: String, font: CTFont) -> NSAttributedString {
        let attributes: [NSAttributedStringKey: Any] = [
            .font: font,
            NSAttributedStringKey(kCTForegroundColorFromContextAttributeName as String): true]
        
        return NSAttributedString(string: string, attributes: attributes)
    }
    
    @objc func drawString(_ s: NSString, font: CTFont,
                    pos_x:CGFloat, pos_y: CGFloat, rect:CGRect, p_antialias: Bool,
                    transparent: Bool, underline: Bool,
                    undercurl: Bool, cursor: Bool) {
//        NSLog("draw string")
        guard let context = self.shellLayer?.context else { return }
        context.saveGState()
        if !transparent {
            context.setFillColor(self.bgcolor!)
            context.fill(rect)
        }
        context.setShouldAntialias(p_antialias)
        context.setAllowsAntialiasing(p_antialias)
        context.setShouldSmoothFonts(p_antialias)
        context.setCharacterSpacing(0)
        context.setTextDrawingMode(.fill)
        context.setFillColor(self.fgcolor!)
        let range = NSMakeRange(0, s.length)
        var offset = CGFloat(0)
        var totalCells = 0
        s.enumerateSubstrings(in: range, options: .byComposedCharacterSequences) { (c, _, _, _) in
            guard let c = c else { return }
            let a = self.attributedString(from: c, font: font)
            let l = CTLineCreateWithAttributedString(a)
            context.textPosition = CGPoint(x: pos_x + offset, y: pos_y)
            CTLineDraw(l, context)
            let cells = cells_for_character(c)
            totalCells += Int(cells)
            offset += CGFloat(cells) * self.char_width
        }
        
        if underline {
            self.drawUnderline(x: pos_x, y: pos_y,
                               cells: totalCells, in: context)
        } else if undercurl {
            self.drawUndercurl(x: pos_x, y: pos_y,
                               cells: totalCells, in: context)
        }
        
        if cursor {
            context.setBlendMode(.difference)
            context.fill(rect)
        }
        context.restoreGState()
        self.dirtyRect = self.dirtyRect.union(rect)
        self.markNeedsDisplay()
    }
    
    private func drawUnderline(x: CGFloat, y: CGFloat, cells: Int, in context: CGContext) {
        let rect = CGRect(x: x, y: y + 0.4 * self.char_descent,
                          width: CGFloat(cells) * self.char_width, height: 1)
        context.setFillColor(self.spcolor!)
        context.fill(rect)
    }
    
    private func drawUndercurl(x: CGFloat, y: CGFloat, cells: Int, in context: CGContext) {
        var x = x
        let y = y + 1
        let w = self.char_width
        let h = 0.5 * self.char_descent
        context.move(to: CGPoint(x: x, y: y))
        for _ in 0..<cells {
            context.addCurve(
                to: CGPoint(x: x + 0.5 * w, y: y + h),
                control1: CGPoint(x: x + 0.25 * w, y: y),
                control2: CGPoint(x: x + 0.25 * w, y: y + h))
            context.addCurve(
                to: CGPoint(x: x + w, y: y),
                control1: CGPoint(x: x + 0.75 * w, y: y + h),
                control2: CGPoint(x: x + 0.75 * w, y: y))
            x += w
        }
        context.setStrokeColor(self.spcolor!)
        context.strokePath()
    }
    
    @objc func initFont(_ fontInfo: String?) -> CTFont {
        let (f, a, d, w, h) = gFM.initializeFont(fontInfo)
        self.char_ascent = a
        self.char_descent = d
        self.char_width = w
        self.char_height = h
        
        return f
    }
}

