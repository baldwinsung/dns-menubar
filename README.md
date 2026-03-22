# SimpleDNSMenuBar

A macOS menu bar app that automatically switches DNS servers based on your Wi-Fi network.

> ⚠️ **Disclaimer:** This software is provided "as is", without warranty of any kind. The author(s) are not liable for any damages or issues arising from the use of this software. Use at your own risk. See [LICENSE](LICENSE) for full details.

> 🤖 **AI Disclosure:** This project was created with assistance from [Claude](https://claude.ai) by Anthropic.

## Features

- Automatic DNS switching when your Wi-Fi network changes
- Per-SSID DNS mappings configured in Preferences
- Manual DNS override from the menu bar
- Revert to automatic (DHCP) DNS with one click
- Launch at Login toggle (macOS 13 Ventura and later)
- Reliable DNS application at login — retries up to 3 times if Wi-Fi is still associating when the app starts
- No password prompt after initial install (privileged helper daemon)

## Requirements

- macOS 12 (Monterey) or later
- Xcode command-line tools (`xcode-select --install`)
- Swift 5.9+

## Installation

```bash
sudo ./install.sh
```

The install script:

1. Builds the app in release mode
2. Installs `SimpleDNSMenuBar.app` to `/Applications`
3. Builds and installs the privileged helper to `/Library/PrivilegedHelperTools/com.baldwinsung.simpledns`
4. Installs the LaunchDaemon plist to `/Library/LaunchDaemons/`
5. Loads the daemon via `launchctl bootstrap`

## Usage

- The app appears in the menu bar on launch
- Open **Preferences** to add SSID → DNS server mappings; recently-seen SSIDs appear in a dropdown
- DNS switches automatically when connecting to a mapped network
- Click any mapping in the menu to apply it manually
- **Automatic (DHCP)** reverts to the system-assigned DNS
- Checkmarks indicate which DNS profile is currently active
- **Launch at Login** in the menu toggles automatic startup (macOS 13+)

## Architecture

SimpleDNSMenuBar uses a two-process design to apply DNS changes without repeated password prompts:

- **SimpleDNSMenuBar** — menu bar app running in user context: monitors Wi-Fi via CoreWLAN, stores SSID mappings in UserDefaults, builds the menu
- **SimpleDNSHelper** — root LaunchDaemon: listens on `/var/run/simpledns.sock`, accepts JSON requests, executes `networksetup -setdnsservers` as root

```
SimpleDNSMenuBar (user)
    └─→ Unix socket (/var/run/simpledns.sock)
            └─→ SimpleDNSHelper (root)
                    └─→ networksetup -setdnsservers
```

## Project Structure

| Path | Description |
|------|-------------|
| `Sources/SimpleDNSMenuBar/` | Main menu bar app |
| `Sources/SimpleDNSHelper/` | Privileged daemon |
| `Resources/Info.plist` | App bundle metadata |
| `Resources/com.baldwinsung.simpledns.plist` | LaunchDaemon configuration |
| `install.sh` | One-shot install script |

## Uninstall

```bash
sudo launchctl bootout system/com.baldwinsung.simpledns
sudo rm /Library/LaunchDaemons/com.baldwinsung.simpledns.plist
sudo rm /Library/PrivilegedHelperTools/com.baldwinsung.simpledns
sudo rm -rf /Applications/SimpleDNSMenuBar.app
```

---

*Coded with [Claude](https://claude.ai)*
