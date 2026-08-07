# 本模块永不创建 skip_mount（SKIPMOUNT 逻辑已移除）：
# 模块 system/ 覆盖挂载由 Magisk 正常处理，防止安装模板残留 skip_mount 导致内置系统应用不被挂载
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=true

abort() {
	echo "$1"
	echo "! installation failed."
	exit 1
}

add_system_app() {
	add_apkpath=$(pm path "$1")
	if [ ! -z "${add_apkpath}" ]; then
		rm -rf "${MODPATH}/system/product/app/$1/"
		mkdir -p "${MODPATH}/system/product/app/$1/"
		for j in ${add_apkpath}; do
			j=${j#*:}
			cp -f "${j}" "${MODPATH}/system/product/app/$1/" 2>/dev/null
		done
		ui_print "正在将 $1 添加到系统App"
	fi

}
print_modname() {
	return
}

on_install() {
	$BOOTMODE || abort "您无法在Recovery模式下安装本模块！"

	unzip -o "$ZIPFILE" -x 'META-INF/*' -d $MODPATH >/dev/null
	#CPU/性能、反诈快应用屏蔽、遮蔽挂载逻辑已迁移至 ZhangSystemDex，安装完成后首次启动由 Dex 自动执行
	#system_app_add中的包名对应的应用如果已安装,该脚本会将其复制为系统应用,可修改变量system_app_add来添加或删除您所需要的APP,多个包名以空格分开
	#system_app_add="com.agc.gcam84 com.github.kr328.clash rikka.appops com.github.metacubex.clash.meta com.github.kr328.clash"
	#ui_print "正在将预设的应用转换为系统应用,您可在instll.sh中修改它"
	#for addsysapp in ${system_app_add}
	#do
	#add_system_app "${addsysapp}"
	#done
	#for i in $(ime list -s)
	#do
	#i=${i%/*}
	#add_system_app "${i}"
	#done
	#ui_print "完成系统应用添加"

	zip_packs=$(find "${MODPATH}" -name "*.apk" | grep -v "base.apk")
	pack_num=0
	pack_total=0
	for n in ${zip_packs}; do
		pack_total=$((${pack_total} + 1))
	done

	ui_print "正在安装模块自带的App到用户"
	for i in ${zip_packs}; do
		pack_num=$((${pack_num} + 1))
		ui_print "正在执行App安装: ${pack_num}/${pack_total}"

		apk_name=$(basename "${i}")
		apk_name_noapk=$(basename "${i}")
		apk_name_noapk=${apk_name_noapk%.apk}
		if [ -z "$(pm list packages | grep ${apk_name_noapk})" ]; then
			ui_print "正在安装: ${i}"
			tmp="/data/local/tmp/${apk_name}"
			cp -f "${i}" "${tmp}"
			chmod 644 "${tmp}"
			pm install "${tmp}"
			rm -f "${tmp}"
		else
			ui_print "${apk_name_noapk}已安装，跳过"
		fi
	done
	ui_print "App安装完成，开始安装模块功能"

	ui_print "反诈/快应用屏蔽与遮蔽挂载由 ZhangSystemDex 首次启动执行"
	cache_path=/data/dalvik-cache/arm
	[ -d $cache_path"64" ] && cache_path=$cache_path"64"
	for fileName in $system_ext_cache; do
		rm -f $cache_path/system_ext@*@"$fileName"*
		rm -f /data/system/package_cache/*/"$fileName"*
	done

	for fileName in $system_cache; do
		rm -f $cache_path/system@*@"$fileName"*
		rm -f /data/system/package_cache/*/"$fileName"*
	done
	chmod -R 7777 ${MODPATH}
	ui_print "完成，重新启动生效"
}

set_permissions() {
	set_perm_recursive $MODPATH 0 0 7777 7777
}
