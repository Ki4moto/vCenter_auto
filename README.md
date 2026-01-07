vCenter 自動構築（Nested ESXi + Ansible）

---

## 1. 概要

本成果物は、Windows ノートPC上の VMware Workstation を基盤とし、  
オフライン環境にて Nested ESXi 環境に vCenter Server を自動構築する成果物です。

※vCenter自動構築の様子については以下動画を参照  
　vCenter自動構築URL：https://youtu.be/kzkzLdW9ePM

【Ansible,Shell,KickStart,Autounattend】を用いて作成

- vCenter Server Appliance（VCSA）を Ansible + vcsa-deploy で自動デプロイ  
- 複数の Nested ESXi を vCenter 管理下クラスタに追加  
- HA / DRS（Live vMotion）を有効化した構成を再現可能  

Windows 側は 仮想化および GUI 実行の土台としてのみ使用し、  
自動化処理はすべて Ubuntu上で完結しています。

今後はAWSのBare-metalインスタンスを使用してクラウド上での応用を目指しております  
（通常AWSインスタンスの2.5倍の料金のため断念）

---

## 2. 背景・目的（Why）

本成果物は、**vCenter 検証環境の更新作業における人的ミスを構造的に減らすこと**を目的として作成しました。

他部署において、vCenter の評価ライセンス（90 日制限）の都合上、  
**90 日ごとに vCenter 検証環境を作り直す業務**が存在しており、  
その作業中に **新人エンジニアが既存 vCenter のデータを誤って削除してしまった**  
という事例を耳にしました。

この作業は以下の特徴を持っています。

- 手順が多く、作業回数も定期的に発生する  
- vCenter 再構築に伴い、vMDK の移動・再配置など **不可逆操作**を含む  
- 作業品質が **個人の注意力・経験値に強く依存**している  

このような条件下では、  
**「注意する」「慎重に作業する」だけで事故を防ぐことには限界がある**  
と考えました。

---

## 3. 課題認識（Problem）

事故の原因は、単なる操作ミスではなく、  
**人が直接ファイルや環境を操作せざるを得ない構造そのもの**にあると考えました。

特に vCenter 更新作業では、

- vMDK ファイルの移動・整理を手動で行う  
- 既存 vMDK と新規 vMDK が同一視界に存在する  
- GUI / CLI による削除操作が即時反映される  

といった状況が発生しやすく、  
**一度の判断ミスが即データ消失につながる**リスクがあります。

このような作業を人手で繰り返す限り、  
**将来的にも同種の事故が再発する可能性は高い**と判断しました。

---

## 4. 解決方針（Approach）

本成果物では、  
**「人の操作で事故が起きるなら、そもそも操作させない構造を作る」**  
という方針を採用しました。

具体的には、以下の設計思想に基づいています。

- vCenter / ESXi 環境を **1 コマンドで再構築可能**にする  
- 既存環境を触らず、**新環境を作り直す方式**を前提とする  
- vMDK を移動・削除する運用を廃止する  

特に vMDK に関しては、  
**NFS サーバを ESXi にマウントする構成**とすることで、

- vMDK は常に NFS 上に存在  
- ESXi 側では参照のみ  
- vMDK の手動削除・移動作業が不要  

という状態を作り、  
**誤削除が発生しうる操作そのものを排除**しました。

---

## 5. 全体構成

