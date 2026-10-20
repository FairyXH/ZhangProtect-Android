#!/system/bin/sh
set -u

KEY="enabled_notification_listeners"
PERM_POST="android.permission.POST_NOTIFICATIONS"
PERM_POLICY="android.permission.ACCESS_NOTIFICATION_POLICY"
DEX_MAIN="io.github.fairyxh.zhangsystemdex.Main"

log()  { echo "[notif] $*"; }
warn() { echo "[notif][WARN] $*" >&2; }
die()  { echo "[notif][ERR] $*" >&2; exit 1; }

need_root() { [ "$(id -u 2>/dev/null)" = "0" ] || die "需要 root"; }

raw_listeners() { settings get secure "$KEY" 2>/dev/null | tr -d '\r'; }

list_components() {
	raw="$(raw_listeners)"
	[ -z "$raw" ] || [ "$raw" = "null" ] && return 0
	echo "$raw" | tr ':' '\n' | grep -v '^$'
}

has_listener() {
	list_components | grep -q "^$1/" 2>/dev/null
}

drop_entries() {
	raw="$(raw_listeners)"
	[ -z "$raw" ] || [ "$raw" = "null" ] && return 0
	new="$(echo "$raw" | tr ':' '\n' | awk -v p="$1/" 'index($0,p)!=1' | paste -sd: -)"
	[ "$new" != "$raw" ] && settings put secure "$KEY" "$new" >/dev/null 2>&1 && return 0
	return 1
}

probe_components() {
	dump="$(cmd package dump "$1" 2>/dev/null)"
	[ -z "$dump" ] && dump="$(dumpsys package "$1" 2>/dev/null)"
	[ -z "$dump" ] && return 0
	echo "$dump" | sed -n '/android\.service\.notification\.NotificationListenerService:/,/^[[:space:]]*[A-Za-z][A-Za-z ]*:$/p' | grep -oE '[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+/[A-Za-z0-9_.$]+' | grep -v '^android/' | sort -u
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

declares_perm() {
	dumpsys package "$1" 2>/dev/null | sed -n '/requested permissions:/,/install permissions:/p' | grep -q "$2"
}

is_granted() {
	dumpsys package "$1" 2>/dev/null | grep -q "$2: granted=true"
}

is_installed() {
	cmd package list packages "$1" 2>/dev/null | grep -q "^package:$1$"
}

get_uid() {
	dumpsys package "$1" 2>/dev/null | sed -n 's/.*appId=\([0-9]*\).*/\1/p' | head -1
}

wait_contains() {
	i=0
	while [ $i -lt 25 ]; do
		raw_listeners | grep -qF "$1" 2>/dev/null && return 0
		i=$((i + 1)); sleep 0.1
	done
	return 1
}

enable_listener() {
	pkg="$1"
	if has_listener "$pkg"; then log "  [listener] 已授权，跳过"; return 0; fi
	comps="$(probe_components "$pkg")"
	if [ -z "$comps" ]; then warn "  [listener] 未找到监听组件"; return 1; fi
	ok=0
	for c in $comps; do
		n="$(norm_component "$c")"
		if cmd notification allow_listener "$n" >/dev/null 2>&1; then
			if wait_contains "$n"; then log "  [listener] 已授权 $n"; ok=1
			else warn "  [listener] 写入未生效: $n"; fi
		else warn "  [listener] allow_listener 失败: $n"; fi
	done
	[ "$ok" = "1" ]
}

disable_listener() {
	if drop_entries "$1"; then
		cmd notification disallow_listener "$1" >/dev/null 2>&1
		log "  [listener] 已关闭"; return 0
	fi
	log "  [listener] 未授权"; return 1
}

grant_post() {
	pkg="$1"
	if ! declares_perm "$pkg" "$PERM_POST"; then log "  [perm] 未声明 POST_NOTIFICATIONS，跳过"; return 0; fi
	if is_granted "$pkg" "$PERM_POST"; then
		log "  [perm] POST_NOTIFICATIONS 已授予"
	elif cmd package grant "$pkg" "$PERM_POST" >/dev/null 2>&1; then
		log "  [perm] POST_NOTIFICATIONS 已授予"
	else warn "  [perm] POST_NOTIFICATIONS 授予失败"; fi
	cmd appops set "$pkg" POST_NOTIFICATION allow >/dev/null 2>&1 && log "  [appop] POST_NOTIFICATION=allow"
}

revoke_post() {
	pkg="$1"
	if cmd package revoke "$pkg" "$PERM_POST" >/dev/null 2>&1; then
		log "  [perm] POST_NOTIFICATIONS 已撤销"
	else
		cmd appops set "$pkg" POST_NOTIFICATION ignore >/dev/null 2>&1 && log "  [appop] POST_NOTIFICATION=ignore"
	fi
}

grant_policy() {
	declares_perm "$1" "$PERM_POLICY" && cmd appops set "$1" ACCESS_NOTIFICATION_POLICY allow >/dev/null 2>&1 && log "  [appop] ACCESS_NOTIFICATION_POLICY=allow"
}

doze_on()  { dumpsys deviceidle whitelist "+$1" >/dev/null 2>&1 && log "  [doze] 已加入白名单"; }
doze_off() { dumpsys deviceidle whitelist "-$1" >/dev/null 2>&1 && log "  [doze] 已移出白名单"; }
allow_bg() {
	cmd appops set "$1" RUN_IN_BACKGROUND allow >/dev/null 2>&1
	cmd appops set "$1" RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
	log "  [appop] 后台运行已放行"
}

cmd_set() {
	[ $# -ge 1 ] || die "用法: notif.sh set <包名> [...]"
	for pkg in "$@"; do
		echo "=============================================="
		log "处理: $pkg"
		is_installed "$pkg" || { warn "包未安装，跳过"; continue; }
		enable_listener "$pkg" || true
		grant_post "$pkg"
		grant_policy "$pkg"
		doze_on "$pkg"
		allow_bg "$pkg"
	done
	echo "=============================================="
	log "完成"
}

cmd_list() {
	case "${1:-}" in
		-v|--verbose) list_components ;;
		--raw) raw_listeners ;;
		--check) [ -n "${2:-}" ] || die "--check 需要包名"; has_listener "$2" && echo yes || echo no ;;
		*) list_components | sed 's#/.*##' | sort -u ;;
	esac
}

