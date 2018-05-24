//
//  OldDocument+CoreDataProperties.swift
//  iVim
//
//  Created by Terry Chou on 2018/5/22.
//  Copyright © 2018 Boogaloo. All rights reserved.
//
//

import Foundation
import CoreData


extension OldDocument {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<OldDocument> {
        return NSFetchRequest<OldDocument>(entityName: "OldDocument")
    }

    @NSManaged public var path: String
    @NSManaged public var bookmark: Data?
    @NSManaged public var modifiedAt: Date?
}
