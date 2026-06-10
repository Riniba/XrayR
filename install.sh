#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/usr/local/XrayR"
CONFIG_DIR="/etc/XrayR"
SERVICE_FILE="/etc/systemd/system/XrayR.service"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}        XrayR Auto Installer            ${NC}"
echo -e "${GREEN}========================================${NC}"

if [ "$(id -u)" != "0" ]; then
echo -e "${RED}请使用 root 运行${NC}"
exit 1
fi

echo -e "${YELLOW}检测系统...${NC}"

if command -v apt >/dev/null 2>&1; then
PM="apt"
else
echo -e "${RED}暂时仅支持 Debian / Ubuntu${NC}"
exit 1
fi

apt update
apt install -y curl wget unzip tar jq ca-certificates

ARCH=$(uname -m)

case "$ARCH" in
x86_64|amd64)
FILE="XrayR-linux-64.zip"
;;
aarch64|arm64)
FILE="XrayR-linux-arm64-v8a.zip"
;;
*)
echo -e "${RED}不支持架构: $ARCH${NC}"
exit 1
;;
esac

echo -e "${YELLOW}获取最新版本...${NC}"

LATEST_VERSION=$(curl -s https://api.github.com/repos/XrayR-project/XrayR/releases/latest | jq -r .tag_name)

if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
echo -e "${RED}获取版本失败${NC}"
exit 1
fi

echo -e "${GREEN}最新版本: ${LATEST_VERSION}${NC}"

DOWNLOAD_URL="https://github.com/XrayR-project/XrayR/releases/download/${LATEST_VERSION}/${FILE}"

echo -e "${YELLOW}下载程序...${NC}"

rm -rf /tmp/xrayr-install
mkdir -p /tmp/xrayr-install

cd /tmp/xrayr-install

curl -fL -o XrayR.zip "$DOWNLOAD_URL"

unzip -o XrayR.zip

mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"

cp -f XrayR "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/XrayR"

cp -f geoip.dat "$INSTALL_DIR/" 2>/dev/null || true
cp -f geosite.dat "$INSTALL_DIR/" 2>/dev/null || true

if [ ! -f "$CONFIG_DIR/config.yml" ]; then
cp config.yml "$CONFIG_DIR/config.yml"
fi

echo -e "${YELLOW}创建 systemd 服务...${NC}"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=XrayR Service
After=network.target nss-lookup.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/XrayR --config ${CONFIG_DIR}/config.yml
Restart=on-failure
RestartSec=10
LimitNOFILE=999999

[Install]
WantedBy=multi-user.target
EOF

echo -e "${YELLOW}创建管理命令...${NC}"

cat > /usr/bin/XrayR <<'EOF'
#!/usr/bin/env bash

case "$1" in
start)
systemctl start XrayR
;;
stop)
systemctl stop XrayR
;;
restart)
systemctl restart XrayR
;;
status)
systemctl status XrayR
;;
enable)
systemctl enable XrayR
;;
disable)
systemctl disable XrayR
;;
log)
journalctl -u XrayR -f --no-pager
;;
config)
cat /etc/XrayR/config.yml
;;
version)
/usr/local/XrayR/XrayR version
;;
*)
echo ""
echo "XrayR 管理命令"
echo "------------------------------------"
echo "XrayR start"
echo "XrayR stop"
echo "XrayR restart"
echo "XrayR status"
echo "XrayR enable"
echo "XrayR disable"
echo "XrayR log"
echo "XrayR config"
echo "XrayR version"
echo "------------------------------------"
;;
esac
EOF

chmod +x /usr/bin/XrayR

rm -f /usr/bin/xrayr
ln -sf /usr/bin/XrayR /usr/bin/xrayr

systemctl daemon-reload
systemctl enable XrayR

echo ""
echo -e "${GREEN}安装完成${NC}"
echo ""
echo "配置文件:"
echo "  nano /etc/XrayR/config.yml"
echo ""
echo "启动:"
echo "  systemctl start XrayR"
echo ""
echo "查看状态:"
echo "  XrayR status"
echo ""
echo "查看日志:"
echo "  XrayR log"
echo ""
