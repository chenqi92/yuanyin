#!/bin/bash

# FFmpeg Kit macOS Setup Script
# Downloads pre-built FFmpeg frameworks for macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$SCRIPT_DIR/../macos"
FRAMEWORKS_DIR="$MACOS_DIR/Frameworks"

# FFmpegKit version
FFMPEG_KIT_VERSION="6.0"

# Note: Unlike iOS, there's no community-maintained macOS FFmpegKit release currently available.
# You'll need to build from source or find a self-hosted version.

echo "=== FFmpegKit macOS Setup ==="
echo "Target directory: $FRAMEWORKS_DIR"

# Check if frameworks already exist
if [ -d "$FRAMEWORKS_DIR" ] && [ "$(ls -A "$FRAMEWORKS_DIR" 2>/dev/null)" ]; then
    if ls "$FRAMEWORKS_DIR"/*.xcframework 1>/dev/null 2>&1 || ls "$FRAMEWORKS_DIR"/*.framework 1>/dev/null 2>&1; then
        echo "Frameworks already exist. Skipping setup."
        exit 0
    fi
fi

echo ""
echo "=========================================="
echo "FFmpegKit macOS Frameworks Not Found"
echo "=========================================="
echo ""
echo "FFmpegKit official binaries have been retired as of January 2025."
echo ""
echo "Unlike iOS, there's no ready-made community solution for macOS."
echo "You have two options:"
echo ""
echo "1. Build from source:"
echo "   git clone https://github.com/arthenica/ffmpeg-kit.git"
echo "   cd ffmpeg-kit"
echo "   ./macos.sh --full --enable-gpl --target=10.15"
echo ""
echo "2. For basic FFmpeg usage, install via Homebrew:"
echo "   brew install ffmpeg"
echo "   Then use the system FFmpeg binary."
echo ""
echo "Place the built frameworks in:"
echo "   $FRAMEWORKS_DIR"
echo ""
echo "Required xcframeworks:"
echo "  - ffmpegkit.xcframework"
echo "  - libavcodec.xcframework"
echo "  - libavdevice.xcframework"
echo "  - libavfilter.xcframework"
echo "  - libavformat.xcframework"
echo "  - libavutil.xcframework"
echo "  - libswresample.xcframework"
echo "  - libswscale.xcframework"
echo ""

# Create the directory structure for manual placement
mkdir -p "$FRAMEWORKS_DIR"

echo "Frameworks directory created. Please add your built frameworks there."
echo ""

# Don't fail - just warn
exit 0
