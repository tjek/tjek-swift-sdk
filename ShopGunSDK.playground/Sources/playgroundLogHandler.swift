import Foundation
import ShopGunSDK

public let playgroundLogHandler: Logger.LogHandler = { (message, level, source, location) in
    
    let output: String
    switch level {
    case .error:
        output = """
        ⁉️ \(message)
        👉 \(location.functionName) @ \(location.fileName):\(location.lineNumber)
        """
    case .important:
        output = "⚠️ \(message)"
    case .verbose:
        output = "🙊 \(message)"
    case .debug:
        output = "🔎 \(message)"
    case .performance:
        output = "⏱ \(message)"
    }
    
    print(output)
}