cmd_del() {
	mode="listener"
	while [ $# -gt 0 ]; do
		case "$1" in
			--all) mode="all" ;;
			--purge) mode="purge" ;;
			--post) mode="post" ;;
			--doze) mode="doze" ;;
			--listener) mode="listener" ;;
			-*) die "未知选项: $1" ;;
			*) break ;;
		esac
		shift
	done
	[ $# -ge 1 ] || die "用法: notif.sh del [--all|--purge|--post|--doze] <包名> [...]"
	for pkg in "$@"; do
		echo "========== $pkg =========="
		case "$mode" in
			listener) disable_listener "$pkg" || true ;;
			post) revoke_post "$pkg" ;;
			doze) doze_off "$pkg" ;;
			all) disable_listener "$pkg" || true; revoke_post "$pkg" ;;
			purge) disable_listener "$pkg" || true; revoke_post "$pkg"; doze_off "$pkg" ;;
		esac
	done
	log "完成"
}

cmd_check() {
	[ $# -ge 1 ] || die "用法: notif.sh check <包名>"
	for pkg in "$@"; do
		echo "========== $pkg =========="
		if is_installed "$pkg"; then echo "安装: 是 (uid=$(get_uid "$pkg"))"; else echo "安装: 否"; fi
		if has_listener "$pkg"; then
			echo "通知使用权: 已开启"
			list_components | grep "^$pkg/" | sed 's/^/           /'
		else echo "通知使用权: 未开启"; fi
		comps="$(probe_components "$pkg")"
		if [ -n "$comps" ]; then echo "可用组件:"; echo "$comps" | sed 's/^/           /'; else echo "可用组件: (无)"; fi
		if declares_perm "$pkg" "$PERM_POST"; then
			is_granted "$pkg" "$PERM_POST" && echo "POST_NOTIFICATIONS: 已声明 / 已授予" || echo "POST_NOTIFICATIONS: 已声明 / 未授予"
		else echo "POST_NOTIFICATIONS: 未声明"; fi
		echo "appop:"; cmd appops get "$pkg" POST_NOTIFICATION 2>/dev/null | sed 's/^/           /'
		dumpsys deviceidle whitelist 2>/dev/null | grep -q ",${pkg}," && echo "电池优化白名单: 是" || echo "电池优化白名单: 否"
		echo
	done
}

cmd_clean() {
	dry=0
	[ "${1:-}" = "--dry-run" ] && dry=1
	raw="$(raw_listeners)"
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
	[ "$removed" -gt 0 ] && settings put secure "$KEY" "$kept" >/dev/null 2>&1
	log "清理完成，移除 $removed 条"
}

cmd_rebind() {
	[ $# -ge 1 ] || die "用法: notif.sh rebind <包名> [...]"
	for pkg in "$@"; do
		echo "========== $pkg =========="
		existing="$(list_components | grep "^$pkg/" | head -1)"
		if [ -n "$existing" ]; then
			drop_entries "$pkg"; cmd notification disallow_listener "$pkg" >/dev/null 2>&1; sleep 1
			cmd notification allow_listener "$existing" >/dev/null 2>&1 && wait_contains "$existing" && log "已重绑 $existing"
		else
			enable_listener "$pkg"
		fi
		am force-stop "$pkg"; sleep 1
		monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 3
		cmd notification post -S bigtext -t rebind-test rebind_$(date +%s) ok >/dev/null 2>&1
		has_listener "$pkg" && log "系统侧: 已授权" || warn "系统侧: 未授权"
	done
}

cmd_summary() {
	n=0
	for p in $(cmd_list); do n=$((n + 1)); done
	echo "已开启通知使用权的应用: $n 个"
	cmd_list | sed 's/^/  /'
}

usage() {
	cat <<'EOF'
notif.sh —— 通知权限工具

用法:
  notif.sh set    <包名> [...]            开启通知权限 + 通知使用权 + 后台放行
  notif.sh list   [-v|--raw|--check <包>] 列出已开启的包（默认一行一个）
  notif.sh del    [--all|--purge|--post|--doze|--listener] <包名> [...]
  notif.sh check  <包名> [...]            查看详情
  notif.sh clean  [--dry-run]             清理失效条目
  notif.sh rebind <包名> [...]            强制刷新绑定
  notif.sh summary                        汇总
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
	clean) cmd_clean "$@" ;;
	rebind) cmd_rebind "$@" ;;
	summary) cmd_summary ;;
	help|-h|--help) usage ;;
	*) echo "未知命令: $action" >&2; usage >&2; exit 2 ;;
esac