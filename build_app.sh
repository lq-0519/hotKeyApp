#!/bin/bash
#
# build_app.sh — 编译并组装成可运行的 hotKeyApp.app
#
# 用法:
#   ./build_app.sh            # release 构建并组装 .app
#   ./build_app.sh --run      # 构建后直接启动
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="hotKeyApp"
BUILD_DIR="${PROJECT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
# 固定本机已有证书的指纹,避免同名新证书或临时签名改变应用授权身份。
# 证书名称为 InputHoldSwitcher Local Code Signing;缺失时停止,不生成新证书。
SIGNING_IDENTITY="659A2CD838DF7ADCB88F313BDE6572A223C4923C"
# 保持已有快捷键配置、开机自启登记与后续构建使用同一应用标识。
BUNDLE_ID="com.hotkeyapp.launcher"
# 本机原有开机自启登记使用此安装路径;--run 必须从固定位置启动,不运行临时副本。
INSTALL_PATH="/Users/bytedance/projects/hotKeyApp/build/hotKeyApp.app"

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--run" ) ]]; then
  echo "用法: $0 [--run]" >&2
  exit 1
fi
if ! /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -Fq "$SIGNING_IDENTITY"; then
  echo "缺少固定签名证书 InputHoldSwitcher Local Code Signing,请恢复原证书及私钥。" >&2
  exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PROJECT_DIR/Resources/Info.plist")" != "$BUNDLE_ID" ]]; then
  echo "应用标识已改变,停止构建以保留原授权身份。" >&2
  exit 1
fi
if [[ "${1:-}" == "--run" && "$APP_BUNDLE" != "$INSTALL_PATH" ]]; then
  echo "请从原安装目录构建并运行: $INSTALL_PATH" >&2
  exit 1
fi

# SwiftPM 缓存放在仓库外的专用持久目录,后续重复构建可复用,也不会与其他项目混用。
SPM_ROOT="${HOME}/Library/Caches/hotKeyApp/SwiftPM"
SPM_FLAGS=(--disable-sandbox
  --cache-path "$SPM_ROOT/cache"
  --config-path "$SPM_ROOT/config"
  --security-path "$SPM_ROOT/security"
  --scratch-path "$SPM_ROOT/build")
mkdir -p "$SPM_ROOT/cache" "$SPM_ROOT/config" "$SPM_ROOT/security" "$SPM_ROOT/build"

# 先在仓库外完成组装与签名,验证成功后才替换现有应用。
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hotkeyapp-build.XXXXXX")"
STAGED_APP="$WORK_DIR/$APP_NAME.app"
CONTENTS="$STAGED_APP/Contents"
# 在替换中途失败时恢复原包;成功或失败都会清理组装用临时文件。
cleanup() {
  if [[ -d "$WORK_DIR/previous.app" ]]; then
    rm -rf "$APP_BUNDLE"
    mv "$WORK_DIR/previous.app" "$APP_BUNDLE"
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "==> [1/5] 编译 (release)"
cd "${PROJECT_DIR}"
swift build -c release "${SPM_FLAGS[@]}"

BIN_PATH="$(swift build -c release "${SPM_FLAGS[@]}" --show-bin-path)/${APP_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
  echo "!! 找不到可执行文件: ${BIN_PATH}" >&2
  exit 1
fi

echo "==> [2/5] 组装 .app 目录结构"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"

echo "==> [3/5] 拷贝可执行文件与 Info.plist"
cp "${BIN_PATH}" "${CONTENTS}/MacOS/${APP_NAME}"
cp "${PROJECT_DIR}/Resources/Info.plist" "${CONTENTS}/Info.plist"
chmod +x "${CONTENTS}/MacOS/${APP_NAME}"

echo "==> [4/5] 使用固定证书签名并验证"
# 仅清除隔离标记以避免 App Translocation,不清除其他无关扩展属性。
xattr -dr com.apple.quarantine "$STAGED_APP" 2>/dev/null || true
codesign --force --timestamp=none --sign "$SIGNING_IDENTITY" "$STAGED_APP"
codesign --verify --deep --strict \
  -R "=identifier \"$BUNDLE_ID\" and certificate root = H\"$SIGNING_IDENTITY\"" "$STAGED_APP"

if [[ "${1:-}" == "--run" ]]; then
  # 仅在新版已验证后结束旧实例,避免同时注册相同全局快捷键。
  pkill -x "${APP_NAME}" 2>/dev/null || true
  for attempt in {1..50}; do
    if ! pgrep -x "$APP_NAME" >/dev/null; then break; fi
    sleep 0.1
  done
  if pgrep -x "$APP_NAME" >/dev/null; then
    echo "旧实例尚未退出,保留原应用,停止替换。" >&2
    exit 1
  fi
fi

mkdir -p "$BUILD_DIR"
if [[ -e "$APP_BUNDLE" ]]; then mv "$APP_BUNDLE" "$WORK_DIR/previous.app"; fi
mv "$STAGED_APP" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
if [[ "${1:-}" == "--run" ]]; then
  echo "==> 启动 ${APP_NAME}"
  open "$INSTALL_PATH"
fi
rm -rf "$WORK_DIR/previous.app"
echo "==> [5/5] 完成: ${APP_BUNDLE}"
