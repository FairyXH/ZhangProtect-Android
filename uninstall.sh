rm_data() {
	rm -rf ${Clash_data_dir}
	rm -rf /data/FilesBackup
	rm -rf /data/adb/Zhang
}
#此脚本在卸载时进行

# 停止 ZhangSystemDex daemon
if [ -f /data/adb/Zhang/daemon.pid ]; then
	oldpid=$(cat /data/adb/Zhang/daemon.pid 2>/dev/null)
	if [ -n "${oldpid}" ] && [ -d "/proc/${oldpid}" ]; then
		oldcmd=$(tr '\0' ' ' </proc/${oldpid}/cmdline 2>/dev/null)
		case "${oldcmd}" in
		*"io.github.fairyxh.zhangsystemdex.Main"*)
			kill "${oldpid}" 2>/dev/null
			;;
		esac
	fi
fi
pkill -f "io.github.fairyxh.zhangsystemdex.Main" 2>/dev/null

# 清理列表
tmp_list="MiuiHome"
dda=/data/dalvik-cache/arm
[ -d $dda"64" ] && dda=$dda"64"
for i in $tmp_list; do
	rm -f $dda/system@*@"$i"*
done
rm -rf /data/system/package_cache/*
rm_data
