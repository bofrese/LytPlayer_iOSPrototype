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


/////////// FAKE TEST DATA ////////////////


// TODO: Should be singelton

class Player : NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var audioPlayer = AVAudioPlayer()
    var currentBook = memoBook
    var currentPart = 0
    
    override init() {
        super.init()
        configureRemoteControlEvents()
        setupCurrentAudioPart()
    }
    
    func pause() {
        audioPlayer.pause()
        setupAudioActive(false)
        isPlaying = false
    }

    func nextAudioPart() {
        // TODO: Check for last part...
        setupCurrentAudioPart( currentPart + 1) { self.play() }
    }
    
    func previousAudioPart() {
        setupCurrentAudioPart( max(currentPart - 1, 0) ) { self.play() }
    }
    
    
    func setupCurrentAudioPart(partNo: Int = 0, success: () -> () = {} ) {
        if let url = currentBook.urlForPart( partNo ) {
            let part = currentBook.part(partNo )
            
            trimMP3(url, beginSec: part.begin, endSec: part.end ) { trimmedUrl in
                NSLog("Trimming of current part has completed ****************")
                do {
                    try self.audioPlayer = AVAudioPlayer(contentsOfURL: trimmedUrl )
                    self.audioPlayer.delegate = self
                    self.currentPart = partNo
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
        let part = currentBook.parts[currentPart]
        let status = "'\(currentBook.title)' (\(currentPart)/\(currentBook.parts.count)) \(part.file) \(part.begin)s - \(part.end)s"
        return status
    }
    
    
    func configureNowPlayingInfo() {
        let infoCenter = MPNowPlayingInfoCenter.defaultCenter()
        infoCenter.nowPlayingInfo = [
            // MPMediaItemPropertyMediaType: MPMediaType.AudioBook, // TODO
            MPMediaItemPropertyAlbumArtist: currentBook.author,
            MPMediaItemPropertyAlbumTitle: currentBook.parts[ currentPart].file, // TODO: Subtitle?
            MPMediaItemPropertyTitle: currentBook.title,
            MPNowPlayingInfoPropertyChapterNumber: currentPart,
            MPNowPlayingInfoPropertyChapterCount : currentBook.parts.count,
            MPMediaItemPropertyArtwork: MPMediaItemArtwork(image: currentBook.coverImage() ),
            MPMediaItemPropertyPlaybackDuration: currentBook.duration,
            MPMediaItemPropertyAlbumTrackNumber: 4, // TODO
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentBook.position,
        ]
    }
    
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
        /*
        commandCenter.previousTrackCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("previousTrackCommand \(event.description)")
            return .Success
        }
        commandCenter.previousTrackCommand.enabled = true
        
        commandCenter.nextTrackCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("nextTrackCommand \(event.description)")
            return .Success
        }
        commandCenter.nextTrackCommand.enabled = true
        */

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
    
    
    // Return true or false, is successfull or not.
    func setupAudioActive(active: Bool) -> Bool {
        var success = false
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            try audioSession.setActive(active, withOptions: .NotifyOthersOnDeactivation ) // ??? Options
            success = true
        } catch {
            NSLog("Error setting AudioSession")
        }
        return success
    }
    
    
    //////////////////////////////////////////////////////////////////////////////////////////
    //#pragma mark AVAudioPlayerDelegate
    
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


