///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation

// MARK: - Publication Requests

extension APIRequest {
    /**
     A request that asks for a specific publication, based on its Id.
     
     - Parameters:
        - publicationId: The Id of the specific publication we are looking for.
     - Returns:
        An APIRequest with a response type of `Publication_v2`. This request is sent to the `v2` api.
     */
    public static func getPublication(withId publicationId: PublicationId) -> APIRequest<Publication_v2, API_v2> {
        APIRequest<Publication_v2, API_v2>(
            endpoint: "catalogs/\(publicationId)",
            method: .GET
        )
    }
    
    /**
     A request that returns a paginated list of publications, limited by the parameters.
     
     - Parameters:
        - businessIds: Limit the list of publications by the id of the business that published them.
        - storeIds: Limit the list of publications by the ids of the stores they cover.
        - near: Specify a coordinate to return publications in relation to. Also optionally limit the publications to within a max radius from that coordinate.
        - acceptedTypes: Choose which types of publications to return (defaults to all)
        - pagination: The count & cursor of the request's page. Defaults to the first page of 24 publications. `itemCount` must not be more than 100. `startCursor` must not be greater than 1000.
     - Returns:
        An APIRequest with a response type of a paginated array of `Publication_v2`. This request is sent to the `v2` api.
     */
    public static func getPublications(
        businessIds: Set<BusinessId> = [],
        storeIds: Set<StoreId> = [],
        near location: LocationQuery? = nil,
        acceptedTypes: Set<Publication_v2.PublicationType> = Set(Publication_v2.PublicationType.allCases),
        pagination: PaginatedRequest<Int> = .firstPage(24)
    ) -> APIRequest<PaginatedResponse<Publication_v2, Int>, API_v2> {
        
        var params = ["types": acceptedTypes.map(\.rawValue).joined(separator: ",")]
        params.merge(pagination.v2RequestParams()) { (_, new) in new }
        
        if !businessIds.isEmpty {
            params["dealer_ids"] = businessIds.map(\.rawValue).joined(separator: ",")
        }
        if !businessIds.isEmpty {
            params["store_ids"] = storeIds.map(\.rawValue).joined(separator: ",")
        }
        if let locationQ = location {
            params.merge(locationQ.v2RequestParams()) { (_, new) in new }
        }
        
        return APIRequest<[Publication_v2], API_v2>(
            endpoint: "catalogs",
            method: .GET,
            queryParams: params
        ).paginatedResponse(paginatedRequest: pagination)
    }
}

// MARK: - Offer Requests

extension APIRequest {
    /**
     A request that asks for a specific offer, based on its Id.
     
     - Parameters:
        - offerId: The Id of the specific offer we are looking for.
     - Returns:
        An APIRequest with a response type of `Offer_v2`. This request is sent to the `v2` api.
     */
    public static func getOffer(withId offerId: OfferId) -> APIRequest<Offer_v2, API_v2> {
        APIRequest<Offer_v2, API_v2>(
            endpoint: "offers/\(offerId)",
            method: .GET
        )
    }
    
    /**
     A request that returns a paginated list of offers, limited by the parameters.
     
     - Parameters:
        - publicationIds: Limit the list of offers by the id of the publication that its in.
        - businessIds: Limit the list of offers by the id of the business that published them.
        - storeIds: Limit the list of offers by the ids of the stores they are in.
        - near: Specify a coordinate to return offers in relation to. Also optionally limit the offers to within a max radius from that coordinate.
        - pagination: The count & cursor of the request's page. Defaults to the first page of 24 offers. `itemCount` must not be more than 100. `startCursor` must not be greater than 1000.
     - Returns:
        An APIRequest with a response type of a paginated array of `Offer_v2`. This request is sent to the `v2` api.
     */
    public static func getOffers(
        publicationIds: Set<PublicationId> = [],
        businessIds: Set<BusinessId> = [],
        storeIds: Set<StoreId> = [],
        near location: LocationQuery? = nil,
        pagination: PaginatedRequest<Int> = .firstPage(24)
    ) -> APIRequest<PaginatedResponse<Offer_v2, Int>, API_v2> {
        
        var params: [String: String] = [:]
        params.merge(pagination.v2RequestParams()) { (_, new) in new }

        if !publicationIds.isEmpty {
            params["catalog_ids"] = publicationIds.map(\.rawValue).joined(separator: ",")
        }
        
        if !businessIds.isEmpty {
            params["dealer_ids"] = businessIds.map(\.rawValue).joined(separator: ",")
        }
        
        if !storeIds.isEmpty {
            params["store_ids"] = storeIds.map(\.rawValue).joined(separator: ",")
        }
        
        if let locationQ = location {
            params.merge(locationQ.v2RequestParams()) { (_, new) in new }
        }

        return APIRequest<[Offer_v2], API_v2>(
            endpoint: "offers",
            method: .GET,
            queryParams: params
        ).paginatedResponse(paginatedRequest: pagination)
    }
}

