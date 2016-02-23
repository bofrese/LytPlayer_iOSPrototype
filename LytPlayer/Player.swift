//
//  Player.swift
//  LytPlayer
//
//  Created by Bo Frese on 8/2-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation
import MediaPlayer



// Singelton! Use  player = Player.sharedInstance

typealias Callback = () -> ()

class Player : NSObject, AVAudioPlayerDelegate {
    
    var isPlaying = false
    var audioPlayer = AVAudioPlayer()
    var currentBook =  book18716 //  book39657 //  memoBook
    var currentPartNo = 0
    var newPartCallback: Callback?
    
    
    static let sharedInstance = Player()
    private override init() {
        super.init()
        configureRemoteControlEvents()
        setupCurrentAudioPart()
    }
    
    // Call this callback when changing to a new BookPart (to update UI f.ex.)
    func setCallback( cb: Callback) {
        newPartCallback = cb
    }
    
    func pause() {
        audioPlayer.pause()
        setupAudioActive(false)
        isPlaying = false
    }

    func stop() {
        audioPlayer.stop()
        isPlaying = false
    }

    func nextAudioPart() {
        if ( currentPartNo < currentBook.parts.count ) {
            setupCurrentAudioPart( currentPartNo + 1) { self.play() }
        } else {
            audioPlayer.stop()
        }
    }
    
    func previousAudioPart() {
        setupCurrentAudioPart( max(currentPartNo - 1, 0) ) { self.play() }
    }
    func playPartForId( partId: String) {
        NSLog("playPartForId(\(partId))...")
        if let partNo = currentBook.partNoForId( partId ) {
            setupCurrentAudioPart( partNo ) { self.play() }
        } else {
            NSLog("partId \(partId) not found")
            // TODO: More errorhandling.....
        }
    }
    func currentPart() -> BookPart {
        return currentBook.part(currentPartNo)
    }
    
    func setupCurrentAudioPart(partNo: Int = 0, success: () -> () = {} ) {
        NSLog("setupCurrentAudioPart( \(partNo)) ...")
        if let url = currentBook.urlForPart( partNo ) {
            let part = currentBook.part(partNo )
            
            trimMP3(url, beginSec: part.begin, endSec: part.end ) { trimmedUrl in
                NSLog("Trimming of current part has completed ****************")
                do {
                    try self.audioPlayer = AVAudioPlayer(contentsOfURL: trimmedUrl )
                    self.audioPlayer.delegate = self
                    self.currentPartNo = partNo
                    self.newPartCallback?()
                    success()
                } catch {
                        // TODO: ??? can happend on multiple fast click in UI - should be prevented!
                }
            }
            
        } else {
            NSLog("mp3 not found")
        }
    }
    func play() {
        setupAudioActive(true)
        audioPlayer.play()
        configureNowPlayingInfo()

        isPlaying = true
        NSLog("Player.play() book: \(currentStatus() )")
    }

    func currentStatus() -> String {
        let part = currentBook.parts[currentPartNo]
        let status = "'\(currentBook.title)' (\(currentPartNo)/\(currentBook.parts.count)) \(part.file) \(part.begin)s - \(part.end)s"
        return status
    }
    
