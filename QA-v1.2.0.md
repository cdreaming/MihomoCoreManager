# Mihomo Core Manager v1.2.0 QA

## 状态栏本体

- [ ] 默认开启图标 + 状态 + 网速时，状态栏本体实际显示实时网速。
- [ ] 上传速度位于上半行，下载速度位于下半行。
- [ ] 双行速度块靠状态栏底部对齐。
- [ ] 两行均只显示数字和单位，没有 `↑ / ↓` 箭头。
- [ ] 数字从同一左边缘开始，固定预留 4 个等宽字符位。
- [ ] `B/s -> KB/s -> MB/s -> GB/s` 切换时单位正确，数字列不左右漂移。
- [ ] 开关“显示图标 / 显示运行状态 / 显示网速 / 仅显示图标”后状态栏仍可点击。

## 下拉面板回归

- [ ] v1.1.9 自定义紧凑下拉面板布局与按钮操作保持正常。
- [ ] 服务器、Core 控制、订阅/日志/项目升级/MetaCubeXD/设置均可正常使用。

## portable

- [ ] AppKit overlay 与子标签会转交状态栏点击，下拉菜单可正常打开。
- [ ] portable 状态栏不使用多行 button title、NSButtonCell wrap、attributedTitle 或 CATextLayer。
- [ ] overlay 初始化失败时安全降级，不导致 App 闪退。
- [ ] recovery shell 仍可在 JXA 菜单初始化失败时启动。
