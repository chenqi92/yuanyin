//
//  MusicActivityWidgetLiveActivity.swift
//  MusicActivityWidget
//
//  Created by 陈奇 on 2026/3/25.
//  Primuse music player Live Activity for Dynamic Island and Lock Screen
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Live Activities App Attributes

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

// MARK: - Shared UserDefaults Helper

private let appGroupId = "group.com.kkape.primuse"

private let _sharedDefault: UserDefaults = {
    if let defaults = UserDefaults(suiteName: appGroupId) {
        return defaults
    }
    return UserDefaults.standard
}()

func getSharedDefaults() -> UserDefaults {
    _sharedDefault.synchronize()
    return _sharedDefault
}

var sharedDefault: UserDefaults {
    return getSharedDefaults()
}

func getAppGroupContainerURL() -> URL? {
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
}

// MARK: - Music Control Helper

private func sendMusicControlCommand(_ command: String) {
    sharedDefault.set(command, forKey: "musicControlCommand")
    sharedDefault.set(Date().timeIntervalSince1970, forKey: "musicControlTimestamp")
    sharedDefault.synchronize()

    let notificationName = CFNotificationName("com.kkape.primuse.musicControl" as CFString)
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        notificationName,
        nil,
        nil,
        true
    )
}

// MARK: - App Intents for Music Control

@available(iOS 16.0, *)
struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "播放/暂停"
    static var description = IntentDescription("切换音乐播放状态")

    func perform() async throws -> some IntentResult {
        sendMusicControlCommand("toggle")
        return .result()
    }
}

@available(iOS 16.0, *)
struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "上一首"
    static var description = IntentDescription("播放上一首")

    func perform() async throws -> some IntentResult {
        sendMusicControlCommand("previous")
        return .result()
    }
}

@available(iOS 16.0, *)
struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "下一首"
    static var description = IntentDescription("播放下一首")

    func perform() async throws -> some IntentResult {
        sendMusicControlCommand("next")
        return .result()
    }
}

@available(iOS 16.0, *)
struct FavoriteIntent: AppIntent {
    static var title: LocalizedStringResource = "收藏"
    static var description = IntentDescription("收藏当前歌曲")

    func perform() async throws -> some IntentResult {
        sendMusicControlCommand("favorite")
        return .result()
    }
}

// MARK: - Music Live Activity Widget

struct MusicActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            LockScreenMusicView(context: context)
        } dynamicIsland: { context in
            let _ = context.state.updateTimestamp
            let defaults = getSharedDefaults()

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MusicCoverView(context: context, defaults: defaults)
                        .frame(width: 56, height: 56)
                        .cornerRadius(8)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(defaults.string(forKey: context.attributes.prefixedKey("title")) ?? "Unknown")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(.white)
                        Text(defaults.string(forKey: context.attributes.prefixedKey("artist")) ?? "Unknown Artist")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if #available(iOS 17.0, *) {
                        Button(intent: FavoriteIntent()) {
                            Image(systemName: "heart")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "heart")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    let progress = defaults.double(forKey: context.attributes.prefixedKey("progress"))
                    let currentTime = defaults.integer(forKey: context.attributes.prefixedKey("currentTime"))
                    let totalTime = defaults.integer(forKey: context.attributes.prefixedKey("totalTime"))
                    let isPlaying = defaults.bool(forKey: context.attributes.prefixedKey("isPlaying"))

                    VStack(spacing: 8) {
                        VStack(spacing: 4) {
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))

                            HStack {
                                Text(formatTime(currentTime))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(formatTime(totalTime))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }

                        HStack(spacing: 32) {
                            if #available(iOS 17.0, *) {
                                Button(intent: PreviousTrackIntent()) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Link(destination: URL(string: "primuse://music/previous")!) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                }
                            }

                            if #available(iOS 17.0, *) {
                                Button(intent: PlayPauseIntent()) {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Link(destination: URL(string: "primuse://music/toggle")!) {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                }
                            }

                            if #available(iOS 17.0, *) {
                                Button(intent: NextTrackIntent()) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Link(destination: URL(string: "primuse://music/next")!) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                MusicCoverView(context: context, defaults: defaults)
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            } compactTrailing: {
                let isPlaying = defaults.bool(forKey: context.attributes.prefixedKey("isPlaying"))
                let progress = defaults.double(forKey: context.attributes.prefixedKey("progress"))
                let themeColorInt = defaults.integer(forKey: context.attributes.prefixedKey("themeColor"))
                let themeColor = colorFromARGB(themeColorInt)

                if isPlaying {
                    AnimatedMusicBars(progress: progress, themeColor: themeColor)
                        .frame(width: 20, height: 14)
                } else {
                    StaticMusicBars(themeColor: themeColor)
                        .frame(width: 20, height: 14)
                }
            } minimal: {
                let isPlaying = defaults.bool(forKey: context.attributes.prefixedKey("isPlaying"))
                let progress = defaults.double(forKey: context.attributes.prefixedKey("progress"))
                let themeColorInt = defaults.integer(forKey: context.attributes.prefixedKey("themeColor"))
                let themeColor = colorFromARGB(themeColorInt)

                if isPlaying {
                    AnimatedMusicBars(progress: progress, themeColor: themeColor)
                        .frame(width: 14, height: 10)
                } else {
                    StaticMusicBars(themeColor: themeColor)
                        .frame(width: 14, height: 10)
                }
            }
            .widgetURL(URL(string: "primuse://music/player"))
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Theme Color Helper

