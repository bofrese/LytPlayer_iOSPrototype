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

// Convenience types and functions .......
typealias Callback = () -> ()
typealias NSErrorCallback = (NSError) -> ()


/**
Player:
This class is responsible for all interaction with the Audio layer in iOS.
No other classes should have any knowledge of which underlying audio playing framework is used!

This is a  Singelton! Use
 
        player = Player.sharedInstance
*/
@objc class Player : NSObject, AVAudioPlayerDelegate {
    var audioPlayer = AVQueuePlayer()
    var currentBook: Book?
    var currentPartNo = 0
    var newPartCallback: Callback?
    var authorizationFailedCallback: Callback?
    var playerItemFailedCallback: NSErrorCallback?
    var timePassedCallback: Callback? // TODO.
    let observerManager = ObserverManager() // For KVO - see: https://github.com/timbodeit/ObserverManager
    
    // ----------------------------------------------------------------------------------------------
    // MARK: - PUBLIC API ............
    
    static let sharedInstance = Player()
    private override init() {
        super.init()
        audioPlayer.actionAtItemEnd = .Advance
        configureRemoteControlEvents()
    }
    
    func loadBook(book: Book) {
        currentBook = book
        self.setupCurrentAudioPart(0) // TODO: Use lastMark when it is implemented
    }
    
    /// Register callback to use when changing to a new BookPart (to update UI f.ex.)
    func whenNewPart( cb: Callback) {
        newPartCallback = cb
    }
    /// Register callback to use when authorization to the server has failed, // TODO: (and we can not resolve login ourselves)
    func whenAuthorizationFailed( cb: Callback) {
        authorizationFailedCallback = cb
    }
    /// Register callback to use when playback of an item has failed , f.ex. network error. (TODO: Attempt auto recovery)
    func whenPlayerItemFailed( cb: NSErrorCallback) {
        playerItemFailedCallback = cb
    }

    /// Play currently loaded book
    func play() {
        guard let _ = currentBook else { NSLog("NO currentBook in \(#function)"); return }
        NSLog("\(#function)()...")

        // Verify that we are ready to play....
        if ( audioPlayer.status == .ReadyToPlay ) {
            NSLog("Player is READY")
            if let status = audioPlayer.currentItem?.status {
                switch status  {
                case AVPlayerItemStatus.ReadyToPlay :
                    NSLog("CurrentItem is READY")
                case AVPlayerItemStatus.Failed :
                    NSLog("CurrentItem is READY")
                default :
                    NSLog("CurrentItem is in an unkknown state...")
                }
            } else {
                NSLog("Player currentItem is in trouble: \(audioPlayer.currentItem.debugDescription)")
            }
        } else {
            NSLog("*** Player is NOT READY : \(audioPlayer.error?.localizedDescription) ***")
        }
        
        setupAudioActive(true)
        audioPlayer.play()
        configureNowPlayingInfo()
        NSLog("Player.play() book: \(currentStatus() )")
        self.notifyAboutNewPart()
    }

    func pause() {
        NSLog("\(#function)()...")
        audioPlayer.pause()
        // TODO: Register where we are so can continue were we stopped.
        setupAudioActive(false)
    }

    func stop() {
        NSLog("\(#function)()...")
        audioPlayer.pause() // AVPlayer does not have a stop method
        // TODO: Register where we are so can continue were we stopped.
        self.observerManager.deregisterAllObservers()
        self.audioPlayer.removeAllItems()
    }

    func isPlaying() -> Bool
    {
        return (audioPlayer.rate > 0.0);
    }
    
    func nextAudioPart() {
        guard let currentBook = currentBook else { NSLog("NO currentBook in \(#function)"); return }
        if ( currentPartNo < currentBook.parts.count ) {
            stop()
            setupCurrentAudioPart( currentPartNo + 1) { self.play() }
        } else {
            stop()
        }
    }
    
    func previousAudioPart() {
        setupCurrentAudioPart( max(currentPartNo - 1, 0) ) { self.play() }
    }
    
    func playPartForId( partId: String) {
        guard let currentBook = currentBook else { NSLog("NO currentBook in \(#function)"); return }
        NSLog("playPartForId(\(partId))...")
        if let partNo = currentBook.partNoForId( partId ) {
            setupCurrentAudioPart( partNo ) { self.play() }
        } else {
            NSLog("partId \(partId) not found")
            // TODO: More errorhandling.....
        }
    }
    
