safe_rm() {
	#防止拼接空字符串导致误删主数据目录
	#参数1: 主数据目录
	#参数2: 目标应用数据目录
	if [ "$1" = "$2" ]; then
		echo "安全禁止删除:$2"
	else
		rm -rf "$2"
		echo "Success"
	fi
}
clear
echo "此脚本将启用所有系统package并清除其数据"
echo "请仅在必要时执行,例如意外冻结系统应用导致部分功能异常等,可使用本脚本尝试重置修复"
echo "按任意键继续"
read -n 1 -s
for i in $(pm list packages -s | grep -vE "com.android.launcher"); do
	i=${i##*:}
	echo
	echo "================"
	echo "操作: ${i}"
	echo "启用包"
	pm enable ${i}
	echo "清除数据"
	pm clear ${i}
	echo "清除数据目录残留"
	media_dir="/data/media/0/Android/data/"
	media_data_dir="${media_dir}${i}"
	data_dir="/data/data/"
	data_data_dir="${data_dir}${i}"
	safe_rm "${media_dir}" "${media_data_dir}"
	safe_rm "${data_dir}" "${data_data_dir}"
	echo "================"
done
echo "清理缓存"
rm -rf /data/system/package_cache/
rm -rf /data/magisk_backup_*
rm -rf /data/resource-cache/*
rm -rf /data/system/package_cache/*
rm -rf /cache/*
rm -rf /data/dalvik-cache/*
echo "操作成功完成 请重启设备"
