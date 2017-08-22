//
//  Stack.swift
//  Locu
//
//  Created by Terry on 2/28/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import Foundation

private indirect enum StackNode<T> {
    case empty
    case node(value: T, next: StackNode)
}

struct Stack<T> {
    private var head: StackNode<T> = .empty
    var count: Int = 0
    
    mutating func push(_ v: T) {
        self.head = StackNode<T>.node(value: v, next: self.head)
        self.count += 1
    }
    
    @discardableResult mutating func pop() -> T? {
        guard case StackNode<T>.node(let value, let next) = self.head else { return nil }
        self.head = next
        self.count -= 1
        
        return value
    }
    
    func top() -> T? {
        guard case StackNode<T>.node(let value, _) = self.head else { return nil }
        
        return value
    }
    
    mutating func removeAll() {
        self.head = .empty
        self.count = 0
    }
}
