# Validation Report — v1.1.8

- App `1.1.8` / Xcode build `118` / portable build `118`。
- v1.1.7 当前操作 spinner、busy cursor、按钮完成检测和项目升级轮询保持不变。
- 原生成功通知只会在当前异步操作退出 busy 后开始自动收起计时；错误通知保持可手动关闭。
- 原生侧栏页面按钮使用整行 47pt 命中区域与独立按压动画；portable 页面按钮最小 46px 并增强按下反馈。
- 设置页 `task(id:)` 已恢复真实 profile/section 字符串插值，首次进入即可加载默认服务器并展示完整选项。
- 运行日志同类持久页面首次加载问题一并修复。
- Source validator 与 portable Go 回归测试加入 v1.1.8 对应门禁。
