import os
import subprocess
import sys
import time

# Kiểm tra quyền root
if os.geteuid() != 0:
    print("Vui lòng chạy script này với sudo:")
    print("sudo python3 crd_setup_fixed.py")
    sys.exit(1)

CRD_SSH_Code = input("Google CRD SSH Code: ")
username = "user"
password = "root"

Pin = 123456
Autostart = True

def run_cmd(cmd):
    """Chạy lệnh và hiển thị output"""
    print(f"Running: {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
    return result

class CRDSetup:
    def __init__(self, user):
        print("Bắt đầu cài đặt...")
        run_cmd("apt update -y")
        self.installCRD()
        self.installDesktopEnvironment()
        self.changewall()
        self.installGoogleChrome()
        self.finish(user)

    @staticmethod
    def installCRD():
        print("Cài đặt Chrome Remote Desktop...")
        run_cmd("wget -q https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb")
        run_cmd("dpkg -i chrome-remote-desktop_current_amd64.deb || true")
        run_cmd("apt install -f -y")
        print("✓ Chrome Remote Desktop đã cài đặt")

    @staticmethod
    def installDesktopEnvironment():
        print("Cài đặt XFCE4 Desktop...")
        run_cmd("export DEBIAN_FRONTEND=noninteractive")
        run_cmd("apt install -y xfce4 desktop-base xfce4-terminal")
        run_cmd('bash -c \'echo "exec /etc/X11/Xsession /usr/bin/xfce4-session" | tee /etc/chrome-remote-desktop-session\'')
        run_cmd("apt remove -y gnome-terminal")
        run_cmd("apt install -y xscreensaver")
        run_cmd("systemctl stop lightdm 2>/dev/null || true")
        run_cmd("apt install -y dbus-x11")
        run_cmd("service dbus start 2>/dev/null || true")
        print("✓ XFCE4 Desktop đã cài đặt")

    @staticmethod
    def installGoogleChrome():
        print("Cài đặt Google Chrome...")
        run_cmd("wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb")
        run_cmd("dpkg -i google-chrome-stable_current_amd64.deb || true")
        run_cmd("apt install -f -y")
        print("✓ Google Chrome đã cài đặt")

    @staticmethod
    def changewall():
        print("Đang tải wallpaper...")
        
        # Chỉ tải 1 ảnh nền với kích thước phổ biến
        wall_dir = "/usr/share/backgrounds"
        os.makedirs(wall_dir, exist_ok=True)
        
        # Tải 1 ảnh nền 1920x1080 (kích thước phổ biến)
        wallpaper_url = "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&auto=format&fit=crop&w=1920&q=80"
        wallpaper_path = f"{wall_dir}/ubuntu-wallpaper.jpg"
        
        # Tải ảnh nền
        run_cmd(f"wget -q -O {wallpaper_path} '{wallpaper_url}'")
        
        # Cài đặt ảnh nền mặc định cho XFCE
        run_cmd("apt install -y xfconf")
        
        # Đặt ảnh nền mặc định cho tất cả user
        xfce_config = f"""[xfce4-desktop]
last-image={wallpaper_path}
image-style=5
color-style=0"""
        
        with open("/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml", "w") as f:
            f.write(f'''<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="{wallpaper_path}"/>
          <property name="image-style" type="int" value="5"/>
          <property name="color-style" type="int" value="0"/>
        </property>
      </property>
    </property>
  </property>
</channel>''')
        
        # Tạo symbolic link để áp dụng cho user mới
        run_cmd(f"mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/")
        run_cmd(f"cp /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/")
        
        print("✓ Wallpaper đã thay đổi (1920x1080)")

    @staticmethod
    def finish(user):
        print("Thiết lập cuối cùng...")
        
        # Tạo user nếu chưa tồn tại
        run_cmd(f"id -u {user} 2>/dev/null || useradd -m {user}")
        run_cmd(f"echo '{user}:{password}' | chpasswd")
        run_cmd(f"usermod -aG sudo {user}")
        
        # Sao chép cấu hình wallpaper cho user
        run_cmd(f"mkdir -p /home/{user}/.config/xfce4/xfconf/xfce-perchannel-xml/")
        run_cmd(f"cp /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml /home/{user}/.config/xfce4/xfconf/xfce-perchannel-xml/")
        run_cmd(f"chown -R {user}:{user} /home/{user}")
        
        if Autostart:
            autostart_dir = f"/home/{user}/.config/autostart"
            run_cmd(f"mkdir -p {autostart_dir}")
            
            colab_desktop = f"""[Desktop Entry]
Type=Application
Name=Colab
Exec=sh -c "sensible-browser https://www.youtube.com/@The_Disala"
Icon=
Comment=Open a predefined notebook at session signin.
X-GNOME-Autostart-enabled=true"""
            
            with open(f"{autostart_dir}/colab.desktop", "w") as f:
                f.write(colab_desktop)
            
            run_cmd(f"chown -R {user}:{user} /home/{user}")
            run_cmd(f"chmod +x {autostart_dir}/colab.desktop")
        
        # Thêm user vào group chrome-remote-desktop
        run_cmd(f"usermod -aG chrome-remote-desktop {user}")
        
        # Kết nối Chrome Remote Desktop
        if CRD_SSH_Code:
            print("Kết nối Chrome Remote Desktop...")
            command = f"{CRD_SSH_Code} --pin={Pin}"
            run_cmd(f"sudo -u {user} -i -- bash -c '{command}'")
        
        run_cmd("systemctl start chrome-remote-desktop 2>/dev/null || true")
        
        print("\n" + "="*60)
        print("CÀI ĐẶT HOÀN TẤT!")
        print("="*60)
        print(f"Username: {username}")
        print(f"Password: {password}")
        print(f"PIN: {Pin}")
        print("\nTruy cập: https://remotedesktop.google.com/access")
        print("="*60)

if __name__ == "__main__":
    try:
        if not CRD_SSH_Code:
            print("Vui lòng nhập CRD SSH Code!")
            sys.exit(1)
        
        if len(str(Pin)) < 6:
            print("PIN phải có ít nhất 6 chữ số!")
            sys.exit(1)
        
        CRDSetup(username)
        
    except KeyboardInterrupt:
        print("\nĐã dừng script!")
    except Exception as e:
        print(f"Lỗi: {e}")
