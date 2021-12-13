///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

public struct DeviceInfo: Codable, Equatable {
    
    /// eg. "iOS" or "watchOS" or "macOS" (derived from the system itself)
    public var systemName: String
    /// eg. "14.2"
    public var systemVersion: String
    /// eg. "iPhone10,1" / "x86_64"
    public var hardwareId: String?
}

#if canImport(WatchKit)
import WatchKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import Foundation

extension DeviceInfo {
    
    public static let current: DeviceInfo = {
        #if os(macOS)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return DeviceInfo(
            systemName: "macOS",
            systemVersion: "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)",
            hardwareId: currentModelHardwareId()
        )
        #elseif os(watchOS)
        let device = WKInterfaceDevice.current()
        return DeviceInfo(
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            hardwareId: currentModelHardwareId()
        )
        #else
        let device = UIDevice.current
        return DeviceInfo(
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            hardwareId: currentModelHardwareId()
        )
        #endif
    }()
}

fileprivate func currentModelHardwareId() -> String? {
    #if os(macOS)

    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model)

    #else
    
    if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
        return simulatorModelIdentifier
    }
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return identifier
    
    #endif
}
