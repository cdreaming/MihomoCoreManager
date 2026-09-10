# v1.1.2 UI compatibility + compact title-bar patch

This source tree is released as v1.1.2. It keeps the v1.1.1 release workflow,
portable runtime, and application functionality, restores the native SwiftUI
menu-bar label layout from v1.0.9, and uses a compact integrated title bar.

Restored UI details:

- 5pt outer spacing and 3pt inner status/speed spacing.
- v1.0.9 icon size and text sizing.
- `Running / Stopped / Checking` status labels.
- text arrows (`↓` / `↑`) and the original two-line speed alignment.
- the original spacer between status and speed blocks.
- removal of the v1.1.1 forced 18pt outer frame and zero padding overrides.

No portable Web UI files were changed because they are byte-identical between
v1.0.9 and v1.1.1.


## v1.1.2 compact title bar

- Uses SwiftUI `.windowStyle(.hiddenTitleBar)` for the main window.
- Hides the standard window title and title-bar backing.
- Enables full-size content under the title-bar region.
- Keeps native macOS traffic-light controls and native drag behavior.
- Reserves a compact 38pt top inset only in the left brand area to avoid overlap.
