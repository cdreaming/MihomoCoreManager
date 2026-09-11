# Mihomo Core Manager v1.2.1

v1.2.1 修复 v1.2.0 在 GitHub Actions 生成的正式 Xcode/SwiftUI 包中仍可能出现的状态栏网速显示异常。v1.2.0 portable 安装版已验证正常，因此本次重点统一正式 target 的状态栏渲染路径。

## GitHub 正式包状态栏修复

- 根因：SwiftUI `MenuBarExtra` 的 label 在实际 `NSStatusItem` 中会压缩多行 `VStack`，导致上下行速率被折叠/裁切，只剩一个数字或单位缺失。
- 修复：正式 target 先将上传/下载两行文字绘制成一个固定 `55×18pt` 的 template `NSImage`，再作为单一状态栏元素交给 `MenuBarExtra`，macOS 不再参与内部两行文字的重新布局。
- 上传在上、下载在下并整体靠下；数字左对齐，固定预留 4 个等宽字符位；单位独立列按实时速率自动切换；状态栏本体不显示方向箭头。
- v1.1.9 的自定义下拉窗口完全保留。

## GitHub Release

- Release workflow 除正式 SwiftUI `arm64.pkg / arm64.zip` 外，也同步构建并上传已验证的 `arm64-portable-installer.zip`，方便直接验证两种构建的状态栏显示一致性。
- 已发布的 `v1.2.0` tag 不需要移动；请使用新 tag `v1.2.1` 发布本次修复。

App v1.2.1 (build 121)，Mihomo Core 管理面板 API 兼容基线 v4.0.0。
