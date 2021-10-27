---
title: 使用 apcupsd 完成 UPS 断电后 ESXi 稳妥关机方案
date: 2021-10-25
updated: 2021-10-25
slug:
categories: 技术
tag:
  - NAS
  - 垃圾佬
  - UPS
copyright: true
comment: true
---

## APC UPS BK650M2-CH

上个月还在杭州的时候，房东家里的空气开关出现了故障，导致每天停电十几次，我那一百多块钱捡来的垃圾 UPS 断电之后续命不到 5 分钟就凉凉了。来到上海换了新家后，准备花 500 元左右买个好一点的 UPS，给我的 NAS 服务器找个好伴侣。这次的 UPS 不再买一百块钱的垃圾货了，实在是太坑人了呜呜呜，那台垃圾 UPS 已经在闲鱼上 50 包邮卖掉了。

市面上 500 左右的畅销 UPS 无非就是施耐德 APC 的 [BK650M2-CH](https://www.apc.com/shop/cn/zh/products/APC-BACK-UPS-BK-650VA-4-2-USB-230V-USB-/P-BK650M2-CH) 和国产山特的 [TG-BOX 600/850](https://www.santak.com.cn/product/santak-tg-box-ups.html) 。两者价位差不太多，从配置上来看  [TG-BOX 600/850](https://www.santak.com.cn/product/santak-tg-box-ups.html) 稍微好一点。但考虑到 APC 的 apcupsd 在 Linux 平台上兼容性比较好，因此我最终还是选择了 [BK650M2-CH](https://www.apc.com/shop/cn/zh/products/APC-BACK-UPS-BK-650VA-4-2-USB-230V-USB-/P-BK650M2-CH) ；另一方面还是本人不太喜欢和信任国产货，被小粉红看到会不会被骂成恨国党（手动狗头。

之前在使用垃圾 UPS 的时候有过一个很 low 的 UPS 断电关机 NAS 的方案，就是通过 ping 的方式来判断是否停电，然后就预估个时间就断电关机。不过这种方案使用起来十分不方便，尤其是当网络抽风的时候，NAS 就无缘无故地关机了；或者有时候 UPS 电池用尽了，关机脚本还没有触发。因此还是需要通过 UPS 本身的串口协议来获取当前 UPS 的状态比较好一些，比用 ping 的方式高到不知道哪里去了。

## ESXi USB 直通翻车

使用 UPS 自带的 USB 线缆插到 NAS 主机 USB 接口之后，ESXi 的 USB 设备列表里也能正确地识别到了该设备。但将该设备添加到 Linux 虚拟机上之后，apcupsd 却无法获取该 UPS 的设备信息，而且在内核日志中一直会出现 `USB disconnect` 的信息，emmm，怀疑是 ESXi 直通 USB 的问题，遂放弃。

```bash
[  124.759971] usb 1-2.1: USB disconnect, device number 4
[  126.840674] usb 1-2.1: new full-speed USB device number 5 using uhci_hcd
[  127.364001] usb 1-2.1: New USB device found, idVendor=051d, idProduct=0002, bcdDevice= 1.06
[  127.364006] usb 1-2.1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[  127.364009] usb 1-2.1: Product: Back-UPS BK650M2-CH FW:294803G -292804G
[  127.364011] usb 1-2.1: Manufacturer: American Power Conversion
[  127.364013] usb 1-2.1: SerialNumber: 9B2118A06920
[  127.403811] hid-generic 0003:051D:0002.0003: hiddev0,hidraw1: USB HID v1.10 Device [American Power Conversion Back-UPS BK650M2-CH FW:294803G -292804G ] on usb-0000:02:01.0-2.1/input0
[  248.394259] usb 1-2.1: USB disconnect, device number 5
[  250.589751] usb 1-2.1: new full-speed USB device number 6 using uhci_hcd
[  251.123039] usb 1-2.1: New USB device found, idVendor=051d, idProduct=0002, bcdDevice= 1.06
[  251.123044] usb 1-2.1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[  251.123048] usb 1-2.1: Product: Back-UPS BK650M2-CH FW:294803G -292804G
[  251.123050] usb 1-2.1: Manufacturer: American Power Conversion
[  251.123052] usb 1-2.1: SerialNumber: 9B2118A06920
[  251.160223] hid-generic 0003:051D:0002.0004: hiddev0,hidraw1: USB HID v1.10 Device [American Power Conversion Back-UPS BK650M2-CH FW:294803G -292804G ] on usb-0000:02:01.0-2.1/input0
[  268.621010] usb 1-2.1: USB disconnect, device number 6
```

不幸 USB 直通给虚拟机的方案翻车了，于是想着要不将 USB 线缆连接到我的 R4S 软路由上🤔️。连接到软路由上要比在 ESXi 主机上好一些，这样在来电之后写的监控脚本也能检测到 UPS 已经通电了，这样就可以自动启动 NAS 主机以及上面的一些 VM。于是就琢磨了以下的方案，线路图如下：

![image-20211025224325577](https://p.k8s.li/2021-10-25-apcupsd-on-openwrt-with-esxi.png)

我的 NAS 服务器、交换机、R4S 软路由的电源都连接到 UPS 上。R6300v2 通过无线桥接的方式连接到房东家的  Wi-Fi。无线桥接之后，R6300v2 就变成了一台"无线交换机"，连接到它的设备将会从房东家 Wi-Fi 路由器的 DHCP 那里获取到同一网段的 IP。R4S 的 WAN 口通过网线连接到 R6300v2 的 LAN 口上，这样 R4S 就能通过 R6300v2 连接到房东家的 Wi-Fi，从而连接到公网。

在这里 R6300v2 的电源未使用 UPS，而通过市电连接，因为停电之后估计房东家的 Wi-Fi 也连不上，连接到 UPS 电源意义不大，其实也用不多少电。断电之后，运行在 R4S 软路由上的 apcupsd 进程会探测到 UPS 电源处于 offline 的状态。等到 UPS 剩余电量还剩 30% 时（或者其他自定义指标）就触发自己定义的断电关机脚本。然后剩余 30% 的电量就供给 R4S 软路由使用至少 5 个小时，这段时间应该很快就能来电。等监测到 UPS 通电之后，再触发自定义的 UPS 来电启动脚本。

大致的流程梳理好之后，那么接下来就开始搞事情。

## apcupsd on openwrt

首先就是在 R4S openwrt 上安装和配置 apcupsd，安装和配置的详细内容可参考几万字的官方手册 [apcupsd.org/manual](http://www.apcupsd.org/manual/) （劝退😂。

### 安装配置

先将 USP 自带的那根 USB 线缆 RJ45 的那一头查到 UPS 的上，再将 USB 那一头插到路由器的 USB 口上。

- 安装 apcupsd 以及 usbutils 等相关依赖包

```bash
# root @ OpenWrt in ~ [21:00:20]
$ opkg update
$ opkg install usbutils kmod-hid kmod-hid-generic kmod-usb-hid apcupsd

# 安装完之后，会在 /etc/apcupsd 目录下生成如下文件
# root @ OpenWrt in ~ [21:01:32]
$ tree /etc/apcupsd
/etc/apcupsd
├── apccontrol # UPS 状态触发脚本
├── apcupsd.conf # apcupsd 配置文件
├── apcupsd_mail.conf # email 发送配置文件，断电都断网了，有它也没啥用呀
├── changeme # UPS 需要进行充电时触发的脚本
├── commfailure # 连接 UPS 设备失败后触发的脚本
├── commok # 连接 UPS 设备之后触发的脚本
├── offbattery # UPS 来电之后触发的脚本
└── onbattery # 断电之后 UPS 进入使用电池状态后触发的脚本
```

- 使用 `lsusb` 或者 `dmesg` 命令查看 USB 设备是否正常连接以及内核加载 USB 设备的信息。如果 USB 设备能正常识别到，那就没问题啦。如果没出现的话，那就重启大法好！看看重启之后能不能识别到 UPS 设备信息。

```bash
# root @ OpenWrt in ~ [21:04:29]
$ lsusb
Bus 005 Device 003: ID 051d:0002 American Power Conversion Uninterruptible Power Supply
# root @ OpenWrt in ~ [21:04:29]
$ dmesg
[   64.485003] usb 5-1: new full-speed USB device number 2 using xhci-hcd
[   64.669133] hid-generic 0003:051D:0002.0001: hiddev96,hidraw0: USB HID v1.10 Device [American Power Conversion Back-UPS BK650M2-CH FW:294803G -292804G ] on usb-xhci-hcd.0.auto-1/input0
[ 1260.590529] usb 5-1: USB disconnect, device number 2
[ 1261.285846] usb 5-1: new full-speed USB device number 3 using xhci-hcd
[ 1261.468989] hid-generic 0003:051D:0002.0002: hiddev96,hidraw0: USB HID v1.10 Device [American Power Conversion Back-UPS BK650M2-CH FW:294803G -292804G ] on usb-xhci-hcd.0.auto-1/input0
```

- 修改 `/etc/default/apcupsd`

```ini
# 因为不是使用 systemd 启动 apcupsd 的，需要将它修改为 yes
ISCONFIGURED=yes
```

- 配置 `/etc/apcupsd/apcupsd.conf`

```ini
# 养成好习惯，先备份一下远配置文件
$ cp /etc/apcupsd/apcupsd.conf{,.bak}
$ vim /etc/apcupsd/apcupsd.conf
# 自定义你的 UPS 名称，使用默认的也可以
UPSNAME BK650M2-CH
# 设置 UPS 的连接线缆为 USB 模式
UPSCABLE usb
# 设置 UPS 的通讯模式为 USB 模式
UPSTYPE usb
# DEVICE 这行需要注释掉或者去掉 /dev/ttyS0
# DEVICE /dev/ttyS0
NETSERVER on

# 以下三个参数定义了何时触发 doshutdown 关机事件
# 当剩余电池电量低于指定百分比
BATTERYLEVEL 30
# 当UPS内部计算的电池剩余运行时间低于指定的分钟数  
MINUTES 15
# 发生电源故障后，进入 UPS 电池模式时间
TIMEOUT 0
```

配置文件具体的参数信息可参考官方手册 [configuration-directive-reference](http://www.apcupsd.org/manual/#configuration-directive-reference)，一般情况下只需要配置上面我提到的那几个参数就可以，感兴趣的可以仔细阅读一些官方手册。

- 开机自启

```bash
$ /etc/init.d/apcupsd enable
$ /etc/init.d/apcupsd start
```

### UPS 状态参数

- 使用 `apcaccess` 查看是否能连接到 UPS 设备，以下是正常通电时的信息：

```ini
# root @ OpenWrt in ~ [21:04:29]
$ apcaccess
APC      : 001,036,0860
DATE     : 2021-10-24 21:02:51 +0800
HOSTNAME : OpenWrt
VERSION  : 3.14.14 (31 May 2016) unknown
UPSNAME  : ups1
CABLE    : USB Cable
DRIVER   : USB UPS Driver
UPSMODE  : Stand Alone
STARTTIME: 2021-10-24 21:02:49 +0800
MODEL    : Back-UPS BK650M2-CH
STATUS   : ONLINE
LINEV    : 224.0 Volts
LOADPCT  : 14.0 Percent
BCHARGE  : 100.0 Percent
TIMELEFT : 46.8 Minutes
MBATTCHG : 5 Percent
MINTIMEL : 3 Minutes
MAXTIME  : 0 Seconds
SENSE    : Low
LOTRANS  : 160.0 Volts
HITRANS  : 278.0 Volts
ALARMDEL : 30 Seconds
BATTV    : 13.5 Volts
LASTXFER : No transfers since turnon
NUMXFERS : 0
TONBATT  : 0 Seconds
CUMONBATT: 0 Seconds
XOFFBATT : N/A
SELFTEST : NO
BATTDATE : 2001-01-01
NOMINV   : 220 Volts
NOMBATTV : 12.0 Volts
NOMPOWER : 390 Watts
FIRMWARE : 294803G -292804G
END APC  : 2021-10-24 21:04:36 +0800
```

- 尝试拔下 UPS 电源，断电之后的状态信息

```ini
# root @ OpenWrt in ~ [21:06:39]
$ apcaccess
APC      : 001,037,0899
DATE     : 2021-10-24 21:05:33 +0800
HOSTNAME : OpenWrt
VERSION  : 3.14.14 (31 May 2016) unknown
UPSNAME  : ups1
CABLE    : USB Cable
DRIVER   : USB UPS Driver
UPSMODE  : Stand Alone
STARTTIME: 2021-10-24 21:02:49 +0800
MODEL    : Back-UPS BK650M2-CH
STATUS   : ONBATT
LINEV    : 0.0 Volts
LOADPCT  : 15.0 Percent
BCHARGE  : 100.0 Percent
TIMELEFT : 46.8 Minutes
MBATTCHG : 5 Percent
MINTIMEL : 3 Minutes
MAXTIME  : 0 Seconds
SENSE    : Low
LOTRANS  : 160.0 Volts
HITRANS  : 278.0 Volts
ALARMDEL : 30 Seconds
BATTV    : 12.8 Volts
LASTXFER : No transfers since turnon
NUMXFERS : 1
XONBATT  : 2021-10-24 21:05:33 +0800
TONBATT  : 27 Seconds
CUMONBATT: 27 Seconds
XOFFBATT : N/A
SELFTEST : NO
BATTDATE : 2001-01-01
NOMINV   : 220 Volts
NOMBATTV : 12.0 Volts
NOMPOWER : 390 Watts
FIRMWARE : 294803G -292804G
END APC  : 2021-10-24 21:06:00 +0800
```

全部的 UPS 状态参数可参考官方手册 [status-report-fields](http://www.apcupsd.org/manual/#status-report-fields) ，不过对于我们来讲，以下几个参数比较重要：

| 参数      | 意义               | 来电          | 断电            |
| --------- | ------------------ | ------------- | --------------- |
| STATUS    | UPS 状态           | ONLINE        | ONBATT          |
| LINEV     | 接入电压           | 224.0 Volts   | 0.0 Volts       |
| BCHARGE   | 电池剩余           | 100.0 Percent | < 100.0 Percent |
| XONBATT   | 上次               | N/A           | ~               |
| TONBATT   | 当前电池使用时间   | N/A           | ~               |
| CUMONBATT | 当前电池使用总时间 | N/A           | ~               |

### apccontrol

`apccontrol` 里定义了 UPS 事件触发后要执行的操作，完整的内容可参考官方手册 [apcupsd](http://www.apcupsd.org/manual/#customizing-event-handling) 。对于我们来讲 `doshutdown` 这个事件是比较重要的：

```text
doshutdown
When the UPS is running on batteries and one of the limits expires (time, run, load), this event is generated to cause the machine to shutdown.

Default: Shuts down the system using shutdown -h or similar
```

当出现如下事件的时候则会调用 doshutdown 后的执行内容：

1. UPS 电池即将用尽
2. UPS 运行在电池模式下剩余时间低于所定义的 `MINUTES` 值
3. UPS 电池剩余百分比低于所定义的 `BATTERYLEVEL` 值
4. UPS. 运行在电池模式下所超出的时间 `TIMEOUT` 值

> When one of the conditions listed below occurs, apcupsd issues a shutdown command by calling `/etc/apcupsd/apccontrol doshutdown`, which should perform a shutdown of your system using the system shutdown(8) command. You can modify the behavior as described in [Customizing Event Handling](http://www.apcupsd.org/manual/#customizing-event-handling).
>
> The conditions that trigger the shutdown can be any of the following:
>
> - Running time on batteries have expired (`TIMEOUT`)
> - The battery runtime remaining is below the configured value (`BATTERYLEVEL`)
> - The estimated remaining runtime is below the configured value (`MINUTES`)
> - The UPS signals that the batteries are exhausted.

```bash
    doshutdown)
	echo "UPS ${2} initiated Shutdown Sequence" | ${WALL}
	echo "apcupsd UPS ${2} initiated shutdown"
	bash /opt/bin/shutdown_esxi.sh
	;;
```

然后我们就可以在 doshutdown 里面加入我们要执行的关机脚本，比如 `shutdown_esxi.sh`。至于如何优雅地关闭 ESXi 主机，推荐使用 govc 这个 CLI 工具。不太建议直接 ssh 到 ESXi 主机，然后 /sbin/shudown.sh && poweroff 一把梭子就完事儿了。这样一顿操作猛有可能会对我们的虚拟机造成一定的影响，我们可以通过 govc 或者 vim-cmd 命令对虚拟机进行挂起或者保存快照的操作，来保存虚拟机断电之前的状态，等所有虚拟机安全关机之后，再关闭 ESXi 主机，这样比较稳妥一点。以下两种关闭 ESXi 的方式任选一种即即可：

## govc

由于我的 apcupsd 是运行在 R4S 软路由上，如果将关机脚本保存在 R4S 软路由上，可以使用 govc 这个工具，然后通过 ESXi 的 https API 来对虚拟机和 ESXi 主机进行相关操作。

- 下载并安装安装 govc

在 [vmware/govmomi/releases](https://github.com/vmware/govmomi/releases) 下载页面找到与自己 CPU 体系架构相匹配的下载地址，比如我的 aarch64 的 CPU 使用如下地址：

```bash
$ wget https://github.com/vmware/govmomi/releases/download/v0.27.1/govc_Linux_arm64.tar.gz
$ tar xf govc_Linux_arm64.tar.gz
$ mv govc /usr/bin
```

- 配置 ESXi 连接信息，使用 `govc host.info` 命令查看是否能正常连接到 ESXi 主机

```bash
$ export GOVC_URL="https://root:passw0rd@esxi.yoi.li"
$ export GOVC_DATASTORE="NVME"

$ govc host.info
Name:              hp-esxi.lan
  Path:            /ha-datacenter/host/hp-esxi.lan/hp-esxi.lan
  Manufacturer:    HPE
  Logical CPUs:    6 CPUs @ 3000MHz
  Processor type:  Genuine Intel(R) CPU 0000 @ 3.00GHz
  CPU usage:       960 MHz (5.3%)
  Memory:          32613MB
  Memory usage:    29512 MB (90.5%)
  Boot time:       2021-10-24 13:57:04.396892 +0000 UTC
  State:           connected
```

- 获取 ESXi 主机上虚拟机的列表

```bash
$ govc ls /ha-datacenter/vm
/ha-datacenter/vm/NAS
/ha-datacenter/vm/kube-control-02
/ha-datacenter/vm/kube-control-03
/ha-datacenter/vm/kube-node-01
/ha-datacenter/vm/kube-registry-01
/ha-datacenter/vm/WG0
/ha-datacenter/vm/Windows
/ha-datacenter/vm/OP
/ha-datacenter/vm/Devbox
/ha-datacenter/vm/kube-control-01
```

- VM 的电源相关操作

```bash
# 将虚拟机挂起
$ govc vm.power -s NAS
```

- 在 VM 里执行命令

```bash
# 先设置终端登录的用户名和密码
$ export GOVC_GUEST_LOGIN="root:passw0rd"
# 先让缓冲区数据写入到磁盘，然后再使用 shutdown 安全地关机
$ govc guest.run -vm NAS "sync && shutdown -h now"
```

- 使用 esxcli 命令查看 VM 进程，以确保虚拟机真正的关闭了。只有当 esxcli vm process list 输出结果为空的时候，ESXi 上所有的 VM 才真正的退出，这时就可以放心大胆地关闭 ESXi 主机了。

```bash
╭─root@esxi-debian-devbox ~
╰─# govc host.esxcli vm process list
ConfigFile:   /vmfs/volumes/6118f30c-3e1989cb-77c4-b47af1db548c/NAS/NAS.vmx
DisplayName:  NAS
ProcessID:    0
UUID:         56 4d 7a 57 4c 17 4e 68-07 25 03 5e 4b 0f 8c 96
VMXCartelID:  1121973
WorldID:      1121976

ConfigFile:   /vmfs/volumes/6118f30c-3e1989cb-77c4-b47af1db548c/Devbox/Devbox.vmx
DisplayName:  Devbox
ProcessID:    0
UUID:         56 4d 91 74 02 b7 b7 59-2b 48 e3 21 d2 a6 b2 9d
VMXCartelID:  1122777
WorldID:      1122778
```

- 关闭 ESXi 主机

```bash
# 通过调用 esxcli 命令来关机
$ govc host.esxcli system shutdown
# 通过 host.shutdown 来关机，不过翻车了
╭─root@esxi-debian-devbox ~
╰─# govc host.shutdown -host "esxi.yoi.li"
govc: no argument
```

- 关机脚本`shutdown_esxi.sh`

```bash
#!/bin/bash
export GOVC_URL="https://root:passw0rd@esxi.yoi.li"
export GOVC_DATASTORE="NVME"
export GOVC_INSECURE=true
export GOVC_GUEST_LOGIN="root:passw0rd"

# suspend all vms
govc find . -type m -runtime.powerState poweredOn | awk -F '/' '{print $NF}' \
| grep -v NAS | xargs -L1 -{} govc vm.power -suspend {}

# sync data to disk and shutdown vm
govc vm.info NAS | grep -q poweredOn && govc guest.run -vm NAS "sync && shutdown -h now"

# wait all vm exit
for((i=0;i<12;i++)); do
    if ! esxcli vm process list | grep UUID; then
        break
    fi
    sleep 10
done

govc host.esxcli system shutdown
```

- 修改` /etc/apcupsd/apccontrol`

```bash
    doshutdown)
	echo "UPS ${2} initiated Shutdown Sequence" | ${WALL}
	echo "apcupsd UPS ${2} initiated shutdown"
	"bash /opt/bin/shutdown_esxi.sh"
	;;
```

##  vim-cmd

由于 vim-cmd 命令只能在 ESXi 主机上运行，因此我们需要将该关机脚本保存到 ESXI 主机上，或者通过 scp 的方式将该脚本传输到 ESXi 主机上，然后执行该脚本完成关机操作。

- 修改` /etc/apcupsd/apccontrol`

```bash
    doshutdown)
	echo "UPS ${2} initiated Shutdown Sequence" | ${WALL}
	echo "apcupsd UPS ${2} initiated shutdown"
	scp shutdown_esxi.sh root@esxi.yoi.li:/
	ssh root@esxi.yoi.li "sh /shutdown_esxi.sh"
	;;
```

- `shutdown_esxi.sh`

```bash
#!/bin/sh
LOG_PATH=/vmfs/volumes/NVME/.log/suspend.log
echo "$(TZ=UTC-8 date +%Y-%m-%d" "%H:%M:%S)" >> ${LOG_PATH}

poweroff_vms(){
    for vm in $(vim-cmd vmsvc/getallvms | grep -E 'NAS' | awk '{print $1}' | xargs); do
        if vim-cmd vmsvc/power.getstate ${vm} | grep 'Powered on'; then
            echo "$(TZ=UTC-8 date +%Y-%m-%d" "%H:%M:%S) shutdown vm ${vm}" >> ${LOG_PATH}
            vim-cmd vmsvc/power.shutdown ${vm}
        fi
    done
}

suspend_vms(){
    for vm in $(vim-cmd vmsvc/getallvms | grep -Ev 'NAS|Vmid' | awk '{print $1}' | xargs); do
    if vim-cmd vmsvc/power.getstate ${vm} | grep 'Powered on'; then
        echo "$(TZ=UTC-8 date +%Y-%m-%d" "%H:%M:%S) suppend vm ${vm}" >> ${LOG_PATH}
        vim-cmd vmsvc/power.suspend ${vm}
    done

}


suspend_vms
poweroff_vms
echo "Poweroff at $(TZ=UTC-8 date +%Y-%m-%d" "%H:%M:%S)" >> ${LOG_PATH}
/bin/host_shutdown.sh
```

通过 ssh 的方式执行该脚本需要 ESXi 主机开启 ssh 服务并做好 ssh 免密登录，这部分内容可参考 [允许使用公钥/私钥身份验证对 ESXi/ESX 主机进行 SSH 访问](https://kb.vmware.com/s/article/1002866?lang=zh_CN)。

## 参考

- [apcupsd 官方文档](http://www.apcupsd.org/manual/)
- [apcupsd debian wiki](https://wiki.debian.org/apcupsd)
- [使用 apcupsd 实现 UPS 断电自动关机](https://linuxtoy.org/archives/howto-use-apcupsd-to-automatically-shutdown-system-during-outrage.html)
- [govc usage](https://github.com/vmware/govmomi/blob/master/govc/USAGE.md)
- [vSphere go命令行管理工具govc](https://gitbook.curiouser.top/origin/vsphere-govc.html)

