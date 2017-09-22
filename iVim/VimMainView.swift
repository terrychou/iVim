//
//  VimMainView.swift
//  VimIOS
//
//  Created by Lars Kindler on 20/11/15.
//  Copyright © 2015 Lars Kindler. All rights reserved.
//

import UIKit

final class VimMainView: UIView {
    override func layoutSubviews() {
//        print("VimMainView Frame: \(self.frame)")
        self.subviews[0].frame = self.frame
    }
}

