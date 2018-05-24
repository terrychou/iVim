//
//  OldDocument+CoreDataClass.swift
//  iVim
//
//  Created by Terry Chou on 2018/5/22.
//  Copyright © 2018 Boogaloo. All rights reserved.
//
//

import Foundation
import CoreData

@objc(OldDocument)
public class OldDocument: NSManagedObject {}

extension OldDocument {
    func touch() {
        self.modifiedAt = Date()
    }
}
