# XrayR

![](https://img.shields.io/github/stars/Drsakura/XrayR)
![](https://img.shields.io/github/forks/Drsakura/XrayR)
![](https://github.com/Drsakura/XrayR/actions/workflows/release.yml/badge.svg)
[![Github All Releases](https://img.shields.io/github/downloads/Drsakura/XrayR/total.svg)]()

一个基于 Xray 的后端框架，支持 V2ray、Trojan、Shadowsocks 协议，支持多面板对接。

---

## 关于本仓库

**本仓库是 [XrayR-project/XrayR](https://github.com/XrayR-project/XrayR) 的 fork。**

上游原始仓库已被作者清空：

| 时间 | 事件 |
|---|---|
| 2025-12-09 | 上游最后一次正常代码更新 |
| 2026-05-11 | 开始逐个删除源码目录与文件 |
| 2026-07-03 | 提交 `Clear all files`，仓库彻底清空 |

配套的一键安装脚本仓库 [XrayR-project/XrayR-release](https://github.com/XrayR-project/XrayR-release) 同样已被清空，
原先流传的 `install.sh` 一键安装命令现已失效（返回 404）。上游最后一个 Release 停留在 **v0.9.4（2024-07-21）**。

本仓库保留了上游清空前的完整源码，并在此基础上继续维护。

* 上游原始项目：https://github.com/XrayR-project/XrayR
* 开源协议：[Mozilla Public License 2.0](LICENSE)，与上游保持一致
* 本仓库地址：https://github.com/Drsakura/XrayR

## 当前状态

| 项目 | 版本 |
|---|---|
| XrayR | 0.9.6 |
| Xray-core | **v1.260327.0**（Xray-core v26.3.27） |
| Go | 1.26 或更高 |

### 从旧版本升级前请注意

内核升级到 v1.260327.0 后，有两处**来自 Xray-core 上游的行为变更**，与本仓库无关但会影响线上节点：

1. **mKCP 伪装头被移除。** Xray-core 已删除 `srtp`、`utp`、`wechat`、`dtls`（tls）、`wireguard`
   五种伪装类型，现仅保留 `http` 与 `noop`。
   **如果面板中有节点的 mKCP 伪装配置为上述五种之一，升级后该节点将无法正常工作**，
   升级前请先在面板中排查并改为 `none`（noop）或 `http`。

2. **`DisableIVCheck` 配置项已失效。** Xray-core 从服务端配置结构体中移除了 IV check 开关。
   该配置项仍可保留在 `config.yml` 中（不会导致启动报错），但不再产生任何作用。
   实际影响为零——XrayR 动态下发的用户账号本来就从未启用过该检查。

## 免责声明

本项目仅供学习与研究使用，不保证任何可用性，也不对使用本软件造成的任何后果负责。

## 特点

* 永久开源且免费。
* 支持 V2ray、Trojan、Shadowsocks 多种协议。
* 支持 Vless 和 XTLS 等新特性。
* 支持单实例对接多面板、多节点，无需重复启动。
* 支持限制在线 IP。
* 支持节点端口级别、用户级别限速。
* 配置简单明了，修改配置自动重启实例。
* 方便编译和升级，可快速更新内核版本。

## 功能介绍

| 功能        | v2ray | trojan | shadowsocks |
|-----------|-------|--------|-------------|
| 获取节点信息    | √     | √      | √           |
| 获取用户信息    | √     | √      | √           |
| 用户流量统计    | √     | √      | √           |
| 服务器信息上报   | √     | √      | √           |
| 自动申请tls证书 | √     | √      | √           |
| 自动续签tls证书 | √     | √      | √           |
| 在线人数统计    | √     | √      | √           |
| 在线用户限制    | √     | √      | √           |
| 审计规则      | √     | √      | √           |
| 节点端口限速    | √     | √      | √           |
| 按照用户限速    | √     | √      | √           |
| 自定义DNS    | √     | √      | √           |

## 支持前端

| 前端                                                          | v2ray | trojan | shadowsocks             |
|-------------------------------------------------------------|-------|--------|-------------------------|
| sspanel-uim                                                 | √     | √      | √ (单端口多用户和V2ray-Plugin) |
| v2board                                                     | √     | √      | √                       |
| [PMPanel](https://github.com/ByteInternetHK/PMPanel)        | √     | √      | √                       |
| [ProxyPanel](https://github.com/ProxyPanel/ProxyPanel)      | √     | √      | √                       |
| [WHMCS (V2RaySocks)](https://v2raysocks.doxtex.com/)        | √     | √      | √                       |
| [GoV2Panel](https://github.com/pingProMax/gov2panel)        | √     | √      | √                       |
| [BunPanel](https://github.com/pennyMorant/bunpanel-release) | √     | √      | √                       |

---

# 部署

## 一键安装（推荐）

在节点机上以 root 执行：

```bash
wget -N https://raw.githubusercontent.com/Drsakura/XrayR/master/release/install.sh && bash install.sh
```

指定版本安装或回退：

```bash
wget -N https://raw.githubusercontent.com/Drsakura/XrayR/master/release/install.sh && bash install.sh v0.9.7
```

脚本会自动识别系统架构、安装依赖、下载并**校验 SHA256**、配置 systemd 服务，
并安装 `XrayR` 管理命令。首次安装完成后编辑配置再启动即可：

```bash
XrayR config    # 填入面板地址、密钥、节点 ID
XrayR start
```

脚本只做安装相关的事——不改防火墙、不改 sysctl、不停用系统日志服务。
升级时会保留 `/etc/XrayR/config.yml` 等现有配置，仅替换程序与 geo 数据文件。

### 管理命令

```
XrayR start / stop / restart / status     启停与状态
XrayR enable / disable                    开机自启
XrayR log                                 实时日志（XrayR log 200 看最近 200 行）
XrayR config                              编辑配置
XrayR version                             查看版本
XrayR update                              升级到最新版（XrayR update v0.9.7 指定版本）
XrayR uninstall                           卸载
```

---

## 手动安装

不想用脚本时，下列步骤等价，全部命令可直接复制执行。

## 1. 下载并解压

从 [Releases](https://github.com/Drsakura/XrayR/releases) 选择对应架构的压缩包。常见架构对应关系：

| 服务器架构 | 文件名 |
|---|---|
| x86_64 / amd64 | `XrayR-linux-64.zip` |
| aarch64 / arm64 | `XrayR-linux-arm64-v8a.zip` |
| armv7 | `XrayR-linux-arm32-v7a.zip` |
| i386 | `XrayR-linux-32.zip` |

不确定架构时用 `uname -m` 查看。以 amd64 为例：

```bash
mkdir -p /usr/local/XrayR && cd /usr/local/XrayR
VER=$(curl -Ls "https://api.github.com/repos/Drsakura/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
wget -O XrayR.zip "https://github.com/Drsakura/XrayR/releases/download/${VER}/XrayR-linux-64.zip"
unzip -o XrayR.zip && rm XrayR.zip && chmod +x XrayR
```

压缩包内含：`XrayR` 主程序、`config.yml` 配置模板、`geoip.dat`、`geosite.dat`、
`dns.json`、`route.json`、`custom_inbound.json`、`custom_outbound.json`、`rulelist`。

## 2. 放置配置文件

配置统一放在 `/etc/XrayR/`：

```bash
mkdir -p /etc/XrayR
cd /usr/local/XrayR
cp config.yml dns.json route.json custom_inbound.json custom_outbound.json rulelist /etc/XrayR/
cp geoip.dat geosite.dat /etc/XrayR/
```

然后编辑 `/etc/XrayR/config.yml`，填入面板地址、密钥和节点 ID：

```bash
nano /etc/XrayR/config.yml
```

最少需要修改 `Nodes` 下的这几项：

```yaml
Nodes:
  - PanelType: "NewV2board"      # 面板类型：SSpanel / NewV2board / PMpanel / Proxypanel / V2RaySocks / GoV2Panel / BunPanel
    ApiConfig:
      ApiHost: "http://面板地址"   # 面板地址
      ApiKey: "你的通信密钥"        # 面板通信密钥
      NodeID: 1                   # 节点 ID
      NodeType: V2ray             # 节点类型：V2ray / Vmess / Vless / Shadowsocks / Trojan / Shadowsocks-Plugin
```

完整配置项说明见 `config.yml` 内的注释。

## 3. 配置 systemd 托管

```bash
cat > /etc/systemd/system/XrayR.service <<'EOF'
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

systemctl daemon-reload
systemctl enable --now XrayR
```

## 4. 常用运维命令

```bash
systemctl status XrayR      # 查看运行状态
systemctl restart XrayR     # 改完配置后重启
systemctl stop XrayR        # 停止
journalctl -u XrayR -f      # 实时查看日志
journalctl -u XrayR -n 200  # 查看最近 200 行日志
```

修改 `/etc/XrayR/config.yml` 后 XrayR 会自动重载，无需手动重启；若未生效再执行 `systemctl restart XrayR`。

## 5. 升级到新版本

配置文件在 `/etc/XrayR/`，升级只替换 `/usr/local/XrayR/` 下的程序，不会动配置：

```bash
systemctl stop XrayR
cd /usr/local/XrayR
VER=$(curl -Ls "https://api.github.com/repos/Drsakura/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
wget -O XrayR.zip "https://github.com/Drsakura/XrayR/releases/download/${VER}/XrayR-linux-64.zip"
unzip -o XrayR.zip && rm XrayR.zip && chmod +x XrayR
systemctl start XrayR && systemctl status XrayR
```

geoip / geosite 数据库如需一并更新，把解压出的 `geoip.dat`、`geosite.dat` 覆盖到 `/etc/XrayR/` 即可。

## 6. 卸载

```bash
systemctl disable --now XrayR
rm -f /etc/systemd/system/XrayR.service
systemctl daemon-reload
rm -rf /usr/local/XrayR /etc/XrayR
```

---

# 从源码编译

需要 Go 1.26 或更高版本（Xray-core v1.260327.0 的硬性要求）。

```bash
git clone https://github.com/Drsakura/XrayR.git
cd XrayR
go build -v -o XrayR -trimpath -ldflags "-s -w -buildid="
```

交叉编译到其他平台，例如给 arm64 服务器编译：

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -v -o XrayR -trimpath -ldflags "-s -w -buildid="
```

# 发布新版本（维护者）

Release 由 GitHub Actions 自动构建：在仓库创建并发布一个 Release（打 tag，如 `v0.9.7`），
`release.yml` 会自动交叉编译全平台二进制、打包并上传到该 Release。

# 配置参考

本仓库的配置格式与上游一致，上游文档站目前仍可访问，可作为配置项参考：
[XrayR 文档](https://xrayr-project.github.io/XrayR-doc/)

> 该文档站属于已停止维护的上游项目，可能随时下线，且不包含本仓库的内核升级说明。

Xray-core 自身的配置（`dns.json`、`route.json`、`custom_inbound.json`、`custom_outbound.json`）
参考 [Xray 官方文档](https://xtls.github.io/config/)。

# Thanks

* [Project X](https://github.com/XTLS/)
* [V2Fly](https://github.com/v2fly)
* [VNet-V2ray](https://github.com/ProxyPanel/VNet-V2ray)
* [Air-Universe](https://github.com/crossfw/Air-Universe)
* [XrayR-project](https://github.com/XrayR-project/XrayR) —— 本项目的上游源仓库

# License

[Mozilla Public License Version 2.0](LICENSE)