### 5.1 構成図
┌──────────────────────────────────────────────┐
│              Windows Notebook                │
│              IP: 192.168.5.10                │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          VMware Workstation             │  │
│  │                                        │  │
│  │  ┌──────────────────────────────────┐ │  │
│  │  │ Ubuntu                            │ │  │
│  │  │ IP: 192.168.5.20                  │ │  │
│  │  │ - Ansible                         │ │  │
│  │  │ - vcsa-deploy                     │ │  │
│  │  │ - your-config.json                │ │  │
│  │  └───────────────┬──────────────────┘ │  │
│  │                  │ HTTPS / API          │
│  │  ┌───────────────▼──────────────────┐ │  │
│  │  │ ESXi #1                            │ │  │
│  │  │ Hostname: esxi_01                  │ │  │
│  │  │ IP: 192.168.5.30                   │ │  │
│  │  │                                    │ │  │
│  │  │  ┌────────────────────────────┐  │ │  │
│  │  │  │ vCenter Server Appliance   │  │ │  │
│  │  │  │ IP: 192.168.5.50           │  │ │  │
│  │  │  └────────────────────────────┘  │ │  │
│  │  │                                    │ │  │
│  │  │  ┌────────────────────────────┐  │ │  │
│  │  │  │ win_01 (DNS / NTP)         │  │ │  │
│  │  │  │ IP: 192.168.5.40           │  │ │  │
│  │  │  └────────────────────────────┘  │ │  │
│  │  └──────────────────────────────────┘ │  │
│  │                                        │  │
│  │  ┌──────────────────────────────────┐ │  │
│  │  │ ESXi #2                            │ │  │
│  │  │ Hostname: esxi_02                  │ │  │
│  │  │ IP: 192.168.5.60                   │ │  │
│  │  └───────────────▲──────────────────┘ │  │
│  │                  │ vCenter 管理下      │
│  │  ┌───────────────▼──────────────────┐ │  │
│  │  │ ESXi #3                            │ │  │
│  │  │ Hostname: esxi_03                  │ │  │
│  │  │ IP: 192.168.5.70                   │ │  │
│  │  └──────────────────────────────────┘ │  │
│  │                                        │  │
│  │  ┌──────────────────────────────────┐ │  │
│  │  │ vCenter Cluster                  │ │  │
│  │  │ (esxi_02 + esxi_03)              │ │  │
│  │  │                                  │ │  │
│  │  │  ┌────────────────────────────┐ │ │  │
│  │  │  │ win_02 (業務VM)            │ │ │  │
│  │  │  │ IP: 192.168.5.80           │ │ │  │
│  │  │  └────────────────────────────┘ │ │  │
│  │  └──────────────────────────────────┘ │  │
│  │                                        │  │
│  └────────────────────────────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘


### 5.2 ホスト名・IP アドレス一覧

管理ネットワーク：192.168.5.0/24

種別	ホスト名	     IPアドレス	     配置場所
Windows Administrator	192.168.5.10	物理
Ubuntu	user	        192.168.5.20	Workstation
ESXi #1	esxi_01	        192.168.5.30	Workstation
win_01	win_01	        192.168.5.40	ESXi #1
vCenter	vcenter	        192.168.5.50	ESXi #1
ESXi #2	esxi_02	        192.168.5.60	Workstation
ESXi #3	esxi_03	        192.168.5.70	Workstation
win_02	win_02	        192.168.5.80	ESXi #2/#3 クラスタ


## 6. 設計意図
vCenter および管理用 Windows Server（win_01）は ESXi #1 上に集約

ESXi #2 / #3 を vCenter 管理下のクラスタとして構成

Windows Server（win_02）は クラスタ上に配置

HA（Live vMotion）/ DRS を有効化し、運用を想定した構成を再現



## 7. 環境構築準備（Windows 側）
実施内容
⓵Administrator でログイン（user ログイン不可）

⓶「PsExec.exe」 をサイトからダウンロード

⓷WindowsPCの「C:\」配下に「Tools」 を作成し、「PsExec.exe」 を配置

⓸WindowsPCの「C:\」配下に「esxi_auto」 を作成

⓹VMware Workstation をデフォルト設定でインストール

⓺Windows PC の NIC に IP アドレスを設定
　　IP: 192.168.5.10/24


## 8. 環境構築手順（Ubuntu 側）
　事前にダウンロードする ISO
　・ubuntu-24.04.2-desktop-amd64.iso
　・VMware-VMvisor-Installer-8.0U1a-21813344.x86_64.iso
　・VMware-VCSA-all-8.0.1-21860503.iso
　・SERVER_EVAL_x64FRE_ja-jp.iso

　※vmware workstation内へのUbuntu仮想マシン作成、インストール方法については以下動画を参照

　　**構築手順URL：https://youtu.be/QvJOxKfZWsg**


　
　※以下にUbuntuインストール完了後に必要なコマンドを記載
　　Ubuntu 初期設定（手動）
　sudo -i
　echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
　apt update
　apt install -y open-vm-tools open-vm-tools-desktop
　shutdown -h now

　　Ubuntuをシャットダウンさせた後に以下2点を実施
  ⓵VCSAをisoとしてマウントしてubuntuを起動しなおすこと
    (vcenter-deployの実行に必要)

  ⓶Ubuntuのvmxファイルを開く。
    ethernet0.virtualDev 
    で検索して、
   「ethernet0.virtualDev = "vlance"」
    を消去して
    ethernet0.virtualDev = "vmxnet3"
    を挿入する(ファイル転送、通信速度を高速にする設定)


  ---------Ubuntu起動後---------------
