---
title: OpenWRT 软路由
date: 2019-09-21
categories: 技术
slug:
tag:
  - OpenWRT
  - 科学上网
copyright: true
comment: true
---

**切记：先关闭 DHCP 再连网卡、先关闭 DHCP 再连网卡、先关闭 DHCP 再连网卡。重要事情说三遍。**

## Debian 透明代理网关？

之前写过一篇，用了一段时间后，感觉太难用了。其中最大的问题还是DNS ，不知道是怎么配置的问题， DNS 查询特别慢，往往需要将近一分钟才能查询到域名。速度上还算可以，能跑满我的 VPS 带宽。

## 下载安装 x86 OpenWRT

下载地址在 OpenWRT [官网](https://downloads.openwrt.org/releases/18.06.4/targets/x86/generic/)，固件选择[openwrt-18.06.4-x86-legacy-combined-ext4.img.gz](https://downloads.openwrt.org/releases/18.06.4/targets/x86/legacy/openwrt-18.06.4-x86-legacy-combined-ext4.img.gz) 就可以，他们之间的[区别在与](https://antkillerfarm.github.io/linux/2015/02/01/Openwrt.html)

> 这里解释一下该文件夹下各个文件的区别：
>
> openwrt-x86-generic-combined-ext4.img.gz
>
> rootfs工作区存储格式为ext4
>
> openwrt-x86-generic-combined-jffs2-128k.img
>
> jffs2可以修改，也就是可以自行更换（删除）rootfs的配置文件，而不需要重新刷固件。
>
> openwrt-x86-generic-combined-squashfs.img
>
> squashfs是个只读的文件系统，相当于win的ghost，使用中配置错误，可直接恢复默认。
>
> openwrt-x86-generic-rootfs-ext4.img.gz
>
> rootfs的镜像，不带引导，可自行定义用grub或者syslinux来引导，存储区为ext4。

下载好 `openwrt-18.06.4-x86-legacy-combined-ext4.img.gz` 文件后解压后得到 `openwrt-18.06.4-x86-legacy-combined-ext4.img` 是 img 格式的文件，不过这个并不能直接供 ESXi 使用，需要使用镜像转换的工具转换成 vmdk 磁盘格式的才可以。

Windows 下可以使用 [StarWind V2V Converter](https://www.starwindsoftware.com/starwind-v2v-converter) 工具来进行转换，下载安装后按照下面的来就行

```bash
Local File --> Source image --> Local File --> VMDK --> ESXi server image
```

![](https://p.k8s.li/1568876856613.png)

![](https://p.k8s.li/1568876894451.png)

![](https://p.k8s.li/1568876920080.png)

![](https://p.k8s.li/1568876940778.png)

转换完成后会有两个文件 `openwrt-18.06.4-x86-legacy-combined-ext4.vmdk` 和 `openwrt-18.06.4-x86-legacy-combined-ext4-flat.vmdk` ，这两个文件一并上传到 ESXi 服务器的数据存储里就行，上传完两个文件和，ESXi 会自动合并这两个文件为 `VMDK/openwrt-18.06.4-x86-legacy-combined-ext4.vmdk`。其实看这两个文件的大小我们就会明白，`openwrt-18.06.4-x86-legacy-combined-ext4.vmdk` 是个 vmdk 文件描述符文件，里面记录着 vmdk 的元数据信息。

```ini
273M  openwrt-18.06.4-x86-legacy-combined-ext4-flat.img
417B  openwrt-18.06.4-x86-legacy-combined-ext4.vmdk
```

```ini
# Disk DescriptorFile
version=1
encoding="UTF-8"
CID=3b677c54
parentCID=ffffffff
createType="vmfs"

# Extent description
RW 558080 VMFS "openwrt-18.06.4-x86-legacy-combined-ext4-flat.vmdk" 0

# The Disk Data Base
#DDB

ddb.adapterType = "lsilogic"
ddb.geometry.cylinders = "35"
ddb.geometry.heads = "255"
ddb.geometry.sectors = "63"
ddb.uuid = "73 5a 46 7e 46 7e a5 f2-98 88 0e 71 f3 88 92 42"
ddb.virtualHWVersion = "4"
```

接下来就是安装啦

在 ESXi 控制台页面使用刚才上传的那个 VMDK 磁盘文件搓一个虚拟机就行。

`创建/注册虚拟机` --> `创建新虚拟机` --> `设置选择名称和客户机操作系统` –-> `选择存储` --> `自定义设置`

![](https://p.k8s.li/1568860424585.png)

**自定义设置** 这一块一定要注意

![](https://p.k8s.li/1568860493961.png)

选择添加硬盘为我们刚才新上传的哪个 VMDK 磁盘即可，然后网络适配器添加一个足够使用，如果你的 ESXi 主机有多块网卡的话可以考虑选择添加两个适配器，在此只把 OpenWRT 虚拟机当作一个旁路网关，一个网口足够了。把网络适配器 `连接` 那里**关掉**、把网络适配器 `连接` 那里**关掉**、把网络适配器 `连接` 那里**关掉**。不然你启动的时候这台 OpenWRT 软路由会在 LAN 口开启 DHCP 服务，如果你的网络环境是办公网络的话，这台开启 DHCP 的软路由可能会把整个办公网络弄瘫痪的。开启虚拟机后把 LAN 口的 DHCP 禁用掉，同时配置一个静态 IP 就可以。一个局域网里开两台 DHCP 服务器，当然会出问题的，惨痛的教训啊。

安装开机之后先上 `passwd` 命令设置一下 root 用户的密码。

接着修改一下网卡配置信息，在 lan 那个网口下配置一个静态 IP 和网关，然后

![](https://p.k8s.li/1568877917688.png)

然后使用命令 `service dnsmasq disable` 、`service odhcp disable`  禁用掉 dhcp 服务即可。然后再编辑虚拟机的设置，把网卡连接上，再重启一下虚拟机即可。通过浏览器访问我们刚才配置的那个静态 IP。

也可以参照 OpenWRT 的[官方说明](https://openwrt.org/docs/guide-user/base-system/dhcp)，使用 uci 命令禁用掉 DHCP

```bash
uci del dhcp.cfg01411c.authoritative
uci del dhcp.cfg01411c.boguspriv
uci del dhcp.cfg01411c.filterwin2k
uci del dhcp.cfg01411c.nonegcache
```

![](https://p.k8s.li/1568878441039.png)

## 初始化安装系统

