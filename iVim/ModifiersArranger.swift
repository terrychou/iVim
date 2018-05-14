//
//  ModifiersArranger.swift
//  iVim
//
//  Created by Terry Chou on 2018/5/6.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import Foundation

final class EKModifiersArranger {
    private var table = [KeyInfoID: EKModifierInfo]()
    private let queue = DispatchQueue(label: "com.terrychou.ivim.modifiers.serial")
}

extension EKModifiersArranger {
    func update(for button: OptionalButton, with keyString: String) {
        self.queue.sync {
            if button.isOn { // register key info
                if !button.isHeld { // just turned on
                    guard let eki = button.effectiveInfo else { return }
                    let mi = EKModifierInfo(string: keyString,
                                            button: button)
                    self.table[eki.identifier] = mi
                    // clear other keys on this button
                    for oki in button.info.values where oki.identifier != eki.identifier {
                        self.table[oki.identifier] = nil
                    }
                }
            } else { // unregister key info
                guard let eki = button.effectiveInfo else { return }
                self.table[eki.identifier] = nil
            }
        }
    }
    
    func query() -> Set<String> {
        var result = Set<String>()
        self.queue.sync {
            for (k, mi) in self.table {
                let discard: Bool
                if let b = mi.button, b.isOn {
                    result.insert(mi.string)
                    b.tryRestore()
                    discard = !b.isOn
                } else {
                    discard = true
                }
                if discard {
                    self.table[k] = nil
                }
            }
        }
        
        return result
    }
    
    func clear() {
        self.queue.sync {
            self.table.removeAll()
        }
    }
}

private struct EKModifierInfo {
    let string: String
    weak var button: OptionalButton?
}
