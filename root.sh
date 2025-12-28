#!/bin/sh

ROOTFS_DIR=$(pwd)
export PATH=$PATH:~/.local/usr/bin
max_retries=50
timeout=10  # Tăng timeout
ARCH=$(uname -m)

# Detect architecture
if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
elif [ "$ARCH" = "armv7l" ]; then
  ARCH_ALT=armhf
else
  printf "Unsupported CPU architecture: ${ARCH}"
  exit 1
fi

if [ ! -e $ROOTFS_DIR/.installed ]; then
  echo "#######################################################################################"
  echo "#"
  echo "#                           Ubuntu 24.04 Noble Numbat Installer"
  echo "#"
  echo "#                           Copyright (C) 2024, RecodeStudios.Cloud"
  echo "#"
  echo "#######################################################################################"

  read -p "Do you want to install Ubuntu 24.04? (YES/no): " install_ubuntu
fi

case $install_ubuntu in
  [yY][eE][sS]|[yY]|"")
    echo "Downloading Ubuntu 24.04 Noble Numbat..."
    
    # URL Ubuntu 24.04 base
    UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04-base-${ARCH_ALT}.tar.gz"
    
    # Alternative mirror
    ALTERNATIVE_URL="https://mirrors.ustc.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04-base-${ARCH_ALT}.tar.gz"
    
    echo "Trying primary mirror..."
    if ! wget --tries=3 --timeout=30 --no-hsts -O /tmp/rootfs.tar.gz "$UBUNTU_URL"; then
      echo "Primary mirror failed, trying alternative..."
      wget --tries=3 --timeout=30 --no-hsts -O /tmp/rootfs.tar.gz "$ALTERNATIVE_URL" || {
        echo "Failed to download Ubuntu 24.04"
        echo "Trying Ubuntu 22.04 as fallback..."
        wget --tries=3 --timeout=30 --no-hsts -O /tmp/rootfs.tar.gz \
          "https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-base-${ARCH_ALT}.tar.gz"
      }
    fi
    
    if [ -f /tmp/rootfs.tar.gz ]; then
      echo "Extracting Ubuntu..."
      tar -xzf /tmp/rootfs.tar.gz -C $ROOTFS_DIR
      echo "Ubuntu extraction completed!"
    else
      echo "Failed to download Ubuntu image"
      exit 1
    fi
    ;;
  *)
    echo "Skipping Ubuntu installation."
    ;;
esac

# Tạo các thư mục cần thiết
mkdir -p $ROOTFS_DIR/dev $ROOTFS_DIR/proc $ROOTFS_DIR/sys $ROOTFS_DIR/tmp
mkdir -p $ROOTFS_DIR/usr/local/bin

if [ ! -e $ROOTFS_DIR/.installed ]; then
  echo "Downloading PRoot..."
  
  # URL Proot mới nhất
  PROOT_URL="https://github.com/proot-me/proot-static-build/raw/master/static/proot-${ARCH}"
  
  # Alternative
  ALT_PROOT_URL="https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}"
  
  if ! wget --tries=5 --timeout=20 --no-hsts -O $ROOTFS_DIR/usr/local/bin/proot "$PROOT_URL"; then
    echo "Trying alternative Proot URL..."
    wget --tries=5 --timeout=20 --no-hsts -O $ROOTFS_DIR/usr/local/bin/proot "$ALT_PROOT_URL"
  fi
  
  # Kiểm tra và cấp quyền
  if [ -f $ROOTFS_DIR/usr/local/bin/proot ]; then
    chmod 755 $ROOTFS_DIR/usr/local/bin/proot
    echo "Proot installed successfully!"
  else
    echo "Warning: Could not download Proot, trying to use system proot if available..."
    if command -v proot >/dev/null 2>&1; then
      cp $(which proot) $ROOTFS_DIR/usr/local/bin/proot
      chmod 755 $ROOTFS_DIR/usr/local/bin/proot
    else
      echo "Error: Proot is required but not available"
      exit 1
    fi
  fi
fi

if [ ! -e $ROOTFS_DIR/.installed ]; then
  # Cấu hình cơ bản cho Ubuntu 24.04
  echo "Configuring Ubuntu 24.04..."
  
  # DNS
  printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 8.8.4.4" > ${ROOTFS_DIR}/etc/resolv.conf
  
  # Tạo các file cần thiết
  mkdir -p ${ROOTFS_DIR}/etc/apt
  cat > ${ROOTFS_DIR}/etc/apt/sources.list << 'EOF'
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF

  # Tạo fstab
  cat > ${ROOTFS_DIR}/etc/fstab << 'EOF'
