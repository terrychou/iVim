//
//  ExtendedKeyboardEditingHistory.swift
//  iVim
//
//  Created by Terry Chou on 2018/5/9.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import Foundation

final class EKEditingHistory {
    private var history = [EKEditingHistoryItem]()
    private var index: Int = -1
}

extension EKEditingHistory {
    private func addItem(_ item: EKEditingHistoryItem) {
//        let sofar: ArraySlice<EKEditingHistoryItem>
//        if self.index < 0 {
//            sofar = []
//        } else if self.index >= self.history.count {
//            sofar = self.history[...]
//        } else {
//            sofar = self.history[...self.index]
//        }
//        self.history = sofar + [item]
//        self.index = sofar.count
        let sofar = self.index > -1 ? self.history[...self.index] : []
        self.history = sofar + [item]
        self.index = sofar.count
//        NSLog("add: \(self.history.count), \(self.index)")
    }
//
//    private var isInSafeRange: Bool {
//        return self.index >= 0 && self.index < self.history.count
//    }
//
//    var currentItem: EKEditingHistoryItem? {
//        guard self.isInSafeRange else { return nil }
//        return self.history[self.index]
//    }
//
//    func removeCurrent() {
//        guard self.isInSafeRange else { return }
//        self.history.remove(at: self.index)
//        self.index -= 1
//    }
    
    func add(buttons: EKButtons, sourceItem: String) {
        let item = EKEditingHistoryItem(buttons: buttons,
                                        sourceItem: sourceItem)
        self.addItem(item)
    }
    
    func undo() -> EKEditingHistoryItem? {
        guard self.index > 0 else { return nil }
        self.index -= 1
//        NSLog("history: \(self.history.count)")
//        NSLog("index: \(self.index)")
        
        return self.history[self.index]
    }
    
    func redo() -> EKEditingHistoryItem? {
        guard self.index < self.history.count - 1 else { return nil }
        self.index += 1
//        NSLog("history: \(self.history.count)")
//        NSLog("index: \(self.index)")
        
        return self.history[self.index]
    }
    
    func clear() {
        self.history.removeAll()
        self.index = -1
    }
    
    func editingItems() -> [String] {
        return self.index > 0 ? // ignore the first item
            self.history[1...self.index].map { $0.sourceItem } :
            []
    }
}

struct EKEditingHistoryItem {
    let buttons: EKButtons
    let sourceItem: String
}
