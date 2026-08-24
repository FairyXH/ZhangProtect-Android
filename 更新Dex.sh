#!/system/bin/sh

MODDIR=$(cd "$(dirname "$0")" && pwd)

DEX_URL="https://raw.githubusercontent.com/FairyXH/ZhangSystemDex/main/Main.dex"
DEX_FILE="$MODDIR/Main.dex"

echo "正在更新 Main.dex..."

# 下载到临时文件，避免下载中断导致原文件损坏
TMP_FILE="$DEX_FILE.tmp"

if command -v curl >/dev/null 2>&1; then
	curl -L "$DEX_URL" -o "$TMP_FILE"
elif command -v wget >/dev/null 2>&1; then
	wget -O "$TMP_FILE" "$DEX_URL"
else
	echo "错误：未找到 curl 或 wget"
	exit 1
fi

# 检查下载是否成功
if [ $? -eq 0 ] && [ -s "$TMP_FILE" ]; then
	mv -f "$TMP_FILE" "$DEX_FILE"
	chmod 644 "$DEX_FILE"
	echo "Main.dex 更新完成"
else
	echo "Main.dex 更新失败"
	rm -f "$TMP_FILE"
	exit 1
fi