    func currentPart() -> BookPart? {
        guard let currentBook = currentBook else { NSLog("NO currentBook in \(#function)"); return nil }
        return currentBook.part(currentPartNo)
    }
    
    // ----------------------------------------------------------------------------------------------
    // MARK: - PRIVATE METHODS ..................
    
    /// Play the next part where the audio file is different from the current
    func nextAudioFile() {
        guard let _ = currentBook else { NSLog("NO currentBook in \(#function)"); return }
        if let newPartNo = partNoForNextAudioFile(currentPartNo) {
            setupCurrentAudioPart( newPartNo) { self.play() }
        }
    }
    
    /// Given a start Part number, find the first following part where the audio file is different
    func partNoForNextAudioFile( startNo: Int ) -> Int? {
        guard let currentBook = currentBook else { NSLog("NO currentBook in \(#function)"); return nil }
        let startFile = currentBook.part(startNo).file
        var newFile = startFile
        var newPartNo = startNo + 1
        while ( newPartNo < currentBook.parts.count ) { // TODO: Shouldnt access parts directly?
            newFile = currentBook.part(newPartNo).file
            if ( newFile != startFile ) {
                return newPartNo
            } else {
                newPartNo += 1
            }
        }
        return nil
    }
    
    /// Setup the provided part number as the current, and prepare to play it.
    func setupCurrentAudioPart(partNo: Int = 0, success: () -> () = {} ) {
        guard let _ = currentBook else { NSLog("NO currentBook in \(#function)"); return }
        NSLog("setupCurrentAudioPart( \(partNo)) ...")
        self.stop()
        self.setupAudioPlayerObservers()
        NSLog("setupCurrentAudioPart() - audioPlayer Initialized ...")
        self.currentPartNo = partNo
        addItemToPlayerQueue(self.currentPartNo)
        success()
    }
    
    /// Added a player item for a given part to the play queue, and setup observers to automatically schedule the following parts.
    func addItemToPlayerQueue( partNo: Int ) {
        guard let currentBook = currentBook else { NSLog("NO currentBook in \(#function)"); return }
        if let url = currentBook.urlForPart( partNo ) {
            NSLog("Add to Queue: \(url.lastPathComponent) from URL: \(url)")
            let asset = AVURLAsset(URL: url)
            let item = AVPlayerItem.init(asset: asset, automaticallyLoadedAssetKeys: ["duration","playable","tracks"]) // Asset keys that need to be present before the item is 'ready'
            self.setupPlayerItemObservers(item, partNo: partNo)
            self.audioPlayer.insertItem(item, afterItem: nil) // append item to player queue
        }
    }
    
    func setupPlayerItemObservers(item: AVPlayerItem, partNo: Int) {
        item.whenChanging("status", manager: observerManager ) { item in
            NSLog("++ ItemObserver Callback on \(NSThread.currentThread().name)")
            switch item.status {
            case .Failed :
                NSLog("--> PlayerItem FAILED: \(item.asset.debugDescription)")
            case .ReadyToPlay :
                NSLog("--> PlayerItem READY: \(item.asset.debugDescription)")
                if let nextPartNo =  self.partNoForNextAudioFile(partNo) {
                    self.addItemToPlayerQueue(nextPartNo)
                }
            case .Unknown :
                NSLog("--> PlayerItem UNKNOWN status: \(item.asset.debugDescription)")
            }
            
            if let error = item.error {
                NSLog("--- Item Error: \(error.localizedDescription) reason: \(error.localizedFailureReason) - UserInfo: \(error.userInfo.debugDescription)")
                if ( error.code == NSURLErrorUserAuthenticationRequired ) { // Error codes: http://nshipster.com/nserror/
                    NSLog("*** Authentication Required !!!! ***")
                    // TODO: Callback to UI ? Deal with Authentication .....
                    // TODO: Remember where we where. Check if something is playing? (then what??)
                    self.pause() // TODO: Can we just resume when we come back???
                    self.authorizationFailedCallback?()
                } else {
                    NSLog("*** UNHANDLED ERROR !!!! ***")
                    // TODO: Deal with other item errors .......
                    self.playerItemFailedCallback?(error)
                }
            }
        }
    }
    
    
    

    // Return a simple string for debug output etc.
    func currentStatus() -> String {
        guard let currentBook = currentBook else { NSLog("NO currentBook in \(#function)"); return "No current Book" }
        let part = currentBook.parts[currentPartNo]
        let status = "'\(currentBook.title)' (\(currentPartNo)/\(currentBook.parts.count)) \(part.file) \(part.begin)s - \(part.end)s"
        return status
    }
    
