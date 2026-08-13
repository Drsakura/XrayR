#!/usr/bin/env bash
#
# XrayR 一键安装 / 升级脚本
# 仓库: https://github.com/Drsakura/XrayR
#
# 用法:
#   bash install.sh              安装或升级到最新版本
#   bash install.sh v0.9.7       安装指定版本
#
# 本脚本只做四件事: 装依赖、下载并校验二进制、写 systemd 服务、装 XrayR 管理命令。
# 不会修改防火墙、不会改动 sysctl、不会停用系统日志服务。

set -euo pipefail

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

TMPDIR=""
cleanup() { [[ -n "${TMPDIR}" && -d "${TMPDIR}" ]] && rm -rf "${TMPDIR}"; }
trap cleanup EXIT

# ---------------------------------------------------------------- 环境检查

check_environment() {
    [[ $(id -u) -eq 0 ]] || die "请以 root 运行: sudo bash install.sh"
    command -v systemctl >/dev/null 2>&1 || die "未检测到 systemd, 本脚本不支持当前系统"
}

detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then echo apt
    elif command -v dnf >/dev/null 2>&1; then echo dnf
    elif command -v yum >/dev/null 2>&1; then echo yum
    elif command -v apk >/dev/null 2>&1; then echo apk
    else echo ""
    fi
}

install_deps() {
    local missing=()
    for c in curl unzip; do
        command -v "$c" >/dev/null 2>&1 || missing+=("$c")
    done
    [[ ${#missing[@]} -eq 0 ]] && return 0

    info "安装缺少的依赖: ${missing[*]}"
    case "$(detect_pkg_manager)" in
        apt) apt-get update -qq && apt-get install -y -qq curl unzip ca-certificates ;;
        dnf) dnf install -y -q curl unzip ca-certificates ;;
        yum) yum install -y -q curl unzip ca-certificates ;;
        apk) apk add --no-cache curl unzip ca-certificates ;;
        *)   die "无法识别包管理器, 请先手动安装: ${missing[*]}" ;;
    esac
}

# 把 uname -m 映射为 Release 里的产物名, 对应 .github/build/friendly-filenames.json
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   echo "64" ;;
        aarch64|arm64)  echo "arm64-v8a" ;;
        armv7l|armv7)   echo "arm32-v7a" ;;
        armv6l|armv6)   echo "arm32-v6" ;;
        armv5*)         echo "arm32-v5" ;;
        i386|i686)      echo "32" ;;
        s390x)          echo "s390x" ;;
        riscv64)        echo "riscv64" ;;
        ppc64le)        echo "ppc64le" ;;
        ppc64)          echo "ppc64" ;;
        mips64el|mips64le) echo "mips64le" ;;
        mips64)         echo "mips64" ;;
        mipsel|mipsle)  echo "mips32le" ;;
        mips)           echo "mips32" ;;
        *)              echo "" ;;
    esac
}

# ---------------------------------------------------------------- 版本与下载

