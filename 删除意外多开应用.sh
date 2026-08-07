MODDIR=${0%/*}
packs=$(find "${MODDIR}/system/product/app" -name "*.apk")
chmod +x ${MODDIR}/aapt

for user in $(ls /data/user | grep -wvE "0"); do

	echo "正在从 ${user} 卸载"
	pm uninstall --user "${user}" "com.softwarebakery.drivedroid.paid"
	for i in ${packs}; do
		if [ -s "${i}" ]; then
			apkinfo=$(${MODDIR}/aapt dump badging "${i}" | grep 'package' | sed 's/ /\n/g' | grep 'name=' | grep -v 'compileSdkVersionCodename=' | sed $'s/\'//g')
			apkinfo=${apkinfo#*=}
			pm uninstall --user "${user}" "${apkinfo}"
		fi
	done
done
echo "完成"
