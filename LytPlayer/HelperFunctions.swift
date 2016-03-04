//
//  HelperFunctions.swift
//  LytPlayer
//
//  Misc generic helper functions for the LytPlayer
//
//  Created by Bo Frese on 19/2-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

import Foundation
import UIKit


// -------------------------------------------------------------------------------------
// MARK: - UI Related helpers

/// Show an alert
func showAlert(title: String, message: String, success: () -> () = {} ) {
    
    let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
    
    alertController.addAction(UIAlertAction(title: "Ok", style: .Default, handler: { (action: UIAlertAction!) in
        NSLog("Handle Ok logic here")
        success()
    }))
    
    alertController.addAction(UIAlertAction(title: "Cancel", style: .Default, handler: { (action: UIAlertAction!) in
        NSLog("Handle Cancel Logic here")
    }))
    
    let app = UIApplication.sharedApplication()
    let viewController = app.delegate?.window??.rootViewController
    // TODO: Aditional logic may be needed to find the visibleViewController ??
    viewController?.presentViewController(alertController, animated: true, completion: nil)
}


// -------------------------------------------------------------------------------------
// MARK: - Async utilities

private let bgSerialQueue = dispatch_queue_create("serial-worker", DISPATCH_QUEUE_SERIAL)
/// Run a function/closeure on a backround serial queue.
func onSerialQueue( closure: () -> () ) {
    dispatch_async(bgSerialQueue) {
        closure()
    }
}
/// Run a function/closeure on the main (UI) queue. If we are already on the main thread then just run the function/closure.
func onMainQueue( closure: () -> () ) {
    if (NSThread.isMainThread()) {
            closure()
    } else {
        dispatch_async(dispatch_get_main_queue()) {
            closure()
        }
    }
}

// -------------------------------------------------------------------------------------
// MARK: - Filesystem and URL utilities

func fileURL(filename: String) -> NSURL {
    // let fileURL = documentsURL().URLByAppendingPathComponent(filename)
    // TODO: Currently we only llok for resoruces, and not file in the Documents directory....
    let fileURL = resourceURL().URLByAppendingPathComponent(filename)
    return fileURL
}

func fileExists(filename: String) -> Bool {
    let url = fileURL(filename)
    let path = url.path
    let exists = NSFileManager.defaultManager().fileExistsAtPath(path!)
    return exists
}

func readFile(filename: String) throws -> String {
    let contentString = try String(contentsOfURL: fileURL(filename), encoding: NSUTF8StringEncoding)
    return contentString
}

func documentsURL() -> NSURL {
    let documentsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
    return documentsURL
}

func resourceURL() -> NSURL {
    return NSURL.fileURLWithPath(resourcePath())
}

func resourcePath() -> String {
    let path = NSBundle.mainBundle().resourcePath!
    return path
}

func debugDumpDir(dir: String) {
    NSLog("Dump \(dir)")
    let files = try! NSFileManager.defaultManager().contentsOfDirectoryAtPath(dir)
    NSLog("- files : \(files)")
}

// MARK: - Regular Expressions
//-----------------------------------------------------------------------------------------
// SwiftRegex.swift
// https://github.com/kasei/SwiftRegex/blob/master/SwiftRegex/SwiftRegex.swift
//
//  Created by Gregory Todd Williams on 6/7/14.
//  Copyright (c) 2014 Gregory Todd Williams. All rights reserved.
//


infix operator =~ {}

func =~ (value : String, pattern : String) -> RegexMatchResult {
    let nsstr = value as NSString // we use this to access the NSString methods like .length and .substringWithRange(NSRange)
    let options : NSRegularExpressionOptions = []
    do {
        let re = try  NSRegularExpression(pattern: pattern, options: options)
        let all = NSRange(location: 0, length: nsstr.length)
        var matches : Array<String> = []
        re.enumerateMatchesInString(value, options: [], range: all) { (result, flags, ptr) -> Void in
            guard let result = result else { return }
            let string = nsstr.substringWithRange(result.range)
            matches.append(string)
        }
        return RegexMatchResult(items: matches)
    } catch {
        return RegexMatchResult(items: [])
    }
}

struct RegexMatchCaptureGenerator : GeneratorType {
    var items: ArraySlice<String>
    mutating func next() -> String? {
        if items.isEmpty { return nil }
        let ret = items[items.startIndex]
        items = items[1..<items.count]
        return ret
    }
}

struct RegexMatchResult : SequenceType, BooleanType {
    var items: Array<String>
    func generate() -> RegexMatchCaptureGenerator {
        return RegexMatchCaptureGenerator(items: items[0..<items.count])
    }
    var boolValue: Bool {
        return items.count > 0
    }
    subscript (i: Int) -> String {
        return items[i]
    }
}
