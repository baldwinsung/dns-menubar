#!/usr/bin/env bash
set -euo pipefail

APP=SimpleDNSMenuBar.app
DEST=/Applications/$APP

swift build -c release

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SimpleDNSMenuBar "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
printf "APPL????" > "$APP/Contents/PkgInfo"

echo "Copying to $DEST (may require password)..."
sudo ditto "$APP" "$DEST"
echo "Installed. Launch with: open $DEST"

# Build and install the privileged helper
swift build -c release --product SimpleDNSHelper
sudo cp .build/release/SimpleDNSHelper /Library/PrivilegedHelperTools/com.baldwinsung.simpledns
sudo chmod 755 /Library/PrivilegedHelperTools/com.baldwinsung.simpledns

# Install LaunchDaemon
sudo cp Resources/com.baldwinsung.simpledns.plist /Library/LaunchDaemons/
sudo chmod 644 /Library/LaunchDaemons/com.baldwinsung.simpledns.plist

# Load (or reload) the daemon
sudo launchctl bootout system/com.baldwinsung.simpledns 2>/dev/null || true
sudo launchctl bootstrap system /Library/LaunchDaemons/com.baldwinsung.simpledns.plist
echo "DNS helper daemon installed and running."
