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

typealias Callback = () -> ()

/*
Player:
This class is responsible for all interaction with the Audio layer in iOS. 
No other classes should have any knowledge of which underlying audio playing framework is used!

This is a  Singelton! Use :
    player = Player.sharedInstance
*/

class Player : NSObject, AVAudioPlayerDelegate {
    var audioPlayer = AVQueuePlayer()
    var currentBook = book37723 // book18716 //  book39657 //  memoBook
    var currentPartNo = 0
    var newPartCallback: Callback?
    
    // ----------------------------------------------------------------------------------------------
    // MARK: - Public API ............
    
    static let sharedInstance = Player()
    private override init() {
        super.init()
        audioPlayer.actionAtItemEnd = .Advance
        configureRemoteControlEvents()
        setupCurrentAudioPart()
    }
    
    // Call this callback when changing to a new BookPart (to update UI f.ex.)
    func whenNewPart( cb: Callback) {
        newPartCallback = cb
    }

    func play() {
        setupAudioActive(true)
        audioPlayer.play()
        configureNowPlayingInfo()
        NSLog("Player.play() book: \(currentStatus() )")
    }

    func pause() {
        audioPlayer.pause()
        setupAudioActive(false)
    }

    func stop() {
        audioPlayer.pause() // TODO: AVPlayer does not have a stop method
    }

    func isPlaying() -> Bool
    {
        return (audioPlayer.rate > 0.0);
    }
    
    func nextAudioPart() {
        if ( currentPartNo < currentBook.parts.count ) {
            setupCurrentAudioPart( currentPartNo + 1) { self.play() }
        } else {
            audioPlayer.pause()  // TODO: AVPlayer does not have a stop method
        }
    }
    
    func nextAudioFile() {
        let currentFile = self.currentPart().file
        var newFile = currentFile
        var newPartNo = currentPartNo + 1
        while ( newPartNo < currentBook.parts.count ) { // TODO: Shouldnt access parts directly?
            newFile = currentBook.part(newPartNo).file
            if ( newFile != currentFile ) {
                setupCurrentAudioPart( newPartNo) { self.play() }
                return
            } else {
                newPartNo += 1
            }
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
    
    // ----------------------------------------------------------------------------------------------
    // MARK: - Private methods ..................
    
    func setupCurrentAudioPart(partNo: Int = 0, success: () -> () = {} ) {
        NSLog("setupCurrentAudioPart( \(partNo)) ...")
        
        // ............. LOCAL AUDIO ..................
        if let url = currentBook.localUrlForPart( partNo ) {
            let part = currentBook.part(partNo )
            
            trimMP3(url, beginSec: part.begin, endSec: part.end ) { trimmedUrl in
                NSLog("Trimming of current part has completed ****************")
                let playerItem = AVPlayerItem(URL: url )
                NSLog("setupCurrentAudioPart: URL= \(url)")
                self.audioPlayer.removeAllItems()
                self.audioPlayer.insertItem( playerItem, afterItem: nil)
                self.listenForEndOfAudio( playerItem )
                self.currentPartNo = partNo
                self.newPartCallback?()
                success()
            }
            
        // ............... REMOTE AUDIO ..................
        } else if let url = currentBook.remoteUrlForPart( partNo ) {
            
            let playerItem = AVPlayerItem(URL: url )
            NSLog("setupCurrentAudioPart: URL= \(url)")
            
            self.audioPlayer.removeAllItems()
            self.audioPlayer.insertItem( playerItem, afterItem: nil)
            listenForEndOfAudio( playerItem )
            
            // TODO: Check for availability...... Currently I get not errors????
            
            self.currentPartNo = partNo
            if ( self.currentPart().begin > 0 ) {
                NSLog("We need to skip to \(self.currentPart().begin)")
                let startTime = CMTimeMake( Int64(self.currentPart().begin * 1000) , 1000)
                self.audioPlayer.seekToTime( startTime ) // FIXME: Do we need to wait for the item to be ready?
            }
            
            self.newPartCallback?()
            success()
        } else {
            NSLog("mp3 not found")
        }
    }

    // Return a simple string for debug output etc.
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
            
            if ( self.isPlaying() ) {
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
        
        // Not shure what sends this event?
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
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "audioSessionInterrupted", name: AVAudioSessionInterruptionNotification, object: audioSession)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "audioSessionRouteChanged", name: AVAudioSessionRouteChangeNotification, object: audioSession)

            success = true

        } catch {
            NSLog("Error setting AudioSession!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
            // TODO: More error handling?
        }
        return success
    }
    
    
    
    func resetPlayer() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        audioPlayer.pause()
        audioPlayer.removeAllItems()
        setupAudioActive(false)
    }
    
    
    // -----------------------------------------------------------------------------------------------------
    // MARK: AVQueuePlayer Events 

    // Setup callbacks.
    func listenForEndOfAudio( audio: AVPlayerItem ) {
        let center = NSNotificationCenter.defaultCenter()
        center.removeObserver(self)
        center.addObserver(self, selector: "endOfAudio", name: AVPlayerItemDidPlayToEndTimeNotification, object: audio)
    }

    // Called whenever we get interrupted (by f.ex. phone call, Alarm clock, etc.)
    func audioSessionInterrupted(notification:NSNotification)
    {
        // TODO: Deal with interruptions  
        // (The Apps AudioSession has been deactivated by the system? 
        // - Adjust App settings accordingly - Pause AVQueuuePlayer, adjust UI?
        // TODO: Do we get both an interrupt begin and and interrupt end event?
        NSLog("AVAudioSessionInterruptionNotification interruption received: \(notification)")
        
    }

    // Called whenever we the audio route is changed (f.ex. switch to headset og AirPlay) // TODO: Check up on this.
    // https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioHardwareRouteChanges/HandlingAudioHardwareRouteChanges.html#//apple_ref/doc/uid/TP40007875-CH5-SW1
    func audioSessionRouteChanged(notification:NSNotification)
    {
        // TODO: Deal with route change - Unplug headset should pause audio (according to Apple HIG)
        NSLog("AVAudioSessionRouteChangeNotification interruption received: \(notification)")
    }

    
    // Called back from AVQueuePlayer on AVPlayerItemDidPlayToEndTimeNotification
    func endOfAudio() {
        NSLog("AVPlayerItemDidPlayToEndTimeNotification received...")
        //self.nextAudioPart()
        self.nextAudioFile() // Skip parts until its a new mp3 file
    }

    
    
    
    // -------------------------------------------------------------------------------------------------
    // MARK: - AVAudioPlayerDelegate - Deal with (background) playback events NOT USED with AVQueuePlayer!!!!
    // TODO: DELETE THESE..........
    
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


