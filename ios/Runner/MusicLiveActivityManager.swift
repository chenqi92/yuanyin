import Foundation
import ActivityKit
import UIKit
import Flutter

/// 音乐 Live Activity 管理器
/// 专门为个人开发者账号设计，使用 pushType: nil 避免 Push Notification 能力限制
@available(iOS 16.1, *)
class MusicLiveActivityManager {
    static let shared = MusicLiveActivityManager()

    /// App Group ID
    private let appGroupId = "group.com.kkape.primuse"

    /// Darwin 通知名称
    private let darwinNotificationName = "com.kkape.primuse.musicControl"

    /// 共享的 UserDefaults
    private lazy var sharedDefaults: UserDefaults? = {
        UserDefaults(suiteName: appGroupId)
    }()

    /// 当前活动 ID
    private var currentActivityId: String?

    /// 当前活动的 UUID (用于数据前缀)
    private var currentActivityUUID: UUID?

    /// 控制命令回调
    var onControlCommand: ((String) -> Void)?

    /// 上次处理的命令时间戳
    private var lastCommandTimestamp: TimeInterval = 0

    private init() {
        registerDarwinNotificationListener()
        cleanupStaleActivities()
    }

    private func cleanupStaleActivities() {
        Task {
            let activities = Activity<LiveActivitiesAppAttributes>.activities
            if !activities.isEmpty {
                for activity in activities {
                    await activity.end(dismissalPolicy: .immediate)
                }
            }
        }
    }

    private func registerDarwinNotificationListener() {
        let notificationName = CFNotificationName(darwinNotificationName as CFString)

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { (_, observer, name, _, _) in
                guard let observer = observer else { return }
                let manager = Unmanaged<MusicLiveActivityManager>.fromOpaque(observer).takeUnretainedValue()
                manager.handleDarwinNotification()
            },
            darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func handleDarwinNotification() {
        guard let defaults = sharedDefaults else { return }

        defaults.synchronize()

        guard let command = defaults.string(forKey: "musicControlCommand") else { return }

        let timestamp = defaults.double(forKey: "musicControlTimestamp")

        if timestamp <= lastCommandTimestamp { return }

        lastCommandTimestamp = timestamp

        DispatchQueue.main.async { [weak self] in
            self?.onControlCommand?(command)
        }

        defaults.removeObject(forKey: "musicControlCommand")
        defaults.synchronize()
    }

    func areActivitiesEnabled() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func createActivity(data: [String: Any]) -> String? {
        guard areActivitiesEnabled() else { return nil }

        if currentActivityId != nil {
            endActivity()
        }

        let activityUUID = UUID()
        let attributes = LiveActivitiesAppAttributes(id: activityUUID)

        saveDataToDefaults(data: data, prefix: activityUUID)
        sharedDefaults?.synchronize()

        let timestamp = Date().timeIntervalSince1970 * 1000
        let contentState = LiveActivitiesAppAttributes.ContentState(appGroupId: appGroupId, updateTimestamp: timestamp)

        do {
            let activity: Activity<LiveActivitiesAppAttributes>

            if #available(iOS 16.2, *) {
                let activityContent = ActivityContent(state: contentState, staleDate: nil)
                activity = try Activity.request(
                    attributes: attributes,
                    content: activityContent,
                    pushType: nil
                )
            } else {
                activity = try Activity<LiveActivitiesAppAttributes>.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
            }

            currentActivityId = activity.id
            currentActivityUUID = activityUUID
            return activity.id
        } catch {
            print("MusicLiveActivityManager: Failed to create activity: \(error.localizedDescription)")
            return nil
        }
    }

    func updateActivity(data: [String: Any]) {
        guard let activityId = currentActivityId,
              let activityUUID = currentActivityUUID else { return }

        saveDataToDefaults(data: data, prefix: activityUUID)
        sharedDefaults?.synchronize()

        let timestamp = Date().timeIntervalSince1970 * 1_000_000

        Task { @MainActor in
            let activities = Activity<LiveActivitiesAppAttributes>.activities

            guard let activity = activities.first(where: { $0.id == activityId }) else {
                if let firstActivity = activities.first {
                    await updateActivityInstance(firstActivity, timestamp: timestamp)
                }
                return
            }

            await updateActivityInstance(activity, timestamp: timestamp)
        }
    }