proc /proc proc defaults 0 0
tmpfs /tmp tmpfs defaults 0 0
EOF

  # Tạo hostname
  echo "ubuntu-24" > ${ROOTFS_DIR}/etc/hostname
  
  # Tạo hosts
  cat > ${ROOTFS_DIR}/etc/hosts << 'EOF'
127.0.0.1 localhost
127.0.1.1 ubuntu-24

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

  # Tạo thư mục .installed
  touch $ROOTFS_DIR/.installed
  
  # Cleanup
  rm -f /tmp/rootfs.tar.gz
  
  echo "Basic configuration completed!"
fi

# Tạo startup script cho Ubuntu 24.04
cat > $ROOTFS_DIR/start-ubuntu.sh << 'EOF'
#!/bin/bash
# Ubuntu 24.04 Startup Script

echo "Setting up Ubuntu 24.04 environment..."

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t tmpfs tmpfs /tmp

# Setup environment
export HOME=/root
export USER=root
export TERM=xterm-256color
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Setup locale
export LANG=C.UTF-8

# Chroot vào Ubuntu
echo "Starting Ubuntu 24.04..."
exec /bin/bash --login
EOF

chmod +x $ROOTFS_DIR/start-ubuntu.sh

# Hiển thị thông tin
CYAN='\e[0;36m'
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
WHITE='\e[0;37m'
RESET_COLOR='\e[0m'

display_info() {
  clear
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${RESET_COLOR}"
  echo -e "${CYAN}        Ubuntu 24.04 Noble Numbat - Ready! ${RESET_COLOR}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${RESET_COLOR}"
  echo -e ""
  echo -e "${YELLOW}Architecture:${RESET_COLOR} $ARCH ($ARCH_ALT)"
  echo -e "${YELLOW}Installation:${RESET_COLOR} $ROOTFS_DIR"
  echo -e ""
  echo -e "${WHITE}Available commands:${RESET_COLOR}"
  echo -e "  ${CYAN}./start-ubuntu${RESET_COLOR}     - Start Ubuntu 24.04"
  echo -e "  ${CYAN}./install-packages${RESET_COLOR} - Install basic packages"
  echo -e ""
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${RESET_COLOR}"
}

# Tạo script để cài packages cơ bản
cat > install-packages.sh << 'EOF'
#!/bin/bash
# Install basic packages in Ubuntu 24.04

PROOT_CMD="$ROOTFS_DIR/usr/local/bin/proot \
  --rootfs=\"${ROOTFS_DIR}\" \
  -0 -w \"/root\" -b /dev -b /sys -b /proc -b /etc/resolv.conf --kill-on-exit"

echo "Updating package lists..."
eval "$PROOT_CMD apt update"

echo "Installing essential packages..."
eval "$PROOT_CMD apt install -y \
  sudo \
  curl \
  wget \
  git \
  vim \
  nano \
  htop \
  net-tools \
  iputils-ping \
  python3 \
  python3-pip \
  ca-certificates \
  locales \
  dialog \
  apt-utils"

echo "Configuring locale..."
eval "$PROOT_CMD locale-gen en_US.UTF-8"
eval "$PROOT_CMD update-locale LANG=en_US.UTF-8"

echo "Cleaning up..."
eval "$PROOT_CMD apt clean"

echo "Package installation completed!"
EOF

chmod +x install-packages.sh

# Tạo script start chính
cat > start-ubuntu << 'EOF'
#!/bin/bash
# Start Ubuntu 24.04 with PRoot

ROOTFS_DIR=$(dirname "$(realpath "$0")")

if [ ! -f "$ROOTFS_DIR/.installed" ]; then
  echo "Ubuntu is not installed. Run the installer first."
  exit 1
fi

if [ ! -f "$ROOTFS_DIR/usr/local/bin/proot" ]; then
  echo "PRoot not found. Please re-run the installer."
  exit 1
fi

echo "Starting Ubuntu 24.04 Noble Numbat..."
echo "Type 'exit' to return to host system"

# Mount points
mkdir -p $ROOTFS_DIR/dev $ROOTFS_DIR/proc $ROOTFS_DIR/sys $ROOTFS_DIR/tmp

# Start Ubuntu với PRoot
$ROOTFS_DIR/usr/local/bin/proot \
  --rootfs="${ROOTFS_DIR}" \
  --cwd=/root \
  --bind=/dev \
  --bind=/sys \
  --bind=/proc \
  --bind=/etc/resolv.conf \
  --bind=/dev/pts \
  --bind=/dev/shm \
  /bin/bash --login
EOF

chmod +x start-ubuntu

display_info

echo -e "\n${YELLOW}To start Ubuntu 24.04, run:${RESET_COLOR}"
echo -e "  ${CYAN}./start-ubuntu${RESET_COLOR}\n"
