///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation

extension TjekEventsTracker {
    /// The dateFormatter of all the dates in/out of the EventsTracker
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        return formatter
    }()
}
