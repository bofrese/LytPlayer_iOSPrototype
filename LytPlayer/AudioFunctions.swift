//
//  AudioFunctions.swift
//  LytPlayer
//
//  Created by Bo Frese on 18/2-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

//// TODO: Probably importing too much here....
import Foundation
//import AVKit
import AssetsLibrary
import AudioToolbox
import AVFoundation
//import MediaPlayer


func trimMP3(url: NSURL, fileName:String = "currentPlaying.m4a", beginSec: Double = 0.0, endSec: Double, success: (NSURL) -> ()) {
    
    let asset = AVAsset(URL: url)
    let documentsDirectory = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
    let trimmedSoundFileURL = documentsDirectory.URLByAppendingPathComponent(fileName)
    //NSLog("saving to \(trimmedSoundFileURL.absoluteString)")
    
    let filemanager = NSFileManager.defaultManager()
    if filemanager.fileExistsAtPath(trimmedSoundFileURL.absoluteString) {
        //// TODO: For some reason we never find it !?!?!?!???????
        NSLog("!!!!!!!!!!! output sound file exists !!!!!!!!!!")
        try! filemanager.removeItemAtURL(trimmedSoundFileURL)
    }
    //try! filemanager.createDirectoryAtURL(trimmedSoundFileURL, withIntermediateDirectories: true, attributes: nil)
    do {
        try filemanager.removeItemAtURL(trimmedSoundFileURL)
    } catch {
        /// Ignore....
    }
    
    
    if let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) {
        exporter.outputFileType =  AVFileTypeAppleM4A // AVFileTypeMPEGLayer3
        exporter.outputURL = trimmedSoundFileURL
        
        let duration = CMTimeGetSeconds(asset.duration)
        if (duration < endSec) {
            NSLog("sound is not long enough")
            return
        }
        let startTime = CMTimeMake( Int64(beginSec * 1000) , 1000)
        let stopTime = CMTimeMake( Int64(min(endSec * 1000, duration * 1000)), 1000)
        let exportTimeRange = CMTimeRangeFromTimeToTime(startTime, stopTime)
        NSLog("Export time range \(startTime.seconds)-\(stopTime.seconds) = \(exportTimeRange.duration.seconds) sec.")
        exporter.timeRange = exportTimeRange
        
        
        // do it
        exporter.exportAsynchronouslyWithCompletionHandler({
            switch exporter.status {
            case  AVAssetExportSessionStatus.Failed:
                NSLog("export failed \(exporter.error)")
            case AVAssetExportSessionStatus.Cancelled:
                NSLog("export cancelled \(exporter.error)")
            default:
                NSLog("export complete")
                let asset = AVAsset(URL: trimmedSoundFileURL)
                NSLog("Trimmed file \(url.pathComponents?.last) \(beginSec) - \(endSec) to file with duration\(CMTimeGetSeconds(asset.duration)) sec.")
                success( trimmedSoundFileURL)
            }
        })
        
    } else {
        NSLog("Failet to create AVAssestExportSession")
        NSLog("- Compatible Presets \(AVAssetExportSession.exportPresetsCompatibleWithAsset( asset) )" )
        NSLog("- Asset: \( asset.description)")
    }
}