resolve_version() {
    local want="${1:-}"
    if [[ -n "${want}" ]]; then
        echo "${want}"
        return 0
    fi
    local v
    v=$(curl -fsSL --retry 3 "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n1) || true
    [[ -n "${v}" ]] || die "无法获取最新版本号。可能是 GitHub API 限流或该仓库尚未发布 Release。
       可手动指定版本重试, 例如: bash install.sh v0.9.7
       版本列表: https://github.com/${REPO}/releases"
    echo "${v}"
}

# Release 附带 .dgst 校验文件, 由 openssl dgst 生成。
# OpenSSL 1.x 输出 "SHA256= <hash>", 3.x 输出 "SHA2-256= <hash>", 两种都认。
verify_checksum() {
    local zip="$1" dgst="$2"
    if [[ ! -s "${dgst}" ]]; then
        warn "未能获取校验文件, 跳过完整性校验"
        return 0
    fi
    local expected actual
    expected=$(grep -iE '^SHA2?-?256=' "${dgst}" | head -n1 | awk '{print $NF}')
    if [[ -z "${expected}" ]]; then
        warn "校验文件中没有 SHA256 条目, 跳过完整性校验"
        return 0
    fi
    actual=$(sha256sum "${zip}" | awk '{print $1}')
    if [[ "${expected}" != "${actual}" ]]; then
        die "下载文件校验失败, 已中止安装。
       期望: ${expected}
       实际: ${actual}"
    fi
    info "SHA256 校验通过"
}

download_release() {
    local version="$1" arch="$2"
    local file="XrayR-linux-${arch}.zip"
    local base="https://github.com/${REPO}/releases/download/${version}"

    TMPDIR=$(mktemp -d)
    info "下载 ${file} (${version})"
    curl -fsSL --retry 3 -o "${TMPDIR}/${file}" "${base}/${file}" \
        || die "下载失败: ${base}/${file}
       请确认该版本存在, 且发布了 linux-${arch} 架构的产物。"

    curl -fsSL --retry 2 -o "${TMPDIR}/${file}.dgst" "${base}/${file}.dgst" 2>/dev/null || true
    verify_checksum "${TMPDIR}/${file}" "${TMPDIR}/${file}.dgst"

    mkdir -p "${TMPDIR}/extract"
    unzip -q -o "${TMPDIR}/${file}" -d "${TMPDIR}/extract"
    [[ -f "${TMPDIR}/extract/XrayR" ]] || die "压缩包内未找到 XrayR 主程序"
}

# ---------------------------------------------------------------- 安装步骤

install_binary() {
    mkdir -p "${INSTALL_DIR}"
    install -m 755 "${TMPDIR}/extract/XrayR" "${INSTALL_DIR}/XrayR"
    info "主程序已安装到 ${INSTALL_DIR}/XrayR"
}

# 配置只在首次安装时写入, 升级时一律保留现有配置。
install_config() {
    mkdir -p "${CONFIG_DIR}"

    # geo 数据每次都刷新, 它们是数据文件不是用户配置
    for f in geoip.dat geosite.dat; do
        [[ -f "${TMPDIR}/extract/${f}" ]] && install -m 644 "${TMPDIR}/extract/${f}" "${CONFIG_DIR}/${f}"
    done

    for f in dns.json route.json custom_inbound.json custom_outbound.json rulelist; do
        if [[ -f "${TMPDIR}/extract/${f}" && ! -f "${CONFIG_DIR}/${f}" ]]; then
            install -m 644 "${TMPDIR}/extract/${f}" "${CONFIG_DIR}/${f}"
        fi
    done

    if [[ -f "${CONFIG_DIR}/config.yml" ]]; then
        FRESH_INSTALL=0
        info "检测到已有配置, 保留 ${CONFIG_DIR}/config.yml 不变"
    else
        FRESH_INSTALL=1
        install -m 644 "${TMPDIR}/extract/config.yml" "${CONFIG_DIR}/config.yml"
        info "已写入配置模板 ${CONFIG_DIR}/config.yml"
    fi
}

install_service() {
    cat > "${SERVICE_FILE}" <<'EOF'
[Unit]
Description=XrayR Service
Documentation=https://github.com/Drsakura/XrayR
After=network.target nss-lookup.target
Wants=network.target

[Service]
Type=simple
User=root
NoNewPrivileges=true
WorkingDirectory=/etc/XrayR
ExecStart=/usr/local/XrayR/XrayR --config /etc/XrayR/config.yml
Restart=on-failure
RestartPreventExitStatus=23
RestartSec=5
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "${SERVICE_FILE}"
    systemctl daemon-reload
    info "systemd 服务已配置"
}

install_manager() {
    if curl -fsSL --retry 2 -o "${MANAGER}.tmp" "${RAW_BASE}/XrayR.sh" 2>/dev/null; then
        mv "${MANAGER}.tmp" "${MANAGER}"
        chmod 755 "${MANAGER}"
        info "管理命令已安装, 输入 XrayR 查看用法"
    else
        rm -f "${MANAGER}.tmp"
        warn "管理脚本下载失败, 可继续用 systemctl 管理服务"
    fi
}

# ---------------------------------------------------------------- 主流程

main() {
    local version arch
    echo
    info "XrayR 安装脚本 — 来源 https://github.com/${REPO}"
    echo

    check_environment
    arch=$(detect_arch)
    [[ -n "${arch}" ]] || die "不支持的系统架构: $(uname -m)"
    info "系统架构: $(uname -m) → linux-${arch}"

    install_deps
    version=$(resolve_version "${1:-}")
    info "目标版本: ${version}"

    local was_active=0
    systemctl is-active --quiet XrayR 2>/dev/null && was_active=1
    if [[ ${was_active} -eq 1 ]]; then
        info "停止正在运行的 XrayR"
        systemctl stop XrayR
    fi

    download_release "${version}" "${arch}"
    install_binary
    install_config
    install_service
    install_manager

    echo
    if [[ ${FRESH_INSTALL} -eq 1 ]]; then
        systemctl enable XrayR >/dev/null 2>&1 || true
        warn "首次安装, 服务尚未启动。"
        echo
        echo "  请先编辑配置填入面板信息:"
        echo "      XrayR config          (或 nano ${CONFIG_DIR}/config.yml)"
        echo
        echo "  至少需要填写 Nodes 下的 PanelType / ApiHost / ApiKey / NodeID / NodeType"
        echo
        echo "  配置完成后启动:"
        echo "      XrayR start"
        echo
    else
        systemctl start XrayR
        sleep 2
        if systemctl is-active --quiet XrayR; then
            info "XrayR 已升级到 ${version} 并重新启动"
        else
            warn "XrayR 启动失败, 请检查日志: XrayR log"
        fi
    fi

    "${INSTALL_DIR}/XrayR" version 2>/dev/null || true
    echo
}

main "${1:-}"
