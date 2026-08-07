#!/system/bin/sh
# ZhangSystemDex 调试运行脚本
# 与 service.sh 启动方式完全等效（同一 classpath、同一入口类、同一模块目录参数），
# 但以前台方式运行，终端实时输出，Ctrl+C 结束，便于调试。
MODDIR=$(cd "$(dirname "$0")" && pwd)
zhang_config="/data/adb/Zhang"
DEX_SRC="${MODDIR}/Main.dex"
DEX_DST="${zhang_config}/Main.dex"
LOGDIR="${zhang_config}/log"
NICE_NAME="zhangsystemdex"
MAIN_CLASS="io.github.fairyxh.zhangsystemdex.Main"

echo "==== ZhangSystemDex 调试模式 ===="
mkdir -p "${zhang_config}"
mkdir -p "${LOGDIR}"

# 同步 Main.dex（与 service.sh 等效）
if [ ! -f "${DEX_SRC}" ]; then
  echo "! Main.dex 不存在: ${DEX_SRC}"
  exit 1
fi
cp -f "${DEX_SRC}" "${DEX_DST}"
chmod 755 "${DEX_DST}"
echo "Main.dex 已同步: ${DEX_DST}"

# 终止已运行的正式 daemon，避免双实例（与 service.sh 相同的 pid 检测逻辑）
if [ -f "${zhang_config}/daemon.pid" ]; then
  oldpid=$(cat "${zhang_config}/daemon.pid" 2>/dev/null)
  if [ -n "${oldpid}" ] && [ -d "/proc/${oldpid}" ]; then
    oldcmd=$(tr '\0' ' ' </proc/${oldpid}/cmdline 2>/dev/null)
    case "${oldcmd}" in
      *"${NICE_NAME}"*|*"${MAIN_CLASS}"*)
        echo "已停止正式 daemon (pid ${oldpid})"
        kill "${oldpid}" 2>/dev/null
        sleep 1
        ;;
    esac
  fi
  rm -f "${zhang_config}/daemon.pid"
fi

# 再兜底清理一次残留实例
pkill -f "${MAIN_CLASS}" 2>/dev/null
sleep 1

echo "配置根: ${zhang_config}"
echo "文件日志: ${LOGDIR}/zhang.log"
echo "注意: 若 config.conf 中 log_enabled=false，Dex 将完全静默"
# 默认进入调试菜单（传 menu 参数）；传 normal 则直接前台运行全部已启用功能
ARG="${1:-menu}"
echo "启动参数: ${ARG}（menu=调试菜单，normal=正常前台运行）"
echo "前台运行中，Ctrl+C 结束调试..."
echo "----------------------------------------"

exec /system/bin/app_process \
  -Djava.class.path="${DEX_DST}" \
  /system/bin \
  --nice-name="${NICE_NAME}" \
  "${MAIN_CLASS}" \
  "${MODDIR}" \
  "${ARG}"
