//
//  CoreDataExtension.swift
//  iVim
//
//  Created by Terry Chou on 2018/5/22.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import CoreData

extension NSManagedObject {
    class var entityName: String {
        let classString = NSStringFromClass(self)
        let components = classString.components(separatedBy: ".")
        
        return components.last ?? classString
    }
    
    class func fetchRequest<T: NSFetchRequestResult>(predicate p: NSPredicate? = nil, sortDescriptors s: [NSSortDescriptor]? = nil) -> NSFetchRequest<T> {
        let request = NSFetchRequest<T>(entityName: self.entityName)
        request.predicate = p
        request.sortDescriptors = s
        
        return request
    }
    
    func delete() {
        guard let c = self.managedObjectContext else { return }
        c.delete(self)
    }
    
    func avatar<T: NSManagedObject>(in context: NSManagedObjectContext) -> T? {
        return (try? context.existingObject(with: self.objectID)) as? T
    }
}

extension NSManagedObjectContext {
    func insertNew<T: NSManagedObject>(_ entity: T.Type) -> T {
        return NSEntityDescription.insertNewObject(forEntityName: entity.entityName, into: self) as! T
    }
    
    func fetch<T: NSManagedObject>(_ entity: T.Type, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> [T]? {
        let request: NSFetchRequest<T> = entity.fetchRequest(predicate: predicate, sortDescriptors: sortDescriptors)
        
        return try? self.fetch(request)
    }
    
    func fetch<T: NSFetchRequestResult>(request: NSFetchRequest<T>) throws -> [T] {
        let results: [Any] = try self.fetch(request)
        
        return results as! [T]
    }
    
    func saveIfChanged() throws {
        guard self.hasChanges else { return }
        try self.save()
    }
    
    var child: NSManagedObjectContext {
        let c = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        c.parent = self
        c.stalenessInterval = 0
        
        return c        
    }
}
