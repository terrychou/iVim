//
//  FileLineReader.swift
//  iVim
//
//  It reads file line by line without reading it into
//  the memory altogether.
//
//  It accepts a file handle instead of a file path string,
//  in order to remind the caller to close the opened file.
//
//  The lines have the newline character attached.
//
//  source: https://stackoverflow.com/a/40855152/723851
//
//  Created by Terry Chou on 2018/5/8.
//  Copyright © 2018 Boogaloo. All rights reserved.
//

import Foundation

struct LineReader {
    private let file: UnsafeMutablePointer<FILE>
}

extension LineReader {
    init?(file: UnsafeMutablePointer<FILE>?) {
        guard let f = file else { return nil }
        self.init(file: f)
    }
    
    var nextLine: String? {
        var line: UnsafeMutablePointer<CChar>?
        var linecap: Int = 0
        defer { free(line) }
        
        return getline(&line, &linecap, self.file) > 0 ?
            String(cString: line!) : nil
    }
    
    func close() {
        fclose(self.file)
    }
}

extension LineReader: Sequence {
    public func makeIterator() -> AnyIterator<String> {
        return AnyIterator<String> {
            return self.nextLine
        }
    }
}
