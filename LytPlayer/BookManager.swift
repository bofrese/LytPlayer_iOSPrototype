//
//  BookManager.swift
//  LytPlayer
//
//  Created by Bo Frese on 1/3-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

import Foundation
import ObjectMapper


class BookManager {
    static let sharedInstance = BookManager()
    
    func findBook(id: String ) -> Book? {
        var book : Book?
        let filename = "\(id)/Book\(id).json"
        
        if ( fileExists(filename) ) {
            do {
                let json = try readFile(filename)
                book = Mapper<Book>().map(json)
                NSLog("Found Book for id: \(id) = \(book)")
                NSLog(" - first part: \(book?.parts[0])")
                NSLog(" - last part : \(book?.parts.last)")
            } catch {
                NSLog("FATAL Error: could not read book: \(filename)")
            }
        } else {
            NSLog("BOOK NOT FOUND: \(filename)")
            // TODO: Try to load book from network......
        }
        
        return book
    }
}