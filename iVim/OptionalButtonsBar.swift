//
//  OptionalButtonsBar.swift
//  iVim
//
//  Created by Terry on 5/15/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

final class OptionalButtonsBar: UIView {
    var buttons = [[EKKeyOption]]()
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
    
    func updateButtons() {
        let m = self.measure
        let width = self.buttonWidth ?? m
        let frame = CGRect(x: 0, y: self.verticalMargin,
                           width: width, height: m)
        let fbc = self.properButtonsCount(for: width)
        self.subviews.forEach { $0.removeFromSuperview() }
        for bi in 0..<fbc {
            let ob = OptionalButton(frame: frame)
            ob.primaryFontSize = self.primaryFontSize
            ob.optionalFontSize = self.optionalFontSize
            ob.setOptions(self.buttons[bi])
            self.addSubview(ob)
        }
    }
    
    private func properButtonsCount(for buttonWidth: CGFloat) -> Int {
        let bc = self.buttons.count
        let hm = self.horizontalMargin + self.horizontalInset()
        let width = self.bounds.width - 2 * hm + self.spacing
        let maxCount = Int(width / (buttonWidth + self.spacing))
        
        return min(bc, maxCount)
    }
    
    private func horizontalInset() -> CGFloat {
        guard #available(iOS 11, *) else { return 0 }
        let insets = self.safeAreaInsets
        
        return max(insets.left, insets.right)
    }
    
    private func layoutButtons() {
        let height = self.measure
        let width = self.buttonWidth ?? height
        let buttons = self.subviews
        let halfCount = buttons.count - buttons.count / 2
        let hm = self.horizontalMargin + self.horizontalInset()
        var x = hm
        for i in 0..<halfCount {
            buttons[i].frame.origin.x = x
            x += width + self.spacing
        }
        
        x = self.bounds.width - hm - width
        for i in stride(from: buttons.count - 1, through: halfCount, by: -1) {
            buttons[i].frame.origin.x = x
            x -= width + self.spacing
        }
    }
    
    private func tuneButtons() {
        let width = self.frame.width
        let style = ButtonsBarStyle(width: width)
        if style != self.style {
            style.setMeasures(for: self)
            self.style = style
        }
        self.updateButtons()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.tuneButtons()
        UIView.performWithoutAnimation {
            self.layoutButtons()
        }
    }
    
    func setButtons(with info: [[EKKeyOption]]) {
        self.buttons = info
        self.updateButtons()
        self.setNeedsLayout()
    }
}

enum ButtonsBarStyle {
    case phone
    case padFull
    case slideOver
    case narrowSlideView
    case wideSlideView
    
    init(width: CGFloat) {
        if UIDevice.current.isPhone {
            self = .phone
        } else if width == UIScreen.main.bounds.width ||
            width == UIScreen.main.bounds.height {
            self = .padFull
        } else if width == 320 {
            self = .slideOver
        } else if width < 450 {
            self = .narrowSlideView
        } else {
            self = .wideSlideView
        }
    }
    
    func setMeasures(for bar: OptionalButtonsBar) {
        let measures: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
        switch self {
        case .phone: measures = (3, 6, 6, 26, 15, 10)
        case .padFull: measures = (15, 8, 10, 43, 21, 14)
        case .slideOver: measures = (8, 8, 5, 26, 15, 10)
        case .narrowSlideView: measures = (10, 8, 6, 36, 21, 14)
        case .wideSlideView: measures = (10, 8, 6, 38, 21, 14)
        }
        bar.horizontalMargin = measures.0
        bar.verticalMargin = measures.1
        bar.spacing = measures.2
        bar.buttonWidth = measures.3
        bar.primaryFontSize = measures.4
        bar.optionalFontSize = measures.5
    }
}
