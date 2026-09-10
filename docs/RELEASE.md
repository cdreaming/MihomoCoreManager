# macOS v1.1.5 发布流程

在 Apple Silicon macOS + Xcode 16.4（或兼容版本）执行：

```bash
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
bash scripts/build-release.sh --unsigned
```

产物：`MihomoCoreManager-v1.1.5-arm64.pkg`、`MihomoCoreManager-v1.1.5-arm64.zip`、Release Notes 与 SHA256SUMS。
