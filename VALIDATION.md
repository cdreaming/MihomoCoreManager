# Validation

v1.2.5 发布前执行：

```bash
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
python3 scripts/release-preflight.py
bash scripts/simulate-release.sh
```

Apple Silicon macOS / GitHub `macos-15` 还必须执行：

```bash
python3 scripts/release-preflight.py --strict-macos
bash scripts/build-release.sh --unsigned
(cd dist && shasum -a 256 -c SHA256SUMS.txt)
```

重点门禁：

- App/Xcode/portable 版本一致为 v1.2.5 / build 125。
- v1.2.3 Controller Secret 独立认证逻辑完整保留。
- 原生与 portable 代理页均提供默认/延时/质量/名字四种排序。
- `GET /group` 用于代理组默认顺序。
- `GET /group/{group}/delay` 用于只测试当前组。
- 测速结果按节点名称共享到其它代理组。
- 原生和 portable 状态栏均提供顶层代理组、每组测速和线路选择。
- 状态栏下拉菜单上传/下载网速为单行。
- 代理组区域前后均有分隔，且动态代理组位于结束分隔线之前。
- portable 标题栏为 36px，原生顶部安全间距为 26pt。
- 标题栏颜色与 Dashboard 整体配色一致。

## v1.2.4 发布事故沉淀门禁

- `ProxySortOption` 必须显式 `Hashable`。
- `ProxySortPicker` 必须保持独立小 View，并使用显式 enum tag。
- `groupDetail` 必须保持拆分，避免把大型 SwiftUI result builder 合并回来。
- `switch proxy?.alive` 必须使用 `.some(true)` / `.none` / `.some(false)`。
- 质量排序 history 必须先落到显式 `[MihomoProxyDelaySample]` 中间值。
- macOS 14 `onChange` 使用双参数 closure。
- Release 必须传入 `SWIFT_ENABLE_BATCH_MODE=NO`。
- Xcode 输出必须写入 `build/xcodebuild-release.log`；失败时回显实际 `error:` 行。
- CI/Release 失败时上传 Xcode log，避免只看到 `exit code 65`。
- 语法解析只是一层门禁，不能替代 Apple Silicon `macos-15` 上的真实 Xcode Release 编译。

详细规则见 `docs/RELEASE-GUARDRAILS.md`。
