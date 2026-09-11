# Validation Report — v1.2.2

<<<<<<< HEAD
v1.2.4 发布前执行：

```bash
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
(cd portable-runtime && CGO_ENABLED=0 go test ./...)
find MihomoCoreManager -name '*.swift' -print0 | xargs -0 -n1 swiftc -frontend -parse
bash scripts/build-portable-installer.sh
```

重点门禁：

- App/Xcode/portable 版本一致为 v1.2.4 / build 124。
- v1.2.3 Controller Secret 独立认证逻辑完整保留。
- 原生与 portable 代理页均提供默认/延时/质量/名字四种排序。
- `GET /group` 用于代理组默认顺序。
- `GET /group/{group}/delay` 用于只测试当前组。
- 测速结果按节点名称共享到其它代理组。
- 原生和 portable 状态栏均提供顶层代理组、每组测速和线路选择。
=======
- App `1.2.2` / Xcode build `122` / portable build `122`。
- 已复现并定位 v1.2.1 GitHub Release 失败根因：Release job 调用 `scripts/build-portable-installer.sh` 前没有配置 Go，脚本在 `command -v go` 处以 `Go is required` 退出。
- `.github/workflows/release.yml` 现在显式使用 `actions/setup-go@v6`，版本由 `portable-runtime/go.mod` 提供；在 Release 构建前运行 `CGO_ENABLED=0 go test ./...`。
- `.github/workflows/ci.yml` 同步配置 Go，并实际运行 portable installer 构建脚本，确保同类环境缺失能在 PR/main CI 阶段发现。
- v1.2.1 正式 Xcode/SwiftUI 状态栏 template image 修复保持不变。
- Source validator、portable Go 回归测试、Swift parse、workflow YAML 解析与源码 SHA manifest 作为 v1.2.2 发布门禁。
>>>>>>> parent of 7d39e5c (v1.2.3)
