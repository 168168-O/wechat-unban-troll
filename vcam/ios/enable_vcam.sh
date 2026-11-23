#!/bin/sh
# iPhone 12 / iOS 15.3 半越狱下的一键启用（rootless）
# 放 /var/mobile/Documents/enable_vcam.sh，Sileo 里装完 tweak 后跑一次
# 用法：ssh 进手机  sh /var/mobile/Documents/enable_vcam.sh

set -e
DOC=/var/mobile/Documents
VCAM="$DOC/vcam"

echo "[1/5] 检查 rootless 根目录"
for p in /var/jb /var/xina /Library/MobileSubstrate; do
  [ -e "$p" ] && echo "    找到 $p"
done

echo "[2/5] 检查 tweak 是否已注入"
if [ -e /var/jb/Library/MobileSubstrate/DynamicLibraries/vcam.dylib ]; then
  echo "    vcam.dylib 已在 /var/jb（rootless）"
elif [ -e /Library/MobileSubstrate/DynamicLibraries/vcam.dylib ]; then
  echo "    vcam.dylib 在 /Library（rootful）——这个包是 rootful 版"
else
  echo "    没找到 vcam.dylib，先装 deb"
fi

echo "[3/5] 准备素材目录"
mkdir -p "$VCAM"
for a in front up down left right mouth blink nod shake digits; do
  if [ -f "$VCAM/$a.mov" ]; then
    echo "    $a.mov OK"
  else
    echo "    缺 $a.mov"
  fi
done

echo "[4/5] 开开关 + 写默认动作"
printf 'front' > "$VCAM/current.txt"

echo "[5/5] 重启微信进程"
killall -9 Weixin 2>/dev/null || true
killall -9 WeChat 2>/dev/null || true
echo "完成。打开微信进任意拍照/人脸页，控制面板会自动浮出。"