    @MainActor
    private func updateActivityInstance(_ activity: Activity<LiveActivitiesAppAttributes>, timestamp: Double) async {
        let contentState = LiveActivitiesAppAttributes.ContentState(appGroupId: appGroupId, updateTimestamp: timestamp)

        if #available(iOS 16.2, *) {
            let activityContent = ActivityContent(state: contentState, staleDate: nil)
            await activity.update(activityContent)
        } else {
            await activity.update(using: contentState)
        }
    }

    func endActivity() {
        guard let activityId = currentActivityId else { return }

        Task {
            let activities = Activity<LiveActivitiesAppAttributes>.activities
            if let activity = activities.first(where: { $0.id == activityId }) {
                await activity.end(dismissalPolicy: .immediate)
            }
        }

        if let uuid = currentActivityUUID {
            clearDefaultsData(prefix: uuid)
            cleanupCoverFiles(prefix: uuid)
        }

        currentActivityId = nil
        currentActivityUUID = nil
    }

    func endAllActivities() {
        let activities = Activity<LiveActivitiesAppAttributes>.activities

        if let uuid = currentActivityUUID {
            clearDefaultsData(prefix: uuid)
            cleanupCoverFiles(prefix: uuid)
        }

        if activities.isEmpty {
            currentActivityId = nil
            currentActivityUUID = nil
            return
        }

        Task {
            for activity in activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }

        currentActivityId = nil
        currentActivityUUID = nil
    }

    private func saveDataToDefaults(data: [String: Any], prefix: UUID) {
        guard let defaults = sharedDefaults else { return }

        for (key, value) in data {
            let prefixedKey = "\(prefix)_\(key)"

            if key == "coverImage" {
                let filename = "cover_\(prefix.hashValue).png"

                if let typedData = value as? FlutterStandardTypedData {
                    if let imagePath = saveImageToFile(data: typedData.data, filename: filename) {
                        defaults.set(imagePath, forKey: prefixedKey)
                    }
                } else if let data = value as? Data {
                    if let imagePath = saveImageToFile(data: data, filename: filename) {
                        defaults.set(imagePath, forKey: prefixedKey)
                    }
                }
            } else {
                defaults.set(value, forKey: prefixedKey)
            }
        }

        defaults.synchronize()
    }

    private func clearDefaultsData(prefix: UUID) {
        guard let defaults = sharedDefaults else { return }

        let keys = ["title", "artist", "album", "isPlaying", "progress", "currentTime", "totalTime", "coverImage", "themeColor"]
        for key in keys {
            defaults.removeObject(forKey: "\(prefix)_\(key)")
        }
        defaults.synchronize()
    }

    private func cleanupCoverFiles(prefix: UUID) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }

        let filename = "cover_\(prefix.hashValue).png"
        let fileURL = containerURL.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func saveImageToFile(data: Data, filename: String) -> String? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return nil }

        guard let originalImage = UIImage(data: data) else { return nil }

        let maxSize: CGFloat = 80
        let targetSize = CGSize(width: maxSize, height: maxSize)

        let format = originalImage.imageRendererFormat
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        let resizedImage = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))

            let sourceAspect = originalImage.size.width / originalImage.size.height
            var drawRect: CGRect

            if sourceAspect > 1 {
                let scaledWidth = maxSize * sourceAspect
                let xOffset = (maxSize - scaledWidth) / 2
                drawRect = CGRect(x: xOffset, y: 0, width: scaledWidth, height: maxSize)
            } else {
                let scaledHeight = maxSize / sourceAspect
                let yOffset = (maxSize - scaledHeight) / 2
                drawRect = CGRect(x: 0, y: yOffset, width: maxSize, height: scaledHeight)
            }

            originalImage.draw(in: drawRect)
        }

        guard let compressedData = resizedImage.pngData() else { return nil }

        let fileURL = containerURL.appendingPathComponent(filename)

        do {
            try compressedData.write(to: fileURL)
            return filename
        } catch {
            print("MusicLiveActivityManager: Failed to save image: \(error)")
            return nil
        }
    }
}

// MARK: - LiveActivitiesAppAttributes
// 必须与 Widget Extension 中的定义完全一致

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable, Codable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
        var appGroupId: String
        var updateTimestamp: TimeInterval
    }

    var id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }

    enum CodingKeys: String, CodingKey {
        case id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
    }
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}
