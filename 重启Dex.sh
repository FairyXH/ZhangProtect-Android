#!/system/bin/sh
# 重启 ZhangSystemDex daemon
MODDIR=$(cd "$(dirname "$0")" && pwd)
sh "${MODDIR}/停止Dex.sh"
sleep 1
sh "${MODDIR}/service.sh"
echo "ZhangSystemDex 已重启"
