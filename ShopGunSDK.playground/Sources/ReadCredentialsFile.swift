import Foundation

public func readCredentialsFile(_ filename: String) -> (key: String, secret: String) {
    guard let fileURL = Bundle.main.url(forResource: filename, withExtension: nil),
        let jsonData = (try? String(contentsOf: fileURL, encoding: .utf8))?.data(using: .utf8),
        let credentialsDict = try? JSONDecoder().decode([String: String].self, from: jsonData),
        let key = credentialsDict["key"],
        let secret = credentialsDict["secret"]
        else {
            fatalError("""
Need valid `\(filename)` file in Playground's `Resources` folder. eg:
{
    "key": "your_key",
    "secret": "your_secret"
}

""")
    }
    return (key: key, secret: secret)
}
