#!/bin/bash
# install-ubuntu24-rdp.sh

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ROOTFS_DIR="ubuntu-24.04-rdp"
ARCH=$(uname -m)
UBUNTU_VERSION="24.04"
TIMEOUT=30

print_header() {
  clear
  echo -e "${CYAN}"
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║     🚀 Ubuntu ${UBUNTU_VERSION} + RDP Auto Installer      ║"
  echo "║                (Noble Numbat with RDP)                ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

detect_arch() {
  case "$ARCH" in
    x86_64) ARCH_ALT="amd64" ;;
    aarch64) ARCH_ALT="arm64" ;;
    armv7l) ARCH_ALT="armhf" ;;
    *)
      echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
      exit 1
      ;;
  esac
  echo -e "${YELLOW}📊 Architecture:${NC} $ARCH ($ARCH_ALT)"
}

download_ubuntu() {
  echo -e "\n${CYAN}📦 Downloading Ubuntu ${UBUNTU_VERSION}...${NC}"
  
  URLS=(
    "https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${ARCH_ALT}.tar.gz"
    "https://mirrors.ustc.edu.cn/ubuntu-cdimage/ubuntu-base/releases/${UBUNTU_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${ARCH_ALT}.tar.gz"
    "https://mirror.kakao.com/ubuntu-cdimage/ubuntu-base/releases/${UBUNTU_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${ARCH_ALT}.tar.gz"
  )
  
  for url in "${URLS[@]}"; do
    echo -e "${YELLOW}Trying:${NC} $(echo $url | cut -d'/' -f3)"
    if wget --tries=2 --timeout=$TIMEOUT -q --show-progress -O /tmp/ubuntu-rootfs.tar.gz "$url"; then
      echo -e "${GREEN}✅ Download successful${NC}"
      return 0
    fi
  done
  
  # Fallback to 22.04
  echo -e "${YELLOW}⚠️  Trying Ubuntu 22.04 as fallback...${NC}"
  wget --tries=2 --timeout=$TIMEOUT -q --show-progress -O /tmp/ubuntu-rootfs.tar.gz \
    "https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-base-${ARCH_ALT}.tar.gz"
}

install_proot() {
  echo -e "\n${CYAN}🔧 Installing PRoot...${NC}"
  
  PROOT_SOURCES=(
    "https://github.com/proot-me/proot-static-build/raw/master/static/proot-$ARCH"
    "https://raw.githubusercontent.com/proot-me/proot-static-build/master/static/proot-$ARCH"
    "https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-$ARCH"
  )
  
  mkdir -p "$ROOTFS_DIR/usr/local/bin"
  
  for source in "${PROOT_SOURCES[@]}"; do
    if wget --tries=2 --timeout=20 -q --show-progress -O "$ROOTFS_DIR/usr/local/bin/proot" "$source"; then
      chmod 755 "$ROOTFS_DIR/usr/local/bin/proot"
      echo -e "${GREEN}✅ PRoot installed${NC}"
      return 0
    fi
  done
  
  echo -e "${RED}❌ Failed to install PRoot${NC}"
  exit 1
}

basic_setup() {
  echo -e "\n${CYAN}⚙️  Basic Ubuntu setup...${NC}"
  
  # DNS
  echo "nameserver 1.1.1.1" > "$ROOTFS_DIR/etc/resolv.conf"
  echo "nameserver 8.8.8.8" >> "$ROOTFS_DIR/etc/resolv.conf"
  
  # APT sources for 24.04
  mkdir -p "$ROOTFS_DIR/etc/apt"
  cat > "$ROOTFS_DIR/etc/apt/sources.list" << 'EOF'
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF
  
  # Create mount points
  mkdir -p "$ROOTFS_DIR"/{dev,proc,sys,tmp,run}
  
  echo -e "${GREEN}✅ Basic setup completed${NC}"
}

create_rdp_installer() {
  echo -e "\n${CYAN}📝 Creating RDP installer script...${NC}"
  
  cat > "$ROOTFS_DIR/install-rdp.sh" << 'EOF'
#!/bin/bash
# RDP Installer for Ubuntu 24.04

echo "=========================================="
echo "   🖥️  RDP Setup for Ubuntu 24.04"
echo "=========================================="

# Update system
echo "🔄 Updating package lists..."
apt update
apt upgrade -y

# Install desktop and RDP
echo "📦 Installing XFCE and RDP..."
apt install -y \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xrdp \
    xorgxrdp \
    firefox \
    curl \
    wget \
    git \
    vim

# Configure RDP
echo "⚙️  Configuring RDP..."
echo "startxfce4" > /etc/xrdp/startwm.sh
chmod +x /etc/xrdp/startwm.sh

# Create user
if ! id "ubuntu" &>/dev/null; then
    echo "👤 Creating user..."
    useradd -m -s /bin/bash ubuntu
    echo "ubuntu:ubuntu123" | chpasswd
    usermod -aG sudo ubuntu
fi

# Start RDP
echo "🚀 Starting RDP service..."
service xrdp start

# Enable on boot
update-rc.d xrdp defaults

echo "=========================================="
echo "   ✅ RDP Setup Complete!"
echo "=========================================="
echo ""
echo "🌐 RDP Information:"
echo "   Port: 3389"
echo "   User: ubuntu"
echo "   Password: ubuntu123"
echo ""
echo "🔗 Connect using:"
echo "   - Windows: mstsc"
echo "   - Linux: remmina or xfreerdp"
echo "   - Address: [SERVER_IP]:3389"
echo ""
echo "📋 Commands:"
echo "   service xrdp status  # Check status"
echo "   service xrdp restart # Restart service"
echo "=========================================="
EOF
  
  chmod +x "$ROOTFS_DIR/install-rdp.sh"
  echo -e "${GREEN}✅ RDP installer created${NC}"
}

