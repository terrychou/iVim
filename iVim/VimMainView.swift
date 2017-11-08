//
//  VimMainView.swift
//  iVim
//
//  Created by Terry Chou on 03/11/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import UIKit

final class VimMainView: UIView {
    private var top: NSLayoutConstraint!
    private var bottom: NSLayoutConstraint!
    private var left: NSLayoutConstraint!
    private var right: NSLayoutConstraint!
    
    private func constraint(for subview: UIView, attribute: NSLayoutAttribute) -> NSLayoutConstraint {
        let c = NSLayoutConstraint(item: subview, attribute: attribute,
                                   relatedBy: .equal, toItem: self,
                                   attribute: attribute, multiplier: 1.0,
                                   constant: 0.0)
        c.priority = UILayoutPriority(750)
        
        return c
    }
    
    func addShellView(_ v: UIView) {
        v.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(v)
        self.top = self.constraint(for: v, attribute: .top)
        self.bottom = self.constraint(for: v, attribute: .bottom)
        self.left = self.constraint(for: v, attribute: .left)
        self.right = self.constraint(for: v, attribute: .right)
        self.addConstraints([self.top, self.bottom, self.left, self.right])
        self.layoutIfNeeded()
    }
    
    @available(iOS 11, *)
    private func updateSubview() {
        let insets = self.safeAreaInsets
        self.top.constant = insets.top
        self.bottom.constant = -insets.bottom
        self.left.constant = insets.left
        self.right.constant = -insets.right
    }
    
    @available(iOS 11.0, *)
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        self.updateSubview()
    }
}

