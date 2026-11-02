#!/bin/sh
# 使用本机研历开发工具生成供测试安装的 Android APK。
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TOOLS_DIR="$HOME/Developer/yanli-tools"
export JAVA_HOME="$TOOLS_DIR/jdk/Contents/Home"
export ANDROID_HOME="$TOOLS_DIR/android"
export ANDROID_USER_HOME="$TOOLS_DIR/android-user"
export GRADLE_USER_HOME="$TOOLS_DIR/gradle-cache"
export PUB_CACHE="$TOOLS_DIR/pub-cache"
export FLUTTER_SUPPRESS_ANALYTICS=true
export PATH="$JAVA_HOME/bin:$TOOLS_DIR/flutter/bin:$PATH"
cd "$ROOT_DIR"
flutter pub get
flutter build apk --release
cp "$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk" "$ROOT_DIR/研历YanLi-安卓体验版.apk"
printf '\nAPK 位置：%s\n' "$ROOT_DIR/研历YanLi-安卓体验版.apk"