　・/home/user/Desktop/ に以下ファイルを配置
    ・ansible.cfg
    ・hosts
    ・install_all.sh
    ・vCenter_auto.yaml
    ・your-config.json

　・Ubuntu内にSSH / SCP 用ツールを導入
  sudo -i
    ※パスワード「P@ssw0rd」を手動入力
  echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null　
　sudo apt install -y openssh-server dos2unix

※Teratermを起動、「192.168.1.20」へログイン(ユーザ名：user、パスワード：P@ssw0rd)
 「SSH SCP…」から以下ファイルを
  Ubuntuの「/home/user/Desktop/」に配置。(構築手順URL：https://youtu.be/QvJOxKfZWsg 参照)
   ・mnt.tar.gz
   ・iso_material.7z
   ・vCLS-0fbe7a01-4565-493a-9968-14e611691acd.7z
   ・vCLS-39831299-7fc9-4d21-a0ea-f8cc1eaa63bc.7z
   ・VMware-VMvisor-Installer-8.0U1a-21813344.x86_64.iso
   ・SERVER_EVAL_x64FRE_ja-jp.iso


　　・Desktop 配下のシェル実行
　cd /home/user/Desktop
　sudo chmod +x install_all.sh
　sudo dos2unix install_all.sh
　sudo ./install_all.sh

　※上記完了後、Teratermの「SSH SCP…」を使用し、Ubuntu内の「/home/user/Desktop/」配下にある以下isoを
　　WindowsPCの「C:\esxi_auto」配下に配置
     ・esxi_01.iso
     ・esxi_02.iso
     ・esxi_03.iso

   ------WindowsPCのcmdを起動して入力------
    query session

    ※出力結果の「Administrator」のIDがsessionIDになる

　　Ubuntuの「vCenter_auto.yaml」ファイル内の「sessionID」を全て↑のsessionID番号に修正する。

　　※ファイル内で「Ctrl+F」⇒検索バーに「session ID」をコピペ、Enter
　　　ひっかかる所のSession IDを全て↑のsessionID番号に修正する。

　　------hostsファイルの内容修正------------
　　　資材内の「hosts」ファイルの7行目の
　　　ansible_password=""
　　　の「""」の間に、自身のWindowsPCのAdministratorアカウントのパスワードを記載する
   ----------------------------------------    

   ------Ubuntu、VMware Workstationに設定------
　　⓵Ubuntuの設定
　　Ubuntu内の設定(画面右上の歯車)⇒「ネットワーク」タブを選択
　　「192.168.1.20」⇒「192.168.5.20」
　　「192.168.1.1」⇒「192.168.5.1」にネットワーク変更
　　⓶VMware Workstationの設定
　　VMware Workstationのツールバーの「編集(E)」⇒「仮想ネットワークエディタ(N)…」を選択
　　「ブリッジ先(G):」のプルダウンを「Wi-Fiのポート(Wireless Adaptor)」から
　　「WindowsPCのポート(Intel(R) Ethernet Connection …)」に変更してポップアップ画面下の「OK」を選択
 　　　※Ubuntuの再起動不要

　　Ubuntuのターミナルで入力
　cd /home/user/Desktop/
　ansible-playbook -i hosts vCenter_auto.yaml


## 9. 実行後の状態

ESXi #1 / #2 / #3 を自動構築

ESXi #1 / #2 / #3 にUbuntu内のNFSサーバをマウント

オフラインでのvCenter自動構築に必要なDNS兼NTPサーバを自動構築(win_01)

vCenter Server デプロイ完了

ESXi #2 / #3 がクラスタに追加済み

HA / DRS 有効化

win_02 をクラスタ上に配置(Live vMotion可能)


※vCenter自動構築の様子については以下動画を参照
　vCenter自動構築URL：https://youtu.be/kzkzLdW9ePM


## 10. 注意点

sessionID はWindowsPCの再ログイン時に変わるため都度確認が必要

VMware Workstation のブリッジ NIC 設定に注意

再実行時は既存 VM / ISO の存在に注意

## 最後に（評価視点）

本 README は 第三者がそのまま再現可能な一次資料として作成しています。

設計意図・構成・実行手順を一貫して説明できる成果物です。







