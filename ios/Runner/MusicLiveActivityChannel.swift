import Flutter
import UIKit
import MediaPlayer

/// Flutter Method Channel for Music Live Activity
/// 为个人开发者账号提供不依赖 Push Notification 的 Live Activity 支持
class MusicLiveActivityChannel: NSObject, FlutterPlugin {

    /// EventChannel sink 用于发送控制命令到 Flutter
    private var eventSink: FlutterEventSink?

    static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.kkape.primuse/music_live_activity",
            binaryMessenger: registrar.messenger()
        )

        let eventChannel = FlutterEventChannel(
            name: "com.kkape.primuse/music_live_activity_events",
            binaryMessenger: registrar.messenger()
        )

        let instance = MusicLiveActivityChannel()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)

        if #available(iOS 16.1, *) {
            MusicLiveActivityManager.shared.onControlCommand = { [weak instance] command in
                print("MusicLiveActivityChannel: Forwarding command to Flutter: \(command)")
                instance?.eventSink?(command)
            }
        }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "forceRefreshNowPlaying" {
            self.forceRefreshNowPlaying()
            result(nil)
            return
        }

        if #available(iOS 16.1, *) {
            switch call.method {
            case "areActivitiesEnabled":
                result(MusicLiveActivityManager.shared.areActivitiesEnabled())

            case "createActivity":
                guard let args = call.arguments as? [String: Any],
                      let data = args["data"] as? [String: Any] else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing data argument", details: nil))
                    return
                }

                if let activityId = MusicLiveActivityManager.shared.createActivity(data: data) {
                    result(activityId)
                } else {
                    result(FlutterError(code: "CREATE_FAILED", message: "Failed to create activity", details: nil))
                }

            case "updateActivity":
                guard let args = call.arguments as? [String: Any],
                      let data = args["data"] as? [String: Any] else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing data argument", details: nil))
                    return
                }

                MusicLiveActivityManager.shared.updateActivity(data: data)
                result(nil)

            case "endActivity":
                MusicLiveActivityManager.shared.endActivity()
                result(nil)

            case "endAllActivities":
                MusicLiveActivityManager.shared.endAllActivities()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        } else {
            result(FlutterError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.1+", details: nil))
        }
    }
}

// MARK: - Now Playing Refresh
extension MusicLiveActivityChannel {
    private static var localNowPlayingInfo: [String: Any] = [:]
    private static var refreshCounter: Int = 0

    func forceRefreshNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        let commandCenter = MPRemoteCommandCenter.shared()

        guard let currentInfo = center.nowPlayingInfo, !currentInfo.isEmpty else {
            print("MusicLiveActivityChannel: No nowPlayingInfo to refresh")
            return
        }

        MusicLiveActivityChannel.refreshCounter += 1
        MusicLiveActivityChannel.localNowPlayingInfo = currentInfo

        let currentRate = currentInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 1.0

        center.nowPlayingInfo = nil
        center.playbackState = .stopped

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            var updatedInfo = currentInfo
            updatedInfo[MPNowPlayingInfoPropertyPlaybackRate] = currentRate
            center.nowPlayingInfo = updatedInfo

            if currentRate > 0 {
                center.playbackState = .playing
            } else {
                center.playbackState = .paused
            }

            commandCenter.playCommand.isEnabled = true
            commandCenter.pauseCommand.isEnabled = true
            commandCenter.togglePlayPauseCommand.isEnabled = true
            commandCenter.nextTrackCommand.isEnabled = true
            commandCenter.previousTrackCommand.isEnabled = true
        }
    }
}

// MARK: - FlutterStreamHandler
extension MusicLiveActivityChannel: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
