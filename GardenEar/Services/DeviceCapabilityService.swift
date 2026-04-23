import UIKit
import Foundation

struct DeviceCapability {
    let modelName: String
    let supportsNatureLM: Bool          // iPhone 12+ only
    let availableStorageGB: Double
    let recommendedModel: OfflineModel
    let recommendationReason: String
}

enum OfflineModel {
    case birdNetTFLite
    case natureLM
    case none
}

struct DeviceCapabilityService {

    static func assess() -> DeviceCapability {
        let modelName = deviceModelName()
        let supportsNatureLM = doesSupportNatureLM(modelName)
        let storageGB = availableStorageGB()

        let recommended: OfflineModel
        let reason: String

        if !supportsNatureLM {
            recommended = .birdNetTFLite
            reason = "Your device (\(modelName)) is optimized for BirdNET — fast and accurate bird ID in 3 seconds."
        } else if storageGB < 1.0 {
            recommended = .birdNetTFLite
            reason = "You have \(String(format: "%.1f", storageGB))GB free. BirdNET only needs 50MB and works great."
        } else if storageGB >= 2.0 {
            recommended = .natureLM
            reason = "You have \(String(format: "%.1f", storageGB))GB free. NatureLM gives richer results including life stage and call type."
        } else {
            recommended = .birdNetTFLite
            reason = "You have \(String(format: "%.1f", storageGB))GB free. BirdNET is the safer choice to preserve your storage."
        }

        return DeviceCapability(
            modelName: modelName,
            supportsNatureLM: supportsNatureLM,
            availableStorageGB: storageGB,
            recommendedModel: recommended,
            recommendationReason: reason
        )
    }

    // MARK: - Storage

    static func availableStorageGB() -> Double {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let path = paths.first,
              let attributes = try? FileManager.default.attributesOfFileSystem(forPath: path.path),
              let freeSize = attributes[.systemFreeSize] as? Int64 else {
            return 0
        }
        return Double(freeSize) / 1_073_741_824   // bytes → GB
    }

    // MARK: - Device model

    static func deviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
        return mapIdentifierToModel(identifier)
    }

    static func mapIdentifierToModel(_ id: String) -> String {
        let models: [String: String] = [
            "iPhone13,1": "iPhone 12 mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
        ]
        return models[id] ?? "iPhone"
    }

    // MARK: - NatureLM eligibility

    static func doesSupportNatureLM(_ modelName: String) -> Bool {
        let supported = ["iPhone 12", "iPhone 13", "iPhone 14", "iPhone 15", "iPhone 16"]
        return supported.contains(where: { modelName.contains($0) })
    }
}