    // Now playing info is showed on the lock screen and the controll center.
    func configureNowPlayingInfo() {
        guard let currentBook = currentBook else { NSLog("NO currentBook in \(#function)"); return }
        NSLog("\(#function)()...")
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
    
    
    // Return true or false, if successfull or not.
    func setupAudioActive(active: Bool) -> Bool {
        NSLog("\(#file).\(#function)( \(active) )...")
        var success = false
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            try audioSession.setActive(active, withOptions: .NotifyOthersOnDeactivation ) // ??? Options
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Player.audioSessionInterrupted), name: AVAudioSessionInterruptionNotification, object: audioSession)
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Player.audioSessionRouteChanged), name: AVAudioSessionRouteChangeNotification, object: audioSession)

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
    // MARK: Notification Methods
    // All callbacks are guaranteed to be called on the Main Thread
    
    func notifyAboutPlayerFailed( error: NSError ) {
        onMainQueue() {
            self.playerItemFailedCallback?(error)
        }
    }
    
    func notifyAboutNewPart() {
        onMainQueue() {
            self.newPartCallback?()
        }
    }
    
    func notifyAboutAuthorizationFailed() {
        onMainQueue() {
            self.authorizationFailedCallback?()
        }
    }
    
    
    // -----------------------------------------------------------------------------------------------------
    // MARK: AVQueuePlayer Events 

    var _timeObserver:AnyObject?
    var _boundarybserver:AnyObject?
    /// Setup Observers for AVQueuePlayer
    func setupAudioPlayerObservers() {

        audioPlayer.whenChanging("currentItem", manager: observerManager) { player in
            NSLog("==> AudioPlayer new current item \(player.currentItem?.asset.debugDescription)")
            self.notifyAboutNewPart()
            
            // TODO: Generate events on parts whithin this audio file.
            if let observer = self._boundarybserver  {
                self.audioPlayer.removeTimeObserver(observer)
                self._boundarybserver = nil
            }
            // TODO: To get the real boundaries we need to find the new current part....
            let boundaries: [NSValue] = [
                NSValue( CMTime: CMTime(seconds:  7, preferredTimescale: 1) ),
                NSValue( CMTime: CMTime(seconds: 12, preferredTimescale: 1) ),
                NSValue( CMTime: CMTime(seconds: 27, preferredTimescale: 1) ),
            ]
            self._boundarybserver = self.audioPlayer.addBoundaryTimeObserverForTimes(boundaries, queue: dispatch_get_main_queue() ) {
                let seconds = CMTimeGetSeconds((self.audioPlayer.currentItem?.currentTime())!)
                let asset = self.audioPlayer.currentItem?.asset
                NSLog("### Passed Boundary to new Part. \(seconds) into \(asset?.debugDescription)")
            }
        }
        audioPlayer.whenChanging("status", manager: observerManager) { player in
            switch( player.status) {
            case .Failed :
                NSLog("*** Player Failed!")
            case .ReadyToPlay :
                NSLog("+++ Player is ready to play!")
            case .Unknown :
                NSLog("??? Player is in UNKNOWN state ???")
            }
        }
        audioPlayer.whenChanging("rate", manager: observerManager) { player in
            let playingState = ( player.rate > 0 ? "Playing" : "Paused")
            NSLog("==> Got new rate \(player.rate) - Player is \(playingState)" )
        }
        if ( _timeObserver == nil) {
            _timeObserver = audioPlayer.addPeriodicTimeObserverForInterval(CMTime(seconds: 5, preferredTimescale: 1), queue: dispatch_get_main_queue() ) {
                cmtime in
                let seconds = CMTimeGetSeconds(cmtime)
                NSLog("... \(seconds) has passed...")
                // TODO: Call callback....
            }
        }
    }
    
    func removeAudioPlayerObservers() {
        observerManager.deregisterObserversForObject(audioPlayer)
        if let observer = _timeObserver  {
            audioPlayer.removeTimeObserver(observer)
            _timeObserver = nil
        }
    }
    

    // Called whenever we get interrupted (by f.ex. phone call, Alarm clock, etc.)
    func audioSessionInterrupted(notification:NSNotification)
    {
        // TODO: Deal with interruptions  
        // (The Apps AudioSession has been deactivated by the system? 
        // - Adjust App settings accordingly - Pause AVQueuuePlayer, adjust UI?
        // TODO: Do we get both an interrupt begin and and interrupt end event?
        NSLog("*** AVAudioSessionInterruptionNotification interruption received: \(notification)")
        
    }

    // Called whenever we the audio route is changed (f.ex. switch to headset og AirPlay) // TODO: Check up on this.
    // https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioHardwareRouteChanges/HandlingAudioHardwareRouteChanges.html#//apple_ref/doc/uid/TP40007875-CH5-SW1
    func audioSessionRouteChanged(notification:NSNotification)
    {
        // TODO: Deal with route change - Unplug headset should pause audio (according to Apple HIG)
        NSLog("*** AVAudioSessionRouteChangeNotification interruption received: \(notification)")
    }

    
    /* Currently unused. Replaced by KVO on AVPlayerItems
    // Setup callbacks.
    func listenForEndOfAudio( audio: AVPlayerItem ) {
        let center = NSNotificationCenter.defaultCenter()
        center.removeObserver(self)
        center.addObserver(self, selector: "endOfAudio", name: AVPlayerItemDidPlayToEndTimeNotification, object: audio)
    }
    
    // Called back from AVQueuePlayer on AVPlayerItemDidPlayToEndTimeNotification
    func endOfAudio() {
        NSLog("------ END OF ITEM!!!!! ----- AVPlayerItemDidPlayToEndTimeNotification received...")
        //self.nextAudioPart()
        NSLog("****************** nextAudioFile DISABLED *********************")
        // TODO: self.nextAudioFile() // Skip parts until its a new mp3 file
    }
    */

    // -----------------------------------------------------------------------------------------------------
    
    // Configure playback control from the remote control center. 
    // Visible when swiping up from the bottom even when other Apps are in the forground,
    // and on the lockscreen while this App is the 'NowPlaying' App.
    // NOTE: There are apparently limit to how many events that can be controlled (3?). 
    //       defining any more, will not make them show in the controll center, but they will
    //       still work via f.ex.  the headset remote controll events (if applicable)
    func configureRemoteControlEvents() {
        NSLog("\(#function)()...")
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
        // Headset remote sends this signal on single click .....
        commandCenter.togglePlayPauseCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
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
        
        // Can be sent by double-clicking on the headset remote
        commandCenter.nextTrackCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("nextTrackCommand \(event.description)")
            self.nextAudioPart()
            return .Success
        }
        commandCenter.nextTrackCommand.enabled = true
        
        // Currently unsure what can send this ????
        commandCenter.changePlaybackRateCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("changePlaybackRateCommand \(event.description)")
            return .Success
        }
        commandCenter.changePlaybackRateCommand.enabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [ 0.5, 1.0, 1.5, 2.0 ]
        
        
        // Not shure what sends this event?
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

        
        // Not room in the command center for both skip forward/backward and previous/next track ?
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

        // Command center has a build in bookmark function. Do we want to use that? If we enable it, there are apparently not room for previous/next track
        /*
        commandCenter.bookmarkCommand.addTargetWithHandler { (event) -> MPRemoteCommandHandlerStatus in
            NSLog("bookmarkCommand \(event.description)")
            return .Success
        }
        commandCenter.bookmarkCommand.enabled = false
        */
    }
    
}



