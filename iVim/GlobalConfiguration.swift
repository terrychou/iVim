//
//  GlobalConfiguration.swift
//  iVim
//
//  Created by Terry on 6/7/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import Foundation


let gSchemeName = "ivimeditor"
let gAppGroup = "group.com.terrychou.ivim"

extension UserDefaults {
    static let appGroup = UserDefaults(suiteName: gAppGroup)!
}
