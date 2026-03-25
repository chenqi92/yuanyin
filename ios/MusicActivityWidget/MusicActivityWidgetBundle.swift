//
//  MusicActivityWidgetBundle.swift
//  MusicActivityWidget
//
//  Created by 陈奇 on 2026/3/25.
//

import WidgetKit
import SwiftUI

@main
struct MusicActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        // 只包含 Live Activity，移除 Xcode 模板 Widget 和 Control
        MusicActivityWidgetLiveActivity()
    }
}
