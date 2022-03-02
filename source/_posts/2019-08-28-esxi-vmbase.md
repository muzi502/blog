---
title: 手搓虚拟机模板
date: 2019-08-28
categories: 技术
slug:
tag:
  - 虚拟机
  - VMware
  - ESXi
copyright: true
comment: true
---

## 0. 背景

由于工作环境是 ESXi 虚拟化，需要经常用一些模板开部署一些虚拟机，由于我的机器没有连接上 vCenter，只能靠上传 OVA 等虚拟机模板来部署，因此需要搓一些虚拟机模板出来。宿主机系统有 Debian 10、Debian 9、Ubuntu1804、Ubuntu 1604、CentOS7.6、Alpine 3.10、OpenWrt/LEDE ，还有 Windows 😂。一般最小化安装之后还是有可以精简的余地，删除掉一些不用的软件包，系统一般情况下都能精简到 700MB 左右，再使用 dd 暴力清零剩余空间，最后导出的 OVA 虚拟机模板在 450MB 左右。这样部署和上传的速度大大加快了。

### 1. Ubuntu 1804

#### 1. 安装镜像

[ubuntu-18.04.3-server-amd64.iso](http://mirrors.ustc.edu.cn/ubuntu-cdimage/releases/18.04/release/ubuntu-18.04.3-server-amd64.iso)

安装过程就不赘述了，主要是懒，安装过程图还要截图什么的，麻烦 😂。建议使用 lvm 分区，安装上 openssh-server 就行，其他的组件一概不用安装，这样能减少系统占用空间的而大小。以后需要安装的话再安装就行。

安装进入系统后使用 `sudo passwd` 来重置 root 的密码

1. 安装 ncdu 工具结合 du 用来分析系统根分区占用大小情况

```bash
apt update && apt install ncdu -y
```

2.默认安装后的系统分区占用情况，虽然在安装的过程中

```bash
root@ubuntu:~# df -h
Filesystem                         Size  Used Avail Use% Mounted on
udev                               1.9G     0  1.9G   0% /dev
tmpfs                              393M  1.1M  392M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   28G  5.7G   21G  22% /
tmpfs                              2.0G     0  2.0G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
tmpfs                              2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/sda2                          976M   76M  834M   9% /boot
/dev/loop0                          91M   91M     0 100% /snap/core/6350
tmpfs                              393M     0  393M   0% /run/user/1000
root@ubuntu:~# free -h
              total        used        free      shared  buff/cache   available
Mem:           3.8G        213M        2.9G        1.1M        759M        3.3G
Swap:          3.8G          0B        3.8G
```

3.默认给分配了个 swap 文件，使用 swapoff -a 关闭 swap 就行，再修改 fstab 文件，删除 swap 那一行，或注释掉

```bash
root@ubuntu:~# swapoff -a
root@ubuntu:~# rm -rf /swap.img
root@ubuntu:~# vi /etc/fstab

```

4.删除 swap file 之后的分区情况，占用的 1.8GB ，如果直接导出的话，OVA 文件至少得 2GB。我们接下来精简系统不需要得包和文件，最终 OVA 大小缩小到 450MB

```bash
root@ubuntu:~# df -h
Filesystem                         Size  Used Avail Use% Mounted on
udev                               1.9G     0  1.9G   0% /dev
tmpfs                              393M  1.1M  392M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   28G  1.8G   25G   7% /
tmpfs                              2.0G     0  2.0G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
tmpfs                              2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/sda2                          976M   76M  834M   9% /boot
/dev/loop0                          91M   91M     0 100% /snap/core/6350
tmpfs                              393M     0  393M   0% /run/user/1000
```

#### 2. 卸载不用的软件包

```bash
# 一把梭子过去就完
rm /etc/cloud
apt purge usbutils wireless-regdb linux-modules-extra-4.15.0-58-generic vim-tiny vim-common ubuntu-advantage-tools cloud-* linux-firmware snapd lxd* linux-headers-* git-man landscape-common ubuntu-release-upgrader-core
```

```ini
snapd: snapd 从不使用果断卸载
lxd*: 历史遗留下来得容器虚拟化，我有 docker 要你何用？
vim-tiny: 默认安装得 vim 死难用，卸载重新装个 vim 就行
cloud-*: 公有云用来导入私钥获取 IP 等等部署虚拟机用到得，自己用不到果断卸载
usbutils: USB 驱动，从不使用，果断卸载。如果你使用 USB 设备得话就保留它
wireless-regdb: 一个无线相关的，用不到
linux-firmware: 里面大部分是网卡蓝牙USB之类得固件，虚拟机用不到
linux-headers-*: 内核源码之类的头文件，用到的时候再安装就行
ubuntu-advantage-tools: 用不到果断卸载
linux-modules-extra-4.15.0-58-generic: 内核模块扩展驱动等，虚拟机很少能用到
git-man: git 的 man 手册，一般用不到
landscape-common: landscape 管理，用不到
ubuntu-release-upgrader-core: 用不到
```

```bash
The following packages were automatically installed and are no longer required:
  amd64-microcode eatmydata gdisk intel-microcode iucode-tool libdbus-glib-1-2 libeatmydata1 libuv1
  python3-blinker python3-jinja2 python3-json-pointer python3-jsonpatch python3-jsonschema python3-jwt
  python3-markupsafe python3-oauthlib thermald
Use 'apt autoremove' to remove them.
The following additional packages will be installed:
  python3-update-manager
Suggested packages:
  python3-launchpadlib
The following packages will be REMOVED:
  cloud-guest-utils* cloud-init* cloud-initramfs-copymods* cloud-initramfs-dyn-netconf* crda* git* git-man*
  landscape-common* linux-firmware* linux-generic* linux-headers-4.15.0-58* linux-headers-4.15.0-58-generic*
  linux-headers-generic* linux-image-generic* linux-modules-extra-4.15.0-58-generic* lxd* lxd-client* snapd*
  ubuntu-advantage-tools* ubuntu-minimal* ubuntu-release-upgrader-core* ubuntu-server* ubuntu-standard*
  update-manager-core* update-notifier-common* usbutils* vim* vim-common* vim-tiny* wireless-regdb*
The following packages will be upgraded:
  python3-update-manager
1 upgraded, 0 newly installed, 30 to remove and 75 not upgraded.
Need to get 35.1 kB of archives.
After this operation, 723 MB disk space will be freed.
Do you want to continue? [Y/n] y
```

**清理卸载后的占用大小**

```bash
root@ubuntu:~# rm -rf /var/lib/apt/lists/*
root@ubuntu:~# rm -rf /var/cache/apt/*
root@ubuntu:~# df -h
Filesystem                         Size  Used Avail Use% Mounted on
udev                               1.9G     0  1.9G   0% /dev
tmpfs                              393M  1.1M  392M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   28G  685M   26G   3% /
tmpfs                              2.0G     0  2.0G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
tmpfs                              2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/sda2                          976M   41M  868M   5% /boot
tmpfs                              393M     0  393M   0% /run/user/1000
root@ubuntu:~#
```

#### 3. 清理日志和缓存

```bash
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/*
rm -rf /var/log/journal/*
```

#### 4. 清理不用的文件

剩下来能精简的只有 `/usr/share` 里面的 doc 和 locale 文件里，减小大概 40 MB

```bash
rm -rf /usr/share/doc

cd /usr/share/locale
# 下面这条命令一定要在 /usr/share/locale 目录下执行
ls | grep -v zh | grep -v en | grep -v us | grep -v @ | grep -v local | xargs rm -rf

root@ubuntu:/usr/share/locale# du -sh
1.5M
```

**最后完毕**

```bash
root@ubuntu:/usr/share/locale# df -h
Filesystem                         Size  Used Avail Use% Mounted on
udev                               1.9G     0  1.9G   0% /dev
tmpfs                              393M  1.1M  392M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   28G  660M   26G   3% /
tmpfs                              2.0G     0  2.0G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
tmpfs                              2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/sda2                          976M   41M  868M   5% /boot
tmpfs                              393M     0  393M   0% /run/user/1000
root@ubuntu:/usr/share/locale# ncdu /
ncdu 1.12 ~ Use the arrow keys to navigate, press ? for help
--- / --------------------------------------------------------------------------------------------------------------
  407.4 MiB [##########] /usr
  109.6 MiB [##        ] /lib
   38.2 MiB [          ] /boot
   27.5 MiB [          ] /var
   14.9 MiB [          ] /bin
   14.4 MiB [          ] /sbin
    5.0 MiB [          ] /etc
    1.1 MiB [          ] /run
   52.0 KiB [          ] /tmp
   32.0 KiB [          ] /home
   20.0 KiB [          ] /root
e  16.0 KiB [          ] /lost+found
    4.0 KiB [          ] /lib64
e   4.0 KiB [          ] /srv
e   4.0 KiB [          ] /opt
e   4.0 KiB [          ] /mnt
e   4.0 KiB [          ] /media
.   0.0   B [          ] /proc
    0.0   B [          ] /sys
    0.0   B [          ] /dev
@   0.0   B [          ]  initrd.img.old
@   0.0   B [          ]  initrd.img
@   0.0   B [          ]  vmlinuz.old
@   0.0   B [          ]  vmlinuz
```

#### 5. 置零剩余空间

```bash
root@ubuntu:/usr/share/locale# df -h
Filesystem                         Size  Used Avail Use% Mounted on
udev                               1.9G     0  1.9G   0% /dev
tmpfs                              393M  1.1M  392M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   28G  660M   26G   3% /
tmpfs                              2.0G     0  2.0G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
tmpfs                              2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/sda2                          976M   41M  868M   5% /boot
tmpfs                              393M     0  393M   0% /run/user/1000
```

经过上面的精简之后，根分区占用 660MB 加上 boot 分区刚好 700 MB 左右。如果现在直接导出 ova 模板的话，vmdk 的体积是很大的，至少 1GB（ `1.3G Aug 28 15:48 Ubuntu1804.ova`） ，因此在导出 ova 模板之前需要把磁盘的剩余空间置零，这样导出的 vmdk 文件大小更小，450MB 左右哈。

直接使用 dd 暴力清零就行啦 `dd if=/dev/zero of=/zero bs=4M || rm -rf /zero`

这个过程比较长，时间取决于你安装虚拟机的时候给定的根分区大小，以及你的磁盘速度

```bash
root@ubuntu:~# dd if=/dev/zero of=/zero bs=4M || rm -rf /zero

dd: error writing '/zero': No space left on device
6860+0 records in
6859+0 records out
28771078144 bytes (29 GB, 27 GiB) copied, 445.634 s, 64.6 MB/s
```

#### 6. 导出 OVA 虚拟机模板

经过置零后我们再导出 OVA 模板

```bash
464M Aug 28 16:15 Ubuntu1804-2.ova # 置零后的大小
1.3G Aug 28 15:48 Ubuntu1804.ova   # 置零前的大小
```

经过置零后，导出的 ova 虚拟机模板体积 460M 左右，骤然减少了接近 2 倍的大小 😂

### 2. Debian 10

#### 1. 安装镜像

安装镜像选用 Debian 的网络版安装镜像，[debian-10.0.0-amd64-netinst.iso](https://mirrors.ustc.edu.cn/debian-cd/10.0.0/amd64/iso-cd/debian-10.0.0-amd64-netinst.iso) 其实选择 [debian-10.0.0-amd64-netinst.iso  ](https://mirrors.ustc.edu.cn/debian-cd/10.0.0/amd64/iso-cd/debian-10.0.0-amd64-xfce-CD-1.iso)版的也行，在最后不要安装桌面环境就可以。

#### 2. 卸载不用的软件包

```bash
# 首先修改一下 apt 源
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
sed -i 's|security.debian.org/debian-security|mirrors.ustc.edu.cn/debian-security|g' /etc/apt/sources.list
apt update
# 装上一些比较实用的工具
apt install --no-install-recommends --no-install-suggests -y wget  ncdu

# 这几个包卸载掉影响不大，应该。。
apt purge emacsen-common firmware-linux-free gcc-8-base linux-image-amd64
```

#### 3. 清理日志和缓存

```bash
rm -rf /var/lib/apt/lists/*
apt autoclean
apt autoremove
```

#### 4. 清理不用的文件

```bash
cd /usr/share/local
du -sh * | grep -v en | grep -v zh | grep -v cn | grep -v us | awk '{print $2}' | xargs rm -rf
rm -rf /usr/share/doc/*
```

#### 5. 置零剩余空间

直接使用 dd 暴力清零就行啦 `dd if=/dev/zero of=/zero bs=4M || rm -rf /zero`

```bash
╭─root@debian ~
╰─# df -h
Filesystem                   Size  Used Avail Use% Mounted on
udev                         2.0G     0  2.0G   0% /dev
tmpfs                        395M   11M  385M   3% /run
/dev/mapper/debian--vg-root   26G  698M   24G   3% /
tmpfs                        2.0G     0  2.0G   0% /dev/shm
tmpfs                        5.0M     0  5.0M   0% /run/lock
tmpfs                        2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/sda1                    236M   48M  176M  22% /boot
tmpfs                        395M     0  395M   0% /run/user/0
```

#### 6. 导出 OVA 虚拟机模板

最终导出的 vmdk 模板为 351M ，棒棒哒 😂

```bash
351M Sep  1 16:17 disk-0.vmdk
```

### 3. CentOS 7.6

#### 1. 安装镜像

安装镜像就选择使用 [CentOS-7-x86_64-Minimal-1810.iso](https://mirrors.ustc.edu.cn/centos/7.6.1810/isos/x86_64/CentOS-7-x86_64-Minimal-1810.iso) 版的 iso 就行，安装过程就不再赘述啦。磁盘分区建议为 lvm ，因为这个是虚拟机模板文件，并不清楚以后的用途和所占用的空间。使用 lvm 可以很方便地扩展根分区。

#### 2. 卸载不用的软件包

```bash
# 修改 yum 源为阿里云
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum install -y wget curl ncdu

yum remove linux-firmware NetworkManager mariadb-libs NetworkManager  alsa-lib centos-logos.noarch
yum list installed | grep firmware | xargs yum remove -y

```

#### 3. 清理日志和缓存

```bash
yum clean all

rm -rf /var/cache
```

#### 4. 清理不用的文件

```bash
# 精简一下 local-archive 文件
localedef --list-archive  | grep -v zh  | grep -v us | grep -v en | grep -v cn | xargs localedef --delete-from-archive
mv /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
build-locale-archive

rm -rf /usr/share/doc
cd /usr/share/locale
# 下面这条命令一定要在 /usr/share/locale 目录下执行
ls | grep -v zh | grep -v en | grep -v us | grep -v @ | grep -v local | xargs rm -rf
rm -rf /usr/share/backgrounds
```

#### 5. 置零剩余空间

直接使用 dd 暴力清零就行啦 `dd if=/dev/zero of=/zero bs=4M || rm -rf /zero`

最后看一下磁盘空间，占用不到 700M ，还是可以的哈

```bash
╭─root@centos ~
╰─# df -h
Filesystem               Size  Used Avail Use% Mounted on
/dev/mapper/centos-root   29G  594M   27G   3% /
devtmpfs                 1.9G     0  1.9G   0% /dev
tmpfs                    1.9G     0  1.9G   0% /dev/shm
tmpfs                    1.9G  9.3M  1.9G   1% /run
tmpfs                    1.9G     0  1.9G   0% /sys/fs/cgroup
/dev/sda1                488M  113M  340M  25% /boot
tmpfs                    378M     0  378M   0% /run/user/0

```

#### 6. 导出 OVA 虚拟机模板

```bash
348M Sep  1 09:00 disk-1.vmdk
```

最后导出的虚拟机模板大小不到 350M

### 4. Alpine 3.10

Alpine 虚拟机本来就很精简啦，其实不用搓也行
