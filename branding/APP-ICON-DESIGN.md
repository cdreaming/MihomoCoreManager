# Mihomo Core Manager App Icon

v1.3.1 replaces the previous artwork with the user-provided `MihomoCoreManager-2.png`: a dark fox mark with cyan/blue/violet neon accents and orbital nodes.

Design / release rules:

- `branding/MihomoCoreManager-2.png` is the original uploaded source and must be kept unchanged.
- `branding/AppIcon-master-1024.png` is the normalized 1024×1024 release master generated from that source.
- SwiftUI/AppKit and Go/AppKit/Web UI consume the same generated AppIcon assets.
- The in-app sidebar/overview branding and GoWebUI brand tiles use the same application icon.

Run `python3 scripts/generate-app-icon.py` to regenerate the master, Xcode AppIcon set and GoWebUI embedded 128 px asset.
