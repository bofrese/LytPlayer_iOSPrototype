//
//  Book.swift
//  LytPlayer
//
//  Created by Bo Frese on 8/2-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

import Foundation
import UIKit
import ObjectMapper


class Book: Mappable, CustomStringConvertible {
    var id: String!            // FIXME: Should all these be marked with !
    var author: String!
    var title: String!
    var cover: String?
    var parts: [BookPart] = []
    var duration: Int! // = 0 // seconds
    var position: Int = 0 // Seconds
    /*
    init( id: Int, author: String, title: String, cover: String, duration: Int = 0, position: Int = 0, parts: [BookPart]) {
        self.id = id
        self.author = author
        self.title = title
        self.cover = cover
        self.parts = parts
        self.position  = position
        self.duration  = duration
        if ( self.duration == 0 ) {
            self.duration = calculateDuration()
        }
    }
*/
    
    required init?(_ map: Map) {
    }
    
    func mapping(map: Map) {
        id <- map["id"]
        author <- map["author"]
        title <- map["title"]
        cover <- map["cover"]
        parts <- map["parts"]
        duration <- map["duration"]
    }
    
    var description: String {
         return "Book: id:\(id) title=\(title), author=\(author), duration=\(duration), cover=\(cover) #parts=\(parts.count)"
    }
    
    func calculateDuration() -> Int {
        return 22000 // TODO: Calculate duration of the entire book
    }
    
    // Currently not used. ....
    func urlForPart( partNumber: Int ) -> NSURL? {
        ///////
        ///Experiment
        let url =  remoteUrlForPart( partNumber)
        NSLog("urlForPart(\(partNumber)) = \(url)")
        return url
        ////////////
//        var url : NSURL?
//        if let localurl = localUrlForPart( partNumber ) {
//            url = localurl
//        } else {
//            url = remoteUrlForPart( partNumber)
//        }
//        NSLog("urlForPart(\(partNumber)) = \(url)")
//        return url
    }
    func localUrlForPart( partNumber: Int ) -> NSURL? {
        var url : NSURL?
        let part = parts[ partNumber]
        let filename = "\(self.id)/\(part.file)"
        
        if ( fileExists(filename)) {
            url = fileURL(filename)
        }
        
        return url
    }
    
    // Get remote urls for the book part.
    // Example: http://m.e17.dk/DodpFiles/10142992/18716/MEM_001.mp3
    func remoteUrlForPart( partNumber: Int ) -> NSURL? {
        let part = parts[ partNumber]
        let urlString = bookRemoteBaseUrl() + "\(self.id)/\(part.file)"
        let url  = NSURL(string: urlString)
        return url
    }
    
    func bookRemoteBaseUrl() -> String {
        let userid = 10142992 // TODO: Get userid
        // TODO: Currently the bookid is included in the file name. It shouldnt be....
        // return "http://m.e17.dk/DodpFiles/\(userid)/\(self.id)/";
        return "http://m.e17.dk/DodpFiles/\(userid)/";

    }
    
    
    func part( partNumber: Int ) -> BookPart {
        return parts[ partNumber]
    }
    
    func partNoForId( partId: String ) -> Int? {
        
        for idx in 0..<parts.count {
            if let foundId = parts[ idx ].id {
                if foundId == partId {
                    return idx
                }
            }
        }
        
        return nil
    }

    
    func coverImage() -> UIImage {
        var coverImg: UIImage?  // TODO: Provide default cover instead (Nota logo?)
        if let path = NSBundle.mainBundle().pathForResource( self.cover , ofType: "jpg") {
            coverImg = UIImage(contentsOfFile: path);
        } else if let path = NSBundle.mainBundle().pathForResource( "nota_logo" , ofType: "jpg") {
            coverImg = UIImage(contentsOfFile: path);
        } else {
            NSLog("No cover image - not even the default one !?!?!?!?")
            // TODO: Better hadling of no cover image....
        }

        return coverImg!
    }
}
