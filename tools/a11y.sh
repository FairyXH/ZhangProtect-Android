#!/system/bin/sh
set -u

KEY_SERVICES="enabled_accessibility_services"
KEY_ENABLED="accessibility_enabled"
PERM_BIND="android.permission.BIND_ACCESSIBILITY_SERVICE"

log()  { echo "[a11y] $*"; }
warn() { echo "[a11y][WARN] $*" >&2; }
die()  { echo "[a11y][ERR] $*" >&2; exit 1; }

need_root() { [ "$(id -u 2>/dev/null)" = "0" ] || die "需要 root"; }

raw_services() { settings get secure "$KEY_SERVICES" 2>/dev/null | tr -d '\r'; }

list_components() {
	raw="$(raw_services)"
	[ -z "$raw" ] || [ "$raw" = "null" ] && return 0
	echo "$raw" | tr ':' '\n' | grep -v '^$'
}

has_service() {
	list_components | grep -q "^$1/" 2>/dev/null
}

bound_components() {
	dumpsys accessibility 2>/dev/null | sed -n '/^ *Enabled services:/,/^ *Binding services:/p' | grep -oE '[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+/[A-Za-z0-9_.$]+' | sort -u
}

bound_count() {
	dumpsys accessibility 2>/dev/null | sed -n '/^ *Bound services:/,/^ *Enabled services:/p' | grep -o 'Service\[label=' | wc -l
}

probe_components() {
	dump="$(cmd package dump "$1" 2>/dev/null)"
	[ -z "$dump" ] && dump="$(dumpsys package "$1" 2>/dev/null)"
	[ -z "$dump" ] && return 0
	echo "$dump" | sed -n '/android\.accessibilityservice\.AccessibilityService:/,/^[[:space:]]*[A-Za-z][A-Za-z ]*:$/p' | grep -oE '[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+/[A-Za-z0-9_.$]+' | grep -v '^android/' | sort -u
}

norm_component() {
	pkg="${1%%/*}"; cls="${1#*/}"
	case "$cls" in
		.*) cls="$pkg$cls" ;;
		*.*) ;;
		*) cls="$pkg.$cls" ;;
	esac
	echo "$pkg/$cls"
}

is_installed() {
	cmd package list packages "$1" 2>/dev/null | grep -q "^package:$1$"
}

get_uid() {
	dumpsys package "$1" 2>/dev/null | sed -n 's/.*appId=\([0-9]*\).*/\1/p' | head -1
}

services_enabled() { [ "$(settings get secure "$KEY_ENABLED" 2>/dev/null | tr -d '\r')" = "1" ]; }

ensure_master_switch() {
	if ! services_enabled; then
		settings put secure "$KEY_ENABLED" 1 >/dev/null 2>&1
		log "  [switch] accessibility_enabled=1"
	fi
}

write_services() { settings put secure "$KEY_SERVICES" "$1" >/dev/null 2>&1; }

wait_contains() {
	i=0
	while [ $i -lt 25 ]; do
		raw_services | grep -qF "$1" 2>/dev/null && return 0
		i=$((i + 1)); sleep 0.1
	done
	return 1
}

drop_entries() {
	raw="$(raw_services)"
	[ -z "$raw" ] || [ "$raw" = "null" ] && return 0
	new="$(echo "$raw" | tr ':' '\n' | awk -v p="$1/" 'index($0,p)!=1' | paste -sd: -)"
	[ "$new" != "$raw" ] && write_services "$new" && return 0
	return 1
}

enable_service() {
	pkg="$1"
	if has_service "$pkg"; then log "  [service] 已启用，跳过"; ensure_master_switch; return 0; fi
	comps="$(probe_components "$pkg")"
	if [ -z "$comps" ]; then warn "  [service] 未找到无障碍服务组件"; return 1; fi
	raw="$(raw_services)"
	[ -z "$raw" ] || [ "$raw" = "null" ] && raw=""
	new="$raw"
	ok=0
	for c in $comps; do
		n="$(norm_component "$c")"
		echo "$new" | tr ':' '\n' | grep -qF "$n" && { log "  [service] 已在列表中 $n"; ok=1; continue; }
		new="${new:+$new:}$n"
		if write_services "$new" && wait_contains "$n"; then
			log "  [service] 已启用 $n"; ok=1
		else warn "  [service] 写入未生效: $n"; new="$raw"; fi
	done
	[ "$ok" = "1" ] && ensure_master_switch
	[ "$ok" = "1" ]
}

disable_service() {
	if drop_entries "$1"; then log "  [service] 已关闭"; return 0; fi
	log "  [service] 未启用"; return 1
}

restart_app() {
	[ -n "${1:-}" ] || return 0
	am force-stop "$1" >/dev/null 2>&1
}