    // Now playing info is showed on the lock screen and the controll center.
    func configureNowPlayingInfo() {
        let infoCenter = MPNowPlayingInfoCenter.defaultCenter()
        infoCenter.nowPlayingInfo = [
            // MPMediaItemPropertyMediaType: MPMediaType.AudioBook, // Not sure we need this, ot what it does....
            MPMediaItemPropertyAlbumArtist: currentBook.author,
            MPMediaItemPropertyAlbumTitle: currentBook.parts[ currentPartNo].file, // TODO: Subtitle? Section title?
            MPMediaItemPropertyTitle: currentBook.title,
            MPNowPlayingInfoPropertyChapterNumber: currentPartNo,
            MPNowPlayingInfoPropertyChapterCount : currentBook.parts.count,
            MPMediaItemPropertyArtwork: MPMediaItemArtwork(image: currentBook.coverImage() ),
            MPMediaItemPropertyPlaybackDuration: currentBook.duration,
            MPMediaItemPropertyAlbumTrackNumber: currentPartNo, // What is the difference between Chapter and Track number? Which should we use?
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentBook.position,
        ]
    }
    
    
    // Configure playback control from the remote control center. 
    // Visible when swiping up from the bottom even when other Apps are in the forground,
    // and on the lockscreen while this App is the 'NowPlaying' App.
    // NOTE: There are apparently limit to how many events that can be controlled (3?). 
    //       defining any more, will not make them show in the controll center, but they will
    //       still work via f.ex.  the headset remote controll events (if applicable)
    func configureRemoteControlEvents() {
        NSLog("Player.configureRemoteControlEvents()... ")
        let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
        commandCenter.playCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("playCommand")
            self.play()
            return .Success
        }
        commandCenter.pauseCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("pauseCommand")
            self.pause()
            return .Success
        }
        commandCenter.togglePlayPauseCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            // Headset remote sends this signal.....
            NSLog("togglePlayPauseCommand \(event.description)")
            if ( self.audioPlayer.playing) {
                self.pause()
            } else {
                self.play()
            }
            return .Success
        }
        
        commandCenter.previousTrackCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("previousTrackCommand \(event.description)")
            self.previousAudioPart()
            return .Success
        }
        commandCenter.previousTrackCommand.enabled = true
        
        commandCenter.nextTrackCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("nextTrackCommand \(event.description)")
            self.nextAudioPart()
            return .Success
        }
        commandCenter.nextTrackCommand.enabled = true
        

        commandCenter.changePlaybackRateCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("changePlaybackRateCommand \(event.description)")
            return .Success
        }
        commandCenter.changePlaybackRateCommand.enabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [ 0.5, 1.0, 1.5, 2.0 ]
        
        
        /*
        commandCenter.seekBackwardCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("seekBackwardCommand \(event.description)")
            return .Success
        }
        commandCenter.seekBackwardCommand.enabled = true
        
        commandCenter.seekForwardCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("seekForwardCommand \(event.description)")
            return .Success
        }
        commandCenter.seekForwardCommand.enabled = true
        */

        /*
        commandCenter.skipBackwardCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("skipBackwardCommand \(event.description)")
            return .Success
        }
        commandCenter.skipBackwardCommand.enabled = true

        commandCenter.skipForwardCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("skipForwardCommand \(event.description)")
            return .Success
        }
        commandCenter.skipForwardCommand.enabled = true
        */
        
        commandCenter.changePlaybackPositionCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("changePlaybackPositionCommand \(event.description)")
            return .Success
        }
        commandCenter.changePlaybackPositionCommand.enabled = true

        /*
        commandCenter.bookmarkCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("bookmarkCommand \(event.description)")
            return .Success
        }
        commandCenter.bookmarkCommand.enabled = false
        */
    }
    
    
    // Return true or false, if successfull or not.
    func setupAudioActive(active: Bool) -> Bool {
        var success = false
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            try audioSession.setActive(active, withOptions: .NotifyOthersOnDeactivation ) // ??? Options
            success = true
        } catch {
            NSLog("Error setting AudioSession")
            // TODO: More error handling?
        }
        return success
    }
    
    // -------------------------------------------------------------------------------------------------
    // MARK: - AVAudioPlayerDelegate - Deal with (background) playback events
    
    @objc func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        NSLog("AVAudioPlayerDelegate audioPlayerDidFinishPlaying book \(currentStatus() )")
        
        // TODO: More logic here to verify next part....
        nextAudioPart()
    }
    
    @objc func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer, error: NSError?) {
        NSLog("AVAudioPlayerDelegate audioPlayerDecodeErrorDidOccur book \(currentStatus() )")
    }
    
    @objc func  audioPlayerBeginInterruption(player: AVAudioPlayer) {
        NSLog("AVAudioPlayerDelegate audioPlayerBeginInterruption book \(currentStatus() )")
    }
    
    @objc func audioPlayerEndInterruption(player: AVAudioPlayer) {
        NSLog("AVAudioPlayerDelegate audioPlayerEndInterruption book \(currentStatus() )")
        play()
    }
    
}