create_start_script() {
  echo -e "\n${CYAN}📄 Creating startup scripts...${NC}"
  
  # Main start script
  cat > "start-ubuntu" << 'EOF'
#!/bin/bash
# Start Ubuntu 24.04 with RDP

ROOTFS_DIR="ubuntu-24.04-rdp"

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "❌ Ubuntu not found. Run installer first."
    exit 1
fi

if [ ! -f "$ROOTFS_DIR/usr/local/bin/proot" ]; then
    echo "❌ PRoot not found."
    exit 1
fi

echo "🚀 Starting Ubuntu 24.04..."
echo "Type 'exit' to return to host system"

# Start with PRoot
exec "$ROOTFS_DIR/usr/local/bin/proot" \
    --rootfs="$ROOTFS_DIR" \
    -0 \
    -w /root \
    --bind=/dev \
    --bind=/proc \
    --bind=/sys \
    --bind=/tmp \
    --bind=/run \
    --bind=/etc/resolv.conf \
    /bin/bash --login
EOF
  
  # Quick RDP setup script
  cat > "quick-rdp-setup" << 'EOF'
#!/bin/bash
# Quick RDP Setup

echo "🚀 Running RDP setup inside Ubuntu..."
cd ubuntu-24.04-rdp
./usr/local/bin/proot -R . -b /dev -b /proc -b /sys /install-rdp.sh

echo ""
echo "✅ RDP should now be running on port 3389"
echo "📢 Check if RDP is working:"
echo "   netstat -tulpn | grep 3389"
EOF
  
  chmod +x start-ubuntu quick-rdp-setup
  echo -e "${GREEN}✅ Startup scripts created${NC}"
}

create_control_script() {
  cat > "control-rdp.sh" << 'EOF'
#!/bin/bash
# RDP Control Script

ROOTFS="ubuntu-24.04-rdp"

case "$1" in
    start)
        echo "Starting RDP..."
        $ROOTFS/usr/local/bin/proot -R $ROOTFS -b /dev -b /proc -b /sys service xrdp start
        ;;
    stop)
        echo "Stopping RDP..."
        $ROOTFS/usr/local/bin/proot -R $ROOTFS -b /dev -b /proc -b /sys service xrdp stop
        ;;
    status)
        echo "RDP Status:"
        $ROOTFS/usr/local/bin/proot -R $ROOTFS -b /dev -b /proc -b /sys service xrdp status
        ;;
    restart)
        echo "Restarting RDP..."
        $ROOTFS/usr/local/bin/proot -R $ROOTFS -b /dev -b /proc -b /sys service xrdp restart
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
EOF
  
  chmod +x control-rdp.sh
}

main() {
  print_header
  detect_arch
  
  echo -e "\n${YELLOW}📁 Installation directory:${NC} $(pwd)/$ROOTFS_DIR"
  
  # Check if already installed
  if [ -d "$ROOTFS_DIR" ]; then
    echo -e "${YELLOW}⚠️  Ubuntu already installed.${NC}"
    read -p "Reinstall? (y/N): " reinstall
    if [[ ! $reinstall =~ ^[Yy]$ ]]; then
      echo -e "\n${GREEN}✅ Run './start-ubuntu' to start${NC}"
      exit 0
    fi
    rm -rf "$ROOTFS_DIR"
  fi
  
  # Create directory
  mkdir -p "$ROOTFS_DIR"
  cd "$ROOTFS_DIR"
  
  # Download Ubuntu
  if ! download_ubuntu; then
    echo -e "${RED}❌ Failed to download Ubuntu${NC}"
    exit 1
  fi
  
  # Extract
  echo -e "\n${CYAN}📂 Extracting Ubuntu...${NC}"
  tar -xzf /tmp/ubuntu-rootfs.tar.gz -C .
  rm -f /tmp/ubuntu-rootfs.tar.gz
  
  # Install PRoot
  install_proot
  
  # Basic setup
  basic_setup
  
  # Create RDP installer
  create_rdp_installer
  
  # Go back to parent directory
  cd ..
  
  # Create scripts
  create_start_script
  create_control_script
  
  # Final message
  echo -e "\n${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}                    ✅ INSTALLATION COMPLETE!                  ${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e ""
  echo -e "${CYAN}📋 Available commands:${NC}"
  echo -e "  ${YELLOW}./start-ubuntu${NC}        - Start Ubuntu 24.04 terminal"
  echo -e "  ${YELLOW}./quick-rdp-setup${NC}     - Install and setup RDP"
  echo -e "  ${YELLOW}./control-rdp.sh${NC}      - Control RDP service"
  echo -e ""
  echo -e "${CYAN}🚀 To setup RDP:${NC}"
  echo -e "  1. Run: ${YELLOW}./start-ubuntu${NC}"
  echo -e "  2. Inside Ubuntu, run: ${YELLOW}/install-rdp.sh${NC}"
  echo -e "  3. Or from host: ${YELLOW}./quick-rdp-setup${NC}"
  echo -e ""
  echo -e "${CYAN}🔗 Connect via RDP:${NC}"
  echo -e "  Address: [SERVER_IP]:3389"
  echo -e "  Username: ubuntu"
  echo -e "  Password: ubuntu123"
  echo -e ""
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
}

# Run
main "$@"
