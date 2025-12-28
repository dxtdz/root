#!/bin/bash
set -euo pipefail

# =============================
# UBUNTU VM FILE
# CREDIT: quanvm0501 (BlackCatOfficial), BiraloGaming
# =============================

# =============================
# CONFIG
# =============================
VM_DIR="$(pwd)/vm"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_FILE="$VM_DIR/ubuntu-image.img"
UBUNTU_PERSISTENT_DISK="$VM_DIR/persistent.qcow2"
SEED_FILE="$VM_DIR/seed.iso"
MEMORY=16G
CPUS=4
SSH_PORT=2222
DISK_SIZE=80G
IMG_SIZE=20G
HOSTNAME="ubuntu"
USERNAME="ubuntu"
PASSWORD="ubuntu"
# sử dụng cái này nếu bạn dùng tcg
# nếu không, chỉ cần đặt nó thành 0G
SWAP_SIZE=4G
mkdir -p "$VM_DIR"
cd "$VM_DIR"

# =============================
# KIỂM TRA CÔNG CỤ
# =============================
for cmd in qemu-system-x86_64 qemu-img cloud-localds; do
    if ! command -v $cmd &>/dev/null; then
        echo "[LỖI] Lệnh '$cmd' không tìm thấy. Hãy cài đặt nó trước."
        exit 1
    fi
done

# =============================
# THIẾT LẬP VM
# =============================
if [ ! -f "$IMG_FILE" ]; then
    echo "[THÔNG TIN] Đang tải Ubuntu Cloud Image..."
    wget "$IMG_URL" -O "$IMG_FILE"
    qemu-img resize "$IMG_FILE" "$DISK_SIZE"

    # Cloud-init setup cho OpenSSH và Swap
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
manage_etc_hosts: true
disable_root: false
ssh_pwauth: true
chpasswd:
  list: |
    $USERNAME:$PASSWORD
  expire: false
packages:
  - openssh-server
runcmd:
  - echo "$USERNAME:$PASSWORD" | chpasswd
  - mkdir -p /var/run/sshd
  - /usr/sbin/sshd -D &
  # Tạo và kích hoạt swap file
  - if [ "$SWAP_SIZE" = "0G" ]; then
      rm -f /swapfile
    else
      fallocate -l $SWAP_SIZE /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    fi
growpart:
  mode: auto
  devices: ["/"]
  ignore_growroot_disabled: false
resize_rootfs: true
EOF

    cat > meta-data <<EOF
instance-id: iid-local01
local-hostname: $HOSTNAME
EOF

    cloud-localds "$SEED_FILE" user-data meta-data
    echo "[THÔNG TIN] Thiết lập VM hoàn tất với OpenSSH và Swap!"
else
    echo "[THÔNG TIN] VM image đã tồn tại, bỏ qua tải xuống..."
fi

# =============================
# THIẾT LẬP DISK PERSISTENT
# =============================
if [ ! -f "$UBUNTU_PERSISTENT_DISK" ]; then
    echo "[THÔNG TIN] Đang tạo disk persistent..."
    qemu-img create -f qcow2 "$UBUNTU_PERSISTENT_DISK" "$IMG_SIZE"
fi

# =============================
# TẮT MÁY GRACEFULLY
# =============================
cleanup() {
    echo "[THÔNG TIN] Đang tắt VM..."
    pkill -f "qemu-system-x86_64" || true
}
trap cleanup SIGINT SIGTERM

# =============================
# KHỞI ĐỘNG VM
# =============================
# Kiểm tra KVM có sẵn không
clear
if [ -e /dev/kvm ]; then
    ACCELERATION_FLAG="-enable-kvm -cpu host"
    echo "[THÔNG TIN] KVM có sẵn. Sử dụng hardware acceleration."
else
    ACCELERATION_FLAG="-accel tcg"
    echo "[THÔNG TIN] KVM không có sẵn. Sử dụng TCG software emulation."
fi
echo "CREDIT: quanvm0501 (BlackCatOfficial), BiraloGaming"
echo "[THÔNG TIN] Đang khởi động VM..."
echo "username: $USERNAME"
echo "password: $PASSWORD"
read -n1 -r -p "Nhấn bất kỳ phím nào để tiếp tục..."
echo ""
echo "[THÔNG TIN] Đang chạy VM. Để SSH vào VM: ssh -p $SSH_PORT $USERNAME@localhost"
echo "[THÔNG TIN] Nhấn Ctrl+A X để thoát QEMU (hoặc Ctrl+C để tắt VM)"
exec qemu-system-x86_64 \
    $ACCELERATION_FLAG \
    -m "$MEMORY" \
    -smp "$CPUS" \
    -drive file="$IMG_FILE",format=qcow2,if=virtio,cache=writeback \
    -drive file="$UBUNTU_PERSISTENT_DISK",format=qcow2,if=virtio,cache=writeback \
    -drive file="$SEED_FILE",format=raw,if=virtio \
    -boot order=c \
    -device virtio-net-pci,netdev=n0 \
    -netdev user,id=n0,hostfwd=tcp::"$SSH_PORT"-:22 \
    -nographic -serial mon:stdio
