//
//  SafeFileMoving.swift
//  iVim
//
//  Created by Terry on 7/11/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import Foundation

extension FileManager {
    func safeMovingItem(from src: URL?, into folder: URL?) -> URL? {
        guard let s = src,
            let d = folder?.appendingPathComponent(s.lastPathComponent).safeDestinationURL else { return nil }
        do {
            try self.moveItem(at: s, to: d)
            return d
        } catch {
            NSLog("Failed to move item from \(s) into \(folder!): \(error)")
            return nil
        }
    }
}

extension URL {
    var safeDestinationURL: URL {
        guard FileManager.default.fileExists(atPath: self.path) else { return self }
        let name = self.deletingPathExtension().lastPathComponent
        let ext = self.pathExtension
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        
        return self.deletingLastPathComponent().appendingPathComponent(name + " " + uuid).appendingPathExtension(ext)
    }
    
    static let documentsDirectory: URL? = FileManager.default.url(for: nil, under: .documentDirectory)
    
    static let inboxDirectory: URL? = FileManager.default.url(for: "Inbox", under: .documentDirectory)
}
