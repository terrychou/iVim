//
//  OptionalButtonsBar.swift
//  iVim
//
//  Created by Terry on 5/15/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

final class OptionalButtonsBar: UIView {
    var buttons = [[ButtonOption]]()
    var style: ButtonsBarStyle?
    var horizontalMargin = CGFloat(8)
    var verticalMargin = CGFloat(8)
    var spacing = CGFloat(12)
    var buttonWidth: CGFloat?
    var primaryFontSize = CGFloat(0)
    var optionalFontSize = CGFloat(0)
}

extension OptionalButtonsBar {
    private var measure: CGFloat {
        return self.bounds.height - self.verticalMargin * 2
    }
    
    private func addButtons() {
        guard self.buttons.count > 0 else { return }
        self.subviews.forEach { $0.removeFromSuperview() }
        let m = self.measure
        let width = self.buttonWidth ?? m
        let frame = CGRect(x: 0, y: self.verticalMargin, width: width, height: m)
        for bo in self.buttons {
            let ob = OptionalButton(frame: frame)
            ob.primaryFontSize = self.primaryFontSize
            ob.optionalFontSize = self.optionalFontSize
            ob.setOptions(bo)
            self.addSubview(ob)
        }
    }
    
    private func layoutButtons() {
        let height = self.measure
        let width = self.buttonWidth ?? height
        let buttons = self.subviews
        let halfCount = buttons.count - buttons.count / 2
        var x = self.horizontalMargin
        for i in 0..<halfCount {
            buttons[i].frame.origin.x = x
            x += width + spacing
        }
        
        x = self.bounds.width - self.horizontalMargin - width
        for i in stride(from: self.buttons.count - 1, through: halfCount, by: -1) {
            buttons[i].frame.origin.x = x
            x -= width + spacing
        }
    }
    
    private func tuneButtons() {
        let width = self.frame.width
        let style = ButtonsBarStyle(width: width)
        guard style != self.style else { return }
        style.setMeasures(for: self)
        self.style = style
        self.addButtons()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.tuneButtons()
        self.layoutButtons()
    }
    
    func setButtons(with info: [[ButtonOption]]) {
        self.buttons = info
        self.addButtons()
        self.setNeedsLayout()
    }
}

enum ButtonsBarStyle {
    case phone
    case padFull
    case slideOver
    case slideView
    
    init(width: CGFloat) {
        if UIDevice.current.isPhone {
            self = .phone
        } else if width == UIScreen.main.bounds.width || width == UIScreen.main.bounds.height {
            self = .padFull
        } else if width == 320 {
            self = .slideOver
        } else {
            self = .slideView
        }
    }
    
    func setMeasures(for bar: OptionalButtonsBar) {
        let measures: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
        switch self {
        case .phone: measures = (3, 6, 6, 26, 15, 10)
        case .padFull: measures = (15, 8, 10, 43, 21, 14)
        case .slideOver: measures = (8, 8, 5, 26, 15, 10)
        case .slideView: measures = (10, 8, 6, 38, 21, 14)
        }
        bar.horizontalMargin = measures.0
        bar.verticalMargin = measures.1
        bar.spacing = measures.2
        bar.buttonWidth = measures.3
        bar.primaryFontSize = measures.4
        bar.optionalFontSize = measures.5
    }
}
