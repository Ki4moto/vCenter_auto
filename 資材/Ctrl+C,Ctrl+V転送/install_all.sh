#!/usr/bin/env bash
set -euo pipefail

# === ここから自動インストールコマンド ===

# 更新
sudo apt update -y

echo "=== Install base packages ==="
sudo apt install -y python3 python3-pip python3-venv sshpass openssh-client

echo "=== Install Ansible (from apt, same as old env) ==="
sudo apt install -y ansible-core

echo "=== Install required Python packages ==="
pip3 install pyvmomi==8.0.3 --break-system-packages
pip3 install requests==2.31.0 --break-system-packages
pip3 install urllib3==2.0.7 --break-system-packages
pip3 install requests_ntlm==1.3.0 --break-system-packages

echo "=== Install Ansible VMware collections ==="
ansible-galaxy collection install community.vmware:4.1.0
ansible-galaxy collection install vmware.vmware_rest:2.3.1

# 必要パッケージ
sudo apt install -y nfs-kernel-server nfs-common
sudo apt install -y net-tools curl wget vim git unzip
pip3 install pywinrm==0.4.3 --break-system-packages
sudo apt install -y python3-xmltodict
ansible-galaxy collection install ansible.windows community.windows
# 必要パッケージ(iso作成)
sudo apt install -y xorriso
# 必要パッケージ(7zファイル展開)
sudo apt install -y p7zip-full
# 必要パッケージ(「.sh」ubuntu実行準備)
sudo apt install -y dos2unix

echo "=== Fix ansible.cfg plugin paths (optional) ==="
sudo mkdir -p /root/.ansible
sudo bash -c 'cat > /root/.ansible.cfg <<EOF
[defaults]
interpreter_python = auto
EOF
'

# NFS有効化
sudo mkdir -p /mnt/nfs_share
sudo bash -c 'echo "/mnt/nfs_share 192.168.5.0/24(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports'
sudo exportfs -ra
sudo systemctl restart nfs-server

echo "=== Show versions ==="
python3 --version
pip3 --version
ansible --version
ansible-galaxy collection list | grep -E "community.vmware|vmware.vmware_rest" || true
pip3 list | grep -E "pyvmomi|requests|urllib3|requests_ntlm" || true


# NFS配下にファイル配置
sudo tar -xzf /home/user/Desktop/mnt.tar.gz -C / 
sudo 7z x /home/user/Desktop/vCLS-0fbe7a01-4565-493a-9968-14e611691acd.7z -o/mnt/nfs_share
sudo 7z x /home/user/Desktop/vCLS-39831299-7fc9-4d21-a0ea-f8cc1eaa63bc.7z -o/mnt/nfs_share
sudo 7z x /home/user/Desktop/iso_material.7z -o/home/user/Desktop
#/home/user/Desktop/配下の全ての「.sh」に実行権限をつける
sudo find /home/user/Desktop/ -type f -name "*.sh" -exec chmod +x {} \;
#/home/user/Desktop/配下の全ての「.sh」をubuntuで実行できるように整える
sudo find /home/user/Desktop -type f -name "*.sh" -exec dos2unix {} \;

#win.isoとesxi.isoの作成、NFS配下にwin_01.isoとwin_02.isoを配置
sudo /home/user/Desktop/iso_material/esxi_01/make_esxi_01_iso.sh
sudo /home/user/Desktop/iso_material/esxi_02/make_esxi_02_iso.sh
sudo /home/user/Desktop/iso_material/esxi_03/make_esxi_03_iso.sh
sudo /home/user/Desktop/iso_material/win_01/make_win_01_iso.sh
sudo /home/user/Desktop/iso_material/win_02/make_win_02_iso.sh


# === ここまで自動インストールコマンド ===

echo "✅ すべてのインストールが完了しました"