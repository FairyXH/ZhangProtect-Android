#!/system/bin/sh
# 停止 ZhangSystemDex daemon
zhang_config="/data/adb/Zhang"
NICE_NAME="zhangsystemdex"
MAIN_CLASS="io.github.fairyxh.zhangsystemdex.Main"

if [ -f "${zhang_config}/daemon.pid" ]; then
	oldpid=$(cat "${zhang_config}/daemon.pid" 2>/dev/null)
	if [ -n "${oldpid}" ] && [ -d "/proc/${oldpid}" ]; then
		oldcmd=$(tr '\0' ' ' </proc/${oldpid}/cmdline 2>/dev/null)
		case "${oldcmd}" in
		*"${NICE_NAME}"* | *"${MAIN_CLASS}"*)
			kill "${oldpid}" 2>/dev/null
			echo "已停止 daemon (pid ${oldpid})"
			;;
		esac
	fi
	rm -f "${zhang_config}/daemon.pid"
fi
pkill -f "${MAIN_CLASS}" 2>/dev/null
pkill -f "${NICE_NAME}" 2>/dev/null
echo "ZhangSystemDex 已停止"
