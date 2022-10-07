import Foundation
import Future

extension Future {
    public init(async: @escaping () async -> Response) {
        self.init { cb in
            Task {
                let response = await async()
                cb(response)
            }
        }
    }
    
    public init<SuccessType>(asyncThrows: @escaping () async throws -> SuccessType) where Response == Result<SuccessType, Error> {
        self.init { cb in
            Task {
                let result: Result<SuccessType, Error>
                do {
                    let response = try await asyncThrows()
                    result = .success(response)
                } catch {
                    result = .failure(error)
                }
                cb(result)
            }
        }
    }
}

extension Future {
    public func awaitable() async -> Response {
        await withCheckedContinuation { continuation in
            self.run { response in
                continuation.resume(returning: response)
            }
        }
    }
    public func awaitable<T, E: Error>() async throws -> T where Response == Result<T, E> {
        try await withCheckedThrowingContinuation { continuation in
            self.run { response in
                continuation.resume(with: response)
            }
        }
    }
}
