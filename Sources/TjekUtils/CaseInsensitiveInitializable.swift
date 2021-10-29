///
///  Copyright (c) 2020 Tjek. All rights reserved.
///

/// Any String-based enum that conforms to this protocol will get a caseInsensitive rawValue initializer. Perfect for server-derived values, for example.
public protocol CaseInsensitiveInitializable {
    init?(caseInsensitive rawValue: String)
}
extension CaseInsensitiveInitializable where Self: RawRepresentable, RawValue == String, Self: CaseIterable {
    public init?(caseInsensitive rawValue: String) {
        if let match = Self.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(rawValue) == .orderedSame
        }) {
            self = match
        } else {
            return nil
        }
    }
}
