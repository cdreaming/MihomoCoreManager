# Mihomo Core Manager v1.2.7

v1.2.7 以用户提供的 `MihomoCoreManager-v1.2.5-release-ready-source-4` 为功能基线完成正式版本升级。本次不额外改写既有功能逻辑，重点是确保 App、Xcode、portable runtime、GitHub Release 与发布文档统一使用同一个 v1.2.7 版本号。

## 版本同步

- App: `1.2.7`
- Build: `127`
- Xcode `MARKETING_VERSION`: `1.2.7`
- Xcode `CURRENT_PROJECT_VERSION`: `127`
- portable runtime: `1.2.7 / 127`
- Architecture: Apple Silicon `arm64`
- Minimum macOS: `14.0`

## 功能基线

- 保留当前源码已有的代理组/代理排序、当前组测速与共享节点延时缓存。
- 保留状态栏代理组菜单、异步测速/线路切换与即时后缀刷新。
- 保留 Cloudflare 530 / Error 1033 临时故障回退和最近代理快照逻辑。
- 保留完整左右布局、无独立视觉标题栏的主窗口结构。
- 保留 portable arm64 安装包构建路径及 Go 测试门禁。

## 发布一致性

- GitHub Release workflow 的手工输入示例已更新到 `1.2.7 / v1.2.7`。
- 发布流程文档和正式资产文件名已同步到 v1.2.7。
- `SOURCE-SHA256SUMS.txt` 已按最终源码重新生成。