cmd_set() {
	[ $# -ge 1 ] || die "用法: a11y.sh set <包名> [...]"
	for pkg in "$@"; do
		echo "=============================================="
		log "处理: $pkg"
		is_installed "$pkg" || { warn "包未安装，跳过"; continue; }
		enable_service "$pkg" || true
	done
	echo "=============================================="
	log "完成（部分 ROM 需重启应用或等待系统重读无障碍配置）"
}

cmd_list() {
	case "${1:-}" in
		-v|--verbose) list_components ;;
		--raw) raw_services ;;
		--bound) bound_components ;;
		--check) [ -n "${2:-}" ] || die "--check 需要包名"; has_service "$2" && echo yes || echo no ;;
		*) list_components | sed 's#/.*##' | sort -u ;;
	esac
}

cmd_del() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--listener|--service) ;;
			-*) die "未知选项: $1" ;;
			*) break ;;
		esac
		shift
	done
	[ $# -ge 1 ] || die "用法: a11y.sh del <包名> [...]"
	for pkg in "$@"; do
		echo "========== $pkg =========="
		disable_service "$pkg" || true
	done
	log "完成"
}

cmd_check() {
	[ $# -ge 1 ] || die "用法: a11y.sh check <包名>"
	for pkg in "$@"; do
		echo "========== $pkg =========="
		if is_installed "$pkg"; then echo "安装: 是 (uid=$(get_uid "$pkg"))"; else echo "安装: 否"; fi
		echo "无障碍总开关: $(services_enabled && echo 开 || echo 关)"
		if has_service "$pkg"; then
			echo "无障碍权限: 已启用"
			list_components | grep "^$pkg/" | sed 's/^/            /'
		else echo "无障碍权限: 未启用"; fi
		comps="$(probe_components "$pkg")"
		if [ -n "$comps" ]; then echo "可用组件:"; echo "$comps" | sed 's/^/            /'; else echo "可用组件: (无)"; fi
		bs="$(bound_components | grep "^$pkg/")"
		if [ -n "$bs" ]; then
			echo "已启用组件:"
			echo "$bs" | sed 's/^/            /'
		fi
		echo "系统实际绑定服务数: $(bound_count)"
		echo
	done
}

cmd_bound() {
	echo "无障碍总开关: $(services_enabled && echo 开 || echo 关)"
	echo "实际绑定服务数: $(bound_count)"
	echo "-- 已启用（配置）--"
	list_components | sed 's/^/  /'
}

cmd_clean() {
	dry=0
	[ "${1:-}" = "--dry-run" ] && dry=1
	raw="$(raw_services)"
	[ -z "$raw" ] || [ "$raw" = "null" ] && { log "列表为空"; exit 0; }
	kept=""; removed=0
	for line in $(echo "$raw" | tr ':' ' '); do
		pkg="${line%%/*}"
		if ! is_installed "$pkg"; then
			warn "移除（包未安装）: $line"; removed=$((removed + 1)); continue
		fi
		comps="$(probe_components "$pkg")"
		if [ -z "$comps" ]; then
			log "保留（无法枚举组件）: $line"; kept="${kept:+$kept:}$line"; continue
		fi
		found=0
		for c in $comps; do [ "$(norm_component "$c")" = "$line" ] && { found=1; break; }; done
		if [ "$found" = "1" ]; then kept="${kept:+$kept:}$line"; else warn "移除（组件不存在）: $line"; removed=$((removed + 1)); fi
	done
	if [ "$dry" = "1" ]; then log "[dry-run] 将移除 $removed 条"; exit 0; fi
	[ "$removed" -gt 0 ] && write_services "$kept"
	log "清理完成，移除 $removed 条"
}

cmd_restart() {
	[ $# -ge 1 ] || die "用法: a11y.sh restart <包名> [...]"
	for pkg in "$@"; do
		log "重启 $pkg"
		restart_app "$pkg"
	done
}

cmd_summary() {
	n=0
	for p in $(cmd_list); do n=$((n + 1)); done
	echo "已启用无障碍的应用: $n 个（总开关: $(services_enabled && echo 开 || echo 关)）"
	cmd_list | sed 's/^/  /'
}

usage() {
	cat <<'EOF'
a11y.sh —— 无障碍服务工具

用法:
  a11y.sh set     <包名> [...]     启用无障碍服务（自动探测组件 + 开总开关）
  a11y.sh list    [-v|--raw|--bound|--check <包>]  列出已启用的包（默认一行一个）
  a11y.sh del     <包名> [...]     关闭无障碍服务
  a11y.sh check   <包名> [...]     查看详情（含实际绑定状态）
  a11y.sh bound                    显示已启用 vs 实际绑定
  a11y.sh clean   [--dry-run]      清理失效条目
  a11y.sh restart <包名> [...]     重启应用（触发重新绑定）
  a11y.sh summary                  汇总
EOF
}

need_root
action="${1:-help}"
[ $# -gt 0 ] && shift
case "$action" in
	set) cmd_set "$@" ;;
	list|ls) cmd_list "$@" ;;
	del|rm) cmd_del "$@" ;;
	check) cmd_check "$@" ;;
	bound) cmd_bound ;;
	clean) cmd_clean "$@" ;;
	restart) cmd_restart "$@" ;;
	summary) cmd_summary ;;
	help|-h|--help) usage ;;
	*) echo "未知命令: $action" >&2; usage >&2; exit 2 ;;
esac