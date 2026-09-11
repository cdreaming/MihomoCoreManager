# Validation

v1.2.3 发布前执行：

```bash
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
(cd portable-runtime && CGO_ENABLED=0 go test ./...)
find MihomoCoreManager -name '*.swift' -print0 | xargs -0 -n1 swiftc -frontend -parse
bash scripts/build-portable-installer.sh
```

重点门禁包括：

- App/Xcode/portable 版本一致为 v1.2.3 / build 123。
- 原生 SwiftUI “代理切换”页面、运行模式与代理组/详细代理代码存在。
- Direct Controller `/configs`、`/proxies` 读取及模式/代理切换代码存在。
- portable 页面和 Go bridge 具备同等代理切换功能。
- portable 回归测试覆盖代理组 URL 编码、模式读取/写入、代理列表和代理选择。
