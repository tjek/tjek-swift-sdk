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
    
    let timeout:TimeInterval
    let baseURL:URL

    public convenience override init() {
        self.init(baseURL:GraphConnection.defaultBaseURL, timeout:GraphConnection.defaultTimeout)
    }
    public convenience init(baseURL:URL) {
        self.init(baseURL:baseURL, timeout:GraphConnection.defaultTimeout)
    }
    public convenience init(timeout:TimeInterval) {
        self.init(baseURL:GraphConnection.defaultBaseURL, timeout:timeout)
    }
    public init(baseURL:URL, timeout:TimeInterval) {
        self.timeout = timeout
        self.baseURL = baseURL
    }
    
    
    public typealias RequestCompletionHandler = (_ graphResponse:GraphResponse?, _ urlResponse:HTTPURLResponse?, _ error:Error?) -> Void
    public func start(_ request:GraphRequest, completion:RequestCompletionHandler?) {

        // build the network session for this connection (if not already built)
        if networkSession == nil {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = timeout
            networkSession = URLSession(configuration: config)
        }

        // build the request data
        var jsonDict = [String:AnyObject]()
        
        jsonDict["query"] = request.query as AnyObject?
        jsonDict["operationName"] = request.operationName as AnyObject?
        jsonDict["variables"] = request.variables as AnyObject?
        
        // TODO: clean variables to avoid JSONSerialization crash?
        
        // serialize the data (try to)
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options:[]) {
            
            
            // build the url request
            var urlRequest = URLRequest(url:baseURL)
            urlRequest.httpMethod = "POST"
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            
            urlRequest.httpBody = jsonData
            
            
            // `self` is strongly captured in this completion handler.
            // if no-one else is holding onto this connection, it will be deinit'd after completion is called
            let taskCompletion:(Data?, URLResponse?, Error?) -> (Void) = { (data, urlResponse, networkError) in
                
                // remove completed active task
                self.activeRequestTasks[request.identifier] = nil
                
                guard completion != nil else {
                    return
                }
                
                
                var graphResponse:GraphResponse? = nil
                let error = networkError
                
                // some response data, and it's parseable as JSON
                if data != nil,
                    let jsonObj = try? JSONSerialization.jsonObject(with: data!, options: []) {
                    
                    // TODO: check status code - if jsonObj contains error data then convert to Error
                    
                    
                    graphResponse = GraphResponse(responseObject: jsonObj as AnyObject?)
                }
                else {
                    // no known data - ERROR!
                    // TODO: generate error if none available?
                }
                
                
                DispatchQueue.main.async {
                    completion?(graphResponse, (urlResponse as? HTTPURLResponse), error)
                }
            }
            
            
            // create a dataTask for this urlRequest
            if let dataTask = networkSession?.dataTask(with: urlRequest, completionHandler: taskCompletion) {
                
                // save the request, keyed by the task Id
                self.activeRequestTasks[request.identifier] = dataTask
                
                dataTask.resume()
            }
        } else {
            // TODO: throw error if cant serialize input data?
        }
    }

    public func cancel(_ requestIdentifier:String? = nil) {
        if requestIdentifier != nil {
            if let task:URLSessionTask = self.activeRequestTasks[requestIdentifier!] {
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
    
    
    public static var defaultBaseURL:URL = URL(string: "https://graph.shopgun.com")!
    public static var defaultTimeout:TimeInterval = 60
    
    
    
    
    // MARK: Private
    
    fileprivate var activeRequestTasks:[String:URLSessionTask] = [:]
    fileprivate var networkSession:URLSession?
}

