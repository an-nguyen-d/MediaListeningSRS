#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 <target-name>"
    echo "Example: $0 MSRS.SharedModels"
    echo ""
    echo "Available targets:"
    xcodebuild -list -project MediaListeningSRS.xcodeproj | grep "MSRS\." | sed 's/^        /  - /'
    exit 1
fi

TARGET="$1"
DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=18.5"

echo "🔨 Building $TARGET..."
echo ""

if xcodebuild build -scheme "$TARGET" -destination "$DESTINATION" -quiet; then
    echo "✅ $TARGET built successfully"
    exit 0
else
    echo "❌ $TARGET build failed"
    exit 1
fi
