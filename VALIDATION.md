# Validation

v1.2.7 发布前执行：

```bash
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
(cd portable-runtime && CGO_ENABLED=0 go test ./...)
find MihomoCoreManager -name '*.swift' -print0 | xargs -0 -n1 swiftc -frontend -parse
bash scripts/build-portable-installer.sh
```

重点门禁：

- App/Xcode/portable 版本一致为 v1.2.7 / build 127。
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
