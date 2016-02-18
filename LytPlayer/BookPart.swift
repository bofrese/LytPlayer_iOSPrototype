//
//  BookPart.swift
//  LytPlayer
//
//  Created by Bo Frese on 8/2-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

import Foundation

class BookPart {
    var file: String
    var begin: Double
    var end: Double
    init (file: String, begin: Double, end: Double ) {
        self.file = file
        self.begin = begin
        self.end = end
    }
}
