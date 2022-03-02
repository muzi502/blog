---
title : Container Linux OS 从入坑到爬出来😂
date: 2019-12-31
updated:
categories: 技术
slug:
tag:
  - docker
  - 容器
  - Linux
  - kubernees
copyright: true
comment: true
---

## 更新日志

- 2019-12-31 初稿，可能完成不了，等到来年了 😂
- 2020-01-01

## 容器优化型操作系统？

### GKE 的  [Container-Optimized OS](https://cloud.google.com/container-optimized-os/docs/)

Google 家的  GKE  中的每个节点都是使用 [Container-Optimized OS](https://cloud.google.com/container-optimized-os/docs/) 来运行工作负载，不过仅仅是针对 GCE 来进行优化的，可能在 OpenStack 或者 vSphere 上运行不起来，(瞎猜 😂

> Container-Optimized OS 是适用于 [Compute Engine](https://cloud.google.com/compute) 虚拟机的操作系统映像，专为运行 Docker 容器而优化。借助 Container-Optimized OS，您可以快速、高效、安全地在  Google Cloud Platform 上启动 Docker 容器。Container-Optimized OS 由 Google  维护，基于 [Chromium OS](https://www.chromium.org/chromium-os) 开放源代码项目。

### CoreOS Container Linux

个人认为 CoreOS 的 CoreOS Container Linux 要比 Container-Optimized OS 和 Photon OS 要更加专业，尤其是针对容器来讲， CoreOS 就是专门用来运行容器的，它没有像 yum 或 apt 这样的包管理器来安装软件，在 CoreOS 中你不需要安装软件，因为所有的应用程序都要使用 docker 来打包。

> 额外提一句，CoreOS 是一个团队，现如今已经被 Red Hat® 收购了，而 Red Hat® 已经被 IBM 收购了，按照关系来讲而 CoreOS 应该是 IBM 的孙子吧 🙃。而 CoreOS Container Linux 仅仅是他们维护项目的其中一个，CoreOS 开源的项目还有：
>
> - etcd：
> - Clair:
> - dex：
> - Prometheus：
> - flannel：

在 Linux 世界里有大量的发行版可以做为服务器系统使用, 但是这些系统大多部署复杂, 更新系统更是困难重重. 这些都是 CoreOS 试图解决的问题。

#### 特点如下

- 最小化的操作系统： 占用内存很少，比典型的服务器版本 Linux 少占 40% 的内存。
- 易于升级： CoreOS 采用双系统分区（主动分区/被动分区）设计而不是采用传统的通过升级包来升级系统，这使得每次升级更加快速，可靠和易于回滚。
- 集成 Docker： CoreOS 默认集成 Docker 并作了很好的支持和优化，省去用户安装，配置，优化 Docker 的时间，极大地方便了用户。
- 易于集群化： CoreOS 本身提供了大型 Docker 容器集群的整体解决方案，通过内置的 fleet 工具在多台系统中部署容器并进行集群化管理。同时通过提供 Discovery Service，便于动态部署和管理集群，解决方案比较成熟。
- 自动化的大规模部署： CoreOS 自身提供的解决方案能够自动地大规模批量部署并操作系统，极大地减少用户工作量。
- 使用 systemd 做为系统服务管理工具，性能比较好，systemd 有现代化的日志功能，同时采用 socket 式与 D-Bus 总线式激活服务.

### Photon OS

#### 官方宣传册

PPT 做的不错呦 😂

![](https://p.k8s.li/20191231163325900.png)

![](https://p.k8s.li/20191231163400135.png)

剽窃一段 VMware 官方的[文档](https://vmware.github.io/photon/)介绍：

> Project Photon OS™ is an open source, minimal Linux container host  that is optimized for cloud-native applications, cloud platforms, and  VMware infrastructure. Photon OS 3.0 introduces ARM64 support, installer improvements and updated packages. We invite partners, customers, and  community members to collaborate on using Photon OS to run  high-performance virtual machines and containerized applications.
>
> - **Optimized for VMware vSphere®**: The Linux kernel is tuned for performance when Photon OS runs on vSphere.
> - **Support for containers**: Photon OS includes the Docker daemon and works with container orchestration frameworks, such as Mesos and Kubernetes.
> - **Efficient lifecycle management**: Photon OS is easy to manage, patch, and update.
> - **Security hardened**: The kernel and other aspects of the operating system are built with an emphasis on security.
>
> For more information, see the [datasheet](https://vmware.github.io/photon/assets/files/photon-os-datasheet.pdf).
>
> Track our progress in earning the Linux Foundation's Core Infrastructure Initiative's Best Practices Badge.

可以看出 Photon OS™ 是针对 VMware vSphere® 虚拟化平台进行内核优化的容器专用操作系统，就和 CoreOS 一样。十分适合专门用来运行容器，当作 Kubernetes 集群中的工作负载来使用。

### RancherOS

剽窃一段官方的[介绍](https://rancher.com/docs/os/v1.x/en/)：

> RancherOS is the smallest, easiest way to run Docker in production. Every process in RancherOS is a container managed by Docker. This includes system services such as `udev` and `syslog`. Because it only includes the services necessary to run Docker, RancherOS is significantly smaller than most traditional operating systems. By removing unnecessary libraries and services, requirements for security patches and other maintenance are also reduced. This is possible because, with Docker, users typically package all necessary libraries into their containers.
>
> Another way in which RancherOS is designed specifically for running Docker is that it always runs the latest version of Docker. This allows users to take advantage of the latest Docker capabilities and bug fixes.
>
> Like other minimalist Linux distributions, RancherOS boots incredibly quickly. Starting Docker containers is nearly instant, similar to starting any other process. This speed is ideal for organizations adopting microservices and autoscaling.
>
> Docker is an open-source platform designed for developers, system admins, and DevOps. It is used to build, ship, and run containers, using a simple and powerful command line interface (CLI). To get started with Docker, please visit the [Docker user guide](https://docs.docker.com/engine/userguide/).

RancherOS 是 Rancher 团队所维护的开源项目，也是对标 CoreOS 一样，专门用来运行容器，并且可以运行在生产环境（至少官方做了这么样的承诺，咱也没在生产用过，不好说。在 RancherOS 中所有的进程（包括系统所有的服务，比如 udev 和 syslog）都是用 docker 来管理，这一点要比 CoreOS 更加激进一些，而 CoreOS 还是使用传统 Linux 发行版中的 systemd 来管理系统中的服务。通过移除传统 Linux 发行版中不必要的服务和库来最小化系统，使他专注单一的功能，即运行 docker 容器。

> Everything in RancherOS is a Docker container. We accomplish this by launching two instances of Docker. One is what we call **System Docker** and is the first process on the system. All other system services, like `ntpd`, `syslog`, and `console`, are running in Docker containers. System Docker replaces traditional init systems like `systemd` and is used to launch [additional system services](https://rancher.com/docs/os/v1.x/en/installation/system-services/adding-system-services/).
>
> System Docker runs a special container called **Docker**, which is another Docker daemon responsible for managing all of the user’s containers. Any containers that you launch as a user from the console will run inside this Docker. This creates isolation from the System Docker containers and ensures that normal user commands don’t impact system services.
>
> We created this separation not only for the security benefits, but also to make sure that commands like `docker rm -f $(docker ps -qa)` don’t delete the entire OS.

`Everything in RancherOS is a Docker container.` 感觉这个要比 CoreOS 更加容器化，甚至使用 docker 取代了 systemd 来管理系统的各种服务。系统启动后运行两个 docker 服务进程，一个是系统 docker ，在此之上在运行系统服务容器，和用户层面的 docker 。不过看一下下面的这张图你就会明白。总的来讲 RancherOS 是使用 docker 来管理整个系统的服务的，包括用户层面的 docker 。

![](https://p.k8s.li/rancheroshowitworks.png)

## 安装体验

咱的虚拟化平台是 VMware vSphere ，因为硬件服务器大多数都是 Dell 的，而  Dell  是 VMware 母公司，对于我司这种传统企业来讲使用 VMware vSphere 这种用户 UI 友好的虚拟化无疑是最好的选择，哈哈 😂。其他虚拟化平台比如 OpenStack 安装步骤会有所不同。

### Container-Optimized OS

因为仅仅是针对 GCE 进行优化的系统，传统的虚拟化比如 KVM 、 ESXi 可能用不了。另外还需要拿 [Chromium OS](https://www.chromium.org/chromium-os)  的源码来编译镜像，没有现成的  ISO 或者 OVA 虚拟机模板可用，咱就不折腾了。毕竟硬件资源有限，现场编译一个 [Chromium OS](https://www.chromium.org/chromium-os)  也需要十几个小时 😥

## Photon OS

可以现成编译一个 ISO 镜像，也可以使用官方已经编译好的 ISO 镜像或者 OVA 虚拟机模板。不过也支持常见的公有云，比如 Amazon AMI 、Google GCE Image、Azure VHD。甚至还有 Raspberry Pi3 Image 树莓派 3😂

### [官方文档](https://vmware.github.io/photon/assets/files/html/3.0/photon_installation/)

官方的安装文档中都给出了各种环境的安装方式，选择自己的环境按照文档一步一步来就行，不过在此注意以下几点。

### 安装镜像

- #### [ISO](https://github.com/vmware/photon/wiki/Downloading-Photon-OS)

通用的方案，适用于各种环境，无论是虚拟机还是物理机，由于咱使用的是 VMware vSphere 虚拟化，咱就使用 OVA 格式，因为后者对 vSphere 进行了优化。对于 VMware 用户来讲最好使用 OVA 格式来进行安装。

- #### [OVA](https://github.com/vmware/photon/wiki/Downloading-Photon-OS)

> Pre-installed minimal environment, customized for VMware hypervisor  environments. These customizations include a highly sanitized and  optimized kernel to give improved boot and runtime performance for  containers and Linux applications. Since an OVA is a complete virtual  machine definition, we've made available a Photon OS OVA that has  virtual hardware version 11; this will allow for compatibility with  several versions of VMware platforms or allow for the latest and  greatest virtual hardware enhancements.

根据官方文档所描述的 OVA 虚拟机模板是针对  VMware hypervisor  虚拟化环境进行优化定制的。

- ##### 其他
- [Amazon Machine Image](https://github.com/vmware/photon/wiki/Downloading-Photon-OS)
- [Google Compute Engine image](https://github.com/vmware/photon/wiki/Downloading-Photon-OS)
- [Azure VHD](https://github.com/vmware/photon/wiki/Downloading-Photon-OS)
- [Raspberry Pi3](https://github.com/vmware/photon/wiki/Downloading-Photon-OS)

### 安装

下载好 OVA 虚拟机模板后，登录到 ESXi 或者 vCenter 中直接使用 OVA 创建虚拟机模板即可，对于 `VMware® Workstation 1x Pro`  可以直接将 OVA 导入成为虚拟机来运行。

#### 1. 导入 OVA 虚拟机模板

![](https://p.k8s.li/20191231105906355.png)

#### 2.添加 OVA 虚拟机模板

![](https://p.k8s.li/20191231110111943.png)

#### 3. 选择存储

![](https://p.k8s.li/20191231110153113.png)

#### 4. 同意许可协议

![](https://p.k8s.li/20191231110231422.png)

#### 5.部署选项

- 选择好网络
- 磁盘置备的方式：精简就是使用到的时候再对磁盘进行制令。厚置备就是创建虚拟机的时候对磁盘进行置零，性能会好一些。

![](https://p.k8s.li/20191231110339494.png)

#### 6. 即将完成

![](https://p.k8s.li/20191231110531238.png)

### 系统启动

![](https://p.k8s.li/20191231111131193.png)

初始用户名是 `root` ，密码是 `changeme` ，输入完密码之后会强制要求你更改密码，在输入一次 `changeme` 之后输入两次修改的密码即可。

登录到系统之后使用 `ip addr` 命令查看由默认的 DHCP 获取到的方式来查看 IP，然后编辑 sshd_config 配置文件允许 root 登录。不得不说 ESXi 的 Web 控制台实在是太难用了，还是 ssh 上去使用吧。

- `vi /etc/ssh/sshd_config` 把 `PermitRootLogin` 配置项修改为 `yes` 即可
- 重启 sshd 服务 `systemctl restart sshd`

### 内核

```bash
Linux  4.19.79-1.ph3-esx #1-photon SMP Tue Oct 22 23:53:27 UTC 2019 x86_64 GNU/Linux

root@photon-machine [ ~ ]# cat /etc/os-release
NAME="VMware Photon OS"
VERSION="3.0"
ID=photon
VERSION_ID=3.0
PRETTY_NAME="VMware Photon OS/Linux"
ANSI_COLOR="1;34"
HOME_URL="https://vmware.github.io/photon/"
BUG_REPORT_URL="https://github.com/vmware/photon/issues"
```

目前的内核版本是 4.19.79 ，比 CentOS 7 系那种五年前的 3.18 内核高到不知道哪里去了。不过个人认为，对于容器虚拟化这种依赖于内核特性的技术来讲还是要选择高一点的版本比较好。像 CentOS 那种五年前的 3.18 版本，那时候容器所依赖的很多内核特性在这些版本上还不够成熟。从使用来讲，或外的公有云像 GKE 、AKS、AKE 等都是使用的 4.14 内核版本以上。

4.19 版本有个小问题，就是如果 kube-proxy 使用 IPVS 的话，需要开启相应的内核模块，主要依赖的内核模块有以下

```bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
```

在 4.19 版本之后 nf_conntrack_ipv4 内核模块替换成了 nf_conntrack ，参看 [coreos/bugs#2518](https://github.com/coreos/bugs/issues/2518)

### 资源占用情况

#### 内存

- 系统初始化启动之后内存仅仅使用了 45Mi

```bash
root@photon-machine [ ~ ]# free -h
              total        used        free      shared  buff/cache   available
Mem:          2.0Gi        45Mi       1.8Gi       0.0Ki        93Mi       1.8Gi
Swap:            0B          0B          0B
```

- 启动 docker 进程之后的占用情况，也仅仅 109Mi

```bash
root@photon-machine [ ~ ]# free -h
              total        used        free      shared  buff/cache   available
Mem:          2.0Gi       109Mi       1.6Gi       0.0Ki       238Mi       1.8Gi
Swap:            0B          0B          0B
```

#### 磁盘

使用 OVA 虚拟机模板启动后的虚拟机，磁盘仅仅占用了 515MB ，确实是相当轻量化，这还是包含了 docker。

```bash
root@photon-machine [ ~ ]# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/root        16G  515M   15G   4% /
devtmpfs        998M     0  998M   0% /dev
tmpfs          1000M     0 1000M   0% /dev/shm
tmpfs          1000M  532K  999M   1% /run
tmpfs          1000M     0 1000M   0% /sys/fs/cgroup
tmpfs          1000M     0 1000M   0% /tmp
/dev/sda2        10M  2.2M  7.9M  22% /boot/efi
tmpfs           200M     0  200M   0% /run/user/0
```

#### 负载

![](https://p.k8s.li/20191231113306435.png)

### 进程和服务

```bash
● photon-machine
    State: running
     Jobs: 0 queued
   Failed: 0 units
    Since: Tue 2019-12-31 13:53:18 UTC; 11min ago
   CGroup: /
           ├─user.slice
           │ └─user-0.slice
           │   ├─session-c1.scope
           │   │ ├─363 /bin/login -p --
           │   │ └─396 -bash
           │   ├─session-c2.scope
           │   │ ├─408 sshd: root@pts/0
           │   │ ├─415 -bash
           │   │ └─560 systemctl status
           │   └─user@0.service
           │     └─init.scope
           │       ├─388 /lib/systemd/systemd --user
           │       └─389 (sd-pam)
           ├─init.scope
           │ └─1 /lib/systemd/systemd
           └─system.slice
             ├─systemd-networkd.service
             │ └─255 /lib/systemd/systemd-networkd
             ├─systemd-udevd.service
             │ └─125 /lib/systemd/systemd-udevd
             ├─vgauthd.service
             │ └─197 /usr/bin/VGAuthService -s
             ├─docker.service
             │ ├─430 /usr/bin/dockerd
             │ └─437 docker-containerd --config /var/run/docker/containerd/containerd.toml
             ├─systemd-journald.service
             │ └─100 /lib/systemd/systemd-journald
             ├─sshd.service
             │ └─361 /usr/sbin/sshd -D
             ├─vmtoolsd.service
             │ └─94 /usr/bin/vmtoolsd
             ├─systemd-resolved.service
             │ └─257 /lib/systemd/systemd-resolved
             ├─dbus.service
             │ └─198 /usr/bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
             ├─systemd-timesyncd.service
             │ └─167 /lib/systemd/systemd-timesyncd
             └─systemd-logind.service
               └─195 /lib/systemd/systemd-logind
```

### 包管理工具

Photon OS 默认的包管理工具是 tdnf ，不过也支持 yum ，两者使用方式有细微的差别，使用的也是相同的软件包源，而且对于国内用户来讲，软件包源在国外服务器上（[https://dl.bintray.com/vmware/](https://dl.bintray.com/vmware/)），速度感人，肉眼可见 KB/s 级别的速度。你懂的，操他奶奶的 GFW，尼玛死了 😡，搞网络封锁耽误这人搬砖。安装速度慢得一批，单单下载 50 MB 的软件包就下不下来，不得不用上我那台透明代理的旁路网关。

```bash
root@photon-OS [ ~ ]# tdnf upgrade

Installing:
runc                x86_64  1.0.0.rc9-1.ph3   photon-updates     10.24M 10736757
containerd          x86_64  1.2.10-1.ph3      photon-updates     76.25M 79950751
docker-engine       x86_64  18.09.9-1.ph3     photon-updates     91.29M 95721322
docker-cli          x86_64  18.09.9-1.ph3     photon-updates     72.76M 76299393

Total installed size: 250.54M 262708223

Upgrading:
sqlite-libs         x86_64  3.27.2-6.ph3      photon-updates      1.08M 1129424
python3-setuptools  noarch  3.7.5-1.ph3       photon-updates      1.61M 1692186
python3-xml         x86_64  3.7.5-1.ph3       photon-updates    333.69k 341698
python3-libs        x86_64  3.7.5-1.ph3       photon-updates     22.88M 23990697
python3             x86_64  3.7.5-1.ph3       photon-updates      2.90M 3044206
openssl             x86_64  1.0.2t-2.ph3      photon-updates      4.53M 4750710
openssh-server      x86_64  7.8p1-6.ph3       photon-updates    904.54k 926254
openssh-clients     x86_64  7.8p1-6.ph3       photon-updates      3.65M 3831266
openssh             x86_64  7.8p1-6.ph3       photon-updates        0.00b 0
linux-esx           x86_64  4.19.87-1.ph3     photon-updates     12.67M 13284780
libarchive          x86_64  3.3.3-4.ph3       photon-updates    804.34k 823648
e2fsprogs-libs      x86_64  1.44.3-4.ph3      photon-updates     74.62k 76416
e2fsprogs           x86_64  1.44.3-4.ph3      photon-updates      1.88M 1972142
docker              x86_64  18.09.9-1.ph3     photon-updates        0.00b 0
dhcp-libs           x86_64  4.3.5-7.ph3       photon-updates    264.25k 270588
dhcp-client         x86_64  4.3.5-7.ph3       photon-updates      2.52M 2642853

Total installed size:  56.05M 58776868
Is this ok [y/N]:y

Downloading:
docker-engine                           302192      1%

docker-engine                           515184      2%
docker-engine                           523376      2%
docker-engine                          4234352     15%
docker-engine                         23477360     84%

docker-engine                         23477360     84%
```

- 56.05M / 58776868B 大小的文件，下载了一上午都没搞完……气的我想掀桌子、砸键盘、摔鼠标 😑

不过可以根据官方的编译文档，把整个软件包源编译出来 ，放在本地使用，然后添加本的 yum 源码即可。

### docker 容器引擎

```ini
root@photon-machine [ ~ ]# docker info
Containers: 0
 Running: 0
 Paused: 0
 Stopped: 0
Images: 0
Server Version: 18.06.2-ce
Storage Driver: overlay2
 Backing Filesystem: extfs
 Supports d_type: true
 Native Overlay Diff: true
Logging Driver: json-file
Cgroup Driver: cgroupfs
Plugins:
 Volume: local
 Network: bridge host macvlan null overlay
 Log: awslogs fluentd gcplogs gelf journald json-file logentries splunk syslog
Swarm: inactive
Runtimes: runc
Default Runtime: runc
Init Binary: docker-init
containerd version: 468a545b9edcd5932818eb9de8e72413e616e86e
runc version: a592beb5bc4c4092b1b1bac971afed27687340c5 (expected: 69663f0bd4b60df09991c08812a60108003fa340)
init version: fec3683
Security Options:
 apparmor
 seccomp
  Profile: default
Kernel Version: 4.19.79-1.ph3-esx
Operating System: VMware Photon OS/Linux
OSType: linux
Architecture: x86_64
CPUs: 1
Total Memory: 1.951GiB
Name: photon-machine
ID: N53E:2APV:XYZX:QFPE:GGZU:7567:XBFB:M4VQ:F5HZ:XPRK:W33H:QYMI
Docker Root Dir: /var/lib/docker
Debug Mode (client): false
Debug Mode (server): false
Registry: https://index.docker.io/v1/
Labels:
Experimental: false
Insecure Registries:
 127.0.0.0/8
Live Restore Enabled: false
```

### 使用体验

总体来讲，除了安装软件速度极慢之外，使用起来和普通的 Linux 发行版无多大差别，系统资源占用比传统的 Linux 发行版要低的多。即便是运行了 docker 进程后系统内存也仅仅占用 100 Mb 左右，而磁盘占用才 500MB 算是比较轻量化的。至于性能方面，目前我还是找不到可以测试对比的方案。

较传统的 Linux 发行版，精简了大量不必要的服务和软件，甚至连 tar 命令都没有……。如果把它当作 kubenetes 工作负载 Node 节点来使用，需要注意的是，kube-proxy 依赖的一些工具并没有安装上。我使用 kubeadm 将该节点加入到集群当中的时候就提示缺少以下几个工具： `ipset socat ethtool ebtables` ，这些对于 IPVS 都是需要的。最好使用 tdnf 一并安装上，并且开启相应的 IPVS 内核模块。

```bash
tdnf install ipset socat ethtool ebtables tar -y
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
```

虽然经过了 3 个版本的更新迭代，但 Photon OS 用于生产环境还需要进行稳定性测试，它不如 CoreOS 那样已经在大规模集群中得到的实践，目前用 Photon OS 的企业我目前还未见到过。而 CoreOS

> “作为 Linux 以及开源软件的支持者，我们相信与 CoreOS  这样的开源社区创新先锋合作是非常重要的。我们希望通过这样的合作来为云平台用户带来更多、更灵活的选择。” 微软 Azure 的首席技术官 Mark Russinovich 提到， “CoreOS Linux  与高性能、大规模的微软云相结合，无疑将会促进各种应用服务的创新、以及全球团队的协作。”

> “我们已经在上千台物理机上成功部署并运行了 CoreOS  Linux。无论从操作系统的安装、升级，还是从容器的管理和应用部署上，她给我们带来了前所未有的体验！对于光音网络这种飞速发展的互联网公司来说，CoreOS 为我们平台的建设提供了有力的技术保障！在使用 CoreOS 的这两年中，我们不再去担心操作系统、Docker 以及 Kubernetes  的兼容性、版本升级以及稳定性，这使得我们可以更专注于应用、业务层上的管理和研发。”  光音网络技术负责人王鹏说，“我们的平台不仅可以跑在自己的物理机上，而且还可以轻松地部署到 AWS 及阿里云上，CoreOS  在这方面功不可没。我们现在很高兴地得知 CoreOS 将强势登陆中国市场，我们对于更好的技术支持和服务无比期待！”
>
> 此处引用 CoreOS [官网博客](https://coreos.com/blog/coreos-linux-available-in-china.html)

CoreOS 的稳定性以及生产实践已经相当成熟了，那么接下来就介绍 CoreOS 的使用体验。

## CoreOS Container Linux

CoreOS 使用用来创建一套大规模的集群环境，单独使用的意义并不大。而且对于我司的 VMware vSphere 并没有进行优化。所以就按照裸金属部署的方式来安装体验。

### [官方文档](http://coreos.com/os/docs/latest/)

#### Cloud Providers

适用于公有云

- [Amazon EC2](http://coreos.com/os/docs/latest/booting-on-ec2.html)
- [DigitalOcean](http://coreos.com/os/docs/latest/booting-on-digitalocean.html)
- [Google Compute Engine](http://coreos.com/os/docs/latest/booting-on-google-compute-engine.html)
- [Microsoft Azure](http://coreos.com/os/docs/latest/booting-on-azure.html)[QEMU](http://coreos.com/os/docs/latest/booting-with-qemu.html)

#### Bare Metal

适用于物理机

- [Using Matchbox](http://coreos.com/matchbox/)
- [Booting with iPXE](http://coreos.com/os/docs/latest/booting-with-ipxe.html)
- [Booting with PXE](http://coreos.com/os/docs/latest/booting-with-pxe.html)
- [Installing to Disk](http://coreos.com/os/docs/latest/installing-to-disk.html)
- [Booting from ISO](http://coreos.com/os/docs/latest/booting-with-iso.html)
- [Root filesystem placement](http://coreos.com/os/docs/latest/root-filesystem-placement.html)

#### Community Platforms

社区提供支持的

These [platforms and providers](http://coreos.com/os/docs/latest/community-platforms.html) offer support and documentation for running Container Linux.

- [CloudStack](http://coreos.com/os/docs/latest/booting-on-cloudstack.html)
- [Eucalyptus](http://coreos.com/os/docs/latest/booting-on-eucalyptus.html)
- [libvirt](http://coreos.com/os/docs/latest/booting-with-libvirt.html)
- [OpenStack](http://coreos.com/os/docs/latest/booting-on-openstack.html)
- [Vagrant](http://coreos.com/os/docs/latest/booting-on-vagrant.html)
- [VirtualBox](http://coreos.com/os/docs/latest/booting-on-virtualbox.html)
- [VMware](http://coreos.com/os/docs/latest/booting-on-vmware.html)

### 安装镜像 [OVA](https://stable.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova.ova)

下载下来 OVA 虚拟机模板 [OVA](https://stable.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova.ova)

### 安装

和 Photon OS 安装步骤一样，在 ESXi 上导入 OVA 虚拟机模板即可，不过需要在最后一步配置好 OS ，包括主机名、配置文件数配置文件 url、加密的配置文件等等，根据自身需求配好即可。可以参照官方[配置文件的文档](https://coreos.com/os/docs/latest/clc-examples.html) 。这一步是必须要做的，不然没有 ssh 公钥和密码你是无法登录到系统中的。

注意，官方给了两种配置文件合适，一个是 yaml 一个是 json ，不过在这里要使用

```json
{
  "ignition": {
    "config": {},
    "timeouts": {},
    "version": "2.1.0"
  },
  "networkd": {},
  "passwd": {
    "users": [
      {
        "name": "core",
        "passwordHash": "$6$43y3tkl...",
        "sshAuthorizedKeys": [
          "key1"
        ]
      }
    ]
  },
  "storage": {},
  "systemd": {}
```

- `password_hash` 可以通过 openssl 命令来生成，把生成的一整串内容填写到上面，包括后面那个点 `.`

```bash
╭─@debian ~
╰─$ openssl passwd -1
Password:
Verifying - Password:
$1$nCzW8953$un/JUMJDE2588l7Y6KkP.
```

- `ssh_authorized_keys` 通过 ssh-keygen 生成，生成的公钥填写在上面。

配置完成之后就把整个内容复制粘贴到第二个框框 `CoreOS config data` 里

#### 其他设置

![](https://p.k8s.li/20191231125441199.png)

### 系统启动

可能是 coreos config 配置文件没有配好，而导致启动后输入设置的密码提示错误 😥，僵硬，只能通过修改 grub 启动参数来跳过了。

- 1.打开 CoreOS 虚拟机电源，并打开控制台。
- 2.当 Boot Loader 提示出现的时候，按下 e 键来编辑 GRUB 菜单。选择第一个 coreos default 编辑。
- 3.添加 `coreos.autologin` 作为启动参数，并 Ctrl-x 或 F10 重启。这将使控制台跳过登录提示并直接进入用户 core 的 shell。
- ![](https://p.k8s.li/20191231133509428.png)
- 启动进入系统之后输入 `sudo passwd` 来修改 root 密码。然后切换到 root 用户下 `passwd core` 修改 core 这个用户的密码。修改之后就可以通过 ssh 登录啦 😂，比 Photon OS 要折腾一番呀。不过啊，使用 OVA 部署最好结合 could-init 来设置虚拟机的 ssh 密钥，网络，主机名等参数。

### 资源占用情况

##### 内存

```bash
core@localhost ~ $ free -h
              total        used        free      shared  buff/cache   available
Mem:          961Mi       177Mi       398Mi       199Mi       385Mi       445Mi
Swap:            0B          0B          0B

```

#### 磁盘

CoreOS 的磁盘分区和 Photon OS 略有不同

```bash
core@localhost ~ $ df -h
Filesystem       Size  Used Avail Use% Mounted on
devtmpfs         460M     0  460M   0% /dev
tmpfs            481M     0  481M   0% /dev/shm
tmpfs            481M  484K  481M   1% /run
tmpfs            481M     0  481M   0% /sys/fs/cgroup
/dev/sda9        6.0G   60M  5.6G   2% /
/dev/mapper/usr  985M  854M   80M  92% /usr
none             481M  200M  282M  42% /run/torcx/unpack
tmpfs            481M     0  481M   0% /media
tmpfs            481M     0  481M   0% /tmp
/dev/sda6        108M  7.9M   92M   8% /usr/share/oem
/dev/sda1        127M   54M   73M  43% /boot
tmpfs             97M     0   97M   0% /run/user/500
```

### 内核以及发行版信息

```bash
Linux localhost 4.19.86-coreos #1 SMP Mon Dec 2 20:13:38 -00 2019 x86_64 Intel(R) Core(TM) i5-4590 CPU @ 3.30GHz GenuineIntel GNU/Linux

core@localhost ~ $ cat /etc/os-release
NAME="Container Linux by CoreOS"
ID=coreos
VERSION=2303.3.0
VERSION_ID=2303.3.0
BUILD_ID=2019-12-02-2049
PRETTY_NAME="Container Linux by CoreOS 2303.3.0 (Rhyolite)"
ANSI_COLOR="38;5;75"
HOME_URL="https://coreos.com/"
BUG_REPORT_URL="https://issues.coreos.com"
COREOS_BOARD="amd64-usr"
```

### docker 容器引擎

```ini
core@localhost ~ $ docker info
Containers: 0
 Running: 0
 Paused: 0
 Stopped: 0
Images: 0
Server Version: 18.06.3-ce
Storage Driver: overlay2
 Backing Filesystem: extfs
 Supports d_type: true
 Native Overlay Diff: true
Logging Driver: json-file
Cgroup Driver: cgroupfs
Plugins:
 Volume: local
 Network: bridge host macvlan null overlay
 Log: awslogs fluentd gcplogs gelf journald json-file logentries splunk syslog
Swarm: inactive
Runtimes: runc
Default Runtime: runc
Init Binary: docker-init
containerd version: 468a545b9edcd5932818eb9de8e72413e616e86e
runc version: a592beb5bc4c4092b1b1bac971afed27687340c5
init version: fec3683b971d9c3ef73f284f176672c44b448662
Security Options:
 seccomp
  Profile: default
 selinux
Kernel Version: 4.19.86-coreos
Operating System: Container Linux by CoreOS 2303.3.0 (Rhyolite)
OSType: linux
Architecture: x86_64
CPUs: 2
Total Memory: 961.7MiB
Name: localhost
ID: VUKA:LDLW:WECP:IZKO:A6ED:IKIN:6C3V:VRIL:S4ND:SCII:66EH:GDYP
Docker Root Dir: /var/lib/docker
Debug Mode (client): false
Debug Mode (server): false
Registry: https://index.docker.io/v1/
Labels:
Experimental: false
Insecure Registries:
 127.0.0.0/8
Live Restore Enabled: false
```

### 负载

![](https://p.k8s.li/20191231135348120.png)

### 进程和服务

```bash
● localhost
    State: running
     Jobs: 0 queued
   Failed: 0 units
    Since: Tue 2019-12-31 13:38:05 UTC; 7h left
   CGroup: /
           ├─user.slice
           │ └─user-500.slice
           │   ├─user@500.service
           │   │ └─init.scope
           │   │   ├─725 /usr/lib/systemd/systemd --user
           │   │   └─726 (sd-pam)
           │   ├─session-2.scope
           │   │ ├─768 sshd: core [priv]
           │   │ ├─781 sshd: core@pts/0
           │   │ ├─782 -bash
           │   │ └─978 systemctl status
           │   └─session-1.scope
           │     ├─713 /bin/login -f
           │     ├─731 -bash
           │     ├─762 su
           │     ├─763 bash
           │     ├─770 su core
           │     ├─771 bash
           │     ├─775 su
           │     └─776 bash
           ├─init.scope
           │ └─1 /usr/lib/systemd/systemd --switched-root --system --deserialize 16
           └─system.slice
             ├─locksmithd.service
             │ └─718 /usr/lib/locksmith/locksmithd
             ├─containerd.service
             │ └─800 /run/torcx/bin/containerd --config /run/torcx/unpack/docker/usr/share/containerd/config.toml
             ├─systemd-networkd.service
             │ └─584 /usr/lib/systemd/systemd-networkd
             ├─systemd-udevd.service
             │ └─583 /usr/lib/systemd/systemd-udevd
             ├─docker.service
             │ └─802 /run/torcx/bin/dockerd --host=fd:// --containerd=/var/run/docker/libcontainerd/docker-containerd.sock --selinux-enabled=true
             ├─update-engine.service
             │ └─663 /usr/sbin/update_engine -foreground -logtostderr
             ├─systemd-journald.service
             │ └─553 /usr/lib/systemd/systemd-journald
             ├─systemd-resolved.service
             │ └─635 /usr/lib/systemd/systemd-resolved
             ├─dbus.service
             │ └─674 /usr/bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation
             ├─systemd-timesyncd.service
             │ └─634 /usr/lib/systemd/systemd-timesyncd
             └─systemd-logind.service
               └─672 /usr/lib/systemd/systemd-logind
```

### 包管理工具

**没得 😂**，你没看错，确实如此，在 CoreOS 上没有你可以用的包管理器，不像 PhotonOS 那样有个 tdnf/yum 让你爽一把 😂。在 CoreOS 一切皆容器。可以看一下 `stackexchange.com` 这个答案 😂：

> To do this on a CoreOS box, following the hints from the [guide here](https://coreos.com/os/docs/latest/install-debugging-tools.html):
>
> 1. Boot up the CoreOS box and connect as the `core` user
> 2. Run the `/bin/toolbox` command to enter the stock Fedora container.
> 3. Install any software you need. To install nano in this case, it would be as simple as doing a `dnf -y install nano` (dnf has replaced yum)
> 4. Use nano to edit files. "But wait -- I'm in a container!" Don't worry -- the host's file system is mounted at `/media/root` when inside the container. So just save a sample text file at `/media/root/home/core/test.txt`, then `exit` the container, and finally go list the files in `/home/core`. Notice your test.txt file?
>
> If any part of this is too cryptic or confusing, please ask follow up questions. :-)

官方推荐使用 [coreos](https://github.com/coreos)/**[toolbox](https://github.com/coreos/toolbox)** 来安装所需要的软件，这个工具以后再详细讲解一下吧。

### 使用体验

安装过程要出于安全考虑比 Photon OS 多于个步骤来登录到系统，目前我还没有找到启动的时候添加 ssh 密钥的办法。总的来讲，再 CoreOS 里一切皆容器运行所需要的服务，这种里面要先进的多。下面的 RancherOS 更是将一切皆容器贯彻到底，甚至将 systemd 取代掉，使用 docker 来管理系统服务。

## RancherOS

目前 RancherOS 的版本是 v1.5.5

```ini
Linux 4.14.138
Buildroot: 2018.02.11
Docker docker-19.03.5 by default
RPi64: Linux 4.14.114
Console:
Alpine: 3.10
CentOS: 7.7.1908
Debian: stretch
Fedora: 31
Ubuntu: bionic
```

### [官方文档](https://rancher.com/docs/os/v1.x/en/)

[安装文档](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/)

#### Cloud 云平台

[Amazon EC2](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/cloud/aws)

[Google Compute Engine](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/cloud/gce)

[DigitalOcean](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/cloud/do)

[Azure](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/cloud/azure)

[OpenStack](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/cloud/openstack)

[VMware ESXi](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/cloud/vmware-esxi)

[Aliyun](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/cloud/aliyun)

#### Bare Metal & Virtual Servers 裸金属

[PXE](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/server/pxe)

[Install to Hard Disk](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/server/install-to-disk)

[Raspberry Pi](https://rancher.com/docs/os/v1.x/en/installation/running-rancheros/server/raspberry-pi)

### [安装镜像](https://github.com/rancher/os/releases/)

RancherOS 将各个平台的安装镜像都放在了 GitHub [release](https://github.com/rancher/os/releases/) 页面上。对于 VMware 用户就使用 [rancheros-vmware.iso](https://github.com/rancher/os/releases/download/v1.5.5/rancheros-vmware.iso) 这个镜像即可。没得 OVA 虚拟机模板只能手动搓一个啦。下载完成之后将这个镜像上传到 vSphere 的数据存储中，按照创建常规虚拟机的方式来创建虚拟机。

### 安装

![](https://p.k8s.li/20191231142454934.png)

使用 ISO 启动之后进入得是一个 liveCD 型得系统，并没有安装虚拟机得磁盘当中，我们需要将 RancherOS 安装到磁盘上。提前准备好 cloud-init 的配置文件，只需要执行 `ros install -c cloud-config.yml -d /dev/sda` 命令就行啦。-d 参数后面跟着安装到的磁盘。

不过需要像 CoreOS 那样准备给一个 `cloud-config.yml` 配置文件，将我们得 ssh 公钥和用户密码填写到里面，不过 `cloud-config` 能配置得选项非常多，在此就不赘述了，等抽空专门写一篇博客来讲讲 cloud-init 的使用。（又挖坑 😂，不知何时能填上 🙃

```bash
[root@rancher rancher]# ros install -c cloud-config.yml -d /dev/sda
INFO[0000] No install type specified...defaulting to generic
Installing from rancher/os:v1.5.5
Continue [y/N]: y
INFO[0002] start !isoinstallerloaded
INFO[0002] trying to load /bootiso/rancheros/installer.tar.gz
69b8396f5d61: Loading layer [==================================================>]  11.89MB/11.89MB
cae31a9aae74: Loading layer [==================================================>]  1.645MB/1.645MB
78885fd6d98c: Loading layer [==================================================>]  1.536kB/1.536kB
51228f31b9ce: Loading layer [==================================================>]   2.56kB/2.56kB
d8162179e708: Loading layer [==================================================>]   2.56kB/2.56kB
3ee208751cd2: Loading layer [==================================================>]  3.072kB/3.072kB
Loaded image: rancher/os-installer:latest
INFO[0002] Loaded images from /bootiso/rancheros/installer.tar.gz
INFO[0002] starting installer container for rancher/os-installer:latest (new)
Installing from rancher/os-installer:latest
mke2fs 1.45.2 (27-May-2019)
64-bit filesystem support is not enabled.  The larger fields afforded by this feature enable full-strength checksumming.  Pass -O 64bit to rectify.
Creating filesystem with 7863808 4k blocks and 7864320 inodes
Filesystem UUID: fe29cb27-b4ac-4c75-a12d-895ea7e52af9
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208,
        4096000

Allocating group tables: done
Writing inode tables: done
Creating journal (32768 blocks): done
Writing superblocks and filesystem accounting information: done

Continue with reboot [y/N]:y
INFO[0288] Rebooting
INFO[0288] Setting reboot timeout to 60 (rancher.shutdown_timeout set to 60)
....^[            ] reboot:info: Setting reboot timeout to 60 (rancher.shutdown_timeout set to 60)
.=.[            ] reboot:info: Stopping /docker : 3d39a73e4089
...........M..........[            ] reboot:info: Stopping /open-vm-tools : ccd97f8a7775
:.[            ] reboot:info: Stopping /ntp : acf47c78a711
.>.[            ] reboot:info: Stopping /network : 08be8ef68e27
..<..[            ] reboot:info: Stopping /udev : 4986cd58a227
.=.[            ] reboot:info: Stopping /syslog : 254137c5e66a
.<.[            ] reboot:info: Stopping /acpid : a2ededff859c
..C..[            ] reboot:info: Stopping /system-cron : 899028a78e3a
..H.[            ] reboot:info: Console Stopping [/console] : 6fc9ef66b43c
Connection to 10.20.172.119 closed by remote host.
Connection to 10.20.172.119 closed.

```

### 内核以及发行版信息

```bash
[root@rancher rancher]# uname -a
Linux rancher 4.14.138-rancher #1 SMP Sat Aug 10 11:25:46 UTC 2019 x86_64 GNU/Linux
[root@rancher rancher]# cat /etc/os-release
NAME="RancherOS"
VERSION=v1.5.5
ID=rancheros
ID_LIKE=
VERSION_ID=v1.5.5
PRETTY_NAME="RancherOS v1.5.5"
HOME_URL="http://rancher.com/rancher-os/"
SUPPORT_URL="https://forums.rancher.com/c/rancher-os"
BUG_REPORT_URL="https://github.com/rancher/os/issues"
BUILD_ID=
```

### docker 容器引擎

在 RancherOS 中有两套 docker ，一套是用来容器化运行系统服务的，包括用户空间的 docker ，而另一套 docker 就是用户空间的 docker

```ini
[root@rancher rancher]# docker info
Client:
 Debug Mode: false

Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 19.03.5
 Storage Driver: overlay2
  Backing Filesystem: tmpfs
  Supports d_type: true
  Native Overlay Diff: true
 Logging Driver: json-file
 Cgroup Driver: cgroupfs
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local logentries splunk syslog
 Swarm: inactive
 Runtimes: runc
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: b34a5c8af56e510852c35414db4c1f4fa6172339
 runc version: 3e425f80a8c931f88e6d94a8c831b9d5aa481657
 init version: fec3683
 Security Options:
  seccomp
   Profile: default
 Kernel Version: 4.14.138-rancher
 Operating System: RancherOS v1.5.5
 OSType: linux
 Architecture: x86_64
 CPUs: 4
 Total Memory: 3.855GiB
 Name: rancher
 ID: 2256:3I2G:WFHC:ZRTL:CKG6:GXD6:3RDL:645J:CD4J:GKJ7:55SG:U32I
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false
 Product License: Community Engine
```

### rancher 引擎

```bash
[root@rancher rancher]# du -sh /var/lib/rancher/engine/*
116.0K  /var/lib/rancher/engine/completion
33.0M   /var/lib/rancher/engine/containerd
5.8M    /var/lib/rancher/engine/containerd-shim
18.0M   /var/lib/rancher/engine/ctr
62.6M   /var/lib/rancher/engine/docker
748.0K  /var/lib/rancher/engine/docker-init
2.7M    /var/lib/rancher/engine/docker-proxy
68.8M   /var/lib/rancher/engine/dockerd
8.3M    /var/lib/rancher/engine/runc
```

### 资源占用

#### 负载

- 可以看出 RancherOS 运行着大量的 `system-docker-containerd-shim` 这是因为它将系服务也都容器化来运行，但奇怪的是无法使用 docker 命令来管理这些服务。

![](https://p.k8s.li/20191231143958024.png)

#### 内存

- 初始化启动后内存使用了 1224MB😂，要比 CoreOS 和 Photon OS 加起来还多 😂

```bash
[rancher@rancher ~]$ free -m
             total       used       free     shared    buffers     cached
Mem:          3947       1224       2722        993          0        993
-/+ buffers/cache:        231       3715
Swap:            0          0          0
```

#### 磁盘

由于系统服务是以容器的方式来运行的，而容器内的进程要访问系统文件系统的话就要将这些文件挂载到容器里去，所以会出现这么多的分区情况，不过绝大多数都是容器挂载的数据卷。

```bash
[root@rancher rancher]# df -h
Filesystem                Size      Used Available Use% Mounted on
overlay                  28.0G      1.0G     25.5G   4% /
tmpfs                     1.9G         0      1.9G   0% /dev
tmpfs                     1.9G         0      1.9G   0% /sys/fs/cgroup
/dev/sda1                28.0G      1.0G     25.5G   4% /media
/dev/sda1                28.0G      1.0G     25.5G   4% /opt
none                      1.9G    944.0K      1.9G   0% /run
/dev/sda1                28.0G      1.0G     25.5G   4% /mnt
/dev/sda1                28.0G      1.0G     25.5G   4% /home
/dev/sda1                28.0G      1.0G     25.5G   4% /etc/resolv.conf
/dev/sda1                28.0G      1.0G     25.5G   4% /etc/logrotate.d
/dev/sda1                28.0G      1.0G     25.5G   4% /usr/lib/firmware
/dev/sda1                28.0G      1.0G     25.5G   4% /usr/sbin/iptables
/dev/sda1                28.0G      1.0G     25.5G   4% /etc/docker
none                      1.9G    944.0K      1.9G   0% /var/run
/dev/sda1                28.0G      1.0G     25.5G   4% /var/log
devtmpfs                  1.9G         0      1.9G   0% /host/dev
shm                      64.0M         0     64.0M   0% /host/dev/shm
/dev/sda1                28.0G      1.0G     25.5G   4% /etc/selinux
/dev/sda1                28.0G      1.0G     25.5G   4% /etc/hosts
/dev/sda1                28.0G      1.0G     25.5G   4% /usr/lib/modules
/dev/sda1                28.0G      1.0G     25.5G   4% /etc/hostname
shm                      64.0M         0     64.0M   0% /dev/shm
/dev/sda1                28.0G      1.0G     25.5G   4% /usr/bin/system-docker
/dev/sda1                28.0G      1.0G     25.5G   4% /var/lib/boot2docker
/dev/sda1                28.0G      1.0G     25.5G   4% /usr/share/ros
/dev/sda1                28.0G      1.0G     25.5G   4% /var/lib/m-user-docker
/dev/sda1                28.0G      1.0G     25.5G   4% /var/lib/waagent
/dev/sda1                28.0G      1.0G     25.5G   4% /var/lib/docker
/dev/sda1                28.0G      1.0G     25.5G   4% /var/lib/kubelet
/dev/sda1                28.0G      1.0G     25.5G   4% /var/lib/rancher
/dev/sda1                28.0G      1.0G     25.5G   4% /usr/bin/ros
/dev/sda1                28.0G      1.0G     25.5G   4% /usr/bin/system-docker-runc
/dev/sda1                28.0G      1.0G     25.5G   4% /etc/ssl/certs/ca-certificates.crt.rancher
/dev/sda1                28.0G      1.0G     25.5G   4% /var/lib/rancher/cache
/dev/sda1                28.0G      1.0G     25.5G   4% /var/lib/rancher/conf
devtmpfs                  1.9G         0      1.9G   0% /dev
shm                      64.0M         0     64.0M   0% /dev/shm
```

#### 文件系统

````bash
[root@rancher rancher]# mount
overlay on / type overlay (rw,relatime,lowerdir=/var/lib/system-docker/overlay2/l/TBWLXSEPWSCBGMNSU37HJXNRO3:/var/lib/system-docker/overlay2/l/DWK2WF5FKFYZTH74WUBGHTRF4V:/var/lib/system-docker/overlay2/l/HDUW6LV2DFEIJPW3IA33YTCNWX:/var/lib/system-docker/overlay2/l/ZDK3KMGDSN5O33AR6XJJF27NFO:/var/lib/system-docker/overlay2/l/TSWFV744M2LUOSPV2N6QHON4NP:/var/lib/system-docker/overlay2/l/QZ3U27554L5LKMJDYP3DC356L7:/var/lib/system-docker/overlay2/l/D6LSXZS2UGAZ7NMKQJKMQVT24P:/var/lib/system-docker/overlay2/l/KHB3OKMEQIL2P34QMHYF3HWTLT,upperdir=/var/lib/system-docker/overlay2/fc79b6b6cf5c6d0b34b5abb95a1a19d765c1a00d66d0cff1ef3778d109471522/diff,workdir=/var/lib/system-docker/overlay2/fc79b6b6cf5c6d0b34b5abb95a1a19d765c1a00d66d0cff1ef3778d109471522/work)
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
tmpfs on /dev type tmpfs (rw,nosuid,mode=755)
devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=666)
sysfs on /sys type sysfs (rw,nosuid,nodev,noexec,relatime)
tmpfs on /sys/fs/cgroup type tmpfs (rw,nosuid,nodev,noexec,relatime,mode=755)
none on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
none on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,devices)
none on /sys/fs/cgroup/net_cls,net_prio type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls,net_prio)
none on /sys/fs/cgroup/perf_event type cgroup (rw,nosuid,nodev,noexec,relatime,perf_event)
none on /sys/fs/cgroup/hugetlb type cgroup (rw,nosuid,nodev,noexec,relatime,hugetlb)
none on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
none on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
none on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
none on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
none on /sys/fs/cgroup/pids type cgroup (rw,nosuid,nodev,noexec,relatime,pids)
mqueue on /dev/mqueue type mqueue (rw,nosuid,nodev,noexec,relatime)
/dev/sda1 on /media type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /opt type ext4 (rw,relatime,data=ordered)
none on /run type tmpfs (rw,relatime)
nsfs on /run/docker/netns/default type nsfs (rw)
nsfs on /run/system-docker/netns/default type nsfs (rw)
nsfs on /run/system-docker/netns/d15f3e062bb6 type nsfs (rw)
/dev/sda1 on /mnt type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /home type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /etc/resolv.conf type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /etc/logrotate.d type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /usr/lib/firmware type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /usr/sbin/iptables type ext4 (ro,relatime,data=ordered)
/dev/sda1 on /etc/docker type ext4 (rw,relatime,data=ordered)
none on /var/run type tmpfs (rw,relatime)
nsfs on /var/run/docker/netns/default type nsfs (rw)
nsfs on /var/run/system-docker/netns/default type nsfs (rw)
nsfs on /var/run/system-docker/netns/d15f3e062bb6 type nsfs (rw)
/dev/sda1 on /var/log type ext4 (rw,relatime,data=ordered)
devtmpfs on /host/dev type devtmpfs (rw,relatime,size=1949420k,nr_inodes=487355,mode=755)
none on /host/dev/pts type devpts (rw,relatime,mode=600,ptmxmode=000)
shm on /host/dev/shm type tmpfs (rw,nosuid,nodev,noexec,relatime,size=65536k)
mqueue on /host/dev/mqueue type mqueue (rw,nosuid,nodev,noexec,relatime)
/dev/sda1 on /etc/selinux type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /etc/hosts type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /usr/lib/modules type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /etc/hostname type ext4 (rw,relatime,data=ordered)
shm on /dev/shm type tmpfs (rw,nosuid,nodev,noexec,relatime,size=65536k)
/dev/sda1 on /usr/bin/system-docker type ext4 (ro,relatime,data=ordered)
/dev/sda1 on /var/lib/boot2docker type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /usr/share/ros type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /var/lib/m-user-docker type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /var/lib/waagent type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /var/lib/docker type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /var/lib/kubelet type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /var/lib/rancher type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /usr/bin/ros type ext4 (ro,relatime,data=ordered)
/dev/sda1 on /usr/bin/system-docker-runc type ext4 (ro,relatime,data=ordered)
/dev/sda1 on /etc/ssl/certs/ca-certificates.crt.rancher type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /var/lib/rancher/cache type ext4 (rw,relatime,data=ordered)
/dev/sda1 on /var/lib/rancher/conf type ext4 (rw,relatime,data=ordered)
devtmpfs on /dev type devtmpfs (rw,relatime,size=1949420k,nr_inodes=487355,mode=755)
none on /dev/pts type devpts (rw,relatime,mode=600,ptmxmode=000)
shm on /dev/shm type tmpfs (rw,nosuid,nodev,noexec,relatime,size=65536k)
mqueue on /dev/mqueue type mqueue (rw,nosuid,nodev,noexec,relatime)
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,relatime,name=systemd)
none on /sys/fs/selinux type selinuxfs (ro,relatime)
````

### 系统服务容器化

通过 top 命令和 ps 命令查看系统运行的进程可以发现以下几个重要的进程

#### top

```bash
 PID  PPID USER     STAT   VSZ %VSZ %CPU COMMAND
 1695  1620 root     S     558m  14%   0% containerd --config /var/run/docker/containerd/containerd.toml --log-level info
 1988  1922 root     S    11420   0%   0% top
    1     0 root     S    1287m  32%   0% system-dockerd --storage-driver overlay2 --graph /var/lib/system-docker --config-file /etc/docker/system-docker.json --restart=false --group root --userland-proxy=false --bip 172.18.42.1/16 --log-opt max-file=2 --log-opt max-size
  489     1 root     S     833m  21%   0% system-docker-containerd -l unix:///var/run/system-docker/libcontainerd/system-docker-containerd.sock --metrics-interval=0 --start-timeout 2m --state-dir /var/run/system-docker/libcontainerd/containerd --shim system-docker-contai
 1370  1353 root     S     808m  20%   0% respawn -f /etc/respawn.conf
 1620  1415 root     S     658m  16%   0% dockerd --group docker --host unix:///var/run/docker.sock --log-opt max-file=2 --log-opt max-size=25m
 1398   489 root     S     472m  12%   0% system-docker-containerd-shim 3d39a73e4089dcbdd144277adb398d3e0d8ba62812a699be7cfeac9598539f6e /var/run/system-docker/libcontainerd/3d39a73e4089dcbdd144277adb398d3e0d8ba62812a699be7cfeac9598539f6e system-docker-runc
 1285   489 root     S     470m  12%   0% system-docker-containerd-shim 254137c5e66a7075c2104cca82fa2e6584509170688064fac1147fbfcda2f5c0 /var/run/system-docker/libcontainerd/254137c5e66a7075c2104cca82fa2e6584509170688064fac1147fbfcda2f5c0 system-docker-runc
 1588  1370 root     S     452m  11%   0% /usr/bin/autologin rancher:tty1
 1013   995 root     S     452m  11%   0% netconf
 1151   489 root     S     406m  10%   0% system-docker-containerd-shim ccd97f8a77756dcc4ae21c935dcaf35aa8f02399e9ca87811a5f4ec1d5d6d1a3 /var/run/system-docker/libcontainerd/ccd97f8a77756dcc4ae21c935dcaf35aa8f02399e9ca87811a5f4ec1d5d6d1a3 system-docker-runc
  995   489 root     S     398m  10%   0% system-docker-containerd-shim 08be8ef68e27d7e3b8f9d2a62914f9b581545ed96d65a751b487e7814f2bc795 /var/run/system-docker/libcontainerd/08be8ef68e27d7e3b8f9d2a62914f9b581545ed96d65a751b487e7814f2bc795 system-docker-runc
  784   489 root     S     335m   8%   0% system-docker-containerd-shim 899028a78e3a3baa42ad1e3042d49f23e9fe2d6cce8b824850aaca4270d681fd /var/run/system-docker/libcontainerd/899028a78e3a3baa42ad1e3042d49f23e9fe2d6cce8b824850aaca4270d681fd system-docker-runc
  803   489 root     S     335m   8%   0% system-docker-containerd-shim a2ededff859cc3d7c1a6342eb5d92606d4da605433d03abc92cc5f6503d53c6f /var/run/system-docker/libcontainerd/a2ededff859cc3d7c1a6342eb5d92606d4da605433d03abc92cc5f6503d53c6f system-docker-runc
 1076   489 root     S     334m   8%   0% system-docker-containerd-shim acf47c78a71194f1ef094302846855c777ef84fe613eb1ac1cc5f7ac868d618c /var/run/system-docker/libcontainerd/acf47c78a71194f1ef094302846855c777ef84fe613eb1ac1cc5f7ac868d618c system-docker-runc
  956   489 root     S     280m   7%   0% system-docker-containerd-shim 4986cd58a227547af8e4867da067cf9f066062536268bf025466f88b4b38d9c3 /var/run/system-docker/libcontainerd/4986cd58a227547af8e4867da067cf9f066062536268bf025466f88b4b38d9c3 system-docker-runc
 1353   489 root     S     270m   7%   0% system-docker-containerd-shim 6fc9ef66b43c9902e23cea7cfdd78b8b5842df2b981d8d7899eacb3b063294fd /var/run/system-docker/libcontainerd/6fc9ef66b43c9902e23cea7cfdd78b8b5842df2b981d8d7899eacb3b063294fd system-docker-runc
 1311  1285 root     S     238m   6%   0% rsyslogd -n
 1168  1151 root     S     146m   4%   0% /usr/bin/vmtoolsd
 1415  1398 root     S     122m   3%   0% system-docker-runc exec -- 6fc9ef66b43c9902e23cea7cfdd78b8b5842df2b981d8d7899eacb3b063294fd env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOSTNAME=rancher HOME=/ ros docker-init --group docker --host unix:
  907   784 root     S     109m   3%   0% container-crontab
 1105  1076 root     S    94084   2%   0% ntpd --nofork -g
  973   956 root     S    22544   1%   0% udevd
 1890  1888 rancher  S    22448   1%   0% sshd: rancher@pts/0
 1586  1370 root     S    22096   1%   0% /usr/sbin/sshd -D
 1888  1586 root     S    22096   1%   0% sshd: rancher [priv]
 1989  1586 root     S    22096   1%   0% sshd: rancher [priv]
 1991  1989 rancher  S    22096   1%   0% sshd: rancher@pts/1
 1922  1891 root     S    16244   0%   0% bash
 1641  1588 rancher  S    16116   0%   0% -bash
 1885  1641 root     S    16116   0%   0% bash
 1891  1890 rancher  S    16116   0%   0% -bash
 1992  1991 rancher  S    16116   0%   0% -bash
 1997  1992 rancher  R    11420   0%   0% top
 1589  1370 root     S     6404   0%   0% /sbin/agetty --noclear tty2 linux
 1591  1370 root     S     6404   0%   0% /sbin/agetty --noclear tty3 linux
 1592  1370 root     S     6404   0%   0% /sbin/agetty --noclear tty4 linux
 1594  1370 root     S     6404   0%   0% /sbin/agetty --noclear tty5 linux
 1595  1370 root     S     6404   0%   0% /sbin/agetty --noclear tty6 linux
 1112   995 root     S     4660   0%   0% dhcpcd -MA4 -e force_hostname=true --timeout 10 -w --debug eth0
  850   803 root     S     4276   0%   0% /usr/sbin/acpid -f
  477     1 root     Z        0   0%   0% [ros]
   49     2 root     IW       0   0%   0% [kworker/1:1]
    8     2 root     IW       0   0%   0% [rcu_sched]
   33     2 root     IW       0   0%   0% [kworker/0:1]
    7     2 root     SW       0   0%   0% [ksoftirqd/0]
   39     2 root     SWN      0   0%   0% [khugepaged]
 1317     2 root     IW       0   0%   0% [kworker/3:2]
   48     2 root     IW       0   0%   0% [kworker/u8:1]
   76     2 root     SW       0   0%   0% [scsi_eh_1]
 1244     2 root     IW       0   0%   0% [kworker/2:2]
    2     0 root     SW       0   0%   0% [kthreadd]
    4     2 root     IW<      0   0%   0% [kworker/0:0H]
    6     2 root     IW<      0   0%   0% [mm_percpu_wq]
    9     2 root     IW       0   0%   0% [rcu_bh]
   10     2 root     SW       0   0%   0% [migration/0]
   11     2 root     SW       0   0%   0% [watchdog/0]
   12     2 root     SW       0   0%   0% [cpuhp/0]
   13     2 root     SW       0   0%   0% [cpuhp/1]
   14     2 root     SW       0   0%   0% [watchdog/1]
   15     2 root     SW       0   0%   0% [migration/1]
   16     2 root     SW       0   0%   0% [ksoftirqd/1]
   18     2 root     IW<      0   0%   0% [kworker/1:0H]
```

### ros

> A system service is a container that can be run in either System Docker or Docker. Rancher provides services that are already available in RancherOS by adding them to the [os-services repo](https://github.com/rancher/os-services). Anything in the `index.yml` file from the repository for the tagged release will be an available system service when using the `ros service list` command.

RancherOS 移除了 systemd ，取而代之的是使用 ros 来管理系统服务。而相应的系统服务也是采用 docker 的方式来运行，包括用户空间的 docker 也是采用 docker 的方式来运行。

```bash
[root@rancher rancher]# ros
NAME:
   ros - Control and configure RancherOS
built: '2019-12-30T09:16:00Z'

USAGE:
   ros [global options] command [command options] [arguments...]

VERSION:
   v1.5.5

AUTHOR(S):
   Rancher Labs, Inc.

COMMANDS:
     config, c   configure settings
     console     manage which console container is used
     engine      manage which Docker engine is used
     service, s
     os          operating system upgrade/downgrade
     tls         setup tls configuration
     install     install RancherOS to disk
     help, h     Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --help, -h     show help
   --version, -v  print the version
```

### 系统进程

- 可以看到，使用 `ros service ps` 命令来查看正在运行的系统服务，这些服务都是以容器的方式来运行的。比如用户空间里的 `user-docker` 、`syslog` 、`udevd`   等等都是以容器的方式来运行的，而不是以传统进程服务来运行的。包括我们安装 RancherOS 到磁盘的时候  `starting installer container for rancher/os-installer:latest (new)` 这个安装程序也是由容器的方式来运行的，把磁盘设备和 `cloud-init` 配置文件一并挂载到容器中。

```bash
[root@rancher rancher]# ros service ps
Name                    Command                                                            State                     Ports
docker                  ros user-docker                                                    Up 9 minutes
logrotate               /usr/bin/entrypoint.sh /usr/sbin/logrotate -v /etc/logrotate.conf  Created
system-cron             container-crontab                                                  Up 9 minutes
container-data-volumes  /usr/bin/ros entrypoint echo                                       Created
console                 /usr/bin/ros entrypoint ros console-init                           Up 9 minutes
system-volumes          /usr/bin/ros entrypoint echo                                       Created
ntp                     /usr/bin/ros entrypoint /bin/start_ntp.sh                          Up 9 minutes
subscriber              /usr/bin/ros entrypoint os-subscriber                              Exited (0) 2 minutes ago
syslog                  /usr/bin/entrypoint.sh rsyslogd -n                                 Up 9 minutes
media-volumes           /usr/bin/ros entrypoint echo                                       Created
preload-user-images     /usr/bin/ros entrypoint ros preload-images                         Exited (0) 9 minutes ago
udev                    /usr/bin/ros entrypoint udevd                                      Up 9 minutes
udev-cold               /usr/bin/ros entrypoint ros udev-settle                            Exited (0) 9 minutes ago
network                 /usr/bin/ros entrypoint netconf                                    Up 9 minutes
open-vm-tools           /usr/bin/ros entrypoint /usr/bin/vmtoolsd                          Up 9 minutes
acpid                   /usr/bin/ros entrypoint /usr/sbin/acpid -f                         Up 9 minutes
command-volumes         /usr/bin/ros entrypoint echo                                       Created
cloud-init-execute      /usr/bin/ros entrypoint cloud-init-execute -pre-console            Exited (0) 9 minutes ago
user-volumes            /usr/bin/ros entrypoint echo                                       Created
all-volumes             /usr/bin/ros entrypoint echo
```

### 包管理器

和 CoreOS 一样，RancherOS 也没得相应的包管理器 😂，都是采用容器来运行所需的服务，使用 `ros` 命令来管理相应的服务。如果想要运行一个服务的话，需要使用 ros 来创建相应的容器来运行才可以。而使用 ros 来创建服务

## 结束

文章写的太仓促了，感觉这些容器优化行操作系统都值得玩一玩得，尤其是 RancherOS 这种将 systemc 取代掉使用 docker 来管理系统服务得牛皮技术，值得研究一哈。因为时间有限，所以就没有详细地展开来将，就等到 2020 年吧 😂。祝大家 2020 年元旦快乐，新的一年里……省略千字祝福 😝
