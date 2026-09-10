# Validation Report — v1.1.7

- App `1.1.7` / Xcode build `117` / portable build `117`。
- 原生 AppModel 使用 `activeOperation` 精确标识发起操作的按钮。
- “开始项目升级”持续轮询远端 update log，确认完成后才恢复按钮。
- 远端管理面板短暂重启/断连时保持 busy 并继续检测。
- 原生当前操作按钮显示 `ProgressView`，悬停时使用旋转 busy cursor（Reduce Motion 时静态）；按压缩放增强为 `0.955`。
- portable UI 使用 `.busy`、`aria-busy`、`cursor: progress`；按压缩放增强为 `0.945`。
- Source validator 与 portable Go 回归测试已加入 v1.1.7 生命周期门禁。
