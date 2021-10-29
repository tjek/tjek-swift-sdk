///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import Foundation
import TjekAPI
#if canImport(TjekPublicationReader)
import TjekPublicationReader
#endif

public struct TjekSDK {
    
    public struct Config {
        public var api: TjekAPI.Config
        #if canImport(TjekPublicationReader)
        public var publication: TjekPublicationReader.Config
        #endif
    }
    
    public static var api: TjekAPI { TjekAPI.shared }
    
    public static func initialize() {
        TjekAPI.initialize()
        TjekPublicationReader.initialize(api: .shared)
    }
    
    public static func initialize(config: Config) {
        TjekAPI.init(config: config.api)
        
        #if canImport(TjekPublicationReader)
        TjekPublicationReader.initialize(config: config.publication, api: .shared)
        #endif
    }
    
}