func colorFromARGB(_ argb: Int) -> Color {
    guard argb != 0 else {
        return Color(red: 0.078, green: 0.722, blue: 0.651)  // Teal
    }

    let a = Double((argb >> 24) & 0xFF) / 255.0
    let r = Double((argb >> 16) & 0xFF) / 255.0
    let g = Double((argb >> 8) & 0xFF) / 255.0
    let b = Double(argb & 0xFF) / 255.0

    return Color(red: r, green: g, blue: b).opacity(a)
}

// MARK: - Animated Music Bars

struct AnimatedMusicBars: View {
    var progress: Double = 0
    var themeColor: Color

    private let barCount = 6

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.06)) { timeline in
            HStack(alignment: .center, spacing: 1.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    MusicBar(index: index, date: timeline.date, progress: progress, color: themeColor)
                }
            }
        }
    }
}

// MARK: - Static Music Bars

struct StaticMusicBars: View {
    var themeColor: Color

    private let barCount = 6

    private func heightForIndex(_ index: Int) -> CGFloat {
        let center = Double(barCount - 1) / 2.0
        let distance = abs(Double(index) - center)
        let maxDistance = center
        return 0.3 + 0.5 * (1.0 - distance / maxDistance)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(themeColor)
                    .frame(width: 1.5)
                    .scaleEffect(y: heightForIndex(index), anchor: .center)
                    .opacity(0.5)
            }
        }
    }
}

struct MusicBar: View {
    let index: Int
    let date: Date
    var progress: Double = 0
    var color: Color

    var body: some View {
        let progressPhase = progress * 20.0
        let phase = Double(index) * 0.8 + progressPhase
        let time = date.timeIntervalSinceReferenceDate

        let wave1 = sin(time * 6.0 + phase)
        let wave2 = sin(time * 4.0 + phase * 0.7) * 0.5
        let wave3 = sin(time * 8.0 + phase * 1.3) * 0.3
        let combinedWave = abs(wave1 + wave2 + wave3) / 1.8

        let height = 0.25 + 0.75 * combinedWave

        RoundedRectangle(cornerRadius: 0.5)
            .fill(color)
            .frame(width: 1.5)
            .scaleEffect(y: height, anchor: .center)
    }
}

// MARK: - Lock Screen View

struct LockScreenMusicView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        let _ = context.state.updateTimestamp
        let defaults = sharedDefault
        let title = defaults.string(forKey: context.attributes.prefixedKey("title")) ?? "Unknown"
        let artist = defaults.string(forKey: context.attributes.prefixedKey("artist")) ?? "Unknown Artist"
        let isPlaying = defaults.bool(forKey: context.attributes.prefixedKey("isPlaying"))
        let progress = defaults.double(forKey: context.attributes.prefixedKey("progress"))

        HStack(spacing: 12) {
            MusicCoverView(context: context, defaults: defaults)
                .frame(width: 56, height: 56)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.white)
                Text(artist)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
            }

            Spacer()

            if #available(iOS 17.0, *) {
                Button(intent: PlayPauseIntent()) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: URL(string: "primuse://music/toggle")!) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.8))
    }
}

// MARK: - Cover Image View

struct MusicCoverView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    let defaults: UserDefaults

    var body: some View {
        defaults.synchronize()

        let coverKey = context.attributes.prefixedKey("coverImage")
        let filename = defaults.string(forKey: coverKey) ?? ""

        let loadedImage = Self.loadCoverImage(filename: filename)

        return Group {
            if let uiImage = loadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.3, green: 0.3, blue: 0.4),
                            Color(red: 0.2, green: 0.2, blue: 0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    private static func loadCoverImage(filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }

        guard let containerURL = getAppGroupContainerURL() else { return nil }

        let fileURL = containerURL.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        guard let imageData = try? Data(contentsOf: fileURL) else { return nil }

        guard let image = UIImage(data: imageData) else { return nil }

        return image
    }
}
