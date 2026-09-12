# QA v1.2.9

## 发布一致性

- [ ] `VERSION` 为 `1.2.9`。
- [ ] Xcode `MARKETING_VERSION=1.2.9`、`CURRENT_PROJECT_VERSION=129`。
- [ ] portable runtime `appVersion=1.2.9`、`buildNumber=129`。
- [ ] `python3 scripts/validate-source.py` 通过。
- [ ] `python3 scripts/release-preflight.py --strict-macos` 在 GitHub `macos-15` arm64 runner 通过。

## 状态栏菜单高度回归

- [ ] `.pkg` 安装后点击状态栏图标，菜单内容低于一屏时一次性全部展开。
- [ ] 内容低于一屏时不出现固定 720pt 外框，也不出现多余纵向拖动条。
- [ ] 增加代理组/菜单项使内容超过一屏后，窗口高度不越过当前屏幕可用区域。
- [ ] 超过一屏时可使用触控板、鼠标滚轮上下滚动并访问最底部菜单项。
- [ ] 将状态栏窗口切换到不同分辨率/不同显示器后，高度上限会跟随新显示器更新。
- [ ] 状态栏内的服务器选择、代理组子菜单、测速、启动/停止/重启/重载、更新、设置等操作仍可正常点击。

## v1.2.8 稳定性回归

- [ ] 关闭主窗口后从状态栏重新打开，窗口可正常移动。
- [ ] 正常使用状态栏时不进入“恢复模式：状态栏渲染已降级”。
- [ ] 恢复模式窗口仍可拖动。
