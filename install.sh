#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

VERSION="${CLOAI_VERSION:-0.0.6}"
PLATFORM="android-arm64"
REPOSITORY="${CLOAI_REPOSITORY:-andTDWF/cloai-termux-installer}"
INSTALL_ROOT="${CLOAI_INSTALL_ROOT:-$HOME/.local/share/cloai}"
BIN_DIR="${CLOAI_BIN_DIR:-${PREFIX:-$HOME/.local}/bin}"
LOCAL_ARCHIVE="${CLOAI_LOCAL_ARCHIVE:-}"
PACKAGE_NAME="cloai-${VERSION}-${PLATFORM}"
ARCHIVE_NAME="$PACKAGE_NAME.tar.gz"

fail() {
  printf 'cloai installer: %s\n' "$*" >&2
  exit 1
}

case "$(uname -s)" in
  Linux) ;;
  *) fail "当前仅支持 Termux/Android" ;;
esac

case "$(uname -m)" in
  aarch64|arm64) ;;
  *) fail "当前仅支持 ARM64，检测到：$(uname -m)" ;;
esac

[[ "${PREFIX:-}" == *com.termux* ]] || fail "请在 Termux 中运行安装器"

for command in tar sha256sum mktemp install ln readlink; do
  command -v "$command" >/dev/null 2>&1 || fail "缺少命令：$command"
done

if ! command -v grun >/dev/null 2>&1; then
  command -v pkg >/dev/null 2>&1 || fail "缺少 glibc-runner，且找不到 pkg"
  printf '正在安装 glibc-runner...\n'
  pkg install -y glibc-repo
  pkg install -y glibc-runner
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/cloai-install.XXXXXX")"
cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

ARCHIVE="$TMP_ROOT/$ARCHIVE_NAME"
CHECKSUM="$ARCHIVE.sha256"

if [[ -n "$LOCAL_ARCHIVE" ]]; then
  [[ -f "$LOCAL_ARCHIVE" ]] || fail "找不到本地归档：$LOCAL_ARCHIVE"
  [[ -f "$LOCAL_ARCHIVE.sha256" ]] || fail "找不到校验文件：$LOCAL_ARCHIVE.sha256"
  install -m 644 "$LOCAL_ARCHIVE" "$ARCHIVE"
  install -m 644 "$LOCAL_ARCHIVE.sha256" "$CHECKSUM"
else
  command -v curl >/dev/null 2>&1 || fail "缺少命令：curl"
  BASE_URL="https://github.com/$REPOSITORY/releases/download/v$VERSION"
  printf '正在下载 Cloai %s...\n' "$VERSION"
  curl -fsSL "$BASE_URL/$ARCHIVE_NAME" -o "$ARCHIVE"
  curl -fsSL "$BASE_URL/$ARCHIVE_NAME.sha256" -o "$CHECKSUM"
fi

(
  cd "$TMP_ROOT"
  sha256sum --check "$(basename "$CHECKSUM")"
)

tar -xzf "$ARCHIVE" -C "$TMP_ROOT"
PACKAGE_DIR="$TMP_ROOT/$PACKAGE_NAME"
[[ -d "$PACKAGE_DIR" ]] || fail "归档结构无效：缺少 $PACKAGE_NAME"
[[ "$(tr -d '\r\n' < "$PACKAGE_DIR/VERSION")" == "$VERSION" ]] || fail "归档版本不匹配"
[[ "$(tr -d '\r\n' < "$PACKAGE_DIR/PLATFORM")" == "$PLATFORM" ]] || fail "归档平台不匹配"

for path in bin/cloai bin/buno lib/bun-shim.so cloai-launcher; do
  [[ -f "$PACKAGE_DIR/$path" ]] || fail "归档缺少：$path"
done

VERSIONS_DIR="$INSTALL_ROOT/versions"
VERSION_DIR="$VERSIONS_DIR/$VERSION"
NEW_VERSION_DIR="$VERSIONS_DIR/.${VERSION}.new.$$"
CURRENT_LINK="$INSTALL_ROOT/current"
PREVIOUS_TARGET=""
REUSE_RUNTIME_DIR=""

if
  [[ -L "$CURRENT_LINK" ]] &&
  [[ -x "$CURRENT_LINK/bin/buno" ]] &&
  [[ -f "$CURRENT_LINK/lib/bun-shim.so" ]]
then
  REUSE_RUNTIME_DIR="$(CDPATH= cd -- "$CURRENT_LINK" && pwd -P)"
fi

mkdir -p "$VERSIONS_DIR" "$BIN_DIR"
rm -rf "$NEW_VERSION_DIR"
mkdir -p "$NEW_VERSION_DIR/bin" "$NEW_VERSION_DIR/lib"
install -m 755 "$PACKAGE_DIR/bin/cloai" "$NEW_VERSION_DIR/bin/cloai"
if [[ -n "$REUSE_RUNTIME_DIR" ]]; then
  ln -s "$REUSE_RUNTIME_DIR/bin/buno" "$NEW_VERSION_DIR/bin/buno"
  ln -s "$REUSE_RUNTIME_DIR/lib/bun-shim.so" "$NEW_VERSION_DIR/lib/bun-shim.so"
  printf '复用现有 Bun 运行环境，仅更新 Cloai 二进制。\n'
else
  install -m 755 "$PACKAGE_DIR/bin/buno" "$NEW_VERSION_DIR/bin/buno"
  install -m 755 "$PACKAGE_DIR/lib/bun-shim.so" "$NEW_VERSION_DIR/lib/bun-shim.so"
fi
install -m 644 "$PACKAGE_DIR/VERSION" "$NEW_VERSION_DIR/VERSION"
install -m 644 "$PACKAGE_DIR/PLATFORM" "$NEW_VERSION_DIR/PLATFORM"

if [[ -L "$CURRENT_LINK" ]]; then
  PREVIOUS_TARGET="$(readlink "$CURRENT_LINK")"
elif [[ -e "$CURRENT_LINK" ]]; then
  fail "$CURRENT_LINK 已存在且不是符号链接"
fi

rm -rf "$VERSION_DIR"
mv "$NEW_VERSION_DIR" "$VERSION_DIR"
ln -sfn "versions/$VERSION" "$CURRENT_LINK"
install -m 755 "$PACKAGE_DIR/cloai-launcher" "$BIN_DIR/cloai"

if ! CLOAI_INSTALL_ROOT="$INSTALL_ROOT" "$BIN_DIR/cloai" --version; then
  if [[ -n "$PREVIOUS_TARGET" ]]; then
    ln -sfn "$PREVIOUS_TARGET" "$CURRENT_LINK"
  else
    rm -f "$CURRENT_LINK"
  fi
  fail "新版本启动验证失败，已恢复之前版本"
fi

printf '\nCloai %s 安装完成：%s\n' "$VERSION" "$BIN_DIR/cloai"
