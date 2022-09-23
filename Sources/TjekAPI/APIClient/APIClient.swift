///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

import Foundation

public actor APIClient {
    public typealias ResponseListener = (URLRequest, Result<HTTPURLResponse, APIError>) async -> Void
    
    public let baseURL: URL
    let session: URLSession
    var willSendRequest: URLRequestBuilder
    var didReceiveResponse: ResponseListener
    let defaultJSONEncoder: JSONEncoder
    
    public init(
        baseURL: URL,
        urlSession: URLSession = URLSession(configuration: .default),
        defaultJSONEncoder: JSONEncoder = JSONEncoder(),
        willSendRequest: @escaping URLRequestBuilder = { _ in },
        didReceiveResponse: @escaping ResponseListener = { _, _ in }
    ) {
        self.baseURL = baseURL
        self.willSendRequest = willSendRequest
        self.didReceiveResponse = didReceiveResponse
        self.session = urlSession
        self.defaultJSONEncoder = defaultJSONEncoder
    }
    
    public func addWillSendRequestBuilder(_ builder: @escaping URLRequestBuilder) {
        let prevReqBuilder = self.willSendRequest
        self.willSendRequest = { urlReq in
            try await prevReqBuilder(&urlReq)
            try await builder(&urlReq)
        }
    }
    public func addDidReceiveResponseListener(_ listener: @escaping ResponseListener) {
        let prevResponseListener = self.didReceiveResponse
        self.didReceiveResponse = { urlReq, result in
            await prevResponseListener(urlReq, result)
            await listener(urlReq, result)
        }
    }
    
    public func send<ResponseType>(_ request: APIRequest<ResponseType>) async -> Result<ResponseType, APIError> {
        await send(request, retryCount: 0)
    }
    
    public func sendThrowable<ResponseType>(_ request: APIRequest<ResponseType>) async throws -> ResponseType {
        try await send(request, retryCount: 0).get()
    }
    
    fileprivate func send<ResponseType>(_ request: APIRequest<ResponseType>, retryCount: Int) async -> Result<ResponseType, APIError> {
        do {
            var urlRequest: URLRequest
            do {
                // let the request build the URLRequest
                urlRequest = try await request.generateURLRequest(baseURL: self.baseURL, defaultJSONEncoder: defaultJSONEncoder)
                // let the client tweak the URLRequest before sending
                try await willSendRequest(&urlRequest)
            } catch let encodeError {
                throw APIError.unencodableRequest(error: encodeError)
            }
            
            do {
                let data: Data
                let urlResponse: URLResponse
                do {
                    (data, urlResponse) = try await session.data(for: urlRequest)
                } catch let networkError {
                    throw APIError.network(error: networkError)
                }
                
                guard let httpResponse = urlResponse as? HTTPURLResponse else {
                    throw APIError.failedRequest(urlResponse: urlResponse)
                }
                if (200..<300).contains(httpResponse.statusCode) {
                    do {
                        // Successfully decoded the expected ResponseType!
                        let decodedResponse = try await request.responseDecoder.decode(data)
                        await self.didReceiveResponse(urlRequest, .success(httpResponse))
                        return .success(decodedResponse) // 👈 Success!
                    } catch let decodeError {
                        throw APIError.decode(error: decodeError, data: data)
                    }
                } else if let errorResponse = try? JSONDecoder().decode(APIError.ServerResponse.self, from: data) {
                    // We got a specific error object in the server's response.
                    throw APIError.server(errorResponse, httpResponse: httpResponse)
                } else if let stringResponse = String(data: data, encoding: .utf8) {
                    // We got some error data in the server's response, but we cant decode it.
                    throw APIError.undecodableServer(stringResponse, httpResponse: httpResponse)
                } else {
                    throw APIError.failedRequest(urlResponse: urlResponse)
                }
            } catch let apiError as APIError {
                await self.didReceiveResponse(urlRequest, .failure(apiError))
                throw apiError
            }
        } catch {
            let apiError = (error as? APIError) ?? .unknown(error: error)
            if request.shouldRetry.predicate(retryCount, apiError) {
                return await self.send(request, retryCount: retryCount + 1)
            } else {
                return .failure(apiError)
            }
        }
    }
}

fileprivate struct APIClientDestroyed: Error { }

extension APIClient {
    /// A callback version of the async `send` function
    public func send<ResponseType>(_ request: APIRequest<ResponseType>, completesOn: DispatchQueue = .main, completion: @escaping (Result<ResponseType, APIError>) -> Void) {
        Task { [weak self] in
            let result: Result<ResponseType, APIError>? = await self?.send(request)
            completesOn.async {
                completion(result ?? .failure(APIError.unknown(error: APIClientDestroyed())))
            }
        }
    }
}

#if canImport(Future)
import struct Future.Future

extension APIClient {
    public func send<ResponseType>(_ request: APIRequest<ResponseType>, completesOn: DispatchQueue = .main) -> Future<Result<ResponseType, APIError>> {
        .init(run: { [weak self] cb in
            Task { [weak self] in
                let result: Result<ResponseType, APIError>? = await self?.send(request)
                completesOn.async {
                    cb(result ?? .failure(APIError.unknown(error: APIClientDestroyed())))
                }
            }
        })
    }
}

#endif
