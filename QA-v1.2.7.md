# QA v1.2.7

## 版本与发布元数据

- [ ] `VERSION` 为 `1.2.7`。
- [ ] Xcode `MARKETING_VERSION=1.2.7`、`CURRENT_PROJECT_VERSION=127`。
- [ ] portable runtime `appVersion=1.2.7`、`buildNumber=127`。
- [ ] `python3 scripts/validate-source.py` 通过。
- [ ] `python3 scripts/build-source-manifest.py --check` 通过。
- [ ] `CGO_ENABLED=0 go test ./...` 通过。

## 状态栏与代理回归

- [ ] 状态栏本体仍为上传在上、下载在下的双行实时网速。
- [ ] 下拉菜单上传/下载实时网速仍在同一行显示。
- [ ] 代理组区域前后分隔线、懒加载、测速、线路切换正常。
- [ ] 状态栏选择线路后顶层代理组后缀能及时刷新。
- [ ] v1.2.4 Cloudflare 临时断线快照回退、代理排序、延时显示、provider 节点和嵌套组解析不回归。

## 主窗口与安全回归

- [ ] 主窗口保持完整左右布局，无独立视觉标题栏。
- [ ] 原生窗口按钮、拖动、缩放、最小化和关闭正常。
- [ ] Core Secret / Controller Secret 继续走既有 Keychain / 鉴权路径。
- [ ] 未开启 `Allow Insecure HTTP` 时仍拒绝明文 HTTP。
- [ ] GET/HEAD 临时错误重试保持有上限，POST/PUT 不自动重试。
