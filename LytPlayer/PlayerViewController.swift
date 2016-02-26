//
//  PlayerViewController.swift
//  LytPlayer
//
//  Created by Bo Frese on 5/2-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

import UIKit
import AudioToolbox
import AVFoundation
import WebKit


class PlayerViewController: UIViewController, WKNavigationDelegate {

    var webView: WKWebView?
    let player = Player.sharedInstance

    // -----------------------------------------------------------------------
    // MARK: UI Outlets and Actions

    @IBOutlet weak var webViewPlaceholder: UIView!
    @IBOutlet weak var playPauseButton: UIButton!
    
    @IBAction func playButtonPressed(sender: UIButton) {
        if ( player.isPlaying() ) {
            player.pause()
        } else {
            player.play()
            self.player.whenNewPart( { self.scrollToCurrentPart()} )
        }
        updatePlayButton()
    }
    
    @IBAction func nextButtonPressed(sender: UIButton) {
        player.nextAudioPart()
        scrollToCurrentPart()
    }

    @IBAction func previousButtonPressed(sender: AnyObject) {
        player.previousAudioPart()
        scrollToCurrentPart()
    }

    // -----------------------------------------------------------------------
    // MARK: Update UI to current state
    
    func scrollToCurrentPart() {
        if let textId = player.currentPart().textId {
            NSLog("Scroll to textId \(textId)")
            
            if let isLoading = webView?.loading where isLoading == true {
                // TODO: Scroll after view has loaded....
                NSLog("We can not scroll when the view is still loading")
            } else {
                webView?.evaluateJavaScript("window.location.hash = '#\(textId)';", completionHandler: {
                    (obj: AnyObject?, err: NSError?) in
                    if let error = err {
                        NSLog("scroll failed \(error)")
                    } else {
                        NSLog("Scroll succeeded?")
                    }
                    
                } )
            }
        } else {
            NSLog("No textId defined for part")
        }
    }
    
    func updatePlayButton() {
        let buttonTitle = ( player.isPlaying() ? "Pause" : "Play")
        playPauseButton.setTitle(buttonTitle, forState: .Normal)
    }

    // Update the play/pause button state when re-emerging from the background.
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updatePlayButton()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let prefs = WKPreferences()
        let conf = WKWebViewConfiguration()
        prefs.javaScriptCanOpenWindowsAutomatically = true
        prefs.javaScriptEnabled = true
        prefs.minimumFontSize = 30  // No effect????
        conf.preferences = prefs
        
        self.webView = WKWebView(frame: self.webViewPlaceholder.bounds, configuration: conf) // instantiate WKWebView
        self.webView?.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.webView?.allowsBackForwardNavigationGestures = true
        self.webViewPlaceholder.addSubview(self.webView!)
        self.webView?.navigationDelegate = self
        self.webView?.allowsBackForwardNavigationGestures = true
        
        // TODO: Hardcoded content file name, should be taken from Book info.
        //if let path = NSBundle.mainBundle().pathForResource( "18716/18716" , ofType: "htm") {
        if let path = NSBundle.mainBundle().pathForResource( "37723/main" , ofType: "html") {
            let url  = NSURL.fileURLWithPath(path)
            let request = NSURLRequest(URL: url)
            webView?.loadRequest(request)
        }
    }

    // TODO: Not used - cleanup....
    func urlForFile( file: String ) -> NSURL? {
        //let fragment = "#pmsu00099"
        var url: NSURL?
        if let path = NSBundle.mainBundle().pathForResource(file, ofType: nil, inDirectory: "18716") {
            //path.appendContentsOf(fragment)
            url = NSURL.fileURLWithPath(path)
        }
        
        return url
    }
    
    
    // --------------------------------------------------------------------------
    // MARK: - WKNavigationDelegate
    // Handle user clikking on links in the webivew used to display book content.
    
    // Start the network activity indicator when the web view is loading
    func webView(webView: WKWebView,didStartProvisionalNavigation navigation: WKNavigation){
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    
    // Stop the network activity indicator when the loading finishes
    func webView(webView: WKWebView,didFinishNavigation navigation: WKNavigation){
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        scrollToCurrentPart()
    }
    
    // Policy when clicking the link - Links like 'filename.smil#id' should change audio player to relevant section.
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        NSLog("webView decidePolicyForNavigationAction... ")
        //NSLog( navigationAction.description)
        if let url = navigationAction.request.URL,
            let ext = url.pathExtension
        {
            if ( ext == "smil") {
                decisionHandler(.Cancel)
                if var smilFile = url.pathComponents?.last {
                    if let fragment = url.fragment {
                        smilFile = "\(smilFile)#\(fragment)"
                    }
                    NSLog("---->>>----- Trying to skip to partId: \(smilFile)")
                    player.playPartForId( smilFile )
                }

            } else {
                decisionHandler(.Allow)
            }
        } else {
            decisionHandler(.Allow)
        }
    }
    
    // Policy after we got the response - Just allow everything.... (we could remove this method)
    func webView(webView: WKWebView,
        decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse,decisionHandler: ((WKNavigationResponsePolicy) -> Void)){
            NSLog("webView decidePolicyForNavigationResponse....")
            NSLog(navigationResponse.response.description)
            decisionHandler(.Allow)
    }
    
    
    // ----------------------------------------------------------------------------------------------------
    // Autogenerated Boilerplate code (not touched yet)........

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

