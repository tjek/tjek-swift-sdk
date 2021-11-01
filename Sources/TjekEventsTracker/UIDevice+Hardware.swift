///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

#if canImport(UIKit)
import UIKit

extension UIDevice {
    /// Returns the identifier of the hardware model.
    /// For example "iPhone10,3" for iPhoneX.
    /// If running in a simulator it will attempt to show the device running in the simulator.
    
    public static var modelId: String? {
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
    }
}
#endif
