MODDIR=${0%/*}
packs=$(find "${MODDIR}" -name "*.apk")
echo "开始升级模块系统应用Apk"
echo "将从当前设备提取安装包并覆盖"
permissions="android.permission.WRITE_SETTINGS
android.permission.WRITE_SECURE_SETTINGS
android.permission.PACKAGE_USAGE_STATS
android.permission.EXPAND_STATUS_BAR
android.permission.ACCESS_NOTIFICATION_POLICY
android.permission.SYSTEM_ALERT_WINDOW
android.permission.RECEIVE_BOOT_COMPLETED
android.permission.QUERY_ALL_PACKAGES
android.permission.FOREGROUND_SERVICE"

chmod +x ${MODDIR}/aapt
for i in ${packs}; do
	echo "正在处理：${i}"
	if [ -s "${i}" ]; then
		apkinfo=$(${MODDIR}/aapt dump badging "${i}" | grep 'package' | sed 's/ /\n/g' | grep 'name=' | grep -v 'compileSdkVersionCodename=' | sed $'s/\'//g')
		apkinfo=${apkinfo#*=}
		for j in $permissions; do
			pm grant ${apkinfo} $j 2>/dev/null
		done
		apkpath=$(pm path "${apkinfo}")
		apkpath=${apkpath#*:}
		cp -f "${apkpath}" "${i}" 2>/dev/null
	fi
done
echo "完成"
