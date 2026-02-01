#!/bin/bash

# =================================================================
#  飞牛 (FnOS) 系统安全体检与修复脚本 V6.0
#  修复：优化语法结构，解决 unexpected EOF 报错问题
# =================================================================

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查权限
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请使用 root 权限运行此脚本${NC}"
  exit 1
fi

echo -e "====================================================="
echo -e "   🚀 系统深度安全扫描 (V6.0 修正版)"
echo -e "====================================================="

# --- 通用检查函数 ---
check_service() {
    local target=$1
    local desc=$2
    local path="/etc/systemd/system/${target}.service"
    
    # 只检查是否存在于 /etc/ 下的伪造服务
    if [ -f "$path" ]; then
        echo -e "${RED}[发现异常]${NC} 发现恶意服务: $target ($desc)"
        systemctl stop "$target" 2>/dev/null
        systemctl disable "$target" 2>/dev/null
        chattr -i "$path" 2>/dev/null
        rm -f "$path"
        echo -e "   -> 已清除"
    else
        echo -e "${GREEN}[正常]${NC} 服务检查: $target 未发现"
    fi
}

check_file() {
    local target=$1
    local desc=$2
    
    if [ -f "$target" ]; then
        echo -e "${RED}[发现异常]${NC} 发现恶意文件: $target ($desc)"
        chattr -i "$target" 2>/dev/null
        rm -f "$target"
        echo -e "   -> 已清除"
    else
        echo -e "${GREEN}[正常]${NC} 文件检查: $target 未发现"
    fi
}

# =================================================================
# [1/6] 恶意服务扫描
# =================================================================
echo -e "\n[1/6] 扫描恶意服务配置..."
check_service "IQ3eOUvBD" "随机名病毒服务"
check_service "dockers" "伪装Docker服务"
check_service "nginx" "伪装Nginx服务(假)"
check_service "smbd" "伪装Samba服务(假)"
check_service "trim_pap" "恶意启动项1"
check_service "trim_https_cgi" "恶意启动项2"
check_service "cron_for_fix" "恶意修复后门"

systemctl daemon-reload

# =================================================================
# [2/6] 恶意文件扫描
# =================================================================
echo -e "\n[2/6] 扫描已知病毒文件..."
check_file "/usr/bin/dockers" "病毒主程序"
check_file "/usr/bin/nginx" "病毒主程序(假Nginx)"
check_file "/usr/bin/nginx.virus" "被隔离的病毒"
check_file "/usr/bin/smbd" "病毒主程序(假Samba)"
check_file "/usr/bin/IQ3eOUvBD" "随机病毒"
check_file "/usr/sbin/gots" "其他病毒组件"

# =================================================================
# [3/6] 智能扫描随机大写文件 (语法优化版)
# =================================================================
echo -e "\n[3/6] 扫描 /usr/bin 下的随机大写文件..."

# 设置白名单 (合法的大写文件名)
WHITELIST="X11|Xorg|GET|HEAD|POST|X|oLschema2ldif"

# 查找所有包含大写字母的文件，并过滤掉白名单
# 使用 grep -E 避免复杂的嵌套引号
SUSPICIOUS=$(find /usr/bin -type f -name "*[A-Z]*" 2>/dev/null | grep -vE "$WHITELIST")

if [ -n "$SUSPICIOUS" ]; then
    echo -e "${RED}[发现异常]${NC} 发现可疑文件:"
    # 将结果转换为数组或逐行处理
    echo "$SUSPICIOUS" | while read -r file; do
        if [ -n "$file" ]; then
            echo -e "   -> 删除: $file"
            chattr -i "$file" 2>/dev/null
            rm -f "$file"
        fi
    done
else
    echo -e "${GREEN}[正常]${NC} 未发现随机生成的病毒文件"
fi

# =================================================================
# [4/6] 检查 Hosts 文件
# =================================================================
echo -e "\n[4/6] 检查系统更新通道 (Hosts)..."
# 分步检查，避免长命令报错
HOSTS_BAD=0
if grep -q "fnnas.com" /etc/hosts; then HOSTS_BAD=1; fi
if grep -q "teiron-inc.cn" /etc/hosts; then HOSTS_BAD=1; fi

if [ $HOSTS_BAD -eq 1 ]; then
    echo -e "${RED}[发现异常]${NC} Hosts 文件包含屏蔽规则"
    chattr -i /etc/hosts
    sed -i '/fnnas.com/d' /etc/hosts
    sed -i '/teiron-inc.cn/d' /etc/hosts
    echo -e "   -> ${GREEN}已修复，更新通道恢复${NC}"
else
    echo -e "${GREEN}[正常]${NC} Hosts 文件干净"
fi

# =================================================================
# [5/6] 核心命令完整性校验
# =================================================================
echo -e "\n[5/6] 校验核心系统命令 (dpkg -V)..."

if dpkg -V passwd util-linux 2>/dev/null | grep -q "5......"; then
    echo -e "${RED}[异常]${NC} 核心命令被篡改，正在修复..."
    apt-get install --reinstall passwd login util-linux -y
    echo -e "   -> ${GREEN}核心命令修复完成${NC}"
else
    echo -e "${GREEN}[正常]${NC} 核心命令 (ls, login, useradd) 校验通过"
fi

# =================================================================
# [6/6] Samba 服务完整性
# =================================================================
echo -e "\n[6/6] 校验 Samba 服务完整性..."

if dpkg -V samba 2>/dev/null | grep -q "/usr/sbin/smbd"; then
    echo -e "${RED}[严重异常]${NC} Samba 主程序校验失败"
    echo -e "   -> 正在强制重装 Samba..."
    killall -9 smbd 2>/dev/null
    export DEBIAN_FRONTEND=noninteractive
    apt-get install --reinstall samba samba-common-bin -y
    systemctl unmask smbd 2>/dev/null
    systemctl restart smbd
    echo -e "   -> ${GREEN}Samba 修复完成${NC}"
else
    echo -e "${GREEN}[正常]${NC} Samba (smbd) 官方校验通过"
fi

echo -e "\n====================================================="
echo -e "   ✅ 所有检查结束"
echo -e "====================================================="
echo -e "提示：请最后重启一次系统：${YELLOW}reboot${NC}"
