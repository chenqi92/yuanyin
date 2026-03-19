#!/bin/bash

# FFmpeg Kit iOS Setup Script
# Downloads pre-built FFmpeg frameworks for iOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$SCRIPT_DIR/../ios"
FRAMEWORKS_DIR="$IOS_DIR/Frameworks"

# FFmpegKit version and download URL
# Using luthviar/ffmpeg-kit-ios-full self-hosted binaries (FFmpegKit official retired Jan 2025)
FFMPEG_KIT_VERSION="6.0"
DOWNLOAD_URL="https://github.com/luthviar/ffmpeg-kit-ios-full/releases/download/6.0/ffmpeg-kit-ios-full.zip"

echo "=== FFmpegKit iOS Setup ==="
echo "Target directory: $FRAMEWORKS_DIR"

# Check if frameworks already exist
if [ -d "$FRAMEWORKS_DIR" ] && [ "$(ls -A "$FRAMEWORKS_DIR" 2>/dev/null)" ]; then
    # Check if we have xcframeworks
    if ls "$FRAMEWORKS_DIR"/*.xcframework 1>/dev/null 2>&1; then
        echo "Frameworks already exist. Skipping download."
        exit 0
    fi
fi

# Create frameworks directory
mkdir -p "$FRAMEWORKS_DIR"

# Temporary directory for download
TEMP_DIR=$(mktemp -d)
ARCHIVE_PATH="$TEMP_DIR/ffmpeg-kit.zip"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Downloading FFmpegKit ${FFMPEG_KIT_VERSION} for iOS..."

# Try downloading
if curl -L -f -o "$ARCHIVE_PATH" "$DOWNLOAD_URL"; then
    echo "Downloaded successfully"
else
    echo ""
    echo "=========================================="
    echo "ERROR: Failed to download FFmpegKit"
    echo "=========================================="
    echo ""
    echo "FFmpegKit official binaries have been retired as of January 2025."
    echo "You need to manually download or build the frameworks."
    echo ""
    echo "Options:"
    echo "1. Download from: https://github.com/luthviar/ffmpeg-kit-ios-full/releases"
    echo "2. Build from source: https://github.com/arthenica/ffmpeg-kit"
    echo "3. Place frameworks manually in:"
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
    exit 1
fi

echo "Extracting frameworks..."
unzip -o -q "$ARCHIVE_PATH" -d "$TEMP_DIR"

# The zip contains xcframeworks inside ffmpeg-kit-ios-full/ directory
EXTRACTED_DIR="$TEMP_DIR/ffmpeg-kit-ios-full"

if [ ! -d "$EXTRACTED_DIR" ]; then
    # Try to find the directory containing xcframeworks
    EXTRACTED_DIR=$(find "$TEMP_DIR" -name "*.xcframework" -type d | head -1 | xargs dirname 2>/dev/null || echo "")
fi

if [ -z "$EXTRACTED_DIR" ] || [ ! -d "$EXTRACTED_DIR" ]; then
    echo "ERROR: Could not find extracted frameworks"
    exit 1
fi

echo "Copying xcframeworks to $FRAMEWORKS_DIR..."

# Copy all xcframeworks
for xcfw in "$EXTRACTED_DIR"/*.xcframework; do
    if [ -d "$xcfw" ]; then
        echo "  Copying $(basename "$xcfw")"
        cp -R "$xcfw" "$FRAMEWORKS_DIR/"
    fi
done

# Verify installation
REQUIRED_FRAMEWORKS=("ffmpegkit" "libavcodec" "libavformat" "libavutil" "libswresample" "libswscale")
MISSING=0

for fw in "${REQUIRED_FRAMEWORKS[@]}"; do
    if [ ! -d "$FRAMEWORKS_DIR/${fw}.xcframework" ]; then
        echo "WARNING: Missing ${fw}.xcframework"
        MISSING=1
    fi
done

if [ $MISSING -eq 1 ]; then
    echo "Some frameworks may be missing. Please verify the installation."
else
    echo "FFmpegKit iOS frameworks installed successfully!"
fi

echo ""
echo "Installed frameworks:"
ls -la "$FRAMEWORKS_DIR"

echo ""
echo "Done."
