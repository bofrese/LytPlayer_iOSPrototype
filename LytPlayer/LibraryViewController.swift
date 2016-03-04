//
//  LibraryViewController.swift
//  LytPlayer
//
//  View to provide access to a webbased interface to the local library.
//  Intercepts URLS to listen to and download books
//
//  Created by Bo Frese on 5/2-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

import UIKit
import WebKit


class LibraryViewController: UIViewController, WKNavigationDelegate  {

    @IBOutlet var webViewPlaceholder: UIView!  // WKWebView not available in Storybarod yet....
    var webView: WKWebView?
    
    override func viewWillAppear(animated: Bool) {
        
        
        super.viewWillAppear(animated)
    }
    
    // MARK: WKNavigationDelegate ................
    
    
    
    /* Start the network activity indicator when the web view is loading */
    func webView(webView: WKWebView,didStartProvisionalNavigation navigation: WKNavigation){
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    
    /* Stop the network activity indicator when the loading finishes */
    func webView(webView: WKWebView,didFinishNavigation navigation: WKNavigation){
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }
    
    func webView(webView: WKWebView,
        decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse,decisionHandler: ((WKNavigationResponsePolicy) -> Void)){
            NSLog("webView decidePolicyForNavigationResponse....")
            NSLog(navigationResponse.response.description)
            decisionHandler(.Allow)
    }

    // Policy when clicking a link
    // Intercept the following URL's.....
    // Afspil bog:  http://m.e17.dk/embedded/#book-player?book=37827
    // Download bog: http://zipit.e17.dk/ZipIt/get.aspx?session=10142992&book=37827&option=daisy
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        NSLog("webView decidePolicyForNavigationAction... ")
        NSLog( navigationAction.debugDescription) // TODO: BUG: We crash with EXE_BAD_ACCESS here ?????
                                                  // Console output indicates we continiue? Maybe called twice???
        if let url = navigationAction.request.URL
        {
            let path       = url.absoluteString
            // let urlComponents = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
            let urlComponents = NSURLComponents(string: path)
            let queryItems = urlComponents?.queryItems
            NSLog("Components: \(urlComponents) Query Items: \(queryItems)")
            //let bookIdQuery     = queryItems?.filter( { $0.name == "book" }).first?.value
            
            let bookIdMatch = path =~ "book=([0-9]+)"
            let bookId = ( bookIdMatch ? bookIdMatch[0] : "unknown")

            NSLog("URL = \(path)")
            if ( path.hasPrefix("http://m.e17.dk/embedded/#book-player?book=")) {
                showAlert("Afspil", message: "Bogen vil blive streamet over nettet - dette kræver konstant netværks adgang under afspilningen. (\(bookId))") {
                    self.tabBarController?.selectedIndex = 0
                }
                decisionHandler(.Cancel)
                
            } else if ( path.hasPrefix("http://zipit.e17.dk/ZipIt/get.aspx?")) {
                showAlert("Download", message: "Vil du downloade hele bogen? Dette kræver meget netværkstrafik. Tilgendgæld kan du lytte til den uden at være on-line. Vi anbefaler at du er på WiFi mens du downloader (\(bookId))")
                decisionHandler(.Cancel)
                    
            } else {
                decisionHandler(.Allow)
            }
        } else {
            NSLog("Could not get URL and path ?????")
            decisionHandler(.Allow)
        }
    }

    
    
    // Create a WKWebView and load the local library
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let prefs = WKPreferences()
        let conf = WKWebViewConfiguration()
        prefs.javaScriptCanOpenWindowsAutomatically = true
        prefs.javaScriptEnabled = true
        conf.preferences = prefs
        
        self.webView = WKWebView(frame: self.webViewPlaceholder.bounds, configuration: conf) // instantiate WKWebView
        self.webView?.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.webView?.allowsBackForwardNavigationGestures = true
        self.webViewPlaceholder.addSubview(self.webView!)
        
        if let startUrl = NSURL(string:"https://nota.dk/bibliotek") {
            let request = NSURLRequest(URL: startUrl)
            webView?.loadRequest(request)
            webView?.navigationDelegate = self
            webView?.allowsBackForwardNavigationGestures = true
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

