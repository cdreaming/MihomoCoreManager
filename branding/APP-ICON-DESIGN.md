# Mihomo Core Manager App Icon

v1.3.0 adopts a modern macOS-style icon: a cyan-to-blue-to-violet rounded tile with a soft folded-ribbon `M` mark.

Design goals:

- clear silhouette at 16–32 px menu/Dock scales;
- modern macOS depth without photorealistic clutter;
- blue/violet network-tool identity consistent with the existing UI;
- one master asset shared by SwiftUI/AppKit and Go/AppKit/Web UI packaging.

`branding/AppIcon-master-1024.png` is the release master. Run `python3 scripts/generate-app-icon.py` to regenerate the Xcode AppIcon set and the GoWebUI embedded 128 px brand asset.
