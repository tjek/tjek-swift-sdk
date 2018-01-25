import ShopGunSDK

extension ShopGunSDK {
    public static let defaultLogHandler: ShopGunSDK.LogHandler = { (msg, lvl, source, location) in
        
        let output: String
        switch lvl {
        case .error:
            let filename = location.file.components(separatedBy: "/").last ?? location.file
            output = """
            ⁉️ \(msg)
            👉 \(location.function) @ \(filename):\(location.line)
            """
        case .important:
            output = "⚠️ \(msg)"
        case .verbose:
            output = "💬 \(msg)"
        case .debug:
            output = "🕸 \(msg)"
        }
        
        print(output)
    }
}
