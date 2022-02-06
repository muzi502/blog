---
title: VMware Tanzu kubernetes 发行版部署尝鲜
date: 2022-02-06
updated: 2022-02-06
slug:
categories: 技术
tag:
  - ESXi
  - Tanzu
  - Kubernetes
  - Cluster-api
copyright: true
comment: true
---

之前接触的 Kubernetes 集群部署工具大多数都是依赖于 ssh 连接到待部署的节点上进行部署操作，这样就要求部署前需要提前准备好集群节点，且要保证这些节点的网络互通以及时钟同步等问题。类似于 kubespray 或者 kubekey 这些部署工具是不会去管这些底层的 IaaS 资源的创建，是要自己提前准备好。但是在一些企业私有云环境中，使用了如 [VMware vShpere](https://docs.vmware.com/cn/VMware-vSphere/index.html) 或 [OpenStack](https://www.openstack.org/) 这些虚拟化平台，是可以将 K8s 集群部署与 IaaS 资源创建这两步统一起来的，这样就可以避免手动创建和配置虚拟机这些繁琐的步骤。

目前将 IaaS 资源创建与 K8s 集群部署结合起来也有比较成熟的方案，比如基于 [cluster-api](https://github.com/kubernetes-sigs/cluster-api) 项目的 [tanzu](https://github.com/vmware-tanzu) 。本文就以 [VMware Tanzu 社区版](https://github.com/vmware-tanzu/community-edition) 为例在一台物理服务器上，从安装 ESXi OS 到部署完成 Tanzu Workload 集群，来体验一下这种部署方案的与众不同之处。

## 部署流程

- 下载依赖文件
- 安装 govc 依赖
- 安装 ESXi OS
- 安装 vCenter
- 配置 vCenter
- 创建 bootstrap 虚拟机
- 初始化 bootstrap 节点
- 部署 Tanzu Manager 集群
- 部署 Tanzu Workload 集群

### 劝退三连 😂

- 需要有一个 [VMware 的账户](https://customerconnect.vmware.com/login) 用于下载一些 ISO 镜像和虚拟机模版;

- 需要有一台物理服务器，推荐最低配置 8C 32G，至少 256GB 存储；

- 需要一台 DHCP 服务器，由于默认是使用 DHCP 获取 IP 来分配给虚拟机的，因此 ESXi 所在的 VM Network  网络中必须有一台 DHCP 服务器用于给虚拟机分配 IP；

### 下载依赖文件

整个部署流程所需要的依文件赖如下，可以先将这些依赖下载到本地的机器上，方便后续使用。

```bash
root@devbox:/root/tanzu # tree -sh
.
├── [  12M]  govc_Linux_x86_64.tar.gz
├── [ 895M]  photon-3-kube-v1.21.2+vmware.1-tkg.2-12816990095845873721.ova
├── [ 225M]  photon-ova-4.0-c001795b80.ova
├── [ 170M]  tce-linux-amd64-v0.9.1.tar.gz
├── [ 9.0G]  VMware-VCSA-all-7.0.3-18778458.iso
└── [ 390M]  VMware-VMvisor-Installer-7.0U2a-17867351.x86_64.iso
```

| 文件                                                         | 用途              | 下载方式       |
| ------------------------------------------------------------ | ----------------- | -------------- |
| [VMware-VMvisor-Installer-7.0U2a-17867351.x86_64.iso](https://customerconnect.vmware.com/downloads/details?downloadGroup=ESXI70U2A&productId=974&rPId=46384) | 安装 ESXi OS      | VMware 需账户  |
| [VMware-VCSA-all-7.0.3-19234570.iso](https://customerconnect.vmware.com/downloads/details?downloadGroup=VC70U3C&productId=974&rPId=83853) | 安装 vCenter      | VMware 需账户  |
| [photon-ova-4.0-c001795b80.ova](https://packages.vmware.com/photon/4.0/Rev2/ova/photon-ova-4.0-c001795b80.ova) | bootstrap 节点    | VMware         |
| [photon-3-kube-v1.21.2+vmware.1-tkg.2-12816990095845873721.ova](https://customerconnect.vmware.com/downloads/get-download?downloadGroup=TCE-090) | tanzu 集群节点    | VMware 需账户  |
| [tce-linux-amd64-v0.9.1.tar.gz](https://github.com/vmware-tanzu/community-edition/releases/download/v0.9.1/tce-linux-amd64-v0.9.1.tar.gz) | tanzu 社区版      | GitHub release |
| [govc_Linux_x86_64.tar.gz](https://github.com/vmware/govmomi/releases/download/v0.27.3/govc_Linux_x86_64.tar.gz) | 安装/配置 vCenter | GitHub release |

注意 ESXi 和 vCenter 的版本最好是 7.0 及以上，我只在 ESXi 7.0.2 和 vCenter 7.0.3 上测试过，其他版本可能会有些差异；另外 ESXi 的版本不建议使用最新的 7.0.3，因为有比较严重的 bug，官方也建议用户生产环境不要使用该版本了 [vSphere 7.0 Update 3 Critical Known Issues - Workarounds & Fix (86287)](https://kb.vmware.com/s/article/86287) 。

### 安装 govc 及依赖

在本地机器上安装好 govc 和 jq，这两个工具后面在配置 vCenter 的时候会用到。

- macOS

```bash
$ brew install govc jq
```

- Debian/Ubuntu

```bash
$ tar -xf govc_Linux_x86_64.tar.gz -C /usr/local/bin
$ apt install jq -y
```

- 其他 Linux 可以在 govc 和 jq 的 GitHub 上下载对应的安装文件进行安装。

### 安装 ESXi OS

ESXi OS 的安装网上有很多教程，没有太多值得讲解的地方，因此就参照一下其他大佬写的博客或者官方的安装文档 [VMware ESXi 安装和设置](https://docs.vmware.com/cn/VMware-vSphere/7.0/vsphere-esxi-701-installation-setup-guide.pdf) 来就行；需要注意一点，ESXi OS 安装时 VMFSL 分区将会占用大量的存储空间，这将会使得 ESXi OS 安装所在的磁盘最终创建出来的 datastore 比预期小很多，而且这个 VMFSL 分区在安装好之后就很难再做调整了。因此如果磁盘存储空间比较紧张，在安装 ESXi OS 之前可以考虑下如何去掉这个分区；或者和我一样将 ESXI OS 安装在了一个 16G 的 USB Dom 盘上，不过生产环境不建议采用这种方案 😂（其实个人觉着安装在 U 盘上问题不大，ESXi OS 启动之后是加载到内存中运行的，不会对 U 盘有大量的读写操作，只不过在机房中 U 盘被人不小心拔走就凉了。

- 设置 govc 环境变量

```bash
# ESXi 节点的 IP
export ESXI_IP="192.168.18.47"
# ESXi 登录的用户名，初次安装后默认为 root
export GOVC_USERNAME="root"
# 在 ESXi 安装时设置的 root 密码
export GOVC_PASSWORD="admin@2022"
# 允许不安全的 SSL 连接
export GOVC_INSECURE=true
export GOVC_URL="https://${ESXI_IP}"
export GOVC_DATASTORE=datastore1
```

- 测试 govc 是否能正常连接 ESXi 主机

```bash
Name:              localhost.local
  Path:            /ha-datacenter/host/localhost/localhost
  Manufacturer:    Dell
  Logical CPUs:    20 CPUs @ 2394MHz
  Processor type:  Intel(R) Xeon(R) Silver 4210R CPU @ 2.40GHz
  CPU usage:       579 MHz (1.2%)
  Memory:          261765MB
  Memory usage:    16457 MB (6.3%)
  Boot time:       2022-02-02 11:53:59.630124 +0000 UTC
  State:           connected
```

### 安装 vCenter

按照 VMware 官方的 vCenter 安装文档 [关于 vCenter Server 安装和设置](https://docs.vmware.com/cn/VMware-vSphere/7.0/com.vmware.vcenter.install.doc/GUID-8DC3866D-5087-40A2-8067-1361A2AF95BD.html) 来安装实在是过于繁琐，其实官方的 ISO 安装方式无非是运行一个 installer web 服务，然后在浏览器上配置好 vCenter 虚拟机的参数，再将填写的配置信息在部署 vcsa 虚拟机的时候注入到 ova 的配置参数中。

知道这个安装过程的原理之后我们也可以自己配置 vCenter 的参数信息，然后通过 govc 来部署 ova；这比使用 UI 的方式简单方便很多，最终只需要填写一个配置文件，一条命令就可以部署完成啦。

- 首先是挂载 vCenter 的 ISO，找到 vcsa ova 文件，它是 vCenter 虚拟机的模版

```bash
$ mount -o loop VMware-VCSA-all-7.0.3-18778458.iso /mnt
$ ls /mnt/vcsa/VMware-vCenter-Server-Appliance-7.0.3.00100-18778458_OVF10.ova
/mnt/vcsa/VMware-vCenter-Server-Appliance-7.0.3.00100-18778458_OVF10.ova
```

- 根据自己的环境信息修改下面安装脚本中的相关配置：

```bash
#!/usr/bin/env bash
VCSA_OVA_FILE=$1

set -o errexit
set -o nounset
set -o pipefail

# ESXi 的 IP 地址
export ESXI_IP="192.168.18.47"

# ESXi 的用户名
export GOVC_USERNAME="root"

# ESXI 的密码
export GOVC_PASSWORD="admin@2020"

# 安装 vCenter 虚拟机使用的 datastore 名称
export GOVC_DATASTORE=datastore1
export GOVC_INSECURE=true
export GOVC_URL="https://${ESXI_IP}"

# vCenter 的登录密码
VM_PASSWORD="admin@2020"
# vCenter 的 IP 地址
VM_IP=192.168.20.92
# vCenter 虚拟机的名称
VM_NAME=vCenter-Server-Appliance
# vCenter 虚拟机使用的网络
VM_NETWORK="VM Network"
# DNS 服务器
VM_DNS="223.6.6.6"
# NTP 服务器
VM_NTP="0.pool.ntp.org"

deploy_vcsa_vm(){
    config=$(govc host.info -k -json | jq -r '.HostSystems[].Config')
    gateway=$(jq -r '.Network.IpRouteConfig.DefaultGateway' <<<"$config")
    route=$(jq -r '.Network.RouteTableInfo.IpRoute[] | select(.DeviceName == "vmk0") | select(.Gateway == "0.0.0.0")' <<<"$config")
    prefix=$(jq -r '.PrefixLength' <<<"$route")
    opts=(
        cis.vmdir.password=${VM_PASSWORD}
        cis.appliance.root.passwd=${VM_PASSWORD}
        cis.appliance.root.shell=/bin/bash
        cis.deployment.node.type=embedded
        cis.vmdir.domain-name=vsphere.local
        cis.vmdir.site-name=VCSA
        cis.appliance.net.addr.family=ipv4
        cis.appliance.ssh.enabled=True
        cis.ceip_enabled=False
        cis.deployment.autoconfig=True
        cis.appliance.net.addr=${VM_IP}
        cis.appliance.net.prefix=${prefix}
        cis.appliance.net.dns.servers=${VM_DNS}
        cis.appliance.net.gateway=$gateway
        cis.appliance.ntp.servers="${VM_NTP}"
        cis.appliance.net.mode=static
    )

    props=$(printf -- "guestinfo.%s\n" "${opts[@]}" | jq --slurp -R 'split("\n") | map(select(. != "")) | map(split("=")) | map({"Key": .[0], "Value": .[1]})')

    cat <<EOF | govc import.${VCSA_OVA_FILE##*.} -options - "${VCSA_OVA_FILE}"
    {
    "Name": "${VM_NAME}",
    "Deployment": "tiny",
    "DiskProvisioning": "thin",
    "IPProtocol": "IPv4",
    "Annotation": "VMware vCenter Server Appliance",
    "PowerOn": false,
    "WaitForIP": false,
    "InjectOvfEnv": true,
    "NetworkMapping": [
        {
        "Name": "Network 1",
        "Network": "${VM_NETWORK}"
        }
    ],
    "PropertyMapping": ${props}
    }
EOF

}

deploy_vcsa_vm
govc vm.change -vm "${VM_NAME}" -g vmwarePhoton64Guest
govc vm.power -on "${VM_NAME}"
govc vm.ip -a "${VM_NAME}"
```

- 通过脚本安装 vCenter，指定第一参数为 OVA 的绝对路径。运行完后将会自动将 ova 导入到 vCenter，并启动虚拟机；

```bash
# 执行该脚本，第一个参数传入 vCenter ISO 中 vcsa ova 文件的绝对路径
$ bash install-vcsa.sh /mnt/vcsa/VMware-vCenter-Server-Appliance-7.0.3.00100-18778458_OVF10.ova

[03-02-22 18:40:19] Uploading VMware-vCenter-Server-Appliance-7.0.3.00100-18778458_OVF10-disk1.vmdk... OK
[03-02-22 18:41:09] Uploading VMware-vCenter-Server-Appliance-7.0.3.00100-18778458_OVF10-disk2.vmdk... (29%, 52.5MiB/s)
[03-02-22 18:43:08] Uploading VMware-vCenter-Server-Appliance-7.0.3.00100-18778458_OVF10-disk2.vmdk... OK
[03-02-22 18:43:08] Injecting OVF environment...
Powering on VirtualMachine:3... OK
fe80::20c:29ff:fe03:2f80
```

- 设置 vCenter 登录的环境变量，我们使用 govc 来配置 vCenter，通过浏览器 Web UI 的方式配置起来效率有点低，不如 govc 命令一把梭方便 😂

```bash
export GOVC_URL="https://192.168.20.92"
export GOVC_USERNAME="administrator@vsphere.local"
export GOVC_PASSWORD="admin@2022"
export GOVC_INSECURE=true
export GOVC_DATASTORE=datastore1
```

- 虚拟机启动后将自动进行 vCenter 的安装配置，等待一段时间 vCenter 安装好之后，使用 govc about 查看 vCenter 的信息，如果能正确或渠道说明 vCenter 就安装好了；

```bash
$ govc about
FullName:     VMware vCenter Server 7.0.3 build-18778458
Name:         VMware vCenter Server
Vendor:       VMware, Inc.
Version:      7.0.3
Build:        18778458
OS type:      linux-x64
API type:     VirtualCenter
API version:  7.0.3.0
Product ID:   vpx
UUID:         0b49e119-e38f-4fbc-84a8-d7a0e548027d
```

### 配置 vCenter

这一步骤主要是配置 vCenter：创建 Datacenter、cluster、folder 等资源，并将 ESXi 主机添加到 cluster 中；

- 配置 vCenter

```bash
# 创建 Datacenter 数据中心
$ govc datacenter.create SH-IDC
# 创建 Cluster 集群
$ govc cluster.create -dc=SH-IDC Tanzu-Cluster
# 将 ESXi 主机添加到 Cluster 当中
$ govc cluster.add -dc=SH-IDC -cluster=Tanzu-Cluster -hostname=192.168.18.47 --username=root -password='admin@2020' -noverify
# 创建 folder，用于将 Tanzu 的节点虚拟机存放到该文件夹下
$ govc folder.create /SH-IDC/vm/Tanzu-node
# 导入 tanzu 汲取节点的虚拟机 ova 模版
$ govc import.ova -dc='SH-IDC' -ds='datastore1' photon-3-kube-v1.21.2+vmware.1-tkg.2-12816990095845873721.ova
# 将虚拟机转换为模版，后续 tanzu 集群将以该模版创建虚拟机
$ govc vm.markastemplate photon-3-kube-v1.21.2
```

### 初始化 bootstrap 节点

bootstrap 节点节点是用于运行 tanzu 部署工具的节点，官方是支持 Linux/macOS/Windows 三种操作系统的，但有一些比较严格的要求：

| Arch: x86; ARM is currently unsupported                      |
| ------------------------------------------------------------ |
| RAM: 6 GB                                                    |
| CPU: 2                                                       |
| [Docker](https://docs.docker.com/engine/install/) Add your non-root user account to the docker user group. Create the group if it does not already exist. This lets the Tanzu CLI access the Docker socket, which is owned by the root user. For more information, see steps 1 to 4 in the [Manage Docker as a non-root user](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user) procedure in the Docker documentation. |
| [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) |
| Latest version of Chrome, Firefox, Safari, Internet Explorer, or Edge |
| System time is synchronized with a Network Time Protocol (NTP) server. |
| Ensure your bootstrap machine is using [cgroup v1](https://man7.org/linux/man-pages/man7/cgroups.7.html). For more information, see [Check and set the cgroup](https://tanzucommunityedition.io/docs/latest/support-matrix/#check-and-set-the-cgroup). |

在这里为了避免这些麻烦的配置，我就直接使用的 VMware 官方的 [Photon OS 4.0 Rev2](https://github.com/vmware/photon/wiki/Downloading-Photon-OS#photon-os-40-rev2-binaries) ，下载 OVA 格式的镜像直接导入到 ESXi 主机启动一台虚拟机即可，能节省不少麻烦的配置；还有一个好处就是在一台单独的虚拟机上运行 tanzu 部署工具不会污染本地的开发环境。

```bash
$ wget https://packages.vmware.com/photon/4.0/Rev2/ova/photon-ova-4.0-c001795b80.ova
# 导入 OVA 虚拟机模版
$ govc import.ova -ds='datastore1' -name bootstrap-node photon-ova-4.0-c001795b80.ova
# 修改一下虚拟机的配置，调整为 4C8G
$ govc vm.change -c 4 -m 8192 -vm bootstrap-node
# 开启虚拟机
$ govc vm.power -on bootstrap-node
# 查看虚拟机获取到的 IPv4 地址
$ govc vm.ip -a -wait 1m bootstrap-node
$ ssh root@192.168.74.10
# 密码默认为 changeme，输入完密码之后提示在输入一遍 changeme，然后再修改新的密码
root@photon-machine [ ~ ]# cat /etc/os-release
NAME="VMware Photon OS"
VERSION="4.0"
ID=photon
VERSION_ID=4.0
PRETTY_NAME="VMware Photon OS/Linux"
ANSI_COLOR="1;34"
HOME_URL="https://vmware.github.io/photon/"
BUG_REPORT_URL="https://github.com/vmware/photon/issues"
```

- 安装部署时需要的一些工具（切，Photon OS 里竟然连个 tar 命令都没有 😠

```bash
root@photon-machine [ ~ ]# tdnf install sudo tar -y
root@photon-machine [ ~ ]# curl -LO https://dl.k8s.io/release/v1.21.2/bin/linux/amd64/kubectl
root@photon-machine [ ~ ]# sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

- 启动 docker，bootstrap 节点会以 kind 的方式运行一个 K8s 集群，需要用到 docker。虽然可以使用外部的 k8s 集群，但不是很推荐，因为 cluster-api 依赖 k8s 的版本，不能太高也不能太低；

```bash
root@photon-machine [ ~ ]# systemctl enable docker --now
```

- 从 [vmware-tanzu/community-edition](https://github.com/vmware-tanzu/community-edition/releases/tag/v0.9.1) 下载 tanzu 社区版的安装包，然后解压后安装；

```bash
root@photon-machine [ ~ ]# curl -LO  https://github.com/vmware-tanzu/community-edition/releases/download/v0.9.1/tce-linux-amd64-v0.9.1.tar.gz
root@photon-machine [ ~ ]# tar -xf tce-linux-amd64-v0.9.1.tar.gz
root@photon-machine [ ~ ]# cd tce-linux-amd64-v0.9.1/
root@photon-machine [ ~ ]# bash install.sh
```

然而不幸地翻车了， install.sh 脚本中禁止 root 用户运行

```bash
+ ALLOW_INSTALL_AS_ROOT=
+ [[ 0 -eq 0 ]]
+ [[ '' != \t\r\u\e ]]
+ echo 'Do not run this script as root'
Do not run this script as root
+ exit 1
```

我就偏偏要以 root 用户来运行怎么惹 😡

![](https://p.k8s.li/2022-01-22-deploy-tanzu-k8s-cluster-01.jpg)

```bash
# sed 去掉第一个 exit 1 就可以了
root@photon-machine [ ~ ]# sed -i.bak "s/exit 1//" install.sh
root@photon-machine [ ~ ]# bash install.sh
```

安装好之后会输出 `Installation complete!`（讲真官方的 install.sh 脚本输出很不友好，污染我的 terminal

```bash
+ tanzu init
| initializing ✔  successfully initialized CLI
++ tanzu plugin repo list
++ grep tce
+ TCE_REPO=
+ [[ -z '' ]]
+ tanzu plugin repo add --name tce --gcp-bucket-name tce-tanzu-cli-plugins --gcp-root-path artifacts
++ tanzu plugin repo list
++ grep core-admin
+ TCE_REPO=
+ [[ -z '' ]]
+ tanzu plugin repo add --name core-admin --gcp-bucket-name tce-tanzu-cli-framework-admin --gcp-root-path artifacts-admin
+ echo 'Installation complete!'
Installation complete!
```

### 部署管理集群

先是部署一个 tanzu 的管理集群，有两种方式，一种是通过 [官方文档](https://tanzucommunityedition.io/docs/latest/getting-started/) 提到的通过 Web UI 的方式。目前这个 UI 界面比较拉垮，它主要是用来让用户填写一些配置参数，然后调用后台的 tanzu 命令来部署集群。并把集群部署的日志和进度展示出来；部署完成之后，这个 UI 又不能管理这些集群，又不支持部署 workload 集群（

另一种就是通过 tanzu 命令指定配置文件来部署，这种方式不需要通过浏览器在 web 页面上傻乎乎地点来点去填一些参数，只需要提前填写好一个 yaml 格式的配置文件即可。下面我们就采用 tanzu 命令来部署集群，管理集群的配置文件模版如下：

- tanzu-mgt-cluster.yaml

```yaml
# Cluster Pod IP 的 CIDR
CLUSTER_CIDR: 100.96.0.0/11
# Service 的 CIDR
SERVICE_CIDR: 100.64.0.0/13
# 集群的名称
CLUSTER_NAME: tanzu-control-plan
# 集群的类型
CLUSTER_PLAN: dev
# 集群节点的 arch
OS_ARCH: amd64
# 集群节点的 OS 名称
OS_NAME: photon
# 集群节点 OS 版本
OS_VERSION: "3"
# 基础设施资源的提供方
INFRASTRUCTURE_PROVIDER: vsphere

# 集群的 VIP
VSPHERE_CONTROL_PLANE_ENDPOINT: 192.168.75.194
# control-plan 节点的磁盘大小
VSPHERE_CONTROL_PLANE_DISK_GIB: "20"
# control-plan 节点的内存大小
VSPHERE_CONTROL_PLANE_MEM_MIB: "8192"
# control-plan 节点的 CPU 核心数量
VSPHERE_CONTROL_PLANE_NUM_CPUS: "4"
# work 节点的磁盘大小
VSPHERE_WORKER_DISK_GIB: "20"
# work 节点的内存大小
VSPHERE_WORKER_MEM_MIB: "4096"
# work 节点的 CPU 核心数量
VSPHERE_WORKER_NUM_CPUS: "2"

# vCenter 的 Datacenter 路径
VSPHERE_DATACENTER: /SH-IDC
# 虚拟机创建的 Datastore 路径
VSPHERE_DATASTORE: /SH-IDC/datastore/datastore1
# 虚拟机创建的文件夹
VSPHERE_FOLDER: /SH-IDC/vm/Tanzu-node
# 虚拟机使用的网络
VSPHERE_NETWORK: /SH-IDC/network/VM Network
# 虚拟机关联的资源池
VSPHERE_RESOURCE_POOL: /SH-IDC/host/Tanzu-Cluster/Resources

# vCenter 的 IP
VSPHERE_SERVER: 192.168.75.110
# vCenter 的用户名
VSPHERE_USERNAME: administrator@vsphere.local
# vCenter 的密码，以 base64 编码
VSPHERE_PASSWORD: <encoded:base64password>
# vCenter 的证书指纹，可以通过 govc about.cert -json | jq -r '.ThumbprintSHA1' 获取
VSPHERE_TLS_THUMBPRINT: EB:F3:D8:7A:E8:3D:1A:59:B0:DE:73:96:DC:B9:5F:13:86:EF:B6:27
# 虚拟机注入的 ssh 公钥，需要用它来 ssh 登录集群节点
VSPHERE_SSH_AUTHORIZED_KEY: ssh-rsa

# 一些默认参数
AVI_ENABLE: "false"
IDENTITY_MANAGEMENT_TYPE: none
ENABLE_AUDIT_LOGGING: "false"
ENABLE_CEIP_PARTICIPATION: "false"
TKG_HTTP_PROXY_ENABLED: "false"
DEPLOY_TKG_ON_VSPHERE7: "true"
```

- 通过 tanzu CLI 部署管理集群

```bash
$ tanzu management-cluster create --file tanzu-mgt-cluster.yaml -v6

# 如果没有配置 VSPHERE_TLS_THUMBPRINT 会有一个确认 vSphere thumbprint 的交互，输入 Y 就可以
Validating the pre-requisites...
Do you want to continue with the vSphere thumbprint EB:F3:D8:7A:E8:3D:1A:59:B0:DE:73:96:DC:B9:5F:13:86:EF:B6:27 [y/N]: y
```

### 部署日志

```bash
root@photon-machine [ ~ ]# tanzu management-cluster create --file tanzu-mgt-cluster.yaml -v 6
compatibility file (/root/.config/tanzu/tkg/compatibility/tkg-compatibility.yaml) already exists, skipping download
BOM files inside /root/.config/tanzu/tkg/bom already exists, skipping download
CEIP Opt-in status: false

Validating the pre-requisites...

vSphere 7.0 Environment Detected.

You have connected to a vSphere 7.0 environment which does not have vSphere with Tanzu enabled. vSphere with Tanzu includes
an integrated Tanzu Kubernetes Grid Service which turns a vSphere cluster into a platform for running Kubernetes workloads in dedicated
resource pools. Configuring Tanzu Kubernetes Grid Service is done through vSphere HTML5 client.

Tanzu Kubernetes Grid Service is the preferred way to consume Tanzu Kubernetes Grid in vSphere 7.0 environments. Alternatively you may
deploy a non-integrated Tanzu Kubernetes Grid instance on vSphere 7.0.
Deploying TKG management cluster on vSphere 7.0 ...
Identity Provider not configured. Some authentication features won't work.
Checking if VSPHERE_CONTROL_PLANE_ENDPOINT 192.168.20.94 is already in use

Setting up management cluster...
Validating configuration...
Using infrastructure provider vsphere:v0.7.10
Generating cluster configuration...
Setting up bootstrapper...
Fetching configuration for kind node image...
kindConfig:
 &{{Cluster kind.x-k8s.io/v1alpha4}  [{  map[] [{/var/run/docker.sock /var/run/docker.sock false false }] [] [] []}] { 0  100.96.0.0/11 100.64.0.0/13 false } map[] map[] [apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
imageRepository: projects.registry.vmware.com/tkg
etcd:
  local:
    imageRepository: projects.registry.vmware.com/tkg
    imageTag: v3.4.13_vmware.15
dns:
  type: CoreDNS
  imageRepository: projects.registry.vmware.com/tkg
  imageTag: v1.8.0_vmware.5] [] [] []}
Creating kind cluster: tkg-kind-c7vj6kds0a6sf43e6210
Creating cluster "tkg-kind-c7vj6kds0a6sf43e6210" ...
Ensuring node image (projects.registry.vmware.com/tkg/kind/node:v1.21.2_vmware.1) ...
Pulling image: projects.registry.vmware.com/tkg/kind/node:v1.21.2_vmware.1 ...
Preparing nodes ...
Writing configuration ...
Starting control-plane ...
Installing CNI ...
Installing StorageClass ...
Waiting 2m0s for control-plane = Ready ...
Ready after 19s
Bootstrapper created. Kubeconfig: /root/.kube-tkg/tmp/config_3fkzTCOL
Installing providers on bootstrapper...
Fetching providers
Installing cert-manager Version="v1.1.0"
Waiting for cert-manager to be available...
Installing Provider="cluster-api" Version="v0.3.23" TargetNamespace="capi-system"
Installing Provider="bootstrap-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-bootstrap-system"
Installing Provider="control-plane-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-control-plane-system"
Installing Provider="infrastructure-vsphere" Version="v0.7.10" TargetNamespace="capv-system"
installed  Component=="cluster-api"  Type=="CoreProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="BootstrapProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="ControlPlaneProvider"  Version=="v0.3.23"
installed  Component=="vsphere"  Type=="InfrastructureProvider"  Version=="v0.7.10"
Waiting for provider infrastructure-vsphere
Waiting for provider control-plane-kubeadm
Waiting for provider cluster-api
Waiting for provider bootstrap-kubeadm
Waiting for resource capi-kubeadm-control-plane-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
Passed waiting on provider bootstrap-kubeadm after 25.205820854s
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-webhook-system', retrying
Passed waiting on provider infrastructure-vsphere after 30.185406332s
Passed waiting on provider cluster-api after 30.213216243s
Success waiting on all providers.

Start creating management cluster...
patch cluster object with operation status:
	{
		"metadata": {
			"annotations": {
				"TKGOperationInfo" : "{\"Operation\":\"Create\",\"OperationStartTimestamp\":\"2022-02-06 02:35:34.30219421 +0000 UTC\",\"OperationTimeout\":1800}",
				"TKGOperationLastObservedTimestamp" : "2022-02-06 02:35:34.30219421 +0000 UTC"
			}
		}
	}
cluster control plane is still being initialized, retrying
Getting secret for cluster
Waiting for resource tanzu-control-plan-kubeconfig of type *v1.Secret to be up and running
Saving management cluster kubeconfig into /root/.kube/config
Installing providers on management cluster...
Fetching providers
Installing cert-manager Version="v1.1.0"
Waiting for cert-manager to be available...
Installing Provider="cluster-api" Version="v0.3.23" TargetNamespace="capi-system"
Installing Provider="bootstrap-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-bootstrap-system"
Installing Provider="control-plane-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-control-plane-system"
Installing Provider="infrastructure-vsphere" Version="v0.7.10" TargetNamespace="capv-system"
installed  Component=="cluster-api"  Type=="CoreProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="BootstrapProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="ControlPlaneProvider"  Version=="v0.3.23"
installed  Component=="vsphere"  Type=="InfrastructureProvider"  Version=="v0.7.10"
Waiting for provider control-plane-kubeadm
Waiting for provider bootstrap-kubeadm
Waiting for provider infrastructure-vsphere
Waiting for provider cluster-api
Waiting for resource capi-kubeadm-control-plane-controller-manager of type *v1.Deployment to be up and running
Passed waiting on provider control-plane-kubeadm after 10.046865402s
Waiting for resource antrea-controller of type *v1.Deployment to be up and running
Moving all Cluster API objects from bootstrap cluster to management cluster...
Performing move...
Discovering Cluster API objects
Moving Cluster API objects Clusters=1
Creating objects in the target cluster
Deleting objects from the source cluster
Waiting for additional components to be up and running...
Waiting for packages to be up and running...
Waiting for package: antrea
Waiting for package: metrics-server
Waiting for package: tanzu-addons-manager
Waiting for package: vsphere-cpi
Waiting for package: vsphere-csi
Waiting for resource antrea of type *v1alpha1.PackageInstall to be up and running
Waiting for resource vsphere-cpi of type *v1alpha1.PackageInstall to be up and running
Waiting for resource vsphere-csi of type *v1alpha1.PackageInstall to be up and running
Waiting for resource metrics-server of type *v1alpha1.PackageInstall to be up and running
Waiting for resource tanzu-addons-manager of type *v1alpha1.PackageInstall to be up and running
Successfully reconciled package: antrea
Successfully reconciled package: vsphere-csi
Successfully reconciled package: metrics-server
Context set for management cluster tanzu-control-plan as 'tanzu-control-plan-admin@tanzu-control-plan'.
Deleting kind cluster: tkg-kind-c7vj6kds0a6sf43e6210

Management cluster created!


You can now create your first workload cluster by running the following:

  tanzu cluster create [name] -f [file]


Some addons might be getting installed! Check their status by running the following:

  kubectl get apps -A
```

- 部署完成之后，将管理集群的 kubeconfig 文件复制到 kubectl 默认的目录下

```bash
root@photon-machine [ ~ ]# cp ${HOME}/.kube-tkg/config ${HOME}/.kube/config
```

- 查看集群状态信息

```bash
# 管理集群的 cluster 资源信息，管理集群的 CR 默认保存在了 tkg-system namespace 下
root@photon-machine [ ~ ]# kubectl get cluster -A
NAMESPACE    NAME                 PHASE
tkg-system   tanzu-control-plan   Provisioned
# 管理集群的 machine 资源信息
root@photon-machine [ ~ ]# kubectl get machine -A
NAMESPACE    NAME                                       PROVIDERID                                       PHASE         VERSION
tkg-system   tanzu-control-plan-control-plane-gs4bl     vsphere://4239c450-f621-d78e-3c44-4ac8890c0cd3   Running       v1.21.2+vmware.1
tkg-system   tanzu-control-plan-md-0-7cdc97c7c6-kxcnx   vsphere://4239d776-c04c-aacc-db12-3380542a6d03   Provisioned   v1.21.2+vmware.1
# 运行的组件状态
root@photon-machine [ ~ ]# kubectl get pod -A
NAMESPACE                           NAME                                                             READY   STATUS    RESTARTS   AGE
capi-kubeadm-bootstrap-system       capi-kubeadm-bootstrap-controller-manager-6494884869-wlzhx       2/2     Running   0          8m37s
capi-kubeadm-control-plane-system   capi-kubeadm-control-plane-controller-manager-857d687b9d-tpznv   2/2     Running   0          8m35s
capi-system                         capi-controller-manager-778bd4dfb9-tkvwg                         2/2     Running   0          8m41s
capi-webhook-system                 capi-controller-manager-9995bdc94-svjm2                          2/2     Running   0          8m41s
capi-webhook-system                 capi-kubeadm-bootstrap-controller-manager-68845b65f8-sllgv       2/2     Running   0          8m38s
capi-webhook-system                 capi-kubeadm-control-plane-controller-manager-9847c6747-vvz6g    2/2     Running   0          8m35s
capi-webhook-system                 capv-controller-manager-55bf67fbd5-4t46v                         2/2     Running   0          8m31s
capv-system                         capv-controller-manager-587fbf697f-bbzs9                         2/2     Running   0          8m31s
cert-manager                        cert-manager-77f6fb8fd5-8tq6n                                    1/1     Running   0          11m
cert-manager                        cert-manager-cainjector-6bd4cff7bb-6vlzx                         1/1     Running   0          11m
cert-manager                        cert-manager-webhook-fbfcb9d6c-qpkbc                             1/1     Running   0          11m
kube-system                         antrea-agent-5m9d4                                               2/2     Running   0          6m
kube-system                         antrea-agent-8mpr7                                               2/2     Running   0          5m40s
kube-system                         antrea-controller-5bbcb98667-hklss                               1/1     Running   0          5m50s
kube-system                         coredns-8dcb5c56b-ckvb7                                          1/1     Running   0          12m
kube-system                         coredns-8dcb5c56b-d98hf                                          1/1     Running   0          12m
kube-system                         etcd-tanzu-control-plan-control-plane-gs4bl                      1/1     Running   0          12m
kube-system                         kube-apiserver-tanzu-control-plan-control-plane-gs4bl            1/1     Running   0          12m
kube-system                         kube-controller-manager-tanzu-control-plan-control-plane-gs4bl   1/1     Running   0          12m
kube-system                         kube-proxy-d4wq4                                                 1/1     Running   0          12m
kube-system                         kube-proxy-nhkgg                                                 1/1     Running   0          11m
kube-system                         kube-scheduler-tanzu-control-plan-control-plane-gs4bl            1/1     Running   0          12m
kube-system                         kube-vip-tanzu-control-plan-control-plane-gs4bl                  1/1     Running   0          12m
kube-system                         metrics-server-59fcb9fcf-xjznj                                   1/1     Running   0          6m29s
kube-system                         vsphere-cloud-controller-manager-kzffm                           1/1     Running   0          5m50s
kube-system                         vsphere-csi-controller-74675c9488-q9h5c                          6/6     Running   0          6m31s
kube-system                         vsphere-csi-node-dmvvr                                           3/3     Running   0          6m31s
kube-system                         vsphere-csi-node-k6x98                                           3/3     Running   0          6m31s
tkg-system                          kapp-controller-6499b8866-xnql7                                  1/1     Running   0          10m
tkg-system                          tanzu-addons-controller-manager-657c587556-rpbjm                 1/1     Running   0          7m58s
tkg-system                          tanzu-capabilities-controller-manager-6ff97656b8-cq7m7           1/1     Running   0          11m
tkr-system                          tkr-controller-manager-6bc455b5d4-wm98s                          1/1     Running   0          10m
```

### 部署流程

结合 [tanzu 的源码](https://github.com/vmware-tanzu/tanzu-framework/blob/main/pkg/v1/tkg/client/init.go) 和部署输出的日志我们大体可以得知，tanzu 管理集群部署大致分为如下几步：

```go
// https://github.com/vmware-tanzu/tanzu-framework/blob/main/pkg/v1/tkg/client/init.go

// management cluster init step constants
const (
	StepConfigPrerequisite                 = "Configure prerequisite"
	StepValidateConfiguration              = "Validate configuration"
	StepGenerateClusterConfiguration       = "Generate cluster configuration"
	StepSetupBootstrapCluster              = "Setup bootstrap cluster"
	StepInstallProvidersOnBootstrapCluster = "Install providers on bootstrap cluster"
	StepCreateManagementCluster            = "Create management cluster"
	StepInstallProvidersOnRegionalCluster  = "Install providers on management cluster"
	StepMoveClusterAPIObjects              = "Move cluster-api objects from bootstrap cluster to management cluster"
)

// InitRegionSteps management cluster init step sequence
var InitRegionSteps = []string{
	StepConfigPrerequisite,
	StepValidateConfiguration,
	StepGenerateClusterConfiguration,
	StepSetupBootstrapCluster,
	StepInstallProvidersOnBootstrapCluster,
	StepCreateManagementCluster,
	StepInstallProvidersOnRegionalCluster,
	StepMoveClusterAPIObjects,
}
```

- ConfigPrerequisite 准备阶段，会下载 `tkg-compatibility` 和 `tkg-bom`镜像，用于检查环境的兼容性；

```bash
Downloading TKG compatibility file from 'projects.registry.vmware.com/tkg/framework-zshippable/tkg-compatibility'
Downloading the TKG Bill of Materials (BOM) file from 'projects.registry.vmware.com/tkg/tkg-bom:v1.4.0'
Downloading the TKr Bill of Materials (BOM) file from 'projects.registry.vmware.com/tkg/tkr-bom:v1.21.2_vmware.1-tkg.1'
ERROR 2022/02/06 02:24:46 svType != tvType; key=release, st=map[string]interface {}, tt=<nil>, sv=map[version:], tv=<nil>
CEIP Opt-in status: false
```

- ValidateConfiguration 配置文件校验，根据填写的参数校验配置是否正确，以及检查 vCenter 当中有无匹配的虚拟机模版；

```bash
Validating the pre-requisites...

vSphere 7.0 Environment Detected.

You have connected to a vSphere 7.0 environment which does not have vSphere with Tanzu enabled. vSphere with Tanzu includes
an integrated Tanzu Kubernetes Grid Service which turns a vSphere cluster into a platform for running Kubernetes workloads in dedicated
resource pools. Configuring Tanzu Kubernetes Grid Service is done through vSphere HTML5 client.

Tanzu Kubernetes Grid Service is the preferred way to consume Tanzu Kubernetes Grid in vSphere 7.0 environments. Alternatively you may
deploy a non-integrated Tanzu Kubernetes Grid instance on vSphere 7.0.
Deploying TKG management cluster on vSphere 7.0 ...
Identity Provider not configured. Some authentication features won't work.
Checking if VSPHERE_CONTROL_PLANE_ENDPOINT 192.168.20.94 is already in use

Setting up management cluster...
Validating configuration...
Using infrastructure provider vsphere:v0.7.10
```

- GenerateClusterConfiguration 生成集群配置文件信息；

```bash
Generating cluster configuration...
```

- SetupBootstrapCluster 设置 bootstrap 集群，目前默认为 kind。会运行一个 docker 容器，里面套娃运行着一个 k8s 集群；这个 bootstrap k8s 集群只是临时运行 cluster-api 来部署管理集群用的，部署完成之后 bootstrap 集群也就没用了，会自动删掉；

```bash
Setting up bootstrapper...
Fetching configuration for kind node image...
kindConfig:
 &{{Cluster kind.x-k8s.io/v1alpha4}  [{  map[] [{/var/run/docker.sock /var/run/docker.sock false false }] [] [] []}] { 0  100.96.0.0/11 100.64.0.0/13 false } map[] map[] [apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
imageRepository: projects.registry.vmware.com/tkg
etcd:
  local:
    imageRepository: projects.registry.vmware.com/tkg
    imageTag: v3.4.13_vmware.15
dns:
  type: CoreDNS
  imageRepository: projects.registry.vmware.com/tkg
  imageTag: v1.8.0_vmware.5] [] [] []}
Creating kind cluster: tkg-kind-c7vj6kds0a6sf43e6210
Creating cluster "tkg-kind-c7vj6kds0a6sf43e6210" ...
Ensuring node image (projects.registry.vmware.com/tkg/kind/node:v1.21.2_vmware.1) ...
Pulling image: projects.registry.vmware.com/tkg/kind/node:v1.21.2_vmware.1 ...
Preparing nodes ...
Writing configuration ...
Starting control-plane ...
Installing CNI ...
Installing StorageClass ...
Waiting 2m0s for control-plane = Ready ...
Ready after 19s
Bootstrapper created. Kubeconfig: /root/.kube-tkg/tmp/config_3fkzTCOL
```

- InstallProvidersOnBootstrapCluster 在 bootstrap 集群上安装 cluste-api 相关组件；

```bash
Installing providers on bootstrapper...
Fetching providers
# 安装 cert-manager 主要是为了生成 k8s 集群部署所依赖的那一堆证书
Installing cert-manager Version="v1.1.0"
Waiting for cert-manager to be available...
Installing Provider="cluster-api" Version="v0.3.23" TargetNamespace="capi-system"
Installing Provider="bootstrap-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-bootstrap-system"
Installing Provider="control-plane-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-control-plane-system"
Installing Provider="infrastructure-vsphere" Version="v0.7.10" TargetNamespace="capv-system"
installed  Component=="cluster-api"  Type=="CoreProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="BootstrapProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="ControlPlaneProvider"  Version=="v0.3.23"
installed  Component=="vsphere"  Type=="InfrastructureProvider"  Version=="v0.7.10"
Waiting for provider infrastructure-vsphere
Waiting for provider control-plane-kubeadm
Waiting for provider cluster-api
Waiting for provider bootstrap-kubeadm
Passed waiting on provider infrastructure-vsphere after 30.185406332s
Passed waiting on provider cluster-api after 30.213216243s
Success waiting on all providers.
```

- CreateManagementCluster 创建管理集群，这一步主要是创建虚拟机、初始化节点、运行 kubeadm 部署 k8s 集群；

```bash
Start creating management cluster...
patch cluster object with operation status:
	{
		"metadata": {
			"annotations": {
				"TKGOperationInfo" : "{\"Operation\":\"Create\",\"OperationStartTimestamp\":\"2022-02-06 02:35:34.30219421 +0000 UTC\",\"OperationTimeout\":1800}",
				"TKGOperationLastObservedTimestamp" : "2022-02-06 02:35:34.30219421 +0000 UTC"
			}
		}
	}
cluster control plane is still being initialized, retrying
Getting secret for cluster
Waiting for resource tanzu-control-plan-kubeconfig of type *v1.Secret to be up and running
Saving management cluster kubeconfig into /root/.kube/config
```

- InstallProvidersOnRegionalCluster 在管理集群上安装 cluster-api 相关组件；

```bash
Installing providers on management cluster...
Fetching providers
Installing cert-manager Version="v1.1.0"
Waiting for cert-manager to be available...
Installing Provider="cluster-api" Version="v0.3.23" TargetNamespace="capi-system"
Installing Provider="bootstrap-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-bootstrap-system"
Installing Provider="control-plane-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-control-plane-system"
Installing Provider="infrastructure-vsphere" Version="v0.7.10" TargetNamespace="capv-system"
installed  Component=="cluster-api"  Type=="CoreProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="BootstrapProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="ControlPlaneProvider"  Version=="v0.3.23"
installed  Component=="vsphere"  Type=="InfrastructureProvider"  Version=="v0.7.10"
Waiting for provider control-plane-kubeadm
Waiting for provider bootstrap-kubeadm
Waiting for provider infrastructure-vsphere
Waiting for provider cluster-api
Waiting for resource capv-controller-manager of type *v1.Deployment to be up and running
Passed waiting on provider infrastructure-vsphere after 20.091935635s
Passed waiting on provider cluster-api after 20.109419304s
Success waiting on all providers.
Waiting for the management cluster to get ready for move...
Waiting for resource tanzu-control-plan of type *v1alpha3.Cluster to be up and running
Waiting for resources type *v1alpha3.MachineDeploymentList to be up and running
Waiting for resources type *v1alpha3.MachineList to be up and running
Waiting for addons installation...
Waiting for resources type *v1alpha3.ClusterResourceSetList to be up and running
Waiting for resource antrea-controller of type *v1.Deployment to be up and running
```

- MoveClusterAPIObjects 将 bootstrap 集群上 cluster-api 相关的资源转移到管理集群上。这一步的目的是为了达到 self-hosted 自托管的功能：即管理集群自身的扩缩容也是通过 cluster-api 来完成，这样就不用再依赖先前的那个 bootstrap 集群了；

```bash
Moving all Cluster API objects from bootstrap cluster to management cluster...
Performing move...
Discovering Cluster API objects
Moving Cluster API objects Clusters=1
Creating objects in the target cluster
Deleting objects from the source cluster
Context set for management cluster tanzu-control-plan as 'tanzu-control-plan-admin@tanzu-control-plan'.
Deleting kind cluster: tkg-kind-c7vj6kds0a6sf43e6210

Management cluster created!

You can now create your first workload cluster by running the following:

  tanzu cluster create [name] -f [file]


Some addons might be getting installed! Check their status by running the following:

  kubectl get apps -A
```

部署完成后会删除 bootstrap 集群，因为 bootstrap 集群中的资源已经转移到了管理集群中，它继续存在的意义不大。

## 部署 workload 集群

上面我们只是部署好了一个 tanzu 管理集群，我们真正的工作负载并不适合运行在这个集群上，因此我们还需要再部署一个 workload 集群，类似于 k8s 集群中的 worker 节点。部署 workload 集群的时候不再依赖 bootstrap 集群，而是使用管理集群。

根据官方文档 [vSphere Workload Cluster Template](https://tanzucommunityedition.io/docs/latest/vsphere-wl-template/) 中给出的模版创建一个配置文件，然后再通过 tanzu 命令来部署即可。配置文件内容如下：

```yaml
# Cluster Pod IP 的 CIDR
CLUSTER_CIDR: 100.96.0.0/11
# Service 的 CIDR
SERVICE_CIDR: 100.64.0.0/13
# 集群的名称
CLUSTER_NAME: tanzu-workload-cluster
# 集群的类型
CLUSTER_PLAN: dev
# 集群节点的 arch
OS_ARCH: amd64
# 集群节点的 OS 名称
OS_NAME: photon
# 集群节点 OS 版本
OS_VERSION: "3"
# 基础设施资源的提供方
INFRASTRUCTURE_PROVIDER: vsphere
# cluster, machine 等自定义资源创建的 namespace
NAMESPACE: default
# CNI 选用类型，目前应该只支持 VMware 自家的 antrea
CNI: antrea

# 集群的 VIP
VSPHERE_CONTROL_PLANE_ENDPOINT: 192.168.20.95
# control-plan 节点的磁盘大小
VSPHERE_CONTROL_PLANE_DISK_GIB: "20"
# control-plan 节点的内存大小
VSPHERE_CONTROL_PLANE_MEM_MIB: "8192"
# control-plan 节点的 CPU 核心数量
VSPHERE_CONTROL_PLANE_NUM_CPUS: "4"
# work 节点的磁盘大小
VSPHERE_WORKER_DISK_GIB: "20"
# work 节点的内存大小
VSPHERE_WORKER_MEM_MIB: "4096"
# work 节点的 CPU 核心数量
VSPHERE_WORKER_NUM_CPUS: "2"

# vCenter 的 Datacenter 路径
VSPHERE_DATACENTER: /SH-IDC
# 虚拟机创建的 Datastore 路径
VSPHERE_DATASTORE: /SH-IDC/datastore/datastore1
# 虚拟机创建的文件夹
VSPHERE_FOLDER: /SH-IDC/vm/Tanzu-node
# 虚拟机使用的网络
VSPHERE_NETWORK: /SH-IDC/network/VM Network
# 虚拟机关联的资源池
VSPHERE_RESOURCE_POOL: /SH-IDC/host/Tanzu-Cluster/Resources

# vCenter 的 IP
VSPHERE_SERVER: 192.168.20.92
# vCenter 的用户名
VSPHERE_USERNAME: administrator@vsphere.local
# vCenter 的密码，以 base64 编码
VSPHERE_PASSWORD: <encoded:YWRtaW5AMjAyMA==>
# vCenter 的证书指纹，可以通过 govc about.cert -json | jq -r '.ThumbprintSHA1' 获取
VSPHERE_TLS_THUMBPRINT: CB:23:48:E8:93:34:AD:27:D8:FD:88:1C:D7:08:4B:47:9B:12:F4:E0
# 虚拟机注入的 ssh 公钥，需要用它来 ssh 登录集群节点
VSPHERE_SSH_AUTHORIZED_KEY: ssh-rsa

# 一些默认参数
AVI_ENABLE: "false"
IDENTITY_MANAGEMENT_TYPE: none
ENABLE_AUDIT_LOGGING: "false"
ENABLE_CEIP_PARTICIPATION: "false"
TKG_HTTP_PROXY_ENABLED: "false"
DEPLOY_TKG_ON_VSPHERE7: "true"
# 是否开启虚拟机健康检查
ENABLE_MHC: true
MHC_UNKNOWN_STATUS_TIMEOUT: 5m
MHC_FALSE_STATUS_TIMEOUT: 12m
# 是否部署 vsphere cis 组件
ENABLE_DEFAULT_STORAGE_CLASS: true
# 是否开启集群自动扩缩容
ENABLE_AUTOSCALER: false
```

- 通过 tanzu 命令来部署 workload 集群

```bash
root@photon-machine [ ~ ]# tanzu cluster create tanzu-workload-cluster --file tanzu-workload-cluster.yaml
Validating configuration...
Warning: Pinniped configuration not found. Skipping pinniped configuration in workload cluster. Please refer to the documentation to check if you can configure pinniped on workload cluster manually
Creating workload cluster 'tanzu-workload-cluster'...
Waiting for cluster to be initialized...
Waiting for cluster nodes to be available...
Waiting for cluster autoscaler to be available...
Unable to wait for autoscaler deployment to be ready. reason: deployments.apps "tanzu-workload-cluster-cluster-autoscaler" not found
Waiting for addons installation...
Waiting for packages to be up and running...
Workload cluster 'tanzu-workload-cluster' created
```

- 部署完成之后查看一下集群的 CR 信息

```bash
root@photon-machine [ ~ ]# kubectl get cluster
NAME                     PHASE
tanzu-workload-cluster   Provisioned
# machine 状态处于 Running 说明节点已经正常运行了
root@photon-machine [ ~ ]# kubectl get machine
NAME                                          PROVIDERID                                       PHASE     VERSION
tanzu-workload-cluster-control-plane-4tdwq    vsphere://423950ac-1c6d-e5ef-3132-77b6a53cf626   Running   v1.21.2+vmware.1
tanzu-workload-cluster-md-0-8555bbbfc-74vdg   vsphere://4239b83b-6003-d990-4555-a72ac4dec484   Running   v1.21.2+vmware.1
```

## 扩容集群

集群部署好之后，如果想对集群节点进行扩缩容，我们可以像 deployment 的一样，只需要修改一些 CR 的信息即可。cluster-api 相关组件会 watch 到这些 CR 的变化，并根据它的 spec 信息进行一系列调谐操作。如果当前集群节点数量低于所定义的节点副本数量，则会自动调用对应的 Provider 创建虚拟机，并对虚拟机进行初始化操作，将它转换为 k8s 里的一个 node 资源；

### 扩容 control-plan 节点

即扩容 master 节点，通过修改 `KubeadmControlPlane` 这个 CR 中的 `replicas` 副本数即可：

```bash
root@photon-machine [ ~ ]# kubectl scale kcp tanzu-workload-cluster-control-plane --replicas=3
# 可以看到 machine 已经处于 Provisioning 状态，说明集群节点对应的虚拟机正在创建中
root@photon-machine [ ~ ]# kubectl get machine
NAME                                          PROVIDERID                                       PHASE          VERSION
tanzu-workload-cluster-control-plane-4tdwq    vsphere://423950ac-1c6d-e5ef-3132-77b6a53cf626   Running        v1.21.2+vmware.1
tanzu-workload-cluster-control-plane-mkmd2                                                     Provisioning   v1.21.2+vmware.1
tanzu-workload-cluster-md-0-8555bbbfc-74vdg   vsphere://4239b83b-6003-d990-4555-a72ac4dec484   Running        v1.21.2+vmware.1
```

### 扩容 work 节点

扩容 worker 节点，通过修改 `MachineDeployment` 这个 CR 中的 `replicas` 副本数即可：

```bash
root@photon-machine [ ~ ]# kubectl scale md tanzu-workload-cluster-md-0 --replicas=3
root@photon-machine [ ~ ]# kubectl get machine
NAME                                          PROVIDERID                                       PHASE     VERSION
tanzu-workload-cluster-control-plane-4tdwq    vsphere://423950ac-1c6d-e5ef-3132-77b6a53cf626   Running   v1.21.2+vmware.1
tanzu-workload-cluster-control-plane-mkmd2    vsphere://4239278c-0503-f03a-08b8-df92286bcdd7   Running   v1.21.2+vmware.1
tanzu-workload-cluster-control-plane-rt5mb    vsphere://4239c882-2fe5-a394-60c0-616941a6363e   Running   v1.21.2+vmware.1
tanzu-workload-cluster-md-0-8555bbbfc-4hlqk   vsphere://42395deb-e706-8b4b-a44f-c755c222575c   Running   v1.21.2+vmware.1
tanzu-workload-cluster-md-0-8555bbbfc-74vdg   vsphere://4239b83b-6003-d990-4555-a72ac4dec484   Running   v1.21.2+vmware.1
tanzu-workload-cluster-md-0-8555bbbfc-ftmlp   vsphere://42399640-8e94-85e5-c4bd-8436d84966e0   Running   v1.21.2+vmware.1
```

## 后续

本文只是介绍了 tanzu 集群部署的大体流程，里面包含了 cluster-api 相关的概念在本文并没有做深入的分析，因为实在是太复杂了 😂，到现在我还是没太理解其中的一些原理，因此后续我再单独写一篇博客来讲解一些 cluster-api 相关的内容，到那时候在结合本文来看就容易理解很多。

## 参考

- [community-edition](https://github.com/vmware-tanzu/community-edition)
- [vmware/photon](https://github.com/vmware/photon)
- [tanzu-framework](https://github.com/vmware-tanzu/tanzu-framework/blob/main/pkg/v1/tkg/client/init.go)
- [cluster-api-provider-vsphere](https://github.com/kubernetes-sigs/cluster-api-provider-vsphere)
- [Deploying a workload cluster](https://tanzucommunityedition.io/docs/latest/workload-clusters/)
- [Examine the Management Cluster Deployment](https://tanzucommunityedition.io/docs/latest/verify-deployment/)
- [Prepare to Deploy a Management or Standalone Clusters to vSphere](https://tanzucommunityedition.io/docs/latest/vsphere/)
