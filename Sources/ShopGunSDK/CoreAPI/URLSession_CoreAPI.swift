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
    func coreAPIDataTask(with urlRequest: URLRequest, completionHandler: @escaping (Result<Data, Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: urlRequest) { (data, response, error) in
            let result = CoreAPI.parseAPIResponse(data: data, response: response, error: error)
            completionHandler(result)
        }
    }
    func coreAPIDataTask<R: Decodable>(with urlRequest: URLRequest, completionHandler: @escaping (Result<R, Error>) -> Void) -> URLSessionDataTask {
        return coreAPIDataTask(with: urlRequest) { (dataResult: Result<Data, Error>) in
            completionHandler(dataResult.decodeJSON())
        }
    }
}

extension CoreAPI {

    // Take the raw API response and turn it into a Result<Data>, parsing any API error json
    static func parseAPIResponse(data: Data?, response: URLResponse?, error: Error?) -> Result<Data, Error> {

        guard let httpStatusCode = (response as? HTTPURLResponse)?.statusCode, let data = data else {
            let resError: Error
            if let err = error {
                resError = err
            } else {
                resError = APIError.invalidNetworkResponseError(urlResponse: response)
            }
            return .failure(resError)
        }

        // client or server error - try to decode the error data
        guard (400...599).contains(httpStatusCode) == false else {
            let error: Error
            if var apiError = try? JSONDecoder().decode(CoreAPI.APIError.self, from: data) {
                apiError.httpResponse = response
                error = apiError
            } else {
                let reason = HTTPURLResponse.localizedString(forStatusCode: httpStatusCode)

                Logger.log("Unknown Server/Client Error: '\(reason)'", level: .error, source: .CoreAPI)
                
                error = APIError.unknownAPIError(httpStatusCode: httpStatusCode, urlResponse: response)
            }

            return .failure(error)
        }

        return .success(data)
    }
}
