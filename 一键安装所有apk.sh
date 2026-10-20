MODDIR=${0%/*}
packs=$(find "${MODDIR}" -name "*.apk")
echo "开始安装Apk"

chmod +x ${MODDIR}/aapt
for i in ${packs}; do
	if [ -s "${i}" ]; then
		pm install "$i"
	fi
done
echo "完成"
