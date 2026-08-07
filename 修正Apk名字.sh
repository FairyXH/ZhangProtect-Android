MODDIR=${0%/*}
packs=$(ls ${MODDIR}/system/product/app)

for i in ${packs}; do
	packsx=$(find "${MODDIR}/system/product/app/${i}" -name "*.apk" | grep -vE "fuck_miui_tml")
	for j in $packsx; do
		echo $j
		apkinfo=$(${MODDIR}/aapt dump badging "${j}" | grep 'package' | sed 's/ /\n/g' | grep 'name=' | grep -v 'compileSdkVersionCodename=' | sed $'s/\'//g')
		apkinfo=${apkinfo#*=}
		mv "${j}" "${MODDIR}/system/product/app/${i}/${apkinfo}.apk" 2>/dev/null
		mv "${MODDIR}/system/product/app/${i}/" "${MODDIR}/system/product/app/${apkinfo}" 2>/dev/null
	done
done
