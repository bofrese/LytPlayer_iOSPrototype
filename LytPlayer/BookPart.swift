//
//  BookPart.swift
//  LytPlayer
//
//  Created by Bo Frese on 8/2-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

import Foundation
import ObjectMapper

// Represents a part, or section in the book. Links one text file to one audio file.
// TODO: In SMIL files we can have multiple audio parts to one text file.
class BookPart: Mappable, CustomStringConvertible {
    var file: String!
    var begin: Double!
    var end: Double!
    var id: String?
    var textFile: String?
    var textId: String?
    
    /*
    init (file: String, begin: Double, end: Double, id: String? = nil, textFile: String? = nil, textId: String? = nil ) {
        self.file = file
        self.begin = begin
        self.end = end
        self.textFile = textFile
        self.textId = textId
        self.id = id
    }
    */
    
    required init?(_ map: Map) {
    }
    
    func mapping(map: Map) {
        id <- map["id"]
        file <- map["audio"]
        textFile <- map["textFile"]
        textId <- map["textId"]
        begin <- map["begin"]
        end <- map["end"]
    }
    
    var description: String {
        return "BookPart: id:\(id) audio=\(file) (\(begin) - \(end)), text=\(textFile) # \(textId)"
    }


}
