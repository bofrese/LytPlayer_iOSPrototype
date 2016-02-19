//
//  SecondViewController.swift
//  LytPlayer
//
//  Created by Bo Frese on 5/2-16.
//  Copyright © 2016 nota.dk. All rights reserved.
//

import UIKit
import WebKit

class SecondViewController: UIViewController, WKNavigationDelegate  {

    @IBOutlet var webViewPlaceholder: UIView!  // WKWebView not available in Storybarod yet....
    var webView: WKWebView?
    
    override func viewWillAppear(animated: Bool) {
        
        
        super.viewWillAppear(animated)
    }
    
    // ............ WKNavigationDelegate ................
    
    // TODO: Intercept the following URL's.....
    // Afspil bog:  http://m.e17.dk/embedded/#book-player?book=37827
    // Download bog: http://zipit.e17.dk/ZipIt/get.aspx?session=10142992&book=37827&option=daisy
    
    
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
    
    // Policy when clicking the link
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        NSLog("webView decidePolicyForNavigationAction... ")
        NSLog( navigationAction.description)
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

    // TODO: Move to generic function lib.
    func showAlert(title: String, message: String, success: () -> () = {} ) {
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        
        alertController.addAction(UIAlertAction(title: "Ok", style: .Default, handler: { (action: UIAlertAction!) in
            NSLog("Handle Ok logic here")
            success()
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .Default, handler: { (action: UIAlertAction!) in
            NSLog("Handle Cancel Logic here")
        }))
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.

        let prefs = WKPreferences()
        let conf = WKWebViewConfiguration()
        prefs.javaScriptCanOpenWindowsAutomatically = true
        prefs.javaScriptEnabled = true
        conf.preferences = prefs
        
        self.webView = WKWebView(frame: self.webViewPlaceholder.bounds, configuration: conf) // instantiate WKWebView
        self.webView?.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.webView?.allowsBackForwardNavigationGestures = true
        self.webViewPlaceholder.addSubview(self.webView!)
        
        // https://nota.dk/bibliotek
        // http://m.e17.dk/  ?
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

