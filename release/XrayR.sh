#!/usr/bin/env bash
#
# XrayR 管理命令, 由 install.sh 安装到 /usr/bin/XrayR
# 仓库: https://github.com/Drsakura/XrayR

set -uo pipefail

REPO="Drsakura/XrayR"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/master/release"
INSTALL_DIR="/usr/local/XrayR"
CONFIG_DIR="/etc/XrayR"
SERVICE_FILE="/etc/systemd/system/XrayR.service"
MANAGER="/usr/bin/XrayR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; PLAIN='\033[0m'
info() { echo -e "${GREEN}[信息]${PLAIN} $*"; }
warn() { echo -e "${YELLOW}[警告]${PLAIN} $*"; }
die()  { echo -e "${RED}[错误]${PLAIN} $*" >&2; exit 1; }

need_root() {
    [[ $(id -u) -eq 0 ]] || die "该操作需要 root 权限"
}

usage() {
    cat <<EOF

XrayR 管理命令

  XrayR start              启动
  XrayR stop               停止
  XrayR restart            重启
  XrayR status             查看运行状态
  XrayR enable             设置开机自启
  XrayR disable            取消开机自启

  XrayR log                实时查看日志 (Ctrl+C 退出)
  XrayR log 200            查看最近 200 行日志

  XrayR config             编辑配置文件
  XrayR version            查看版本

  XrayR update             升级到最新版本
  XrayR update v0.9.7      升级/回退到指定版本
  XrayR uninstall          卸载

配置目录: ${CONFIG_DIR}
程序目录: ${INSTALL_DIR}

EOF
}

cmd_status() {
    if [[ ! -f "${SERVICE_FILE}" ]]; then
        warn "XrayR 未安装"
        return 1
    fi
    systemctl status XrayR --no-pager -l
}

cmd_log() {
    local lines="${1:-}"
    if [[ -n "${lines}" ]]; then
        journalctl -u XrayR -n "${lines}" --no-pager
    else
        echo "实时日志, 按 Ctrl+C 退出"
        journalctl -u XrayR -f
    fi
}

cmd_config() {
    need_root
    [[ -f "${CONFIG_DIR}/config.yml" ]] || die "配置文件不存在: ${CONFIG_DIR}/config.yml"
    local editor="${EDITOR:-}"
    if [[ -z "${editor}" ]]; then
        for e in nano vim vi; do
            command -v "$e" >/dev/null 2>&1 && { editor="$e"; break; }
        done
    fi
    [[ -n "${editor}" ]] || die "未找到可用的文本编辑器, 请手动编辑 ${CONFIG_DIR}/config.yml"

    "${editor}" "${CONFIG_DIR}/config.yml"

    # XrayR 自身会监听配置变更并热重载, 这里只在服务未运行时提示
    if systemctl is-active --quiet XrayR; then
        info "配置已保存, XrayR 会自动热重载"
        echo "     若未生效可执行: XrayR restart"
    else
        info "配置已保存, 服务当前未运行"
        echo "     启动: XrayR start"
    fi
}

cmd_version() {
    if [[ -x "${INSTALL_DIR}/XrayR" ]]; then
        "${INSTALL_DIR}/XrayR" version
    else
        die "未找到 ${INSTALL_DIR}/XrayR"
    fi
}

cmd_update() {
    need_root
    local version="${1:-}"
    info "从 GitHub 拉取安装脚本"
    local tmp
    tmp=$(mktemp) || die "无法创建临时文件"
    if ! curl -fsSL --retry 3 -o "${tmp}" "${RAW_BASE}/install.sh"; then
        rm -f "${tmp}"
        die "安装脚本下载失败, 请检查网络"
    fi
    bash "${tmp}" ${version}
    rm -f "${tmp}"
}

cmd_uninstall() {
    need_root
    echo
    warn "即将卸载 XrayR, 以下内容会被删除:"
    echo "    ${INSTALL_DIR}        (程序)"
    echo "    ${SERVICE_FILE}       (服务)"
    echo "    ${MANAGER}            (管理命令)"
    echo
    echo "    ${CONFIG_DIR}         (配置, 将询问是否保留)"
    echo
    read -r -p "确认卸载? [y/N] " confirm
    [[ "${confirm}" =~ ^[Yy]$ ]] || { info "已取消"; return 0; }

    systemctl disable --now XrayR >/dev/null 2>&1 || true
    rm -f "${SERVICE_FILE}"
    systemctl daemon-reload
    rm -rf "${INSTALL_DIR}"

    read -r -p "是否同时删除配置目录 ${CONFIG_DIR}? [y/N] " rmcfg
    if [[ "${rmcfg}" =~ ^[Yy]$ ]]; then
        rm -rf "${CONFIG_DIR}"
        info "配置目录已删除"
    else
        info "配置目录已保留: ${CONFIG_DIR}"
    fi

    rm -f "${MANAGER}"
    info "XrayR 已卸载"
}

case "${1:-}" in
    start)     need_root; systemctl start XrayR   && info "已启动"  || die "启动失败, 查看日志: XrayR log" ;;
    stop)      need_root; systemctl stop XrayR    && info "已停止" ;;
    restart)   need_root; systemctl restart XrayR && info "已重启"  || die "重启失败, 查看日志: XrayR log" ;;
    status)    cmd_status ;;
    enable)    need_root; systemctl enable XrayR  >/dev/null 2>&1 && info "已设置开机自启" ;;
    disable)   need_root; systemctl disable XrayR >/dev/null 2>&1 && info "已取消开机自启" ;;
    log)       cmd_log "${2:-}" ;;
    config)    cmd_config ;;
    version|-v|--version) cmd_version ;;
    update)    cmd_update "${2:-}" ;;
    uninstall) cmd_uninstall ;;
    ""|help|-h|--help) usage ;;
    *)         echo -e "${RED}未知命令: $1${PLAIN}"; usage; exit 1 ;;
esac
