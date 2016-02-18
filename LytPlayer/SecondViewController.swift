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
        
        super.viewWillAppear(animated)
    }
    
    // ............ WKNavigationDelegate ................
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

