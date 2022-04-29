---
title: 使用 Redfish 自动化安装 ESXi OS
date: 2022-04-30
updated: 2022-04-30
slug: redfish-esxi-os-installer
categories: 技术
tag:
- ESXi
- Redfish
- Dell 服务器
- HPE 服务器
- Lenovo 服务器
- 裸金属服务器
copyright: true
comment: true
---

从去年十一月底到现在一直在做在  [VMware ESXi](https://www.vmware.com/products/esxi-and-esx.html)  上部署 [超融合集群](https://www.smartx.com/smartx-hci/) 的产品化工具，也是在最近完成了前后端的联调，五一节后开始进入测试阶段。为了测试不同的 VMware ESXi 版本和我们产品的兼容性，需要很频繁地在一些物理服务器（如戴尔、联想、惠普、浪潮、超微等）上安装 VMware ESXi OS。

之前一直都是登录 IPMI 管理页面，挂载远程的 ISO 文件手动安装。安装完成之后还需要配置 ESXi 管理网络的 IP 地址。整体的安装流程比较繁琐，而且物理服务器每次重启和开机都十分耗时，对经常要安装 ESXi 的 QE 小伙伴来讲十分痛苦。

为了后续测试起来爽快一点，不用再为安装 ESXi OS 而烦恼，于是就基于 Redfish 快速实现了一套自动化安装 ESXi OS 的工具 [redfish-esxi-os-installer](https://github.com/muzi502/redfish-esxi-os-installer)。通过它我们内部的戴尔、联想、HPE 服务器安装 ESXi OS 只需要填写一个配置文件并选择需要安装的 ESXi ISO，运行一下 Jenkins Job 等待十几分钟就能自动安装好。原本需要一个多小时的工作量，现在只需要运行一下 Jenkins Job 帮助我们自动安装好 ESXi OS 啦 😂，真是爽歪歪。

五一假期刚开始，正好有时间抽空整理一下最近学到的东西，和大家分享一下这套自动化安装 ESXi OS 工具。

## 需求分析

- 支持服务器：联想/戴尔/HPE（超微和浪潮优先级不高，暂时不支持）；
- 一键自动化安装/重装 ESXi OS，最好能配置好 Jenkins Job；
- 指定 ESXi OS 安装的物理盘：由于物理服务器有多块硬盘，ESXi OS 需要安装在指定的硬盘上。一般为 SATA DOM 盘。比如戴尔的 [DELLBOSS](https://downloads.dell.com/manuals/all-products/esuprt_solutions_int/esuprt_solutions_int_solutions_resources/servers-solution-resources_white-papers10_en-us.pdf)，联想的 [ThinkSystem M.2](https://lenovopress.com/lp0769.pdf) 。这类 DOM 盘的好处就在于不占用多余的 HBA 卡或 PCI 插槽，有点类似于家用台式机主板上的 M.2 硬盘位插槽；
- 指定网卡并配置静态 IP 地址：由于我们的物理服务器上有多块网卡，且不同的网卡有不同的网络用途，因此需要指定某块物理网卡为 ESXi 管理网络所使用的网卡。
- 为 ESXi 管理网路配置静态 IP、子网掩码、网关，便于部署好之后直接就能通过该 IP 访问 ESXi。而不是通过 DHCP 分配一个 IP，然后再登录 IPMI 管理页面手动查看 ESXi 的 IP；

## 技术调研

目前市面上主流的裸金属服务器自动化安装 OS 的工具有 PXE 和 IPMI/Redfish 两种。

### PXE

虽然内部也有 PXE 服务可用，但重启服务器和设置服务器的引导项为 PXE 启动仍然需要手动登录 IPMI 管理页面进行操作，无法做到自动重启和自动重装，仍有一定的工作量。而且 PXE 安装 OS 无法解决为每台服务器配置各自的安装盘和管理网络网卡及静态 IP 地址的问题，遂放弃。

### IPMI/Redfish

[Redfish](https://www.dmtf.org/standards/redfish) 的概念和原理什么的就懒得介绍了，下面就直接剽窃一下官方的文档吧 😅：

> `DMTF` 的 `Redfish®` 是一个标准 `API`，旨在为融合、混合 `IT` 和软件定义数据中心（`SDDC`）提供简单和安全管理。
>
> 在 `Redfish` 出现之前，现代数据中心环境中缺乏互操作管理标准。随着机构越来越青睐于大规模的解决方案，传统标准不足以成功管理大量简单的多节点服务器或混合基础设施。`IPMI` 是一种较早的带外管理标准，仅限于“最小公共集”命令集（例如，开机/关机/重启、温度值、文本控制台等），由于供应商扩展在所有平台上并不常见，导致了客户常用的功能集减少。许多用户开发了自己的紧密集成工具，但是也不得不依赖带内管理软件。
>
> 而对于企业级用户来说，设备都是上千台，其需要统一的管理界面，就要对接不同供应商的 `API`。当基本 `IPMI` 功能已经不太好满足大规模 `Scale-out` 环境时，如何以更便捷的方式调用服务器高级管理功能就是一个新的需求。
>
> 为了寻求一个基于广泛使用的工具来加快发展的现代接口，现如今，客户需要一个使用互联网和 `web` 服务环境中常见的协议、结构和安全模型定义的 `API`。
>
> `Redfish` 可扩展平台管理 `API`（`The Redfish Scalable Platforms Management API`）是一种新的规范，其使用 `RESTful` 接口语义来访问定义在模型格式中的数据，用于执行带外系统管理 （`out of band systems management`）。其适用于大规模的服务器，从独立的服务器到机架式和刀片式的服务器环境，而且也同样适用于大规模的云环境。
>
> `Redfish` 的第 `1` 版侧重于服务器，为 `IPMI-over-LAN` 提供了一个安全、多节点的替代品。随后的 `Redfish` 版本增加了对网络接口(例如 `NIC`、`CNA` 和 `FC HBA`)、`PCIe` 交换、本地存储、`NVDIMM`、多功能适配器和可组合性以及固件更新服务、软件更新推送方法和安全特权映射的管理。此外，`Redfish` 主机接口规范允许在操作系统上运行应用程序和工具，包括在启动前（固件）阶段-与 `Redfish` 管理服务沟通。
>
> 在定义 `Redfish` 标准时，协议与数据模型可分开并允许独立地修改。以模式为基础的数据模型是可伸缩和可扩展的，并且随着行业的发展，它将越来越具有人类可读性定义。

通过 Redfish 我们可以对服务器进行挂载/卸载 ISO、设置 BIOS 启动项、开机/关机/重启等操作。只需要使用一些特定的 ansible 模块，将它们缝合起来就能将整个流程跑通。

内部的服务器戴尔、联想、HPE 的较多，这三家厂商对 Redfish 支持的也比较完善。于是这个 ESXi OS 自动化安装工具 [redfish-esxi-os-installer](https://github.com/muzi502/redfish-esxi-os-installer) 就基于 Redfish 并结合 Jenkins 实现了一套自动化安装 ESXi OS 的方案，下面就详细介绍一下这套方案的安装流程和技术实现细节。

## 安装流程

1. 获取硬盘和网卡硬件设备信息
2. 根据硬件设备信息填写配置文件
3. 根据配置文件生成 ansible inventory 文件
4. 根据配置文件为每台主机生成 kickstart 文件
5. 将生成好的 kickstart 文件打包放到 ESXi ISO 当中
6. 为每台主机重新构建一个 ESXi ISO 文件
7. 通过 redfish 弹出已有的 ISO 镜像
8. 通过 redfish 插入远程的 ISO 镜像
9. 设置 one-boot 启动引导项为虚拟光驱
10. 重启服务器到 ESXI ISO
11. ESXi installer 调用 Kickstart 脚本安装 OS
12. 等待 ESXi OS 安装完成

### 获取硬件信息

该步骤主要是获取 ESXi OS 所要安装的硬盘和管理网络网卡设备信息。

#### 获取硬盘型号/序列号

要指定 ESXi OS 安装的硬盘，可以通过硬盘型号或序列号的方式。如果当前服务器已经安装了 ESXi，登录到 ESXi 则可以查看到所安装硬盘的型号：

- 比如这台戴尔的服务器 ESXi OS 安装的硬盘型号是 `DELLBOSS VD`（注意中间的空格不要省略）；

![img](https://p.k8s.li/2022-04-30-redfish-auto-install-esxi-os-01.png)

- 比如这台联想服务器的 SATA DOM 盘型号为 `ThinkSystem M.2`

![img](https://p.k8s.li/2022-04-30-redfish-auto-install-esxi-os-06.png)

- 如果安装的是 Linux，可以通过 [smartctl](https://www.smartmontools.org/) 工具查看所要安装硬盘的型号即 `Device Model`，比如：

```bash
╭─root@esxi-debian-nas ~
╰─# smartctl -x /dev/sdb
smartctl 6.6 2017-11-05 r4594 [x86_64-linux-4.19.0-18-amd64] (local build)
Copyright (C) 2002-17, Bruce Allen, Christian Franke, www.smartmontools.org

=== START OF INFORMATION SECTION ===
Device Model:     HGST HUH721212ALE604
Serial Number:    5PJAMUHD
LU WWN Device Id: 5 000cca 291e10521
```

![img](https://p.k8s.li/2022-04-30-redfish-auto-install-esxi-os-04.png)

如果有多块型号相同的硬盘，ESXi 会默认选择第一块，如果要指定某一块硬盘则使用 WWN 号的方式，获取 WWN ID 的命令如下：

```bash
╭─root@esxi-debian-nas ~
╰─# smartctl -x /dev/sdb | sed -n "s/LU WWN Device Id:/naa./p" | tr -d ' '
naa.5000cca291e10521
```

#### 获取网卡设备名/MAC 地址

- 如果当前物理服务器已经安装了 ESXi，则登录 ESXi 主机查看 ESXi 默认的管理网络 vSwitch0 虚拟交换机所连接的物理网卡设备名，比如这台服务器网卡设备名为 `vmnic4`

![img](https://p.k8s.li/2022-04-30-redfish-auto-install-esxi-os-05.png)

- 另一种方式则是登录服务器的 IPMI 管理页面，查看对应网卡的 MAC 地址

![img](https://p.k8s.li/2022-04-30-redfish-auto-install-esxi-os-02.png)

### 填写配置文件

通过以上方式确定好 ESXi OS 所安装的硬盘型号或序列号，以及 ESXi 默认管理网络 vSwitch0 所关联的物理网卡设备名或 MAC 地址之后，我们就将这些配置参数填入到该配置文件当中。后面的工具会使用该配置为每台机器生成不同的 kickstart 文件，在 kickstart 文件中指定 ESXi OS 安装的硬盘，ESXi 管理网络所使用的网卡，以及设置静态 IP、子网掩码、网关、主机名等参数。

- [config.yaml](https://github.com/muzi502/redfish-esxi-os-installer/blob/master/config-example.yaml)

```yaml
hosts:
- ipmi:
    vendor: lenovo                  # 服务器厂商名 [dell, lenovo, hpe]
    address: 10.172.70.186          # IPMI IP 地址
    username: username              # IPMI 用户名
    password: password              # IPMI 密码
  esxi:
    esxi_disk: ThinkSystem M.2      # ESXi OS 所安装硬盘的型号或序列号
    password: password              # ESXi 的 root 用户密码
    address: 10.172.69.86           # ESXi 管理网络 IP 地址
    gateway: 10.172.64.1            # ESXi 管理网络网关
    netmask: 255.255.240.0          # ESXi 管理网络子网掩码
    hostname: esxi-69-86            # ESXi 主机名（可选）
    mgtnic: vmnic4                  # ESXi 管理网络网卡名称或MAC 地址

- ipmi:
    vendor: dell
    address: 10.172.18.191
    username: username
    password: password
  esxi:
    esxi_disk: DELLBOSS VD
    password: password
    address: 10.172.18.95
    gateway: 10.172.16.1
    netmask: 255.255.240.0
    mgtnic: B4:96:91:A7:3F:D6
```

### 生成 inventory 文件

在 [tools.sh](https://github.com/muzi502/redfish-esxi-os-installer/blob/master/tools.sh) 脚本中通过 [yq](https://github.com/mikefarah/yq) 命令行工具解析 `config.yaml` 配置文件，得到每台主机的配置信息，并根据该信息生成一个 ansible 的 inventory 文件

```bash
function rendder_host_info(){
    local index=$1
    vendor=$(yq -e eval ".hosts.[$index].ipmi.vendor" ${CONFIG})
    os_disk="$(yq -e eval ".hosts.[$index].esxi.esxi_disk" ${CONFIG})"
    esxi_mgtnic=$(yq -e eval ".hosts.[$index].esxi.mgtnic" ${CONFIG})
    esxi_address=$(yq -e eval ".hosts.[$index].esxi.address" ${CONFIG})
    esxi_gateway=$(yq -e eval ".hosts.[$index].esxi.gateway" ${CONFIG})
    esxi_netmask=$(yq -e eval ".hosts.[$index].esxi.netmask" ${CONFIG})
    esxi_password=$(yq -e eval ".hosts.[$index].esxi.password" ${CONFIG})
    ipmi_address=$(yq -e eval ".hosts.[$index].ipmi.address" ${CONFIG})
    ipmi_username=$(yq -e eval ".hosts.[$index].ipmi.username" ${CONFIG})
    ipmi_password=$(yq -e eval ".hosts.[$index].ipmi.password" ${CONFIG})
    esxi_hostname="$(yq -e eval ".hosts.[$index].esxi.hostname" ${CONFIG} 2> /dev/null || true)"
}

function gen_inventory(){
    cat << EOF > ${INVENTORY}
_hpe_

_dell_

_lenovo_

[all:children]
hpe
dell
lenovo
EOF

    for i in $(seq 0 `expr ${nums} - 1`); do
        rendder_host_info ${i}
        host_info="${ipmi_address} username=${ipmi_username} password=${ipmi_password} esxi_address=${esxi_address} esxi_password=${esxi_password}"
        sed -i "/_${vendor}_/a ${host_info}" ${INVENTORY}
    done
    sed -i "s#^_dell_#[dell]#g;s#^_lenovo_#[lenovo]#g;s#_hpe_#[hpe]#g" ${INVENTORY}
    echo "gen inventory success"
}

```

生成后的 inventory 文件内容如下，根据不同的厂商名称进行分组

```ini
[hpe]
10.172.18.191 username=username password=password esxi_address=10.172.18.95 esxi_password=password

[dell]
10.172.18.192 username=username password=password esxi_address=10.172.18.96 esxi_password=password

[lenovo]
10.172.18.193 username=username password=password esxi_address=10.172.18.97 esxi_password=password

[all:children]
hpe
dell
lenovo
```

### 检查 Redfish 登录是否正常

通过 Redfish 的 GetSystemInventory 命令获取服务器的 inventory 清单来检查登录 Redfish 是否正常，用户名或密码是否正确。

```yaml
  - name: Getting system inventory
    community.general.redfish_info:
      category: Systems
      command: GetSystemInventory
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
```

### 生成 kickstart 文件

在 [tools.sh]() 同样使用 yq 命令行工具渲染配置文件，得到每台主机的配置信息，为每台主机生成一个特定的 kickstart 文件。

在 kickstart 文件中我们我们可以通过 `install --overwritevmfs --firstdisk="${ESXI_DISK}"` 配置 ESXi OS 安装在哪一块硬盘上；

通过 `network --bootproto=static` 为 ESXi 管理网络配置静态 IP、子网掩码、网关、主机名、物理网卡等参数。需要注意的是，如果使用 MAC 地址指定网卡，MAC 地址必须为大写，因此需要使用 tr 进行了一下大小写转换；

通过 `clearpart --alldrives --overwritevmfs` 可以清除所有硬盘上的分区，我们安装时一般是将它们全部清理掉，方便进行测试；

最后再开启 SSH 服务并开启 sshServer 的防火墙，方便后续测试使用；

```bash
function gen_iso_ks(){
    local ISO_KS=$1
    local ESXI_DISK=${os_disk}
    local IP_ADDRESS=${esxi_address}
    local NETMASK=${esxi_netmask}
    local GATEWAY=${esxi_gateway}
    local DNS_SERVER="${GATEWAY}"
    local PASSWORD=${esxi_password}
    local HOSTNAME="$(echo ${esxi_hostname} | sed "s/null/esxi-${esxi_address//./-}/")"
    local MGTNIC=$(echo ${esxi_mgtnic} | tr '[a-z]' '[A-Z]' | sed 's/VMNIC/vmnic/g')
    cat << EOF > ${ISO_KS}
vmaccepteula

# Set the root password for the DCUI and Tech Support Mode
rootpw ${PASSWORD}

# Set the keyboard
keyboard 'US Default'

# wipe exisiting VMFS store # CAREFUL!
clearpart --alldrives --overwritevmfs

# Install on the first local disk available on machine
install --overwritevmfs --firstdisk="${ESXI_DISK}"

# Set the network to DHCP on the first network adapter
network --bootproto=static --hostname=${HOSTNAME} --ip=${IP_ADDRESS} --gateway=${GATEWAY} --nameserver=${DNS_SERVER} --netmask=${NETMASK} --device="${MGTNIC}"

reboot

%firstboot --interpreter=busybox

# Enable SSH
vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh
esxcli network firewall ruleset set --enabled=false --ruleset-id=sshServer
EOF
}
```

### 重新构建 ESXi ISO

这一步的操作主要是修改 ESXi ISO 的启动项配置，配置 ks 文件的路径，主要是修改 ISO 文件里的 ` boot.cfg` 和 `efi/boot/boot.cfg` 文件。在启动参数中加入 `ks=cdrom:/KS.CFG` 用于指定 ESXi OS 安装通过读取 kickstart 脚本的方式来完成。

```bash
sed -i -e 's#cdromBoot#ks=cdrom:/KS.CFG systemMediaSize=small#g' boot.cfg
sed -i -e 's#cdromBoot#ks=cdrom:/KS.CFG systemMediaSize=small#g' efi/boot/boot.cfg
```

另外在 VMware 的 KB [Boot option to configure the size of ESXi system partitions (81166)](https://kb.vmware.com/s/article/81166) 中，提到过可以设置 `systemMediaSize=small` 来调整 VMFS-L 分区的大小。ESXi 7.0 版本之后会默认创建一个 VMFS-L 分区，如果 SATA DOM 盘比较小的话比如只有 128G，建议设置此参数。不然可能会导致安装完 ESXi OS 之后磁盘剩余的空间都被 VMFS-L 分区给占用，导致没有一个本地的数据存储可以使用。

修改好 ESXi 的启动配置之后，我们再使用 genisoimage 命令重新构建一个 ESXi ISO 文件，将构建好的 ISO 文件放到一个 http 文件服务的目录下，如 nginx 的 `/usr/share/nginx/html/iso`。后面将会通过 http 的方式将 ISO 挂载到服务器的虚拟光驱上。

```bash
function rebuild_esxi_iso() {
    local dest_iso_mount_dir=$1
    local dest_iso_path=$2
    pushd ${dest_iso_mount_dir} > /dev/null
    sed -i -e 's#cdromBoot#ks=cdrom:/KS.CFG systemMediaSize=small#g' boot.cfg
    sed -i -e 's#cdromBoot#ks=cdrom:/KS.CFG systemMediaSize=small#g' efi/boot/boot.cfg
    genisoimage -J \
                -R  \
                -o ${dest_iso_path} \
                -relaxed-filenames \
                -b isolinux.bin \
                -c boot.cat \
                -no-emul-boot \
                -boot-load-size 4 \
                -boot-info-table \
                -eltorito-alt-boot \
                -eltorito-boot efiboot.img \
                -quiet --no-emul-boot \
                . > /dev/null
  popd > /dev/null
}
```

重新构建好 ESXi ISO 之后的 nginx 目录结构如下：

```bash
# tree /usr/share/nginx/html/iso/
/usr/share/nginx/html/iso/
├── redfish
│   ├── 172.20.18.191
│   │   └── VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso # 重新构建的 ISO
│   ├── 172.20.18.192
│   │   └── VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso # 重新构建的 ISO
│   ├── 172.20.18.193
│   │   └── VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso # 重新构建的 ISO
│   └── 172.20.70.186
│       └── VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso # 重新构建的 ISO
├── VMware-VMvisor-Installer-6.7.0.update03-14320388.x86_64.iso # 原 ISO
├── VMware-VMvisor-Installer-7.0U2a-17867351.x86_64.iso         # 原 ISO
└── VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso         # 原 ISO
```

### 通过 redfish 弹出已有的 Virtual Media

redfish 插入/弹出 ISO 操作有现成可用的 ansible 模块可以使用，不必重复造轮子。不同的服务器厂商调用的模块可能会有所不同，不过参数基本上是相同的。

如果当前服务器上已经挂载了一些其他的 ISO，要将他们全部弹出才行，不然在挂载 ISO 的时候会失败退出，并且也能避免多个 ISO 重启启动的时候引起冲突启动到另一个 ISO 中。

- 联想服务器的 VirtualMediaEject 命令可以弹出所有的 ISO

```yaml
  - name: Lenovo | Eject all Virtual Media
    community.general.xcc_redfish_command:
      category: Manager
      command: VirtualMediaEject
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
      resource_id: "1"
    when:
    - inventory_hostname in groups['lenovo']
    tags:
    - mount-iso
    - umount-iso
```

- 戴尔和 HPE 服务器在弹出 ISO 的时候需要先知道原有 ISO 的 URL。因此先通过 `GetVirtualMedia` 命令获取到一个 ISO 的 URL 列表，然后再根据这个列表一一弹出。

```yaml
  - name: Get virtual media details
    community.general.redfish_info:
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
      category: "Manager"
      command: "GetVirtualMedia"
    register: result
    tags:
    - mount-iso
    - umount-iso
    when:
    - inventory_hostname not in groups['lenovo']

  - name: Eject virtual media
    community.general.redfish_command:
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
      category: "Manager"
      command: "VirtualMediaEject"
      virtual_media:
        image_url: "{{ item }}"
    with_items: "{{ result.redfish_facts.virtual_media.entries[0][1] | selectattr('ConnectedVia', 'equalto','URI') | map(attribute='Image') | list }}"
    when:
    - inventory_hostname not in groups['lenovo']
    tags:
    - mount-iso
    - umount-iso
```

在弹出一个 ISO 的时候需要先知道 ISO 的 URL，感觉有点奇葩 😂。更合理的应该是需要一个挂载点的标识，就像比 Linux 上的挂载点。在 umount 挂载的设备时，只需要知道挂载点即可，不需要知道挂载的设备是什么。在 ISSUE [VirtualMediaEject should not require image_url ](https://github.com/ansible-collections/community.general/issues/3042) 中有大佬反馈过在弹出 ISO 的时候不应该需要 image url，不过被 maintainer 给否决了 😅。

> Yes, at least with the behavior we've implemented today the image URL is needed since the expectation is the user is specifying the image URL for the ISO to eject. I think we need to consider some things first before making changes.
>
> If the image URL is not given, then what exactly should be ejected? All virtual media your example indicates? This seems a bit heavy handed in my opinion, but others might like this behavior. Redfish itself doesn't support an "eject all" type of operation, and I suspect the script you're referencing is either using OEM actions or is just looping on all slots and ejecting everything.
>
> Should a user be allowed specify an alternative identifier (such as the "Id" of the virtual media instance) in order to control what slot is ejected?
>
> Certainly would like opinions from others for desired behavior. I do like the idea of keeping the mandatory argument list as minimal as possible, but would like to agree upon the desired behavior first.

### 通过 Redfish 插入 ISO

- 联想服务器使用的是 `community.general.xcc_redfish_command` 模块，redfish 的 command 为 VirtualMediaInsert；

```yaml
  - name: Lenovo | Insert {{ image_url }} Virtual Media
    community.general.xcc_redfish_command:
      category: Manager
      command: VirtualMediaInsert
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
      virtual_media:
        image_url: "{{ image_url }}"
        media_types:
          - CD
          - DVD
      resource_id: "1"
    when:
    - inventory_hostname in groups['lenovo']
    tags:
    - mount-iso
```

- 戴尔和 HPE 服务器挂载 ISO 使用的则是 `community.general.redfish_command` 模块，command 和联想的相同；

```yaml
   - name: Insert {{ image_url }} ISO as virtual media device
    community.general.redfish_command:
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
      category: "Manager"
      command: "VirtualMediaInsert"
      virtual_media:
        image_url: "{{ image_url }}"
        media_types:
          - CD
          - DVD
    when:
    - inventory_hostname not in groups['lenovo']
    tags:
    - mount-iso
```

需要注意的是：如果使用 `community.general.redfish_command` 模块为联想的服务器挂载 ISO 会提示 4xx 错误，必须使用 `community.general.xcc_redfish_command` 模块才行。

### 设置启动项为虚拟光驱

此过程是将服务器的启动项设置为虚拟光驱，不同厂商的服务器调用的 ansible 模块可能也会有所不同。

- 联想和 HPE 服务器

```yaml
  - name: Set one-time boot device to {{ bootdevice }}
    community.general.redfish_command:
      category: Systems
      command: SetOneTimeBoot
      bootdevice: "{{ bootdevice }}"
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
      timeout: 20
    when:
    - inventory_hostname not in groups['dell']
```

- 戴尔服务器

```yaml
  - name:  Dell | set iDRAC attribute for one-time boot from virtual CD
    community.general.idrac_redfish_config:
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
      category: "Manager"
      command: "SetManagerAttributes"
      manager_attributes:
        ServerBoot.1.BootOnce: "Enabled"
        ServerBoot.1.FirstBootDevice: "VCD-DVD"
    when:
    - inventory_hostname in groups['dell']
```

### 重启服务器

重启服务器直接调用 `community.general.redfish_command` 模块就可以。不过需要注意的是，重启服务器之前要保证服务器当前状态为开启状态，因此调用一下 redfish 的 PowerOn 命令对服务器进行开机，如果已处于开机状态则无影响，然后再调用 PowerForceRestart 命令重启服务器。

```yaml
- hosts: all
  name: Power Force Restart the host
  gather_facts: false
  tasks:
  - name: Turn system power on
    community.general.redfish_command:
      category: Systems
      command: PowerOn
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
  - name: Reboot system
    community.general.redfish_command:
      category: Systems
      command: PowerForceRestart
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
      timeout: 20
  tags:
  - reboot
```

这里还有优化的空间，就是根据电源的状态决定是重启还是开机，不过有点麻烦懒得弄了 😅

### 等待 ESXi OS 安装完成

服务器重启之后，我们通过 govc 命令不断尝试连接 ESXi 主机，如果能够正常连接则说明 ESXi OS 已经安装完成了。一般情况下等待 15 分钟左右就能安装完成，期间需要重启服务器两次，每次重启大概需要 5 分钟左右，实际上 ESXi 进入安装页面到安装完成只需要 5 分钟左右，服务器开机自检占用的时间会稍微长一点。

![image-20220428210819057](https://p.k8s.li/2022-04-30-redfish-auto-install-esxi-os-03.png)

```yaml
- hosts: all
  name: Wait for the ESXi OS installation to complete
  gather_facts: false
  vars:
    esxi_username: "root"
    govc_url: "https://{{ esxi_username }}:{{ esxi_password }}@{{ esxi_address }}"
  tasks:
  - name: "Wait for {{ inventory_hostname }} install ESXi {{ esxi_address }} host to be complete"
    shell: "govc about -k=true -u={{ govc_url}}"
    retries: 60
    delay: 30
    register: result
    until: result.rc == 0
  tags:
  - post-check
```

## Makefile 封装

为了方便操作，将上述流程使用 Makefile 进行封装一下，如果不配置 Jenkins Job 的话，可以在本地填写好 `config.yaml` 配置文件，然后运行 make 命令来进行相关操作。

### vars

```bash
SRC_ISO_DIR     ?= /usr/share/nginx/html/iso
HTTP_DIR        ?= /usr/share/nginx/html/iso/redfish
HTTP_URL        ?= http://172.20.17.20/iso/redfish
ESXI_ISO        ?= VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso

SRC_ISO_DIR   # 原 ESXi ISO 的存放目录
ESXI_ISO      # ESXi ISO 的文件名，如 VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso
HTTP_DIR      # HTTP 服务器的静态文件存放目录，比如 /usr/share/nginx/html 或 /var/www/html
              # 重新构建好的 ISO 文件将存放到这个目录当中
HTTP_URL      # HTTP 服务器的 URL 地址，比如 http://172.20.29.171/iso/redfish
```

### target

```yaml
make docke-run  # 在 docker 容器里运行所有操作，好处就是不用再安装一堆 ansible 等工具的依赖
make inventory  # 根据 config.yaml 配置文件生成 ansible 的 inventory 文件
make pre-check  # 检查生成的 inventory 文件是否正确，连接 redfish 是否正常
make build-iso  # 为每台主机生成 kickstart 文件并重新构建 ESXi OS ISO 文件
make mount-iso  # 将构建好的 ISO 文件通过 redfish 挂载到物理服务器的虚拟光驱，并设备启动项
make reboot     # 重启服务器，进入到虚拟光驱启动 ESXi inatller
make post-check # 等待 ESXi OS 安装完成
make install-os # 运行 pre-check, mount-iso, reboot, post-check
```

## Jenkins Job

虽然在 Makefile 里封装了比较方便的命令操作，但是对于不太熟悉这套流程的使用人员来讲还是不够便捷。对于使用人员来讲不需要知道具体的流程是什么，因此还需要提供一个更为便捷的入口来使用这套工具，对外屏蔽掉技术实现的细节。

在我们内部，老牌 CI 工具 Jenkins 大叔十分受欢迎，使用的十分普遍。之前同事也常调侃：`我们内部的 Jenkins 虽然达不到人手一个的数量，但每个团队有两三个自己的 Jenkins 再正常不过了`🤣。因此提供了一个 Jenkins Job 来运行这套安装工具再完美不过了。这样使用人员就不用再 clone repo 代码，傻乎乎地运行一些 make 命令了，毕竟一个 Jenkins build 的按钮比 make 命令好好用得太多。

我们组的 Jenkins 比较特殊，是使用 kubernetes Pod 作为动态 Jenkins slave 节点，即每运行一个 Jenkins Job 就会根据定义的 Pod 模版创建一个 Pod 到指定的 Kubernetes 集群中，然后 Jenkinsfile 中定义的 stage 都会运行在这个 Pod 容器内。这些内容可以参考一下我之前写的 [Jenkins 大叔与 kubernetes 船长手牵手 🧑‍🤝‍🧑](https://blog.k8s.li/jenkins-with-kubernetes.html)。

### Jenkinsfile

如果你熟悉 Jenkins 的话，可以创建一个 Jenkins Job ，并在 Job 中设置好如下几个参数，并将这个 [Jenkinsfile](https://github.com/muzi502/redfish-esxi-os-installer/blob/master/jenkins/Jenkinsfile) 中的内容复制到 Jenkins Job 的配置中。

| 参数名      | 参数类型  | 说明                      |
| ----------- | --------- | ------------------------- |
| esxi_iso    | ArrayList | ESXi ISO 文件名列表       |
| http_server | String    | HTTP 服务器的 IP 地址     |
| http_dir    | String    | HTTP 服务器的文件目录路径 |
| config_yaml | Text      | config.yaml 配置文件内容  |

```bash
// params of jenkins job
def ESXI_ISO = params.esxi_iso
def CONFIG_YAML = params.config_yaml
def HTTP_SERVER = params.http_server

// default params for the job
def HTTP_DIR  = params.http_dir ?: "/usr/share/nginx/html"
def SRC_ISO_DIR = params.src_iso_dir ?: "${HTTP_DIR}/iso"
def DEST_ISO_DIR = params.dest_iso_dir ?: "${HTTP_DIR}/iso/redfish"

def WORKSPACE = env.WORKSPACE
def JOB_NAME = "${env.JOB_BASE_NAME}"
def BUILD_NUMBER = "${env.BUILD_NUMBER}"
def POD_NAME = "jenkins-${JOB_NAME}-${BUILD_NUMBER}"
def POD_IMAGE = params.pod_image ?: "ghcr.io/muzi502/redfish-esxi-os-installer:v0.1.0-alpha.1"
// Kubernetes pod template to run.
podTemplate(
    cloud: "kubernetes",
    namespace: "default",
    name: POD_NAME,
    label: POD_NAME,
    yaml: """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: runner
    image: ${POD_IMAGE}
    imagePullPolicy: Always
    tty: true
    volumeMounts:
    - name: http-dir
      mountPath: ${HTTP_DIR}
    securityContext:
      privileged: true
    env:
    - name: ESXI_ISO
      value: ${ESXI_ISO}
    - name: SRC_ISO_DIR
      value: ${SRC_ISO_DIR}
    - name: HTTP_DIR
      value: ${DEST_ISO_DIR}
    - name: HTTP_URL
      value: http://${HTTP_SERVER}/iso/redfish
  - name: jnlp
    args: ["\$(JENKINS_SECRET)", "\$(JENKINS_NAME)"]
    image: "jenkins/inbound-agent:4.11.2-4-alpine"
    imagePullPolicy: IfNotPresent
  volumes:
  - name: http-dir
    nfs:
      server: ${HTTP_SERVER}
      path: ${HTTP_DIR}
""",
) {
    node(POD_NAME) {
        try {
            container("runner") {
                writeFile file: 'config.yaml', text: "${CONFIG_YAML}"
                stage("Inventory") {
                    sh """
                    cp -rf /ansible/* .
                    make inventory
                    """
                }
                stage("Precheck") {
                    sh """
                    make pre-check
                    """
                }
                if (params.build_iso) {
                    stage("Build-iso") {
                        sh """
                        make build-iso
                        """
                    }
                }
                stage("Mount-iso") {
                    sh """
                    make mount-iso
                    """
                }
                stage("Reboot") {
                    sh """
                    make reboot
                    sleep 60
                    """
                }
                stage("Postcheck") {
                    sh """
                    make post-check
                    """
                }
            }
            stage("Success"){
                MESSAGE = "【Succeed】Jenkins Job ${JOB_NAME}-${BUILD_NUMBER} Link: ${BUILD_URL}"
                // slackSend(channel: '${SLACK_CHANNE}', color: 'good', message: "${MESSAGE}")
            }
        } catch (Exception e) {
            MESSAGE = "【Failed】Jenkins Job ${JOB_NAME}-${BUILD_NUMBER} Link: ${BUILD_URL}"
            // slackSend(channel: '${SLACK_CHANNE}', color: 'warning', message: "${MESSAGE}")
            throw e
        }
    }
}
```

或者参考 [Export/import jobs in Jenkins](https://stackoverflow.com/questions/8424228/export-import-jobs-in-jenkins) 将这个 [Job](https://github.com/muzi502/redfish-esxi-os-installer/blob/master/jenkins/config.xml) 的配置导入到 Jenkins 当中，并设置好上面提到的几个参数。

![image-20220429201859704](https://p.k8s.li/2022-04-30-redfish-esxi-os-installer-07.png)

## 常见问题

### 硬件信息收集

整体上该方案有一点不足的就是需要人为地确认 ESXi OS 安装硬盘的型号/序列号，以及 ESXi 管理网络所使用的物理网卡。其实是可以通过 redfish 的 API 来统一地获取，然后再根据这些硬件设备信息进行选择，这样就不用登录到每一台物理服务器上进行查看了。

但考虑到实现成本，工作量会翻倍，而且我们的服务器都是固定的，只要人为确认一次就可以，下一次重装 ESXi OS 的时候只需要复制粘贴上一次的硬件配置即可，所以目前并没有打算做获取硬件信息的功能。

而且即便是将硬件信息获取出来，如果没有一个可视化的 Web UI 展示这些设备信息，也很难从一堆硬件数据中找出特定的设备，对这些数据进行 UI 展示工作量也会翻倍，因此暂时不再考虑这个功能了。

### 挂载 ISO 之前先确保 ISO 存在

有些服务器比如 HPE 在挂载一个不存在的 ISO 时并不会报错，当时我排查了好久才发现 😂，我一直以为是启动项设置的问题。因此在挂载 ISO 之前我们可以通过 curl 的方式检查一下 ISO 的 URL 是否正确，如果 404 不存在的话就报错退出。

```yaml
- hosts: all
  name: Mount  {{ image_url }} ISO
  gather_facts: false
  tasks:
  - name: Check {{ image_url }} ISO file exists
    shell: "curl -sI {{ image_url }}"
    register: response
    failed_when: "'200 OK' not in response.stdout or '404 Not Found' in response.stdout"
    tags:
    - mount-iso
```

### 单独构建 Kickstart ISO

目前的方案是为将 ESXi 的 kickstart 文件 KS.CFG 放到了 ESXi OS ISO 镜像里，由于每台主机的 kickstart 文件都不相同，这就需要为每台服务器构建一个 ISO 文件，如果机器数量比较多的话，可能会占用大量的磁盘存储空间，效率上会有些问题。也尝试过将 kickstart 文件单独放到一个 ISO 中，大体的思路如下：

- 构建 kickstart ISO 文件，-V 参数指定 ISO 的 label 名称为 KS

```bash
$ genisoimage -o /tmp/ks.iso -V KS ks.cfg
```

- 修改 ESXi 启动配置，将 ks 文件路径通过 label 的方式指向刚才构建的 ISO

```bash
$ sed -i -e 's#cdromBoot#ks=hd:KS:/ks.cfg systemMediaSize=small#g' boot.cfg
$ sed -i -e 's#cdromBoot#ks=hd:KS:/ks.cfg systemMediaSize=small#g' efi/boot/boot.cfg
```

- 修改一下 playbook，插入两个 ISO

```yaml
  - name: Insert {{ item }} ISO as virtual media device
    community.general.redfish_command:
      baseuri: "{{ baseuri }}"
      username: "{{ username }}"
      password: "{{ password }}"
      category: "Manager"
      command: "VirtualMediaInsert"
      virtual_media:
        image_url: "{{ item }}"
        media_types:
          - CD
          - DVD
    with_items:
    - "{{ esxi_iso_url }}"
    - "{{ ks_iso_url }}"
    when:
    - inventory_hostname not in groups['lenovo']
    tags:
    - mount-iso
```

等这些都修改好之后我满怀期待地运行了 make mount-iso 命令等到奇迹的发生，没想到直接翻车了！不支持挂载两个 ISO，白白高兴一场，真气人 😡

```yaml
TASK [Insert {{ item }} ISO as virtual media device] ******************************************************************************************
changed: [10.172.18.191] => (item=http://10.172.29.171/iso/redfish/VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso)
changed: [10.172.18.192] => (item=http://10.172.29.171/iso/redfish/VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso)
changed: [10.172.18.193] => (item=http://10.172.29.171/iso/redfish/VMware-VMvisor-Installer-7.0U3d-19482537.x86_64.iso)
failed: [10.172.18.193] (item=http://10.172.29.171/iso/redfish/10.172.18.193/ks.iso) => {"ansible_loop_var": "item", "changed": false, "item": "http://10.172.29.171/iso/redfish/10.172.18.193/ks.iso", "msg": "Unable to find an available VirtualMedia resource supporting ['CD', 'DVD']"}
failed: [10.172.18.192] (item=http://10.172.29.171/iso/redfish/10.172.18.192/ks.iso) => {"ansible_loop_var": "item", "changed": false, "item": "http://10.172.29.171/iso/redfish/10.172.18.192/ks.iso", "msg": "Unable to find an available VirtualMedia resource supporting ['CD', 'DVD']"}
failed: [10.172.18.191] (item=http://10.172.29.171/iso/redfish/10.172.18.191/ks.iso) => {"ansible_loop_var": "item", "changed": false, "item": "http://10.172.29.171/iso/redfish/10.172.18.191/ks.iso", "msg": "Unable to find an available VirtualMedia resource supporting ['CD', 'DVD']"}
```

或许将 ISO 替换成软盘  floppy  的方式可能行得通，不过当我看了 [create-a-virtual-floppy-image-without-mount](https://stackoverflow.com/questions/11202706/create-a-virtual-floppy-image-without-mount) 后直接把我整不会了，没想创建一个软盘文件到这么麻烦，还是直接放弃该方案吧 🌚。

多说一句，之所以想到使用软盘的方式是因为之前在玩 [Packer](https://github.com/hashicorp/packer) 的时候，研究过它就是将 kickstart 文件制作成一个软盘，插入到虚拟机中。虚拟机开机后通过 vCenter API 发送键盘输入，插入 kickstart 的路径，anaconda 执行自动化安装 OS。

```bash
==> vsphere-iso-base: Creating VM...
==> vsphere-iso-base: Customizing hardware...
==> vsphere-iso-base: Mounting ISO images...
==> vsphere-iso-base: Adding configuration parameters...
==> vsphere-iso-base: Creating floppy disk...
    vsphere-iso-base: Copying files flatly from floppy_files
    vsphere-iso-base: Done copying files from floppy_files
    vsphere-iso-base: Collecting paths from floppy_dirs
    vsphere-iso-base: Resulting paths from floppy_dirs : [./kickstart/centos/http/]
    vsphere-iso-base: Recursively copying : ./kickstart/centos/http/
    vsphere-iso-base: Done copying paths from floppy_dirs
    vsphere-iso-base: Copying files from floppy_content
    vsphere-iso-base: Done copying files from floppy_content
==> vsphere-iso-base: Uploading created floppy image
==> vsphere-iso-base: Adding generated Floppy...
==> vsphere-iso-base: Set boot order temporary...
==> vsphere-iso-base: Power on VM...
==> vsphere-iso-base: Waiting 15s for boot...
==> vsphere-iso-base: Typing boot command...
==> vsphere-iso-base: Waiting for IP...

root@devbox-fedora:/root # scp 192.168.24.43:/vmfs/volumes/Packer/base-os-centos7/packer-tmp-created-floppy.flp .
packer-tmp-created-floppy.flp                                                                                100% 1440KB  89.4MB/s   00:00
root@devbox-fedora:/root # mount packer-tmp-created-floppy.flp /mnt
root@devbox-fedora:/root # readlink /dev/disk/by-label/packer
../../loop2
root@devbox-fedora:/root # df -h /mnt
Filesystem      Size  Used Avail Use% Mounted on
/dev/loop2      1.4M   16K  1.4M   2% /mnt
root@devbox-fedora:/root #
root@devbox-fedora:/root # ls /mnt
HTTP
root@devbox-fedora:/root # ls /mnt/HTTP
7
root@devbox-fedora:/root # ls /mnt/HTTP/7
KS.CFG
```

### 通过 http 方式读取 kickstart

不一定可行，在通过 http 方式读取 kickstart 文件之前，ESXi OS installer 需要有一个 IP 地址才行。如果服务器如果有多块网卡的话，就很难确定是否分配到一个 IP，使用默认 DHCP 的方式并不一定能获取到正确的 IP 地址。因此读取 kickstart 文件的方式还是建议使用 ISO 的方式，这样在安装 OS 时对网络环境无依赖，更稳定一些。

### 支持其他 OS 的安装

目前该方案只支持 ESXi OS 的安装，其他 OS 的自动化安装其实原理是一样的。比如 CentOS 同样也是修改 kickstart 文件。如果要指定 OS 所安装的磁盘可以参考一下戴尔官方的一篇文档 [Automating Operating System Deployment to Dell BOSS – Techniques for Different Operating Systems](https://www.dell.com/support/kbdoc/zh-hk/000177584/automating-operating-system-deployment-to-dell-boss-techniques-for-different-operating-systems) 。

```bash
%include /tmp/bootdisk.cfg
%pre
# Use DELLBOSS device for OS install if present.
BOSS_DEV=$(find /dev -name "*DELLBOSS*" -printf %P"\n" | egrep -v -e part -e scsi| head -1)
if [ -n "$BOSS_DEV" ]; then
    echo ignoredisk --only-use="$BOSS_DEV" > /tmp/bootdisk.cfg
fi
%end
```

如果要为某块物理网卡配置 IP 地址，可以根据 MAC 地址找到对应的物理网卡，然后将静态 IP 配置写入到网卡配置文件当中。比如 CentOS 在 kickstart 中为某块物理网卡配置静态 IP，可以采用如下方式：

```bash
MAC_ADDRESS 在生成 kickstart 文件的时候根据 config.yaml 动态修改的
# MAC_ADDRESS=B4:96:91:A7:3F:D6

# 根据 MAC 地址获取到网卡设备的名称
NIC=$(grep -l ${MAC_ADDRESS} /sys/class/net/*/address | awk -F'/' '{print $5}')

# 将网卡静态 IP 配置写入到文件当中
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-${NIC}
TYPE=Ehternet
BOOTPROTO=static
DEFROUTE=yes
NAME=${NIC}
DEVICE=${NIC}
ONBOOT=yes
IPADDR=${IP}
NETMASK=${NETMASK}
GATEWAY=${GATEWAY}
EOF
```

由于时间关系，在这里就不再进行深入讲解了，在这里只是提供一个方法和思路。至于 Debian/Ubuntu 发行版，还是你们自己摸索吧，因为我工作中确实没有在物理服务器上安装这些发行版的场景，毕竟国内企业私有云环境中使用 CentOS/RedHat 系列发行版的占绝大多数。

## 参考

### Redfish 相关

- [DMTF’s Redfish](https://www.dmtf.org/standards/redfish)
- [Redfish 白皮书](https://www.dmtf.org/sites/default/files/DSP2044%20Redfish%20%E7%99%BD%E7%9A%AE%E4%B9%A6%201.0.0.pdf)
- [Redfish 下一代数据中心管理标准详解和实践](https://wsgzao.github.io/post/redfish/)
- [redfish-ansible-module](https://github.com/dell/redfish-ansible-module)
- [python-redfish-lenovo](https://github.com/lenovo/python-redfish-lenovo)
- [xcc_redfish_command module](https://docs.ansible.com/ansible/latest/collections/community/general/xcc_redfish_command_module.html)
- [Lenovo XClarity Controller Redfish REST API](https://sysmgt.lenovofiles.com/help/index.jsp?topic=%2Fcom.lenovo.systems.management.xcc.doc%2Frest_api.html)
- [Installation and Upgrade Script Commands](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.upgrade.doc/GUID-61A14EBB-5CF3-43EE-87EF-DB8EC6D83698.html)
- [Redfish API implementation on HPE servers with iLO RESTful API technical white paper](https://www.hpe.com/psnow/doc/4AA6-1727ENW)
- [VirtualMediaEject should not require image_url ](https://github.com/ansible-collections/community.general/issues/3042)

### VMware ESXi 相关

- [Reducing Esxi 7 VMFSL](https://communities.vmware.com/t5/ESXi-Discussions/Reducing-Esxi-7-VMFSL/td-p/2808955)
- [Identifying disks when working with VMware ESXi (1014953)](https://kb.vmware.com/s/article/1014953)
- [PowerEdge Boot Optimized Storage Solution BOSS - Dell](https://downloads.dell.com/manuals/all-products/esuprt_solutions_int/esuprt_solutions_int_solutions_resources/servers-solution-resources_white-papers10_en-us.pdf)
- [ESXi Kickstart script to grep for correct LUN? (iSCSI, Boot from SAN)](https://www.reddit.com/r/vmware/comments/2a5jv7/esxi_kickstart_script_to_grep_for_correct_lun/)
- [Automating Operating System Deployment to Dell BOSS – Techniques for Different Operating Systems](https://www.dell.com/support/kbdoc/zh-hk/000177584/automating-operating-system-deployment-to-dell-boss-techniques-for-different-operating-systems)
