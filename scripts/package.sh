#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../release.conf
. "$PROJECT_DIR/release.conf"

PACKAGE_NAME="cloai-${CLOAI_VERSION}-${CLOAI_PLATFORM}"
DIST_DIR="$PROJECT_DIR/dist"
STAGING_ROOT="$DIST_DIR/staging"
STAGING_DIR="$STAGING_ROOT/$PACKAGE_NAME"
ARCHIVE="$DIST_DIR/$PACKAGE_NAME.tar.gz"
CHECKSUM="$ARCHIVE.sha256"
RESOURCES_DIR="$PROJECT_DIR/resources"
CLOAI_BINARY="$RESOURCES_DIR/bin/cloai"
BUNO_BINARY="$RESOURCES_DIR/bin/buno"
BUN_SHIM="$RESOURCES_DIR/lib/bun-shim.so"

fail() {
  printf 'package: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "找不到文件：$1"
}

require_executable() {
  [[ -x "$1" ]] || fail "文件不可执行：$1"
}

for command in file tar sha256sum install; do
  command -v "$command" >/dev/null 2>&1 || fail "缺少命令：$command"
done

require_executable "$CLOAI_BINARY"
require_executable "$BUNO_BINARY"
require_file "$BUN_SHIM"
require_executable "$PROJECT_DIR/launcher/cloai"

(
  cd "$RESOURCES_DIR"
  sha256sum --check SHA256SUMS
)

for artifact in "$CLOAI_BINARY" "$BUNO_BINARY" "$BUN_SHIM"; do
  file "$artifact" | grep -Eq 'ARM aarch64|ARM64' || fail "不是 ARM64 文件：$artifact"
done

ACTUAL_VERSION="$($CLOAI_BINARY --version | awk '{print $1}')"
[[ "$ACTUAL_VERSION" == "$CLOAI_VERSION" ]] ||
  fail "版本不一致：配置为 $CLOAI_VERSION，二进制为 $ACTUAL_VERSION"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/bin" "$STAGING_DIR/lib"

install -m 755 "$CLOAI_BINARY" "$STAGING_DIR/bin/cloai"
install -m 755 "$BUNO_BINARY" "$STAGING_DIR/bin/buno"
install -m 755 "$BUN_SHIM" "$STAGING_DIR/lib/bun-shim.so"
install -m 755 "$PROJECT_DIR/launcher/cloai" "$STAGING_DIR/cloai-launcher"
printf '%s\n' "$CLOAI_VERSION" > "$STAGING_DIR/VERSION"
printf '%s\n' "$CLOAI_PLATFORM" > "$STAGING_DIR/PLATFORM"

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE" "$CHECKSUM"
tar -C "$STAGING_ROOT" -czf "$ARCHIVE" "$PACKAGE_NAME"
(
  cd "$DIST_DIR"
  sha256sum "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"
  sha256sum --check "$(basename "$CHECKSUM")"
)

printf '已生成：%s\n' "$ARCHIVE"
printf '校验和：%s\n' "$CHECKSUM"