// MARK: - Store Requests

public enum StoresRequestSortOrder: String {
    case nearest         = "distance"
    case businessNameA_Z = "dealer"
}

extension APIRequest {
    /**
     A request that asks for a specific store, based on its Id.
     
     - Parameters:
        - storeId: The Id of the specific store we are looking for.
     - Returns:
        An APIRequest with a response type of `Store_v2`. This request is sent to the `v2` api.
     */
    public static func getStore(withId storeId: StoreId) -> APIRequest<Store_v2, API_v2> {
        APIRequest<Store_v2, API_v2>(
            endpoint: "stores/\(storeId)",
            method: .GET
        )
    }
    
    /**
     A request that returns a paginated list of stores, limited by the parameters.
     
     - Parameters:
        - offerIds: Limit the list of stores by the ids of the offers it contains.
        - publicationIds: Limit the list of stores by the ids of the publications it has.
        - businessIds: Limit the list of stores by the ids of the businesses that run them.
        - near: Specify a coordinate to return stores in relation to. Also optionally limit the stores to within a max radius from that coordinate.
        - sortedBy: An array of sort keys, defining which order we want the stores returned in. If left empty the server decides.
        - pagination: The count & cursor of the request's page. Defaults to the first page of 24 stores. `itemCount` must not be more than 100. `startCursor` must not be greater than 1000.
     - Returns:
        An APIRequest with a response type of a paginated array of `Store_v2`. This request is sent to the `v2` api.
     */
    public static func getStores(
        offerIds: Set<OfferId> = [],
        publicationIds: Set<PublicationId> = [],
        businessIds: Set<BusinessId> = [],
        near location: LocationQuery? = nil,
        sortedBy sortOrder: [StoresRequestSortOrder] = [],
        pagination: PaginatedRequest<Int> = .firstPage(24)
    ) -> APIRequest<PaginatedResponse<Store_v2, Int>, API_v2> {
        
        var params: [String: String] = [:]
        params.merge(pagination.v2RequestParams()) { (_, new) in new }

        if !offerIds.isEmpty {
            params["offer_ids"] = offerIds.map(\.rawValue).joined(separator: ",")
        }
        
        if !publicationIds.isEmpty {
            params["catalog_ids"] = publicationIds.map(\.rawValue).joined(separator: ",")
        }
        
        if !businessIds.isEmpty {
            params["dealer_ids"] = businessIds.map(\.rawValue).joined(separator: ",")
        }
        
        if !sortOrder.isEmpty {
            params["order_by"] = sortOrder.map(\.rawValue).joined(separator: ",")
        }
        
        if let locationQ = location {
            params.merge(locationQ.v2RequestParams()) { (_, new) in new }
        }
        
        return APIRequest<[Store_v2], API_v2>(
            endpoint: "stores",
            method: .GET,
            queryParams: params
        ).paginatedResponse(paginatedRequest: pagination)
    }
}

// MARK: - Business Requests

extension APIRequest {
    /**
     A request that asks for a specific business, based on its Id.
     
     - Parameters:
        - businessId: The Id of the specific business we are looking for.
     - Returns:
        An APIRequest with a response type of `Business_v2`. This request is sent to the `v2` api.
     */
    public static func getBusiness(withId businessId: BusinessId) -> APIRequest<Business_v2, API_v2> {
        APIRequest<Business_v2, API_v2>(
            endpoint: "dealers/\(businessId)",
            method: .GET
        )
    }
}
