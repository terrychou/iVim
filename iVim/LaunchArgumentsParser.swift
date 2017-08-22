//
//  LaunchArgumentsParser.swift
//  iVim
//
//  Created by Terry on 8/22/17.
//  Copyright © 2017 Boogaloo. All rights reserved.
//

import Foundation

private let kUDLaunchArguments = "kUDLaunchArguments"
private let kUDAlwaysLaunchWithArguments = "kUDAlwaysLaunchWithArguments"

struct LaunchArgumentsParser {}

extension LaunchArgumentsParser {
    private var argumentsLine: String? {
        return UserDefaults.standard.string(forKey: kUDLaunchArguments)
    }
    
    private func clearArgumentsLine() {
        let ud = UserDefaults.standard
        ud.set("", forKey: kUDLaunchArguments)
        ud.synchronize()
    }
    
    private var always: Bool {
        return UserDefaults.standard.bool(forKey: kUDAlwaysLaunchWithArguments)
    }
    
    func parse() -> [String] {
        guard let line = self.argumentsLine, !line.isEmpty else { return [] }
        let result = CommandTokenizer(line: line).run()
        if !self.always { self.clearArgumentsLine() }
        
        return result
    }
}

