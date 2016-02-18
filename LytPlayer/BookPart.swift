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
    var id: String?
    var textFile: String?
    var textId: String?
    init (file: String, begin: Double, end: Double, id: String? = nil, textFile: String? = nil, textId: String? = nil ) {
        self.file = file
        self.begin = begin
        self.end = end
        self.textFile = textFile
        self.textId = textId
        self.id = id
    }
}
