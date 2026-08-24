MODDIR=$(cd "$(dirname "$0")" && pwd)
zhang_config="/data/adb/Zhang"
DEX_SRC="${MODDIR}/Main.dex"
DEX_DST="${zhang_config}/Main.dex"
LOGDIR="${zhang_config}/log"
PIDFILE="${zhang_config}/daemon.pid"
NICE_NAME="zhangsystemdex"
MAIN_CLASS="io.github.fairyxh.zhangsystemdex.Main"

mkdir -p "${zhang_config}"
mkdir -p "${LOGDIR}"

# 初始化 config.conf（配置根 + 日志总开关，Dex 首次运行也会兜底生成）
if [ ! -f "${MODDIR}/config.conf" ]; then
	echo "root_dir=/data/adb/Zhang" >"${MODDIR}/config.conf"
	echo "log_enabled=true" >>"${MODDIR}/config.conf"
	echo "ZhangSystemDex: config.conf initialized"
fi

# 引入 Dex：模块 Main.dex -> 配置根
if [ ! -f "${DEX_SRC}" ]; then
	echo "! Main.dex not found in module directory: ${DEX_SRC}"
	exit 1
fi
cp -f "${DEX_SRC}" "${DEX_DST}"
chmod 755 "${DEX_DST}"
echo "ZhangSystemDex: Main.dex synced to ${DEX_DST}"

# 防重复启动
if [ -f "${PIDFILE}" ]; then
	oldpid=$(cat "${PIDFILE}" 2>/dev/null)
	if [ -n "${oldpid}" ] && [ -d "/proc/${oldpid}" ]; then
		oldcmd=$(tr '\0' ' ' </proc/${oldpid}/cmdline 2>/dev/null)
		case "${oldcmd}" in
		*"${NICE_NAME}"* | *"${MAIN_CLASS}"*)
			echo "ZhangSystemDex already running (pid ${oldpid})"
			exit 0
			;;
		esac
		kill "${oldpid}" 2>/dev/null
		sleep 1
	fi
	rm -f "${PIDFILE}"
fi

# 启动 Dex daemon（终端输出 -> daemon.log，内部 Logger 同时写 zhang.log）
nohup /system/bin/app_process \
	-Djava.class.path="${DEX_DST}" \
	/system/bin \
	--nice-name="${NICE_NAME}" \
	"${MAIN_CLASS}" \
	"${MODDIR}" \
	>"${LOGDIR}/daemon.log" 2>&1 &
echo $! >"${PIDFILE}"

sleep 1
if [ -d "/proc/$(cat ${PIDFILE})" ]; then
	echo "ZhangSystemDex started, pid $(cat ${PIDFILE})"
else
	echo "! ZhangSystemDex failed to start, see ${LOGDIR}/daemon.log"
fi
