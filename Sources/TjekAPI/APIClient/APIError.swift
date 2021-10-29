///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

import Foundation

public enum APIError: Error {
    case server(ServerResponse, httpResponse: HTTPURLResponse)
    case undecodableServer(String, httpResponse: HTTPURLResponse)
    case unencodableRequest(error: Error)
    case network(error: Error, urlResponse: URLResponse?)
    case failedRequest(urlResponse: URLResponse?)
    case decode(error: Error, data: Data)
    case unknown(error: Error)
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .server(response, httpResponse):
            return "[Tjek.APIError: Server] \(response.message) (\(response.name)): \(response.details) ([\(httpResponse.statusCode)] \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode) ))"
        case let .undecodableServer(response, httpResponse):
            return "[Tjek.APIError: Undecodable Server] '\(response)' ([\(httpResponse.statusCode)] \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode) ))"
        case let .unencodableRequest(error):
            return "[Tjek.APIError: Unencodable Request] \(error.localizedDescription)"
        case let .network(error, _):
            return "[Tjek.APIError: Network] \(error.localizedDescription)"
        case let .decode(error, _):
            return "[Tjek.APIError: Decoding] \(error.localizedDescription)"
        case let .failedRequest(urlResponse):
            return "[Tjek.APIError: Failed Request] \(urlResponse?.debugDescription ?? "No URL response")"
        case let .unknown(error):
            return "[Tjek.APIError: Unknown] \(error.localizedDescription)"
        }
    }
}

extension APIError {
    public struct ServerResponse: Decodable {
        public var code: Int
        public var name: String
        public var message: String
        public var details: String

        // MARK: Decodable
        
        enum CodingKeys: String, CodingKey {
            case code, name, message, details
        }
        
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            
            self.code = try c.decode(Int.self, forKey: .code)
            self.name = try c.decode(String.self, forKey: .name)
            self.message = try c.decode(String.self, forKey: .message)
            self.details = try c.decode(String.self, forKey: .details)
        }
    }
    
    public var serverResponse: ServerResponse? {
        guard case let .server(response, _) = self else {
            return nil
        }
        return response
    }
}

extension APIError {
    public var httpURLResponse: HTTPURLResponse? {
        switch self {
        case .undecodableServer(_, let httpResponse),
             .server(_, let httpResponse):
            return httpResponse
        default:
            return nil
        }
    }
}
