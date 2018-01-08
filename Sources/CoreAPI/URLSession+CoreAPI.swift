//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension URLSession {
    func coreAPIDataTask(with urlRequest: URLRequest, completionHandler: @escaping (Result<Data>) -> Void) -> URLSessionDataTask {
        return dataTask(with: urlRequest) { (data, response, error) in
            let result = CoreAPI.parseAPIResponse(data: data, response: response, error: error)
            completionHandler(result)
        }
    }
    func coreAPIDataTask<R: Decodable>(with urlRequest: URLRequest, completionHandler: @escaping (Result<R>) -> Void) -> URLSessionDataTask {
        return coreAPIDataTask(with: urlRequest) { (dataResult: Result<Data>) in
            completionHandler(dataResult.decodeJSON())
        }
    }
}

extension CoreAPI {

    // Take the raw API response and turn it into a Result<Data>, parsing any API error json
    static func parseAPIResponse(data: Data?, response: URLResponse?, error: Error?) -> Result<Data> {

        guard let httpStatusCode = (response as? HTTPURLResponse)?.statusCode, let data = data else {
            let resError: Error
            if let err = error {
                resError = err
            } else {
                // TODO: Real error if no status code _AND_ no data _AND_ no error
                resError = NSError(domain: "Unknown network error", code: 123, userInfo: nil)
            }
            return .error(resError)
        }

        // client or server error - try to decode the error data
        guard (400...599).contains(httpStatusCode) == false else {
            let error: Error
            if var apiError = try? JSONDecoder().decode(CoreAPI.APIError.self, from: data) {
                apiError.httpResponse = response
                error = apiError
            } else {
                // TODO: Real error if client/server error with unknown data format
                let reason = HTTPURLResponse.localizedString(forStatusCode: httpStatusCode)

                ShopGunSDK.log("Unknown Server/Client Error: '\(reason)'", level: .error, source: .CoreAPI)
                error = NSError(domain: "Unknown Server/Client Error", code: 123, userInfo: nil)
            }

            return .error(error)
        }

        return .success(data)
    }
}

