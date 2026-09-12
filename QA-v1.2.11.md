# QA v1.2.11

## 发布一致性

- [ ] `VERSION` 为 `1.2.11`。
- [ ] Xcode `MARKETING_VERSION=1.2.11`、`CURRENT_PROJECT_VERSION=1211`。
- [ ] portable runtime `appVersion=1.2.11`、`buildNumber=1211`。
- [ ] `python3 scripts/validate-source.py` 通过。
- [ ] GitHub `macos-15` arm64 上 `bash scripts/simulate-release.sh` 完整通过并生成原生 `.pkg`。

## GitHub `.pkg` 状态栏重点验收

- [ ] 下拉菜单整体底色接近参考图 `#1A1A1D`，卡片为稍亮的中性灰，不再偏蓝或近纯黑。
- [ ] 菜单内容低于一屏时全部自然展开，不出现滚动容器。
- [ ] 菜单内容超过一屏时可用鼠标滚轮/触控板上下滚动，但右侧**完全不显示**系统粗滚动条/拖动条。
- [ ] 每个代理组根标题显示 `组名 · 当前线路`；首次打开菜单也必须出现当前 `now`。
- [ ] 从 MetaCubeXD/其它客户端改线路后，关闭再打开状态栏菜单能显示新的 `now`。
- [ ] 在状态栏菜单内切换线路后，对应根标题立即更新。
- [ ] 状态栏本体仍按开关正常显示图标、状态和双行实时网速。

## 主窗口

- [ ] 左侧品牌区版本信息显示 `程序版本：v1.2.11`，不得显示 `Core 面板：v4.0.0`。
- [ ] `Core 版本` 和 `MetaCubeXD` 版本仍正常显示。
- [ ] 关闭主窗口后从状态栏重新打开仍可正常移动。
