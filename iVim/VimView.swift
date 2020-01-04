//
//  VimView.swift
//  iVim
//
//  Created by Lars Kindler on 31/10/15.
//  Refactored by Terry Chou on 20/07/17
//  Rewritten by Terry Chou on 18/09/18
//  Copyright © 2015 Boogaloo. All rights reserved.
//

import UIKit
import CoreText

final class VimView: UIView {
    private var dirtyRect: CGRect = .zero
    var fgColor: VimColor = 0
    var bgColor: VimColor = 0
    var spColor: VimColor = 0
    var font: CTFont?
    @objc var char_ascent: CGFloat = 0
    var char_descent: CGFloat = 0
    @objc var char_width: CGFloat = 0
    @objc var char_height: CGFloat = 0
    lazy var ctx: CGContext = {
        let size = self.bufferBounds.size
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        let ctx = UIGraphicsGetCurrentContext()
        UIGraphicsEndImageContext()
        guard let result = ctx else {
            fatalError("failed to create buffer context")
        }
        result.translateBy(x: 0.0, y: size.height)
        result.scaleBy(x: 1.0, y: -1.0)
        
        return result
    }()
    lazy var bufferBounds: CGRect = {
        var result = UIScreen.main.bounds
        let length = max(result.width, result.height)
        result.size.width = length
        result.size.height = length
        
        return result
    }()
}

extension Thread {
    static func runOnMainThread(_ task: @escaping () -> Void) {
        if self.isMainThread {
            task()
        } else {
            DispatchQueue.main.async(execute: task)
        }
    }
}

private extension CGRect {
    mutating func safeFormUnion(_ rect: CGRect) {
        // "safe" means not to union with .zero
        // whose result doesn't make sense here
        self = self == .zero ? rect : self.union(rect)
    }
}

extension VimView {    
    private func redrawImmediately() {
        // force the redraw happen immediately
//        RunLoop.main.run(mode: .tracking, before: Date())
    }
    
    func markRectNeedsDisplay(_ rect: CGRect) {
//        NSLog("dirty rect \(self.dirtyRect) new rect \(rect)")
        self.dirtyRect.safeFormUnion(rect)
//        self.markNeedsDisplay()
    }
    
    func markNeedsDisplay() {
        Thread.runOnMainThread {
            self.setNeedsDisplay(self.dirtyRect)
            self.dirtyRect = .zero
        }
    }
    
    func flush(_ redrawImmediately: Bool) {
        self.markNeedsDisplay()
        if redrawImmediately {
            self.redrawImmediately()
        }
//        if self.dirtyRect != .zero {
//            self.redrawImmediately()
//            self.dirtyRect = .zero
//        }
//        NSLog("\(#function)")
    }
    
    @objc func initFont(_ fontInfo: String?) -> CTFont {
        let (f, a, d, w, h) = gFM.initializeFont(fontInfo)
        self.char_ascent = a
        self.char_descent = d
        self.char_width = w
        self.char_height = h
        self.font = f
        
        return f
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.resizeShell()
    }
    
    @objc func resizeShell() {
        let f = self.frame
//        print("resize shell", f)
        gui_resize_shell(CInt(f.width), CInt(f.height))
    }
    
    override func draw(_ rect: CGRect) {
        var image: CGImage?
        self.ctx.saveGState()
        image = self.ctx.makeImage()
        self.ctx.restoreGState()
        guard let img = image,
            let ctx = UIGraphicsGetCurrentContext()
            else { return }
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.draw(img, in: self.bufferBounds)
        ctx.restoreGState()
    }
}
