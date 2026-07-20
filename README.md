# Cloai Termux Installer

将 Cloai CLI、Bun glibc 运行时和 Bun-Termux shim 打包为 Android ARM64 Release，并通过一条命令安装到 Termux。

## 支持范围

- Termux / Android
- ARM64 (`aarch64`)
- Cloai `0.0.6`
- Bun `1.3.13`

归档包含 `cloai`、`buno` 和 `bun-shim.so`。目标设备仍需安装 Termux 的 `glibc-runner`；安装器会在缺少时调用 `pkg` 安装。

## 更新本地原始资源

原始资源保存在本地 `resources/`，该目录已被 `.gitignore` 忽略，不会上传到 GitHub。打包脚本只从这里读取文件：

```text
resources/
├── bin/
│   ├── cloai
│   └── buno
├── lib/
│   └── bun-shim.so
└── SHA256SUMS
```

更新原始文件后，重新生成校验文件：

```bash
cp /path/to/new/cloai resources/bin/cloai
cp "$HOME/.bun/bin/buno" resources/bin/buno
cp "$HOME/.bun/lib/bun-shim.so" resources/lib/bun-shim.so
chmod +x resources/bin/cloai resources/bin/buno

cd resources
sha256sum bin/cloai bin/buno lib/bun-shim.so > SHA256SUMS
```

## 构建 Release 归档

确认 `release.conf` 中的版本与 `resources/bin/cloai --version` 一致，然后执行：

```bash
./scripts/package.sh
```

产物：

```text
dist/cloai-0.0.6-android-arm64.tar.gz
dist/cloai-0.0.6-android-arm64.tar.gz.sha256
```

将这两个文件作为附件上传到 GitHub Release `v0.0.6`。`dist/` 同样不提交到 Git 仓库。仓库只保存安装器、启动器、配置、打包脚本和文档。

## 一键安装

```bash
curl -fsSL "https://raw.githubusercontent.com/andTDWF/cloai-termux-installer/main/install.sh" | bash
```

指定版本：

```bash
curl -fsSL "https://raw.githubusercontent.com/andTDWF/cloai-termux-installer/main/install.sh" |
  env CLOAI_VERSION=0.0.6 bash
```

默认安装位置：

```text
~/.local/share/cloai/versions/<version>
~/.local/share/cloai/current
$PREFIX/bin/cloai
```

## 本地验证

无需上传 GitHub，可直接测试生成的归档：

```bash
CLOAI_LOCAL_ARCHIVE="$PWD/dist/cloai-0.0.6-android-arm64.tar.gz" \
CLOAI_INSTALL_ROOT="$PWD/tmp/install" \
CLOAI_BIN_DIR="$PWD/tmp/bin" \
./install.sh

CLOAI_INSTALL_ROOT="$PWD/tmp/install" "$PWD/tmp/bin/cloai" --version
```

## 更新与卸载

再次运行安装命令即可安装指定版本并切换 `current` 链接。若现有安装中的 `buno` 和 `bun-shim.so` 完整可用，升级时会复用它们，只更新 Cloai 二进制和版本元数据；首次安装或运行环境缺失时仍执行完整安装。旧版本目录继续保留。

卸载默认安装：

```bash
rm -rf "$HOME/.local/share/cloai"
rm -f "$PREFIX/bin/cloai"
```

## 第三方组件

Bun-Termux wrapper/shim 来源：

- https://github.com/Happ1ness-dev/bun-termux
- https://github.com/kaan-escober/bun-termux-loader

发布包含第三方 Bun 二进制前，请确认并遵守 Bun、Bun-Termux 以及 Cloai 相关许可条款。