/////////// BACKUP COPY OF PREVIOUS EXPERIEMTNS ///////////////////////



/* TODO: Try this..... - to add meta data about BookPart to AVPlayerItems

class BookPartPlayerItem : AVPlayerItem  {
    var bookPart: BookPart
    
    //                 let item = AVPlayerItem(URL: url)

    init(url: NSURL, bookPart: BookPart) {
        super.init(URL: url)
        self.bookPart = bookPart
    }
}

*/
    /*
    // Setup audioplayer for the current audiopart (and prepare for the following parts)
    func __EXPERIMENT2_setupCurrentAudioPart(partNo: Int = 0, success: () -> () = {} ) {
        guard let currentBook = currentBook else { NSLog("NO currentBook in \(__FUNCTION__)"); return }
        NSLog("setupCurrentAudioPart( \(partNo)) ...")
        
        self.observerManager.deregisterAllObservers()
        self.audioPlayer.removeAllItems()
        self.setupAudioPlayerObservers()
        
        onSerialQueue() {
            var newPartNo = partNo
            
            repeat {
                if let url = currentBook.remoteUrlForPart( newPartNo ) {
                    NSLog("Add to Queue: \(url.lastPathComponent) from URL: \(url)")
                    
                    //let item = AVPlayerItem(URL: url)
                    let asset = AVURLAsset(URL: url)
                    let item = AVPlayerItem.init(asset: asset, automaticallyLoadedAssetKeys: ["duration","playable","tracks"])
                    self.setupPlayerItemObservers(item)
            
                    
                    self.audioPlayer.insertItem(item, afterItem: nil) // append item to player queue
                }
                if let no =  self.partNoForNextAudioFile(newPartNo) {
                    newPartNo = no
                } else {
                    newPartNo = -1
                }
            } while ( newPartNo > 0 ) //  && newPartNo < 50 ) // TEMPORARY EXPERIMEMT
        }
        success() // TODO: Should we wait with this until the first item is added to the queue ?
    }
    */
    
    /*
    func _EXPERIMENT1_setupCurrentAudioPart(partNo: Int = 0, success: () -> () = {} ) {
        guard let currentBook = currentBook else { NSLog("NO currentBook in \(__FUNCTION__)"); return }
        NSLog("setupCurrentAudioPart( \(partNo)) ...")
        
        
        // ................ EXPERIMENTAL QUEUE PLAYER ...................
        
        self.observerManager.deregisterAllObservers()
        self.audioPlayer.removeAllItems()
        var playerItems: [AVPlayerItem] = []

        // FIXME: Write this in a more swifty way.....
        var newPartNo = partNo
        
        repeat {
            if let url = currentBook.remoteUrlForPart( newPartNo ) {
                NSLog("Add to Queue: \(url.lastPathComponent) from URL: \(url)")
                
                //let item = AVPlayerItem(URL: url)
                let asset = AVURLAsset(URL: url)
                let item = AVPlayerItem.init(asset: asset, automaticallyLoadedAssetKeys: ["duration","playable","tracks"])
                
                item.whenChanging("status", manager: observerManager ) { item in
                    //NSLog("--> New status for PlayerItem asset: \(item.asset.debugDescription) Status=\(item.status.rawValue)")
                    switch item.status {
                    case .Failed :
                        NSLog("--> PlayerItem FAILED: \(item.asset.debugDescription)")
                    case .ReadyToPlay :
                        NSLog("--> PlayerItem READY: \(item.asset.debugDescription)")
                    case .Unknown :
                        NSLog("--> PlayerItem UNKNOWN status: \(item.asset.debugDescription)")
                    }
                    
                    if let error = item.error {
                        NSLog("--- Item Error: \(error.localizedDescription) reason: \(error.localizedFailureReason) - UserInfo: \(error.userInfo.debugDescription)")
                        if ( error.code == NSURLErrorUserAuthenticationRequired ) { // Error codes: http://nshipster.com/nserror/
                            NSLog("*** Authentication Required !!!! ***")
                            // TODO: Callback to UI ? Deal with Authentication .....
                            // TODO: Remember where we where. Check if something is playing? (then what??)
                            self.stop()
                        }
                    }
                }

                /* Not sure we need this?
                item.whenChanging("loadedTimeRanges", manager: observerManager ) { item in
                    NSLog("--> New loadedTimeRanges for PlayerItem: \(item.asset.debugDescription) LoadedRange=\(item.loadedTimeRanges.debugDescription)")
                }
                */
                
                playerItems.append(item)
            }
            if let no =  partNoForNextAudioFile(newPartNo) {
                newPartNo = no
            } else {
                newPartNo = -1
            }
        } while ( newPartNo > 0 ) //  && newPartNo < 50 ) // TEMPORARY EXPERIMEMT

        /*
        if let firstItem = playerItems.first {
            self.listenForEndOfAudio(firstItem)
        }
        */
        
        //////// TODOD: Does this make it hang???   
        //let reducedPlayerItems : [AVPlayerItem] = Array( playerItems[0...5] )
        //audioPlayer = AVQueuePlayer(items: reducedPlayerItems )
        
        onSerialQueue() {
            self.audioPlayer = AVQueuePlayer(items: playerItems)
            self.setupAudioPlayerObservers()
            
        }
        
        //TODO: Not sure we should call this here. Only when begin playing... self.newPartCallback?()
        success()
        return // ........................ END EXPERIMENT ..............
        ////////////////////////////////////////////////////////////////
    

        
        
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
            if ( self.currentPart()!.begin > 0 ) {
                NSLog("We need to skip to \(self.currentPart()!.begin)")
                let startTime = CMTimeMake( Int64(self.currentPart()!.begin * 1000) , 1000)
                self.audioPlayer.seekToTime( startTime ) // FIXME: Do we need to wait for the item to be ready?
            }
            
            self.newPartCallback?()
            success()
        } else {
            NSLog("mp3 not found")
        }
    }
    */



