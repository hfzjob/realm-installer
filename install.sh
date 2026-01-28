#!/bin/bash

# =========================================================
# Realm 一键安装与管理脚本
# 功能：安装 Realm、添加转发规则、管理服务
# 适配：Debian / Ubuntu
# =========================================================

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 检查是否为 root 用户
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 必须使用 root 用户运行此脚本！${PLAIN}" && exit 1

# 配置文件路径
CONFIG_FILE="/etc/realm/config.toml"
SERVICE_FILE="/etc/systemd/system/realm.service"
BIN_PATH="/usr/local/bin/realm"

# 1. 安装 Realm
install_realm() {
    echo -e "${GREEN}正在开始安装 Realm...${PLAIN}"
    
    # 更新系统并安装必要工具
    apt-get update -y
    apt-get install -y wget tar ufw

    # 检测架构
    ARCH=$(uname -m)
    if [[ $ARCH == "x86_64" ]]; then
        DOWNLOAD_URL="https://github.com/zhboner/realm/releases/latest/download/realm-x86_64-unknown-linux-gnu.tar.gz"
    elif [[ $ARCH == "aarch64" ]]; then
        DOWNLOAD_URL="https://github.com/zhboner/realm/releases/latest/download/realm-aarch64-unknown-linux-gnu.tar.gz"
    else
        echo -e "${RED}不支持的架构: $ARCH${PLAIN}"
        exit 1
    fi

    # 下载并安装
    wget -O realm.tar.gz "$DOWNLOAD_URL"
    tar -xvf realm.tar.gz
    chmod +x realm
    mv realm "$BIN_PATH"
    rm realm.tar.gz

    # 创建配置目录
    mkdir -p /etc/realm

    # 初始化基础配置文件
    cat > "$CONFIG_FILE" <<EOF
[network]
no_tcp = false
use_udp = true
EOF

    # 创建 Systemd 服务
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=realm
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
DynamicUser=true
ExecStart=$BIN_PATH -c $CONFIG_FILE

[Install]
WantedBy=multi-user.target
EOF

    # 启动服务
    systemctl daemon-reload
    systemctl enable --now realm

    echo -e "${GREEN}Realm 安装成功！${PLAIN}"
    echo -e "${YELLOW}请使用脚本菜单选择 [2] 来添加转发规则。${PLAIN}"
}

# 2. 添加转发规则
add_rule() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}请先安装 Realm！${PLAIN}"
        return
    fi

    echo -e "${GREEN}=== 添加新的转发规则 ===${PLAIN}"
    
    read -p "请输入中转机(本机)监听端口 (例如 6666): " listen_port
    read -p "请输入落地机 IP 地址: " remote_ip
    read -p "请输入落地机端口: " remote_port

    # 写入配置
    cat >> "$CONFIG_FILE" <<EOF

[[endpoints]]
listen = "0.0.0.0:$listen_port"
remote = "$remote_ip:$remote_port"
EOF

    # 开放防火墙
    ufw allow "$listen_port"/tcp
    ufw allow "$listen_port"/udp
    echo -e "${GREEN}防火墙已放行端口: $listen_port${PLAIN}"

    # 重启服务
    systemctl restart realm
    echo -e "${GREEN}规则添加成功！服务已重启。${PLAIN}"
}

# 3. 查看状态
check_status() {
    systemctl status realm
    echo -e "${YELLOW}当前配置文件内容 ($CONFIG_FILE):${PLAIN}"
    cat "$CONFIG_FILE"
}

# 4. 卸载
uninstall_realm() {
    systemctl stop realm
    systemctl disable realm
    rm -f "$SERVICE_FILE"
    rm -f "$BIN_PATH"
    rm -rf /etc/realm
    systemctl daemon-reload
    echo -e "${GREEN}Realm 已卸载。${PLAIN}"
}

# 主菜单
show_menu() {
    clear
    echo -e "${GREEN}Realm 一键管理脚本 (适用于 BWG/Linux)${PLAIN}"
    echo "-----------------------------------"
    echo "1. 安装 Realm"
    echo "2. 添加转发规则"
    echo "3. 查看运行状态 & 配置文件"
    echo "4. 卸载 Realm"
    echo "0. 退出"
    echo "-----------------------------------"
    read -p "请输入数字 [0-4]: " num

    case "$num" in
        1) install_realm ;;
        2) add_rule ;;
        3) check_status ;;
        4) uninstall_realm ;;
        0) exit 0 ;;
        *) echo -e "${RED}请输入正确的数字！${PLAIN}" ;;
    esac
}

show_menu
