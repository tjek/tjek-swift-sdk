//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import Foundation

@objc(SGNGraphConnection)
public class GraphConnection : NSObject {
    
    let timeout:NSTimeInterval
    let baseURL:NSURL

    public convenience override init() {
        self.init(baseURL:GraphConnection.defaultBaseURL, timeout:GraphConnection.defaultTimeout)
    }
    public convenience init(baseURL:NSURL) {
        self.init(baseURL:baseURL, timeout:GraphConnection.defaultTimeout)
    }
    public convenience init(timeout:NSTimeInterval) {
        self.init(baseURL:GraphConnection.defaultBaseURL, timeout:timeout)
    }
    public init(baseURL:NSURL, timeout:NSTimeInterval) {
        self.timeout = timeout
        self.baseURL = baseURL
    }
    
    
    public typealias RequestCompletionHandler = (graphResponse:GraphResponse?, urlResponse:NSHTTPURLResponse?, error:NSError?) -> Void
    public func start(request:GraphRequest, completion:RequestCompletionHandler?) {

        // build the network session for this connection (if not already built)
        if networkSession == nil {
            let config = NSURLSessionConfiguration.defaultSessionConfiguration()
            config.timeoutIntervalForRequest = timeout
            networkSession = NSURLSession(configuration: config)
        }

        // build the request data
        var jsonDict = [String:AnyObject]()
        
        jsonDict["query"] = request.query
        jsonDict["operationName"] = request.operationName
        jsonDict["variables"] = request.variables
        
        // TODO: clean variables to avoid JSONSerialization crash?
        
        // serialize the data (try to)
        if let jsonData = try? NSJSONSerialization.dataWithJSONObject(jsonDict, options:[]) {
            
            
            // build the url request
            let url:NSURL? = baseURL
            
            let urlRequest = NSMutableURLRequest(URL:url!)
            urlRequest.HTTPMethod = "POST"
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            
            urlRequest.HTTPBody = jsonData
            
            
            // `self` is strongly captured in this completion handler.
            // if no-one else is holding onto this connection, it will be deinit'd after completion is called
            let taskCompletion:(NSData?, NSURLResponse?, NSError?) -> (Void) = { (data, urlResponse, networkError) in
                
                // remove completed active task
                self.activeRequestTasks[request.identifier] = nil
                
                guard completion != nil else {
                    return
                }
                
                
                var graphResponse:GraphResponse? = nil
                let error = networkError
                
                // some response data, and it's parseable as JSON
                if data != nil,
                    let jsonObj = try? NSJSONSerialization.JSONObjectWithData(data!, options: []) {
                    
                    // TODO: check status code - if jsonObj contains error data then convert to Error
                    
                    
                    graphResponse = GraphResponse(responseObject: jsonObj)
                }
                else {
                    // no known data - ERROR!
                    // TODO: generate error if none available?
                }
                
                
                dispatch_async(dispatch_get_main_queue()) {
                    completion?(graphResponse:graphResponse, urlResponse:(urlResponse as? NSHTTPURLResponse), error:error)
                }
            }
            
            
            
            // create a dataTask for this urlRequest
            if let dataTask = networkSession?.dataTaskWithRequest(urlRequest, completionHandler: taskCompletion) {
                
                // save the request, keyed by the task Id
                self.activeRequestTasks[request.identifier] = dataTask
                
                dataTask.resume()
            }
        } else {
            // TODO: throw error if cant serialize input data?
        }
    }

    public func cancel(requestIdentifier:String? = nil) {
        if requestIdentifier != nil {
            if let task:NSURLSessionTask = self.activeRequestTasks[requestIdentifier!] {
                self.activeRequestTasks[requestIdentifier!] = nil
                task.cancel()
            }
            
        }
        else {
            self.activeRequestTasks = [:]
            networkSession?.invalidateAndCancel()
            networkSession = nil
        }
    }
    
    
    public static var defaultBaseURL:NSURL = NSURL(string: "https://graph.shopgun.com")!
    public static var defaultTimeout:NSTimeInterval = 60
    
    
    
    
    // MARK: Private
    
    private var activeRequestTasks:[String:NSURLSessionTask] = [:]
    private var networkSession:NSURLSession?
}

