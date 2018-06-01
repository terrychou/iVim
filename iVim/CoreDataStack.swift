//
//  CoreDataStack.swift
//  iVim
//
//  Created by Terry Chou on 2018/5/22.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import UIKit
import CoreData

let gCDS = CoreDataStack.shared

private let modelName = "DataModel"
private let databaseName = "db"
private let databaseDirectory = FileManager.default.url(for: "Database", under: .libraryDirectory)

final class CoreDataStack {
    static let shared = CoreDataStack()
    let context: NSManagedObjectContext
    private init() {
        guard let url = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
            fatalError("failed to locate data model")
        }
        guard let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("failed to initialize model \(url)")
        }
        guard let storeURL = databaseDirectory?.appendingPathComponent(databaseName) else {
            fatalError("failed to get store url")
        }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        self.context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        do {
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: nil)
            self.context.persistentStoreCoordinator = coordinator
        } catch {
            fatalError("failed to add persistent store: \(error)")
        }
    }
}

extension CoreDataStack {
    func save() {
        do {
            try self.context.saveIfChanged()
        } catch {
            self.raiseInconsistencyException()
        }
    }
    
    func delete(_ object: NSManagedObject) {
        object.delete()
        self.save()
    }
    
    private var presentedViewController: UIViewController? {
        return UIApplication.shared.keyWindow?.rootViewController.flatMap { $0.presentedViewController ?? $0 }
    }
    
    private func raiseInconsistencyException() {
        guard let pvc = self.presentedViewController else { return }
        let alert = UIAlertController(
            title: "Fatal Error",
            message: "The app cannot continue because of an internal inconsistency.\n\nPress OK to terminate. Sorry for the inconvenience",
            preferredStyle: .alert)
        let aOk = UIAlertAction(title: "OK", style: .default) { _ in
            NSException(name: .internalInconsistencyException,
                        reason: "Core Data Error",
                        userInfo: nil).raise()
        }
        alert.addAction(aOk)
        pvc.present(alert, animated: true, completion: nil)
    }
}
