import ShopGunSDK

extension ShopGunSDK {
    public static func configureForPlaygroundDevelopment() {
        let creds = readCredentialsFile("credentials.secret.json")
        
        // must first configure
        let coreAPISettings = CoreAPI.Settings(key: creds.key,
                                               secret: creds.secret,
                                               baseURL: URL(string: "https://api-edge.etilbudsavis.dk")!)
        
        ShopGunSDK.configure(settings: .init(coreAPI: coreAPISettings, eventsTracker: nil, sharedKeychainGroupId: nil), logHandler: ShopGunSDK.defaultLogHandler)
    }
}
