# v1.1.2 unified layout refinement

This source package keeps the v1.1.2 version metadata and title-bar optimization,
then further refines the native SwiftUI dashboard layout based on the reported UI issues.

Main refinements:

- Reduced loose spacing and made page structures more consistent.
- Overview: aligned the "实时流量" and "快速控制" blocks with balanced heights and responsive columns.
- Core 控制: aligned "服务控制" and "服务信息" blocks and tightened the service info table layout.
- 订阅管理: unified provider row widths, separators, and action area layout.
- 设置: rebuilt the "App 与状态栏" panel into structured rows, and made the server controls responsive.
- Wider pages fall back to two columns when appropriate; narrower windows stack vertically to avoid overlap.
