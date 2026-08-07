#!/system/bin/sh
# 启动 ZhangSystemDex daemon（等价于 service.sh）
MODDIR=$(cd "$(dirname "$0")" && pwd)
sh "${MODDIR}/service.sh"
echo "ZhangSystemDex 已启动"
echo "日志: /data/adb/Zhang/log/daemon.log（终端）/ zhang.log（文件）"
