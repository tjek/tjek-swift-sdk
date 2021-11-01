import Foundation
import CommonCrypto

extension UnsafeRawBufferPointer {
    func md5() -> Data {
        let digestLength = Int(CC_MD5_DIGEST_LENGTH)
        
        var result = Data(repeating: 0, count: digestLength)
        let base = baseAddress!
        result.withUnsafeMutableBytes { r in
            let resultBase = r.baseAddress!.assumingMemoryBound(to: UInt8.self)
            CC_MD5(base, CC_LONG(count), resultBase)
        }
        return result
    }
}

extension Data {
    func md5() -> Data {
        return withUnsafeBytes { $0.md5() }
    }
}
