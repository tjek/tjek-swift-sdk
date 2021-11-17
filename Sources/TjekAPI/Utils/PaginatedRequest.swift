///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

public struct PaginatedRequest<CursorType> {
    public var startCursor: CursorType
    public var itemCount: Int
    
    public init(start: CursorType, count: Int) {
        self.startCursor = start
        self.itemCount = count
    }
}

extension PaginatedRequest: Equatable where CursorType: Equatable { }

extension PaginatedRequest where CursorType == Int {
    public static func firstPage(_ count: Int = 24) -> Self {
        PaginatedRequest(start: 0, count: count)
    }
    
    public var nextPage: Self {
        PaginatedRequest(
            start: self.startCursor + self.itemCount,
            count: self.itemCount
        )
    }
}

extension PaginatedRequest where CursorType == String? {
    public static func firstPage(_ count: Int = 24) -> Self {
        PaginatedRequest(start: nil, count: count)
    }
}

// MARK: -

public struct PageInfo<CursorType> {
    public typealias CursorType = String
    
    public var lastCursor: CursorType?
    public var hasNextPage: Bool

    public init(lastCursor: CursorType?, hasNextPage: Bool) {
        self.lastCursor = lastCursor
        self.hasNextPage = hasNextPage
    }
}

extension PageInfo: Equatable where CursorType: Equatable { }

// MARK: -

public struct PaginatedResponse<ResultsType, CursorType> {
    public typealias CursorType = String
    
    public var results: [ResultsType]
    public var pageInfo: PageInfo<CursorType>
    
    public init(results: [ResultsType], pageInfo: PageInfo<CursorType>) {
        self.results = results
        self.pageInfo = pageInfo
    }
    
    /// An empty first page that has no next page
    public static var emptyFirstPage: Self {
        PaginatedResponse(results: [], pageInfo: .init(lastCursor: nil, hasNextPage: false))
    }
}

extension PaginatedResponse: Equatable where ResultsType: Equatable, CursorType: Equatable { }

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension PaginatedResponse where ResultsType: Identifiable {
    /// Appends the results of `nextPage` to the reciever. If `removeDuplicates` is true, it removes elements with matching IDs from the nextPage results before appending (this does not change the `pageInfo`, which simply replaces the current page info)
    public func appending(nextPage: PaginatedResponse<ResultsType, CursorType>, removeDuplicates: Bool) -> Self {
        var copy = self

        copy.pageInfo = nextPage.pageInfo
        
        if removeDuplicates && !results.isEmpty {
            let existingIds = Set(results.map(\.id))
            
            copy.results += nextPage.results.filter({
                !existingIds.contains($0.id)
            })
        } else {
            copy.results += nextPage.results
        }
        return copy
    }
}

extension PaginatedResponse {
    public func mapCursor<NewCursorType>(_ transform: (CursorType?) -> NewCursorType?) -> PaginatedResponse<ResultsType, NewCursorType> {
        PaginatedResponse<ResultsType, NewCursorType>(
            results: self.results,
            pageInfo: .init(
                lastCursor: transform(self.pageInfo.lastCursor),
                hasNextPage: self.pageInfo.hasNextPage
            )
        )
    }
    
    public func mapResults<NewResultsType>(_ transform: (ResultsType) -> NewResultsType) -> PaginatedResponse<NewResultsType, CursorType> {
        PaginatedResponse<NewResultsType, CursorType>(
            results: results.map(transform),
            pageInfo: pageInfo
        )
    }
}

extension PaginatedResponse where CursorType == Int {
    /// Build a String-based PaginatedResponse from an integer offset cursor
    public init(results: [ResultsType], expectedCount: Int, startingAtOffset: Int) {
        self.init(
            results: results,
            pageInfo: PageInfo(
                lastCursor: startingAtOffset + results.count,
                hasNextPage: results.count >= expectedCount
            )
        )
    }
    
    public func withStringCursor() -> PaginatedResponse<ResultsType, String> {
        self.mapCursor({ (oldCursor: Int?) -> String? in
            (self.results.isEmpty && oldCursor == 0) ? nil : oldCursor.map(String.init)
        })
    }
}

extension APIRequest {
    public func paginatedResponse<ResponseElement>(paginatedRequest: PaginatedRequest<Int>) -> APIRequest<PaginatedResponse<ResponseElement, Int>, VersionTag> where ResponseType == [ResponseElement] {
        self.map({
            PaginatedResponse(
                results: $0,
                expectedCount: paginatedRequest.itemCount,
                startingAtOffset: paginatedRequest.startCursor
            )
        })
    }
}

// MARK: -

#if canImport(Future)
import Future

extension Future {
    /// Makes a Future that repeatedly performs the paginatedFuture until the response says there are no more pages.
    public static func getAllPages<ResultsType, CursorType, ErrorType: Error>(
        for paginatedFuture: @escaping (_ afterCursor: CursorType?) -> Future<Result<PaginatedResponse<ResultsType, CursorType>, ErrorType>>
    ) -> Future<Result<[ResultsType], ErrorType>> {
        func getNextPage(after cursor: CursorType?, resultsSoFar: [ResultsType]) -> Future<Result<[ResultsType], ErrorType>> {
            paginatedFuture(cursor).flatMapResult({ paginatedResponse in
                if paginatedResponse.pageInfo.hasNextPage && paginatedResponse.pageInfo.lastCursor != nil {
                    return getNextPage(
                        after: paginatedResponse.pageInfo.lastCursor,
                        resultsSoFar: resultsSoFar + paginatedResponse.results
                    )
                } else {
                    return Future<Result<[ResultsType], ErrorType>>(
                        value: .success(resultsSoFar + paginatedResponse.results)
                    )
                }
            })
        }
        return getNextPage(after: nil, resultsSoFar: [])
    }
}

#endif
