//
//  FileLineReader.swift
//  iVim
//
//  It reads file line by line without reading it into
//  the memory altogether.
//
//  It accepts a file handle instead of a file path string.
//
//  The lines have the newline character attached.
//
//  source: https://stackoverflow.com/a/40855152/723851
//
//  Created by Terry Chou on 2018/5/8.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import Foundation

final class LineReader {
    private let file: UnsafeMutablePointer<FILE>
    
    init?(file: UnsafeMutablePointer<FILE>?) {
        guard let f = file else { return nil }
        self.file = f
    }
    
    deinit {
        fclose(self.file)
    }
}

extension LineReader {
    var nextLine: String? {
        var line: UnsafeMutablePointer<CChar>?
        var linecap: Int = 0
        defer { free(line) }
        
        return getline(&line, &linecap, self.file) > 0 ?
            String(cString: line!) : nil
    }
}

extension LineReader: Sequence {
    public func makeIterator() -> AnyIterator<String> {
        return AnyIterator<String> {
            return self.nextLine
        }
    }
}
