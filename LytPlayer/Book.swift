//
//  Book.swift
//  LytPlayer
//
//  Created by Bo Frese on 8/2-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

import Foundation
import UIKit


// Not realy used yet....
protocol Playable {
    
}


class Book: Playable {
    var id: Int
    var author: String
    var title: String
    var cover: String
    var parts: [BookPart]
    var duration: Int // seconds
    var position: Int // Seconds
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
    
    func calculateDuration() -> Int {
        return 22000 // TODO: Calculate duration of the entire book
    }
    
    func urlForPart( partNumber: Int ) -> NSURL? {
        var url : NSURL?
        let part = parts[ partNumber]
        
        if let path = NSBundle.mainBundle().pathForResource( part.file , ofType: "mp3") {
            url  = NSURL.fileURLWithPath(path)
        }
        
        return url
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
        }

        return coverImg!
    }
}
