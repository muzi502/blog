---
title: 使用 Packer 构建虚拟机镜像踩的坑
date: 2022-05-25
updated: 2022-05-25
slug:
categories: 技术
tag:
  - packer
  - esxi
  - k3s
  - vSphere
  - argo-workflow
  - redfish
copyright: true
comment: true
---
不久前写过一篇博客《[使用 Redfish 自动化安装 ESXi OS](https://blog.k8s.li/redfish-esxi-os-installer.html)》分享了如何使用 Redfish 给物理服务器自动化安装 ESXi OS。虽然在我们内部做到了一键安装/重装 ESXi OS，但想要将这套方案应用在客户的私有云机房环境中还是有很大的难度。

首先这套工具必须运行在 Linux 中才行，对于 Bare Metal 裸服务器来讲还没有安装任何 OS，这就引申出了鸡生蛋蛋生鸡的尴尬难题。虽然可以给其中的一台物理服务器安装上一个 Linux 发行版比如 CentOS，然后再将这套自动化安装 ESXi OS 的工具搭建上去，但这会额外占用一台物理服务器，客户也肯定不愿意接受。

真实的实施场景中，可行的方案就是将这套工具运行在实施人员的笔记本电脑或者客户提供的台式机上。这又引申出了一个另外的难题：实施人员的笔记本电脑或者客户提供的台式机运行的大都是 Windows 系统，在 Windows 上安装 Ansible、Make、Python3 等一堆依赖，想想就不太现实，而且稳定性和兼容性很难得到保障，以及开发环境和运行环境不一致导致一些其他的奇奇怪怪的问题。虽然该工具支持容器化运行能够解决开发环境和运行环境不一致的问题，但在 Windows 上安装 docker 也比较繁琐和麻烦。

这时候就要搬出计算机科学中的至理名言: **计算机科学领域的任何问题都可以通过增加一个间接的中间层来解决**。

> **Any problem in computer science can be solved by another layer of indirection.**

既然我们这套工具目前只能在 Linux 上稳定运行，那么我们不如就将这套工具和它所运行的环境封装在一个“中间容器”里，比如虚拟机。使用者只需要安装像 [VMware Workstation](https://www.vmware.com/products/workstation-pro/workstation-pro-evaluation.html) 或者 [Oracle VirtualBox](https://www.virtualbox.org/) 虚拟化管理软件运行这台虚拟机不就行了。一切皆可套娃（🤣

其实原理就像 docker 容器那样，我们将这套工具和它所依赖的运行环境在构建虚拟机的时候将它们全部打包在一起，使用者只需要想办法将这个虚拟机运行起来，就能一键使用我们这个工具，不必再手动安装 Ansible 和 Python3 等一堆依赖了，真正做到开箱即用。

于是本文分享一下如何使用 [Packer](https://www.packer.io/) 在 [VMware vSphere](https://www.vmware.com/products/vsphere.html) 环境上构建虚拟机镜像的方案，以及如何在这个虚拟机中运行一个 k3s 集群，然后通过 [argo-workflow](https://github.com/argoproj/argo-workflows) 工作流引擎运行 [redfish-esxi-os-installer](https://github.com/muzi502/redfish-esxi-os-installer) 来对裸金属服务器进行自动化安装 ESXi OS 的操作。

## 劝退三连 😂

- 提前下载好 Base OS 的 ISO 镜像，比如 [CentOS-7-x86_64-Minimal-2009.iso](https://mirrors.tuna.tsinghua.edu.cn/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-Minimal-2009.iso)
- 需要一个 [vCenter Server](https://www.vmware.com/products/vcenter-server.html) 以及一台 [VMware ESXi](https://www.vmware.com/products/esxi-and-esx.html) 主机
- ESXi 的 VM Network 网络中需要有一台 DHCP 服务器用于给 VM 分配 IP

## Packer

很早之前玩儿 VMware ESXi 的时候还没有接触到 Packer，那时候只能使用[手搓虚拟机模版](https://blog.k8s.li/esxi-vmbase.html)的方式，费时费力还容易出错，下面就介绍一下这个自动化构建虚拟机镜像的工具。

### 简介

[Packer](https://github.com/hashicorp/packer) 是 [hashicorp](https://www.hashicorp.com/) 公司开源的一个虚拟机镜像构建工具，与它类似的工具还有 [OpenStack diskimage-builder](https://github.com/openstack/diskimage-builder)、[AWS EC2 Image Builder](https://aws.amazon.com/image-builder/) ，但是这两个只支持自家的平台。Packer 能够支持主流的公有云、私有云以及混合云，比它俩高到不知道哪里去了。可以这么来理解：Packer 在 IaaS 虚拟化领域的地位就像 Docker 在 PaaS 容器虚拟中那样重要，一个是虚拟机镜像的构建，另一个容器镜像的构建，有趣的是两者都是在 2013 年成立的项目。

Kubernetes 社区的 [image-builder](https://github.com/kubernetes-sigs/image-builder) 项目就是使用 Packer 构建一些公有云及私有云的虚拟机模版提供给 [cluster-api](https://github.com/kubernetes-sigs/cluster-api) 项目使用，十分推荐大家去看下这个项目的代码，刚开始我也是从这个项目熟悉 Packer 的，并从中抄袭借鉴了很多内容 😅。

下面就介绍一下 Packer 的基本使用方法

### 安装

对于 Linux 发行版，建议直接下载二进制安装包来安装，通过包管理器安装感觉有点麻烦

```bash
$ wget https://releases.hashicorp.com/packer/1.8.0/packer_1.8.0_linux_amd64.zip
$ unzip packer_1.8.0_linux_amd64.zip
$ mv packer /usr/local/bin/packer
```

如果是 macOS 用户直接 `brew install packer` 命令一把梭就能安装好

### 配置

不同于 Docker 有一个 Dockerfile 文件来定义如何构建容器镜像，Packer 构建虚拟机镜像则是由一系列的配置文件缝合而成，主要由 [Builders](https://www.packer.io/docs/terminology#builders) 、[Provisioners](https://www.packer.io/docs/terminology#provisioners) 、[Post-processors](https://www.packer.io/docs/terminology#post-processors) 这三部分组成。其中 Builder 主要是与 IaaS Provider 构建器相关的一些参数；Provisioner 用来配置构建过程中需要运行的一些任务；Post-processors 用于配置构建动作完成后的一些后处理操作；下面就依次介绍一下这几个配置的详细使用说明：

另外 Packer 推荐的配置语法是 [HCL2](https://www.packer.io/guides/hcl)，但个人觉着 HCL 的语法风格怪怪的，不如 json 那样整洁好看 😅，因此下面我统一使用 json 来进行配置，其实参数都一样，只是格式不相同而已。

#### vars/var-file

Packer 的变量配置文件有点类似于 Ansible 中的 vars。一个比较合理的方式就是按照每个参数的作用域进行分类整理，将它们统一放在一个单独的配置文件中，这样维护起来会更方便一些。参考了 image-builder 项目中的 [ova](https://github.com/kubernetes-sigs/image-builder/tree/master/images/capi/packer/ova) 构建后我根据参数的不同作用划分成了如下几个配置文件：

- [vcenter.json](https://github.com/muzi502/packer-vsphere-example/blob/master/packer/vcenter.json)：主要用于配置一些与 vCenter 相关的参数，比如 datastore、datacenter、resource_pool、vcenter_server 等；另外像 vcenter 的用户名和密码建议使用环境变量的方式，避免明文编码在文件当中；

```json
{
  "folder": "Packer",
  "resource_pool": "Packer",
  "cluster": "Packer",
  "datacenter": "Packer",
  "datastore": "Packer",
  "convert_to_template": "false",
  "create_snapshot": "true",
  "linked_clone": "true",
  "network": "VM Network",
  "password": "password",
  "username": "administrator@vsphere.local",
  "vcenter_server": "vcenter.k8s.li",
  "insecure_connection": "true"
}
```

- [centos7.json](https://github.com/muzi502/packer-vsphere-example/blob/master/packer/centos7.json)：主要用于配置一些通过 ISO 安装 CentOS 的参数，比如 ISO 的下载地址、ISO 的 checksum、kickstart 文件路径、关机命令、isolinux 启动参数等；

```json
{
  "boot_command_prefix": "<tab> text ks=hd:fd0:",
  "boot_command_suffix": "/7/ks.cfg<enter><wait>",
  "boot_media_path": "/HTTP",
  "build_name": "centos-7",
  "distro_arch": "amd64",
  "distro_name": "centos",
  "distro_version": "7",
  "floppy_dirs": "./kickstart/{{user `distro_name`}}/http/",
  "guest_os_type": "centos7-64",
  "iso_checksum": "07b94e6b1a0b0260b94c83d6bb76b26bf7a310dc78d7a9c7432809fb9bc6194a",
  "iso_checksum_type": "sha256",
  "iso_url": "https://mirrors.edge.kernel.org/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-Minimal-2009.iso",
  "os_display_name": "CentOS 7",
  "shutdown_command": "shutdown -h now",
  "vsphere_guest_os_type": "centos7_64Guest"
}
```

- [photon3.json](https://github.com/muzi502/packer-vsphere-example/blob/master/packer/photon3.json)：主要用于配置一些通过 ISO 安装 Photon3 OS 的参数，和上面的 centos7.json 作用基本一致；

```json
{
  "boot_command_prefix": "<esc><wait> vmlinuz initrd=initrd.img root/dev/ram0 loglevel=3 photon.media=cdrom ks=",
  "boot_command_suffix": "/3/ks.json<enter><wait>",
  "boot_media_path": "http://{{ .HTTPIP }}:{{ .HTTPPort }}",
  "build_name": "photon-3",
  "distro_arch": "amd64",
  "distro_name": "photon",
  "distro_version": "3",
  "guest_os_type": "vmware-photon-64",
  "http_directory": "./kickstart/{{user `distro_name`}}/http/",
  "iso_checksum": "c2883a42e402a2330d9c39b4d1e071cf9b3b5898",
  "iso_checksum_type": "sha1",
  "iso_url": "https://packages.vmware.com/photon/3.0/Rev3/iso/photon-minimal-3.0-a383732.iso",
  "os_display_name": "VMware Photon OS 64-bit",
  "shutdown_command": "shutdown now",
  "vsphere_guest_os_type": "vmwarePhoton64Guest"
}
```

- [common.json](https://github.com/muzi502/packer-vsphere-example/blob/master/packer/common.json)：一些公共参数，比如虚拟机的 ssh 用户名和密码（要和 kickstart 中设置的保持一致）、虚拟机的一些硬件配置如 CPU、内存、硬盘、虚拟机版本、网卡类型、存储控制器类型等；

```json
{
  "ssh_username": "root",
  "ssh_password": "password",
  "boot_wait": "15s",
  "disk_controller_type": "lsilogic",
  "disk_thin_provisioned": "true",
  "disk_type_id": "0",
  "firmware": "bios",
  "cpu": "2",
  "cpu_cores": "1",
  "memory": "4096",
  "disk_size": "65536",
  "network_card": "e1000",
  "ssh_timeout": "3m",
  "vmx_version": "14",
  "base_build_version": "{{user `template`}}",
  "build_timestamp": "{{timestamp}}",
  "build_name": "k3s",
  "build_version": "{{user `ova_name`}}",
  "export_manifest": "none",
  "output_dir": "./output/{{user `build_version`}}"
}
```

#### Builder

Builder 就是告诉 Packer 要使用什么类型的构建器构建什么样的虚拟机镜像，主要是与底层 IaaS 资源提供商相关的配置。比如 [vSphere Builder](https://www.packer.io/plugins/builders/vsphere) 中有如下两种构建器：

- [vsphere-iso](https://www.packer.io/docs/builders/vsphere/vsphere-iso) 从 ISO 安装 OS 开始构建，通常情况下构建为一个虚拟机或虚拟机模版
- [vsphere-clone](https://www.packer.io/docs/builders/vsphere/vsphere-clone) 通过 clone 虚拟机的方式进行构建，通常情况下构建产物为导出后的 OVF/OVA 文件

不同类型的 Builder 配置参数也会有所不同，每个参数的详细用途和说明可以参考 [Packer 官方的文档](https://www.packer.io/plugins)，在这里就不一一说明了。因为 Packer 的参数配置是在是太多太复杂了，很难三言两语讲清楚。最佳的方式就是阅读官方的文档和一些其他项目的实现方式，照葫芦画瓢学就行。

[builders.json](https://github.com/muzi502/packer-vsphere-example/blob/master/packer/builder.json)：里面的配置参数大多都是引用的 var-file 中的参数，将这些参数单独抽出来的好处就是不同的 builder 之间可以复用一些公共参数。比如 vsphere-iso 和 vsphere-clone 这两种不同的 builder 与 vCenter 相关的 datacenter、datastore、vcenter_server 等参数都是其实相同的。

- [vsphere-iso](https://www.packer.io/docs/builders/vsphere/vsphere-iso) ：通过 ISO 安装 OS 构建一个虚拟机或虚拟机模版

```json
{
  "builders": [
    {
      "CPUs": "{{user `cpu`}}",
      "RAM": "{{user `memory`}}",
      "boot_command": [
        "{{user `boot_command_prefix`}}",
        "{{user `boot_media_path`}}",
        "{{user `boot_command_suffix`}}"
      ],
      "boot_wait": "{{user `boot_wait`}}",
      "cluster": "{{user `cluster`}}",
      "communicator": "ssh",
      "convert_to_template": "{{user `convert_to_template`}}",
      "cpu_cores": "{{user `cpu_cores`}}",
      "create_snapshot": "{{user `create_snapshot`}}",
      "datacenter": "{{user `datacenter`}}",
      "datastore": "{{user `datastore`}}",
      "disk_controller_type": "{{user `disk_controller_type`}}",
      "firmware": "{{user `firmware`}}",
      "floppy_dirs": "{{ user `floppy_dirs`}}",
      "folder": "{{user `folder`}}",
      "guest_os_type": "{{user `vsphere_guest_os_type`}}",
      "host": "{{user `host`}}",
      "http_directory": "{{ user `http_directory`}}",
      "insecure_connection": "{{user `insecure_connection`}}",
      "iso_checksum": "{{user `iso_checksum_type`}}:{{user `iso_checksum`}}",
      "iso_urls": "{{user `iso_url`}}",
      "name": "vsphere-iso-base",
      "network_adapters": [
        {
          "network": "{{user `network`}}",
          "network_card": "{{user `network_card`}}"
        }
      ],
      "password": "{{user `password`}}",
      "shutdown_command": "echo '{{user `ssh_password`}}' | sudo -S -E sh -c '{{user `shutdown_command`}}'",
      "ssh_clear_authorized_keys": "false",
      "ssh_password": "{{user `ssh_password`}}",
      "ssh_timeout": "4h",
      "ssh_username": "{{user `ssh_username`}}",
      "storage": [
        {
          "disk_size": "{{user `disk_size`}}",
          "disk_thin_provisioned": "{{user `disk_thin_provisioned`}}"
        }
      ],
      "type": "vsphere-iso",
      "username": "{{user `username`}}",
      "vcenter_server": "{{user `vcenter_server`}}",
      "vm_name": "{{user `base_build_version`}}",
      "vm_version": "{{user `vmx_version`}}"
    }
  ]
}
```

- [vsphere-clone](https://www.packer.io/docs/builders/vsphere/vsphere-clone)：通过 clone 虚拟机构建一个虚拟机，并导出虚拟机 OVF 模版

```json
{
  "builders": [
    {
      "CPUs": "{{user `cpu`}}",
      "RAM": "{{user `memory`}}",
      "cluster": "{{user `cluster`}}",
      "communicator": "ssh",
      "convert_to_template": "{{user `convert_to_template`}}",
      "cpu_cores": "{{user `cpu_cores`}}",
      "create_snapshot": "{{user `create_snapshot`}}",
      "datacenter": "{{user `datacenter`}}",
      "datastore": "{{user `datastore`}}",
      "export": {
        "force": true,
        "manifest": "{{ user `export_manifest`}}",
        "output_directory": "{{user `output_dir`}}"
      },
      "folder": "{{user `folder`}}",
      "host": "{{user `host`}}",
      "insecure_connection": "{{user `insecure_connection`}}",
      "linked_clone": "{{user `linked_clone`}}",
      "name": "vsphere-clone",
      "network": "{{user `network`}}",
      "password": "{{user `password`}}",
      "shutdown_command": "echo '{{user `ssh_password`}}' | sudo -S -E sh -c '{{user `shutdown_command`}}'",
      "ssh_password": "{{user `ssh_password`}}",
      "ssh_timeout": "4h",
      "ssh_username": "{{user `ssh_username`}}",
      "template": "{{user `template`}}",
      "type": "vsphere-clone",
      "username": "{{user `username`}}",
      "vcenter_server": "{{user `vcenter_server`}}",
      "vm_name": "{{user `build_version`}}"
    }
  ]
}
```

#### [Provisioner](https://www.packer.io/docs/provisioners)

Provisioner 就是告诉 Packer 要如何构建镜像，有点类似于 Dockerile 中的 RUN/COPY/ADD 等指令，用于执行一些命令/脚本、往虚拟机里添加一些文件、调用第三方插件执行一些操作等。

在这个配置文件中我先使用 file 模块将一些脚本和依赖文件上传到虚拟机中，然后使用 shell 模块在虚拟机中执行 install.sh 安装脚本。如果构建的 builder 比较多，比如需要支持多个 Linux 发行版，这种场景建议使用 Ansible。由于我在 ISO 安装 OS 的构建流程中已经将一些与 OS 发行版相关的操作完成了，在这里使用 shell 执行的操作不需要区分哪个 Linux 发行版，所以就没有使用 ansible。

```json
{
  "provisioners": [
    {
      "type": "file",
      "source": "scripts",
      "destination": "/root",
      "except": [
        "vsphere-iso-base"
      ]
    },
    {
      "type": "file",
      "source": "resources",
      "destination": "/root",
      "except": [
        "vsphere-iso-base"
      ]
    },
    {
      "type": "shell",
      "environment_vars": [
        "INSECURE_REGISTRY={{user `insecure_registry`}}"
      ],
      "inline": "bash /root/scripts/install.sh",
      "except": [
        "vsphere-iso-base"
      ]
    }
  ]
}
```

### post-processors

一些构建后的操作， 比如 `"type": "manifest"` 可以导出一些构建过程中的配置参数，给后续的其他操作来使用。再比如 `"type": "shell-local"` 就是执行一些 shell 脚本，在这里就是执行一个 Python 脚本将 OVF 转换成 OVA。

```json
{
  "post-processors": [
    {
      "custom_data": {
        "release_version": "{{user `release_version`}}",
        "build_date": "{{isotime}}",
        "build_name": "{{user `build_name`}}",
        "build_timestamp": "{{user `build_timestamp`}}",
        "build_type": "node",
        "cpu": "{{user `cpu`}}",
        "memory": "{{user `memory`}}",
        "disk_size": "{{user `disk_size`}}",
        "distro_arch": "{{ user `distro_arch` }}",
        "distro_name": "{{ user `distro_name` }}",
        "distro_version": "{{ user `distro_version` }}",
        "firmware": "{{user `firmware`}}",
        "guest_os_type": "{{user `guest_os_type`}}",
        "os_name": "{{user `os_display_name`}}",
        "vsphere_guest_os_type": "{{user `vsphere_guest_os_type`}}"
      },
      "name": "packer-manifest",
      "output": "{{user `output_dir`}}/packer-manifest.json",
      "strip_path": true,
      "type": "manifest",
      "except": [
        "vsphere-iso-base"
      ]
    },
    {
      "inline": [
        "python3 ./scripts/ova.py --vmx {{user `vmx_version`}} --ovf_template {{user `ovf_template`}} --build_dir={{user `output_dir`}}"
      ],
      "except": [
        "vsphere-iso-base"
      ],
      "name": "vsphere",
      "type": "shell-local"
    }
  ]
}
```

### 构建

[packer-vsphere-example](https://github.com/muzi502/packer-vsphere-example) 项目的目录结构如下：

```bash
../packer-vsphere-example
├── kickstart        # kickstart 配置文件存放目录
├── Makefile         # makefile，make 命令的操作的入口
├── packer           # packer 配置文件
│   ├── builder.json # packer builder 配置文件
│   ├── centos7.json # centos iso 安装 os 的配置
│   ├── common.json  # 一些公共配置参数
│   ├── photon3.json # photon3 iso 安装 os 的配置
│   └── vcenter.json # vcenter 相关的配置
├── resources        # 一些 k8s manifests 文件
└── scripts          # 构建过程中需要用到的脚本文件
```

与 docker 类似，packer 执行构建操作的子命令同样也是 build，即 `packer build`，不过 packer build 命令支持的选项并没有 docker 那么丰富。最核心选项就是 -except, -only, -var,  -var-file 这几个：

```bash
$ packer build
Options:

	# 控制终端颜色输出
  -color=false                  Disable color output. (Default: color)
  # debug 模式，类似于断点的方式运行
  -debug                        Debug mode enabled for builds.
  # 排除一些 builder，有点类似于 ansible 的 --skip-tags
  -except=foo,bar,baz           Run all builds and post-processors other than these.
  # 指定运行某些 builder，有点类似于 ansible 的 --tags
  -only=foo,bar,baz             Build only the specified builds.
  # 强制构建，如果构建目标已经存在则强制删除重新构建
  -force                        Force a build to continue if artifacts exist, deletes existing artifacts.
  -machine-readable             Produce machine-readable output.
  # 出现错误之后的动作，cleanup 清理所有操作、abort 中断执行、ask 询问、
  -on-error=[cleanup|abort|ask|run-cleanup-provisioner] If the build fails do: clean up (default), abort, ask, or run-cleanup-provisioner.
  # 并行运行的 builder 数量，默认没有限制，有点类似于 ansible 中的 --forks 参数
  -parallel-builds=1            Number of builds to run in parallel. 1 disables parallelization. 0 means no limit (Default: 0)
  # UI 输出的时间戳
  -timestamp-ui                 Enable prefixing of each ui output with an RFC3339 timestamp.
  # 变量参数，有点类似于 ansible 的 -e 选项
  -var 'key=value'              Variable for templates, can be used multiple times.
  # 变量文件，有点类似于 ansible 的 -e@ 选项
  -var-file=path                JSON or HCL2 file containing user variables.

# 指定一些 var 参数以及 var-file 文件，最后一个参数是 builder 的配置文件路径
$ packer build  --var ova_name=k3s-photon3-c4ca93f --var release_version=c4ca93f --var ovf_template=/root/usr/src/github.com/muzi502/packer-vsphere-example/scripts/ovf_template.xml --var template=base-os-photon3 --var username=${VCENTER_USERNAME} --var password=${VCENTER_PASSWORD} --var vcenter_server=${VCENTER_SERVER} --var build_name=k3s-photon3 --var output_dir=/root/usr/src/github.com/muzi502/packer-vsphere-example/output/k3s-photon3-c4ca93f -only vsphere-clone -var-file=/root/usr/src/github.com/muzi502/packer-vsphere-example/packer/vcenter.json -var-file=/root/usr/src/github.com/muzi502/packer-vsphere-example/packer/photon3.json -var-file=/root/usr/src/github.com/muzi502/packer-vsphere-example/packer/common.json /root/usr/src/github.com/muzi502/packer-vsphere-example/packer/builder.json
```

上面那个又长又臭的 packer build 命令我们在 [Makefile](https://github.com/muzi502/packer-vsphere-example/blob/master/Makefile) 里封装一下，那么多的参数选项手动输起来能把人气疯 😂

- 首先定义一些默认的参数，比如构建版本、构建时间、base 模版名称、导出 ova 文件名称等等。

```makefile
# Ensure Make is run with bash shell as some syntax below is bash-specific
SHELL:=/usr/bin/env bash
.DEFAULT_GOAL:=help

# Full directory of where the Makefile resides
ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

RELEASE_VERSION       ?= $(shell git describe --tags --always --dirty)
RELEASE_TIME          ?= $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
PACKER_IMAGE          ?= hashicorp/packer:1.8
PACKER_CONFIG_DIR     = $(ROOT_DIR)/packer
PACKER_FORCE          ?= false
PACKER_OVA_PREFIX     ?= k3s
PACKER_BASE_OS        ?= centos7
PACKER_OUTPUT_DIR     ?= $(ROOT_DIR)/output
PACKER_TEMPLATE_NAME  ?= base-os-$(PACKER_BASE_OS)
OVF_TEMPLATE          ?= $(ROOT_DIR)/scripts/ovf_template.xml
PACKER_OVA_NAME       ?= $(PACKER_OVA_PREFIX)-$(PACKER_BASE_OS)-$(RELEASE_VERSION)
```

- 然后定义 vars 和 var-file 参数

```makefile
# 是否为强制构建，增加 force 参数
ifeq ($(PACKER_FORCE), true)
  PACKER_FORCE_ARG = --force=true
endif

# 定义 vars 可变参数，比如 vcenter 用户名、密码 等参数
PACKER_VARS = $(PACKER_FORCE_ARG) \            # 是否强制构建
	--var ova_name=$(PACKER_OVA_NAME) \          # OVA 文件名
	--var release_version=$(RELEASE_VERSION) \   # 发布版本
	--var ovf_template=$(OVF_TEMPLATE) \         # OVF 模版文件
	--var template=$(PACKER_TEMPLATE_NAME) \     # OVA 的 base 虚拟机模版名称
	--var username=$${VCENTER_USERNAME} \        # vCenter 用户名（环境变量）
	--var password=$${VCENTER_PASSWORD} \        # vCenter 密码（环境变量）
	--var vcenter_server=$${VCENTER_SERVER} \    # vCenter 访问地址（环境变量）
	--var build_name=$(PACKER_OVA_PREFIX)-$(PACKER_BASE_OS) \  # 构建名称
	--var output_dir=$(PACKER_OUTPUT_DIR)/$(PACKER_OVA_NAME)   # OVA 导出的目录

# 定义 var-file 参数
PACKER_VAR_FILES = -var-file=$(PACKER_CONFIG_DIR)/vcenter.json \ # vCenter 的参数配置
	-var-file=$(PACKER_CONFIG_DIR)/$(PACKER_BASE_OS).json \        # OS 的参数配置
	-var-file=$(PACKER_CONFIG_DIR)/common.json                     # 一些公共配置
```

- 最后定义 make targrt

```makefile
.PHONY: build-template
# 通过 ISO 安装 OS 构建一个 base 虚拟机
build-template: ## build the base os template by iso
	packer build $(PACKER_VARS) -only vsphere-iso-base $(PACKER_VAR_FILES) $(PACKER_CONFIG_DIR)/builder.json

.PHONY: build-ovf
# 通过 clone 方式构建并导出 OVF/OVA
build-ovf: ## build the ovf template by clone the base os template
	packer build $(PACKER_VARS) -only vsphere-clone $(PACKER_VAR_FILES) $(PACKER_CONFIG_DIR)/builder.json
```

- 构建 BASE 模版

```bash
# 通过 PACKER_BASE_OS 参数设置 base os 是 photon3 还是 centos7
$ make build-template PACKER_BASE_OS=photon3
```

- 构建 OVF 模版并导出为 OVA

```bash
# 通过 PACKER_BASE_OS 参数设置 base os 是 photon3 还是 centos7
$ make build-ovf PACKER_BASE_OS=photon3
```

## 构建流程

将 Packer 的配置文件以及 Makefile 封装好之后，我们就可以运行 `make build-template` 和 `make build-ovf` 命令来构建虚拟机模版了，整体的构建流程如下：

- 先使用 ISO 构建一个与业务无关的 base 虚拟机
- 在 base 虚拟机之上通过 vsphere-clone 方式构建业务虚拟机
- 导出 OVF 虚拟机文件，打包成 OVA 格式的虚拟机模版

### 通过 vsphere-iso 构建 Base 虚拟机

base 虚拟机有点类似于 Dockerfile 中的 FROM base 镜像。在 Packer 中我们可以把一些很少会改动的内容做成一个 base 虚拟机。然后从这个 base 虚拟机克隆出一台新的虚拟机来完成接下来的构建流程，这样能够节省整体的构建耗时，使得构建效率更高一些。

- centos7 构建输出日志

```bash
vsphere-iso-base: output will be in this color.
==> vsphere-iso-base: File /root/.cache/packer/e476ea1d3ef3c2e3966a7081ac4239cd5ae5e8a3.iso already uploaded; continuing
==> vsphere-iso-base: File [Packer] packer_cache//e476ea1d3ef3c2e3966a7081ac4239cd5ae5e8a3.iso already exists; skipping upload.
==> vsphere-iso-base: the vm/template Packer/base-os-centos7 already exists, but deleting it due to -force flag
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
==> vsphere-iso-base: IP address: 192.168.29.46
==> vsphere-iso-base: Using SSH communicator to connect: 192.168.29.46
==> vsphere-iso-base: Waiting for SSH to become available...
==> vsphere-iso-base: Connected to SSH!
==> vsphere-iso-base: Executing shutdown command...
==> vsphere-iso-base: Deleting Floppy drives...
==> vsphere-iso-base: Deleting Floppy image...
==> vsphere-iso-base: Eject CD-ROM drives...
==> vsphere-iso-base: Creating snapshot...
==> vsphere-iso-base: Clear boot order...
Build 'vsphere-iso-base' finished after 6 minutes 42 seconds.
==> Wait completed after 6 minutes 42 seconds
==> Builds finished. The artifacts of successful builds are:
--> vsphere-iso-base: base-os-centos7

[root@localhost:/vmfs/volumes/622aec5b-de94a27c-948e-00505680fb1d] ls packer_cache/
51511394170e64707b662ca8db012be4d23e121f.iso  d3e175624fc2d704975ce9a149f8f270e4768727.iso  e476ea1d3ef3c2e3966a7081ac4239cd5ae5e8a3.iso
[root@localhost:/vmfs/volumes/622aec5b-de94a27c-948e-00505680fb1d] ls -alh base-os-centos7/
total 4281536
drwxr-xr-x    1 root     root       72.0K Apr  1 09:17 .
drwxr-xr-t    1 root     root       76.0K Apr  1 09:17 ..
-rw-------    1 root     root        4.0G Apr  1 09:17 base-os-centos7-3ea6b205.vswp
-rw-r--r--    1 root     root         253 Apr  1 09:17 base-os-centos7-65ff34a3.hlog
-rw-------    1 root     root       64.0G Apr  1 09:17 base-os-centos7-flat.vmdk
-rw-------    1 root     root        8.5K Apr  1 09:17 base-os-centos7.nvram
-rw-------    1 root     root         482 Apr  1 09:17 base-os-centos7.vmdk
-rw-r--r--    1 root     root           0 Apr  1 09:17 base-os-centos7.vmsd
-rwxr-xr-x    1 root     root        2.3K Apr  1 09:17 base-os-centos7.vmx
-rw-------    1 root     root           0 Apr  1 09:17 base-os-centos7.vmx.lck
-rwxr-xr-x    1 root     root        2.2K Apr  1 09:17 base-os-centos7.vmx~
-rw-------    1 root     root        1.4M Apr  1 09:17 packer-tmp-created-floppy.flp
-rw-r--r--    1 root     root       96.1K Apr  1 09:17 vmware.log

root@devbox-fedora:/root # scp 192.168.24.43:/vmfs/volumes/Packer/base-os-centos7/packer-tmp-created-floppy.flp .

root@devbox-fedora:/root # mount packer-tmp-created-floppy.flp /mnt
root@devbox-fedora:/root # readlink /dev/disk/by-label/packer
../../loop2
root@devbox-fedora:/root # ls /mnt/HTTP/7/KS.CFG
KS.CFG
```

- Photon3 构建输出日志

```
vsphere-iso-base: output will be in this color.

==> vsphere-iso-base: File /root/.cache/packer/d3e175624fc2d704975ce9a149f8f270e4768727.iso already uploaded; continuing
==> vsphere-iso-base: File [Packer] packer_cache//d3e175624fc2d704975ce9a149f8f270e4768727.iso already exists; skipping upload.
==> vsphere-iso-base: the vm/template Packer/base-os-photon3 already exists, but deleting it due to -force flag
==> vsphere-iso-base: Creating VM...
==> vsphere-iso-base: Customizing hardware...
==> vsphere-iso-base: Mounting ISO images...
==> vsphere-iso-base: Adding configuration parameters...
==> vsphere-iso-base: Starting HTTP server on port 8674
==> vsphere-iso-base: Set boot order temporary...
==> vsphere-iso-base: Power on VM...
==> vsphere-iso-base: Waiting 15s for boot...
==> vsphere-iso-base: HTTP server is working at http://192.168.29.171:8674/
==> vsphere-iso-base: Typing boot command...
==> vsphere-iso-base: Waiting for IP...
==> vsphere-iso-base: IP address: 192.168.29.208
==> vsphere-iso-base: Using SSH communicator to connect: 192.168.29.208
==> vsphere-iso-base: Waiting for SSH to become available...
==> vsphere-iso-base: Connected to SSH!
==> vsphere-iso-base: Executing shutdown command...
==> vsphere-iso-base: Deleting Floppy drives...
==> vsphere-iso-base: Eject CD-ROM drives...
==> vsphere-iso-base: Creating snapshot...
==> vsphere-iso-base: Clear boot order...
Build 'vsphere-iso-base' finished after 5 minutes 24 seconds.

==> Wait completed after 5 minutes 24 seconds

==> Builds finished. The artifacts of successful builds are:
--> vsphere-iso-base: base-os-photon3
```

通过 `packer build` 命令的输出我们大致可以推断出通过 vsphere-iso 构建 Base 虚拟机的主要步骤和原理：

- 下载 ISO 文件到本地的 ${HOME}/.cache/packer 目录，并以 checksum.iso 方式保存，这样的好处就是便于缓存 ISO 文件，避免重复下载；
- 上传本地 ISO 文件到 vCenter 的 datastore 中，默认保存在 datastore 的 packer_cache 目录下，如果 ISO 文件已经存在了，则会跳过上传的流程；
- 创建虚拟机，配置虚拟机硬件，挂载上传的 ISO 文件到虚拟机上的 CD/ROM，设置 boot 启动项为 CD/ROM
- 如果 [boot_media_path](https://www.packer.io/plugins/builders/vsphere/vsphere-iso#boot-configuration) 是 http 类型的则在本地随机监听一个 TCP 端口来运行一个 http 服务，用于提供 kickstart 文件的 HTTP 下载功能；如果是目录类型的则将 kickstart 文件创建成一个软盘文件，并将该文件上传到 datastore 中，将软盘文件插入到虚拟机中；
- 虚拟机开机启动到 ISO 引导页面，通过 vCenter API 发送键盘输入，插入 kickstart 文件的路径；
- 通过 vCenter API 发送回车键盘输入，ISO 中的 OS 安装程序读取 kickstart 进行 OS 安装；
- 在 kickstart 脚本里安装 [open-vm-tools](https://github.com/vmware/open-vm-tools) 工具；
- 等待 OS 安装完成，安装完成重启后进入安装好的 OS，OS 启动后通过 DHCP 获取 IP 地址；
- 通过 vm-tools 获取到虚拟机的 IP 地址，然后 ssh 连接到虚拟机执行关机命令；
- 虚拟机关机，卸载 ISO 和软驱等不需要的设备；
- 创建快照或者将虚拟机转换为模版；

个人觉着这里比较好玩儿就是居然可以通过 vCenter 或 ESXi 的 [PutUsbScanCodes](https://vdc-repo.vmware.com/vmwb-repository/dcr-public/1ef6c336-7bef-477d-b9bb-caa1767d7e30/82521f49-9d9a-42b7-b19b-9e6cd9b30db1/vim.VirtualMachine.html#putUsbScanCodes) API 来给虚拟机发送一些键盘输入的指令，感觉这简直太神奇啦 😂。之前我们的项目是将 kickstart 文件构建成一个 ISO 文件，然后通过重新构建源 ISO 的方式来修改 isolinux 启动参数。后来感觉这种重新构建 ISO 的方式太蠢了，于是就参考 Packer 的思路使用 govc 里内置的 [vm.keystrokes](https://github.com/vmware/govmomi/blob/master/govc/vm/keystrokes.go) 命令来给虚拟机发送键盘指令，完成指定 kickstart 文件路径参数启动的操作。具体的 govc 操作命令可以参考如下：

```bash
# 发送 tab 键，进入到 ISO 启动参数编辑页面
$ govc vm.keystrokes -vm='centos-vm-192' -c='KEY_TAB'
# 发送 Right Control + U 键清空输入框
$ govc vm.keystrokes -vm='centos-vm-192' -rc=true -c='KEY_U'
# 输入 isolinux 的启动参数配置，通过 ks=hd:LABEL=KS:/ks.cfg 指定 kickstart 路径，LABEL 为构建 ISO 时设置的 lable
$ govc vm.keystrokes -vm='centos-vm-192' -s='vmlinuz initrd=initrd.img ks=hd:LABEL=KS:/ks.cfg inst.stage2=hd:LABEL=CentOS\\x207\\x20x86_64 quiet console=ttyS0'
# 按下回车键，开始安装 OS
$ govc vm.keystrokes -vm='centos-vm-192' -c='KEY_ENTER'
```

### 通过 vsphere-clone 构建业务虚拟机并导出 OVF/OVA

通过 vsphere-iso 构建 Base 虚拟机之后，我们就使用这个 base 虚拟机克隆出一台新的虚拟机，用来构建我们的业务虚拟机镜像，将 k3s, argo-workflow, redfish-esxi-os-installer 这一堆工具打包进去；

```bash
vsphere-clone: output will be in this color.

==> vsphere-clone: Cloning VM...
==> vsphere-clone: Customizing hardware...
==> vsphere-clone: Power on VM...
==> vsphere-clone: Waiting for IP...
==> vsphere-clone: IP address: 192.168.30.112
==> vsphere-clone: Using SSH communicator to connect: 192.168.30.112
==> vsphere-clone: Waiting for SSH to become available...
==> vsphere-clone: Connected to SSH!
==> vsphere-clone: Uploading scripts => /root
==> vsphere-clone: Uploading resources => /root
==> vsphere-clone: Provisioning with shell script: /tmp/packer-shell557168976
==> vsphere-clone: Executing shutdown command...
==> vsphere-clone: Creating snapshot...
    vsphere-clone: Starting export...
    vsphere-clone: Downloading: k3s-photon3-c4ca93f-disk-0.vmdk
    vsphere-clone: Exporting file: k3s-photon3-c4ca93f-disk-0.vmdk
    vsphere-clone: Writing ovf...
==> vsphere-clone: Running post-processor: packer-manifest (type manifest)
==> vsphere-clone: Running post-processor: vsphere (type shell-local)
==> vsphere-clone (shell-local): Running local shell script: /tmp/packer-shell2376077966
    vsphere-clone (shell-local): image-build-ova: cd /root/usr/src/github.com/muzi502/packer-vsphere-example/output/k3s-photon3-c4ca93f
    vsphere-clone (shell-local): image-build-ova: create ovf k3s-photon3-c4ca93f.ovf
    vsphere-clone (shell-local): image-build-ova: create ova manifest k3s-photon3-c4ca93f.mf
    vsphere-clone (shell-local): image-build-ova: creating OVA using tar
    vsphere-clone (shell-local): image-build-ova: ['tar', '-c', '-f', 'k3s-photon3-c4ca93f.ova', 'k3s-photon3-c4ca93f.ovf', 'k3s-photon3-c4ca93f.mf', 'k3s-photon3-c4ca93f-disk-0.vmdk']
    vsphere-clone (shell-local): image-build-ova: create ova checksum k3s-photon3-c4ca93f.ova.sha256
Build 'vsphere-clone' finished after 14 minutes 16 seconds.

==> Wait completed after 14 minutes 16 seconds

==> Builds finished. The artifacts of successful builds are:
--> vsphere-clone: k3s-photon3-c4ca93f
--> vsphere-clone: k3s-photon3-c4ca93f
--> vsphere-clone: k3s-photon3-c4ca93f
```

通过 packer build 命令的输出我们大致可以推断出构建流程：

- clone 虚拟机，修改虚拟机的硬件配置
- 虚拟机开机，通过 vm-tools 获取虚拟机的 IP 地址
- 获取到虚拟机的 IP 地址后等待 ssh 能够正常连接
- ssh 能够正常连接后，通过 scp 的方式上传文件
- ssh 远程执行虚拟机里的 [install.sh](https://github.com/muzi502/packer-vsphere-example/blob/master/scripts/install.sh) 脚本
- 执行虚拟机关机命令
- 创建虚拟机快照
- 导出虚拟机 OVF 文件
- 导出构建配置参数的 manifest.json 文件
- 执行 [ova.py](https://github.com/muzi502/packer-vsphere-example/blob/master/scripts/ova.py) 脚本，根据 manifest.json 配置参数将 OVF 格式转换成 OVA

至此，整个的虚拟机模版的构建流程算是完成了，最终我们的到一个 OVA 格式的虚拟机模版。使用的时候只需要在本地机器上安装好 VMware Workstation 或者 Oracle VirtualBox 就能一键导入该虚拟机，开机后就可以使用啦，算是做到了开箱即用的效果。

```bash
output
└── k3s-photon3-c4ca93f
    ├── k3s-photon3-c4ca93f-disk-0.vmdk
    ├── k3s-photon3-c4ca93f.mf
    ├── k3s-photon3-c4ca93f.ova
    ├── k3s-photon3-c4ca93f.ova.sha256
    ├── k3s-photon3-c4ca93f.ovf
    └── packer-manifest.json
```

## argo-workflow 和 k3s

在虚拟机内使用 redfish-esxi-os-installer 有点特殊，是将它放在 argo-workflow 的 Pod 内来执行的。在 workflow 模版文件 [workflow.yaml](https://github.com/muzi502/packer-vsphere-example/blob/master/resources/workflow/workflow.yaml) 中我们定义了若干个 steps 来运行 redfish-esxi-os-installer。

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: redfish-esxi-os-installer-
  namespace: default
spec:
  entrypoint: redfish-esxi-os-installer
  templates:
  - name: redfish-esxi-os-installer
    steps:
    - - arguments:
          parameters:
          - name: command
            value: pre-check
        name: Precheck
        template: installer
    - - arguments:
          parameters:
          - name: command
            value: build-iso
        name: BuildISO
        template: installer
    - - arguments:
          parameters:
          - name: command
            value: mount-iso
        name: MountISO
        template: installer
    - - arguments:
          parameters:
          - name: command
            value: reboot
        name: Reboot
        template: installer
    - - arguments:
          parameters:
          - name: command
            value: post-check
        name: Postcheck
        template: installer
    - - arguments:
          parameters:
          - name: command
            value: umount-iso
        name: UmountISO
        template: installer
  - container:
      name: installer
      image: ghcr.io/muzi502/redfish-esxi-os-installer:v0.1.0-alpha.1
      command:
      - bash
      - -c
      - |
        make inventory && make {{inputs.parameters.command}}
      env:
      - name: POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: HOST_IP
        valueFrom:
          fieldRef:
            fieldPath: status.hostIP
      - name: SRC_ISO_DIR
        value: /data/iso
      - name: HTTP_DIR
        value: /data/iso/redfish
      - name: HTTP_URL
        value: http://$(HOST_IP)/files/iso/redfish
      - name: ESXI_ISO
        valueFrom:
          configMapKeyRef:
            name: redfish-esxi-os-installer-config
            key: esxi_iso
      securityContext:
        privileged: true
      volumeMounts:
      - mountPath: /ansible/config.yaml
        name: config
        readOnly: true
        subPath: config.yaml
      - mountPath: /data
        name: data
    inputs:
      parameters:
      - name: command
    name: installer
    retryStrategy:
      limit: "2"
      retryPolicy: OnFailure
  volumes:
  - configMap:
      items:
      - key: config
        path: config.yaml
      name: redfish-esxi-os-installer-config
    name: config
  - name: data
    hostPath:
      path: /data
      type: DirectoryOrCreate
```

由于目前没有 Web UI 和后端 Server 所以还是需要手动编辑 [/root/resources/workflow/configmap.yaml](https://github.com/muzi502/packer-vsphere-example/blob/master/resources/workflow/configmap.yaml) 配置文件，然后再执行 `kubectl create -f /root/resources/workflow` 命令创建 workflow 工作流。

workflow 创建了之后，就可以通过 argo 命令查看 workflow 执行的进度和状态

```bash
root@localhost [ ~/resources/workflow ]# argo get redfish-esxi-os-installer-tjjqz
Name:                redfish-esxi-os-installer-tjjqz
Namespace:           default
ServiceAccount:      unset (will run with the default ServiceAccount)
Status:              Succeeded
Conditions:
 PodRunning          False
 Completed           True
Created:             Mon May 23 11:07:31 +0000 (16 minutes ago)
Started:             Mon May 23 11:07:31 +0000 (16 minutes ago)
Finished:            Mon May 23 11:23:38 +0000 (19 seconds ago)
Duration:            16 minutes 7 seconds
Progress:            6/6
ResourcesDuration:   29m45s*(1 cpu),29m45s*(100Mi memory)

STEP                                TEMPLATE                   PODNAME                                     DURATION  MESSAGE
 ✔ redfish-esxi-os-installer-tjjqz  redfish-esxi-os-installer
 ├───✔ Precheck(0)                  installer                  redfish-esxi-os-installer-tjjqz-647555770   11s
 ├───✔ BuildISO(0)                  installer                  redfish-esxi-os-installer-tjjqz-3078771217  14s
 ├───✔ MountISO(0)                  installer                  redfish-esxi-os-installer-tjjqz-4099695623  19s
 ├───✔ Reboot(0)                    installer                  redfish-esxi-os-installer-tjjqz-413209187   7s
 ├───✔ Postcheck(0)                 installer                  redfish-esxi-os-installer-tjjqz-2674696793  14m
 └───✔ UmountISO(0)                 installer                  redfish-esxi-os-installer-tjjqz-430254503   13s
```

### argo-workflow

之所以使用 argo-workflow 而不是使用像 docker、nerdctl 这些命令行工具来运行 redfish-esxi-os-installer ，是因为通过 argo-workflow 来编排我们的安装部署任务能够比较方便地实现多个任务同时运行、获取任务执行的进度及日志、获取任务执行的耗时、停止重试等功能。使用 argo-workflow 来编排我们的安装部署任务，并通过 argo-workflow 的 RESTful API 获取部署任务的进度日志等信息，这样做更云原生一些（🤣

![argo-workfloe-apis](https://p.k8s.li/2022-05-23-packer-vsphere-example-01.png)

在我们内部其实最终目的是准备将该方案做成一个产品化的工具，提供一个 Web UI 用来进行配置部署参数以及展示部署的进度日志等功能。当初设计方案的时候也是参考了一下  [VMware Tanzu 社区版](https://github.com/vmware-tanzu/community-edition) ：部署 Tanzu 管理集群的时候需要有一个已经存在的 k8s 集群，或者通过 Tanzu 新部署一个 kind 集群。部署一个 tanzu 管理集群可以通过 tanzu 命令行的方式，也可以通过 Tanzu Web UI 的方式，Tanzu Web UI 的方式其实就是一个偏向于产品化的工具。在 [VMware Tanzu kubernetes 发行版部署尝鲜](https://blog.k8s.li/deploy-tanzu-k8s-cluster.html) 我曾分享过 Tanzu 的部署方式，感兴趣的话可以去看一下。

![tanzu-cluster](https://p.k8s.li/2022-05-23-packer-vsphere-example-02.png)

该方案主要是面向一些产品化的场景，由于引入了 K8s 这个庞然大物，整体的技术栈会复杂一些，但也有一些好处啦 😅。

### k8s and k3s

argo-workflow 需要依赖一个 k8s 集群才能运行，我们内部测试了 kubekey、sealos、kubespray、k3s 几种常见的部署工具。综合评定下来 k3s 集群占用的资源最少。参考 [K3s 资源分析](https://docs.rancher.cn/docs/k3s/installation/installation-requirements/resource-profiling/_index/) 给出的资源要求，最小只需要 768M 内存就能运行。对于硬件资源不太充足的笔记本电脑来讲，k3s 无疑是目前最佳的方案。

另外还有一个十分重要的原因就是 k3s server 更换单 control plan 节点的 IP 地址十分方便，对用户来说是无感知的。这样就可以将安装 k3s 的操作在构建 OVA 的时候完成，而不是在使用的时候手动执行安装脚本来安装。

只要开机运行虚拟机能够通过 DHCP 分配到一个内网 IPv4 地址或者手动配置一个静态 IP，k3s 就能够正常运行起来，能够真正做到开箱即用，而不是像 kubekey、sealos、kubespray 那样傻乎乎地填写一个复杂无比的配置文件，然后再执行一些命令来安装 k8s 集群。这种导入虚拟机开即用的方式，对用户来讲十分友好。

当然在使用 kubekey、sealos、kubespray 在构建虚拟机的时候安装好 k8s 集群也不是不可行，只不过我们构建时候虚拟机的 IP 地址（比如 10.172.20.223）和使用时的 IP 地址（比如 192.168.20.11）基本上是不会相同的。给 k8s control plain 节点更换 IP 的操作 [阳明博主](https://www.qikqiak.com/) 曾在 [如何修改 Kubernetes 节点 IP 地址?](https://www.qikqiak.com/post/how-to-change-k8s-node-ip/) 文章中分享过他的经历，看完后直接把我整不会了，感觉操作起来实在是太麻烦了，还不如重新部署一套新的 k8s 方便呢 😂

其实构建虚拟机模版的时候安装 k8s 的思路最初我是借鉴的 [cluster-api](https://github.com/kubernetes-sigs/cluster-api) 项目 😂。即将部署 k8s 依赖的一些文件和容器镜像构建在虚拟机模版当中，部署 k8s 的时候不需要再联网下载这些依赖资源了。不同的是，我们通过 k3s 直接提前将 k8s 集群部署好了，也就省去了让用户执行部署的操作。

综上，选用 k3s 作为该方案的 K8s 底座无疑是最佳的啦（

## 其他

### 使用感受

使用了一段时间后感觉 Packer 的复杂度和上手难度要比 Docker 构建容器镜像要高出一个数量级。可能是因为虚拟机并不像容器镜像那样有 [OCI](https://opencontainers.org/) 这种统一的构建、分发、运行工业标准。虚拟机的创建克隆等操作与底层的 IaaS 供应商耦合的十分紧密，这就导致不同 IaaS 供应商比如 vSphere、kvm/qemu 他们之间能够复用的配置参数并不多。比如 vSphere 里有 datastore、datacenter、resource_pool、folder 等概念，但 kvm/qemu 中缺没有，这就导致很难将它们统一成一个配置。

### OVA 格式

使用 OVA 而不是 vagrant.box、vmdk、raw、qcow2 等其他格式是因为 OVA 支持支持一键导入的特性，在 Windows 上使用起来比较方便。毕竟 Windows 上安装 Vagrant 或者 qemu/KVM 也够你折腾的了，[VMware Workstation](https://www.vmware.com/products/workstation-pro/workstation-pro-evaluation.html) 或者 [Oracle VirtualBox](https://www.virtualbox.org/) 使用得更广泛一些。

另外 Packer 并不支持直接将虚拟机导出为 OVA 的方式，默认情况下只会通过 vCenter 的 API 导出为 ovf。如果需要 OVA 格式，需要将 OVF 打包成 OVA。在 ISSUE [Add support for exporting to OVA in vsphere-iso builder #9645](https://github.com/hashicorp/packer/issues/9645) 也有人反馈了支持 OVA 导出的需求，但 Packer 至今仍未支持。将 OVF 转换为 OVA 我是参考的 image-builder 项目的 [**image-build-ova.py** ](https://github.com/kubernetes-sigs/image-builder/blob/master/images/capi/hack/image-build-ova.py) 来完成的。

### 安装 open-vm-tool 失败

由于 ISO 中并不包含 open-vm-tool 软件包，这就需要在 ISO 安装 OS 的过程中联网安装 open-vm-tools。如果安装的时候网络抖动了就可能会导致 open-vm-tools 安装失败。open-vm-tools 安装失败 packer 是无法感知到的，只能一直等到获取虚拟机 IP 超时后退出执行。目前没有很好的办法，只能在 kickstart 里安装 open-vm-tools 的时候进行重试直到 open-vm-tools 安装成功。

### 减少导出后 vmdk 文件大小

曾经在 [手搓虚拟机模板](https://blog.k8s.li/esxi-vmbase.html) 文章中分析过通过 dd 置零的方式可以大幅减少虚拟机导出后的 vmdk 文件大

> ```bash
> 464M Aug 28 16:15 Ubuntu1804-2.ova # 置零后的大小
> 1.3G Aug 28 15:48 Ubuntu1804.ova   # 置零前的大小
> ```

需要注意的是，在 dd 置零之前要先停止 k3s 服务，不然置零的时候会占满 root 根分区导致 kubelet 启动 GC 将一些镜像给删除掉。之前导出虚拟机后发现少了一些镜像，排查了好久才发现是 kubelet GC 把我的镜像给删掉了，踩了个大坑，可气死我了 😡

另外也可以删除一些不必要的文件，比如 containerd 中 `io.containerd.content.v1.content/blobs/sha256` 一些镜像 layer 的原始 blob 文件是不需要的，可以将它们给删除掉，这样能够减少部分磁盘空间占用；

```bash
function cleanup(){
  # stop k3s server for for prevent it starting the garbage collection to delete images
  systemctl stop k3s

  # Ensure on next boot that network devices get assigned unique IDs.
  sed -i '/^\(HWADDR\|UUID\)=/d' /etc/sysconfig/network-scripts/ifcfg-* 2>/dev/null || true

  # Clean up network interface persistence
  find /var/log -type f -exec truncate --size=0 {} \;
  rm -rf /tmp/* /var/tmp/*

  # cleanup all blob files of registry download image
  find /var/lib/rancher/k3s/agent/containerd/io.containerd.content.v1.content/blobs/sha256 -size +1M -type f -delete

  # zero out the rest of the free space using dd, then delete the written file.
  dd if=/dev/zero of=/EMPTY bs=4M status=progress || rm -f /EMPTY
  dd if=/dev/zero of=/data/EMPTY bs=4M status=progress || rm -f /data/EMPTY
  # run sync so Packer doesn't quit too early, before the large file is deleted.
  sync

  yum clean all
}
```

### Photon3

之前在 [轻量级容器优化型 Linux 发行版 Photon OS](https://blog.k8s.li/Photon-OS.html) 里分享过 VMware 的 Linux 发行版 [Photon](https://vmware.github.io/photon/assets/files/html/3.0/)。不同于传统的 Linux 发行版 Photon 的系统十分精简，使用它替代 CentOS 能够一定程度上减少系统资源的占用，导出后的 vmdk 文件也要比 CentOS 小一些。

### [goss](https://github.com/aelsabbahy/goss)

在构建的过程中我们在 k3s 集群上安装了一些其他的组件，比如提供文件上传和下载服务的 filebrowser 以及 workflow 工作流引擎 argo-workflow，为了保证这些服务的正常运行，我们就需要通过不同的方式去检查这些服务是否正常。一般是通过 kubectl get 等命令查看 deployment、pod、daemonset 等服务是否正常运行，或者通过 curl 访问这些这些服务的健康检查 API。

由于检查项比较多且十分繁琐，使用传统的 shell 脚本来做这并不是很方便，需要解析每个命令的退出码以及返回值。因此我们使用 [goss](https://github.com/aelsabbahy/goss) 通过 YAML 格式的配置文件来定义一些检查项，让它批量来执行这些检查，而不用在 shell 对每个检查项写一堆的 awk/grep 等命令来 check 了。

- [k3s.yaml](https://github.com/muzi502/packer-vsphere-example/blob/master/scripts/goss/k3s.yaml)：用于检查 k3s 以及它默认自带的服务是否正常运行

```yaml

# DNS 类型的检查
dns:
  # 检查 coredns 是否能够正常解析到 kubernetes apiserver 的 service IP 地址
  kubernetes.default.svc.cluster.local:
    resolvable: true
    addrs:
      - 10.43.0.1
    server: 10.43.0.10
    timeout: 600
    skip: false

# TCP/UDP 端口类型的检查
addr:
  # 检查 coredns 的 UDP 53 端口是否正常
  udp://10.43.0.10:53:
    reachable: true
    timeout: 500

# 检查 cni0 网桥是否存在
interface:
  cni0:
    exists: true
    addrs:
      - 10.42.0.1/24

# 本机端口类型的检查
port:
  # 检查 ssh 22 端口是否正常
  tcp:22:
    listening: true
    ip:
      - 0.0.0.0
    skip: false
  # 检查 kubernetes apiserver 6443 端口是否正常
  tcp6:6443:
    listening: true
    skip: false

# 检查一些 systemd 服务的检查
service:
  # 默认禁用 firewalld 服务
  firewalld:
    enabled: false
    running: false
  # 确保 sshd 服务正常运行
  sshd:
    enabled: true
    running: true
    skip: false
  # 检查 k3s 服务是否正常运行
  k3s:
    enabled: true
    running: true
    skip: false

# 定义一些 shell 命令执行的检查
command:
  # 检查 kubernetes cheduler 组件是否正常
  check_k8s_scheduler_health:
    exec: curl -k https://127.0.0.1:10259/healthz
    # 退出码是否为 0
    exit-status: 0
    stderr: []
    # 标准输出中是否包含正确的输出值
    stdout: ["ok"]
    skip: false
  # 检查 kubernetes controller-manager 是否正常
  check_k8s_controller-manager_health:
    exec: curl -k https://127.0.0.1:10257/healthz
    exit-status: 0
    stderr: []
    stdout: ["ok"]
    skip: false
  # 检查 cluster-info  中输出的组件运行状态是否正常
  check_cluster_status:
    exec: kubectl cluster-info | grep 'is running'
    exit-status: 0
    stderr: []
    timeout: 0
    stdout:
      - CoreDNS
      - Kubernetes control plane
    skip: false
  # 检查节点是否处于 Ready 状态
  check_node_status:
    exec: kubectl get node -o jsonpath='{.items[].status}' | jq -r '.conditions[-1].type'
    exit-status: 0
    stderr: []
    timeout: 0
    stdout:
      - Ready
    skip: false
  # 检查节点 IP 是否正确
  check_node_address:
    exec: kubectl get node -o wide -o json | jq -r '.items[0].status.addresses[] | select(.type == "InternalIP") | .address'
    exit-status: 0
    stderr: []
    timeout: 0
    stdout:
      - {{ .Vars.ip_address }}
    skip: false
  # 检查 traefik loadBalancer 的 IP 地址是否正确
  check_traefik_address:
    exec: kubectl -n kube-system get svc traefik -o json | jq -r '.status.loadBalancer.ingress[].ip'
    exit-status: 0
    stderr: []
    timeout: 0
    stdout:
      - {{ .Vars.ip_address }}
    skip: false
  # 检查 containerd 容器运行是否正常
  check_container_status:
    exec: crictl ps --output=json | jq -r '.containers[].metadata.name' | sort -u
    exit-status: 0
    stderr: []
    timeout: 0
    stdout:
      - coredns
      - /lb-.*-443/
      - /lb-.*-80/
      - traefik
    skip: false
  # 检查 kube-system namespace 下的 pod 是否正常
  check_kube_system_namespace_pod_status:
    exec: kubectl get pod -n kube-system -o json | jq -r '.items[] | select((.status.phase != "Running") and (.status.phase != "Succeeded") and (.status.phase != "Completed"))'
    exit-status: 0
    stderr: []
    timeout: 0
    stdout: ["!string"]
  # 检查 k8s deployment 服务是否都正常
  check_k8s_deployment_status:
    exec: kubectl get deploy --all-namespaces -o json | jq -r '.items[]| select(.status.replicas == .status.availableReplicas) | .metadata.name' | sort -u
    exit-status: 0
    stderr: []
    timeout: 0
    stdout:
      - coredns
      - traefik
    skip: false
  # 检查 svclb-traefik daemonset 是否正常
  check_k8s_daemonset_status:
    exec: kubectl get daemonset --all-namespaces -o json | jq -r '.items[]| select(.status.replicas == .status.availableReplicas) | .metadata.name' | sort -u
    exit-status: 0
    stderr: []
    timeout: 0
    stdout:
      - svclb-traefik
    skip: false
```

- [goss.yaml](https://github.com/muzi502/packer-vsphere-example/blob/master/scripts/goss/goss.yaml)：用于检查我们部署的一些服务是否正常

```yaml
# 通过 include 其他 gossfile 方式将上面定义的 k3s.yaml 检查项也包含进来
gossfile:
  k3s.yaml: {}
dns:
  # 检查部署的 filebrowser deployment 的 service IP 是否能正常解析到
  filebrowser.default.svc.cluster.local:
    resolvable: true
    server: 10.43.0.10
    timeout: 600
    skip: false
  # 检查部署的 argo-workflow deployment 的 service IP 是否能正常解析到
  argo-workflow-argo-workflows-server.default.svc.cluster.local:
    resolvable: true
    server: 10.43.0.10
    timeout: 600
    skip: false

# 一些 HTTP 请求方式的检查
http:
  # 检查 filebrowser 服务是否正常运行，类似于 pod 里的存活探针
  http://{{ .Vars.ip_address }}/filebrowser/:
    status: 200
    timeout: 600
    skip: false
    method: GET
  # 检查 argo-workflow 是否正常运行
  http://{{ .Vars.ip_address }}/workflows/api/v1/version:
    status: 200
    timeout: 600
    skip: false
    method: GET

# 同样也是一些 shell 命令的检查项目
command:
  # 检查容器镜像是否齐全，避免缺镜像的问题
  check_container_images:
    exec: crictl images --output=json | jq -r '.images[].repoTags[]' | awk -F '/' '{print $NF}' | awk -F ':' '{print $1}' | sort -u
    exit-status: 0
    stderr: []
    timeout: 0
    stdout:
      - argocli
      - argoexec
      - workflow-controller
      - filebrowser
      - nginx
    skip: false
  # 检查容器运行的状态是否正常
  check_container_status:
    exec: crictl ps --output=json | jq -r '.containers[].metadata.name' | sort -u
    exit-status: 0
    stderr: []
    timeout: 0
    stdout:
      - argo-server
      - controller
      - nginx
      - filebrowser
    skip: false
  # 检查一些 deployment 的状态是否正常
  check_k8s_deployment_status:
    exec: kubectl get deploy -n default -o json | jq -r '.items[]| select(.status.replicas == .status.availableReplicas) | .metadata.name' | sort -u
    exit-status: 0
    stderr: []
    timeout: 0
    stdout:
      - argo-workflow-argo-workflows-server
      - argo-workflow-argo-workflows-workflow-controller
      - filebrowser
    skip: false

# 一些硬件参数的检查，比如 CPU 核心数、内存大小、可用内存大小
matching:
  check_vm_cpu_core:
    content: {{ .Vars.cpu_core_number }}
    matches:
      gt: 1
  check_vm_memory_size:
    content: {{ .Vars.memory_size }}
    matches:
      gt: 1880000
  check_available_memory_size:
    content: {{ .Vars.available_memory_size }}
    matches:
      gt: 600000
```

另外 goss 也比较适合做一些巡检的工作。比如在一个 k8s 集群中进行巡检：检查集群内 pod 的状态、kubernetes 组件的状态、CNI 运行状态、节点的网络、磁盘存储空间、CPU 负载、内核参数、daemonset 服务状态等，都可以参照上述方式定义一系列的检查项，使用 goss 来帮我们自动完成巡检。

### 导入 OVA 虚拟机后 Pod 状态异常

将 OVA 虚拟机在 VMware Workstation 上导入之后，由于虚拟机 IP 的变化可能会导致一些 Pod 处于异常的状态，这时候就需要对这些 Pod 进行强制删除，强制重启一下才能恢复正常。因此需要需要在虚拟机里增加一个 [prepare.sh](https://github.com/muzi502/packer-vsphere-example/blob/master/scripts/prepare.sh) 脚本用来重启这些状态异常的 Pod。当导入 OVA 虚拟机后运行这个脚本让所有的 Pod 都正常运行起来，然后再调用 goss 来检查其他服务是否正常。

```bash
#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

kubectl get pods --no-headers -n kube-system | grep -E '0/2|0/1|Error|Unknown|CreateContainerError|CrashLoopBackOff' | awk '{print $1}' | xargs -t -I {} kubectl delete pod -n kube-system --grace-period=0 --force {} > /dev/null  2>&1 || true
kubectl get pods --no-headers -n default | grep -E '0/1|Error|Unknown|CreateContainerError|CrashLoopBackOff' | awk '{print $1}' | xargs -t -I {} kubectl delete pod -n default --grace-period=0 --force {} > /dev/null  2>&1 || true
while true; do
  if kubectl get pods --no-headers --all-namespaces | grep -Ev 'Running|Completed'; then
    echo "Waiting for service readiness"
    sleep 10
  else
    break
  fi
done

cd ${HOME}/.goss
cat > vars.yaml << EOF
ip_address: $(ip r get 1 | sed "s/ uid.*//g" | awk '{print $NF}' | head -n1)
cpu_core_number: $(grep -c ^processor /proc/cpuinfo)
memory_size: $(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')
available_memory_size: $(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')
EOF
goss --vars vars.yaml -g goss.yaml validate --retry-timeout=10s
```

## 参考

- [K3S 工具进阶完全指南](https://www.escapelife.site/posts/754ba85c.html)
- [K3s 资源分析](https://docs.rancher.cn/docs/k3s/installation/installation-requirements/resource-profiling/_index/)
- [goss](https://github.com/aelsabbahy/goss/blob/master/docs/manual.md)：goss 配置文档
- [awesome-baremetal](https://github.com/alexellis/awesome-baremetal)：一些与裸金属服务器相关的工具汇总
- [Kickstart Syntax Reference](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/installation_guide/sect-kickstart-syntax)：CentOS/Red Hat kickstart 语法
- [Kickstart Support in Photon OS](https://vmware.github.io/photon/assets/files/html/3.0/photon_user/kickstart.html)：Photon OS 的 kickstart 语法

### Packer 相关

- [bento](https://github.com/chef/bento)：是一个 Packer 最佳实践的模版仓库，不过它的 builder 是 Vagrant，但可以从中借鉴一些 Linux 发行版的自动化安装脚本，比如 CentOS 的 [kickstart](https://github.com/chef/bento/tree/main/packer_templates/centos/http) 文件。
- [基于 Packer+Ansible 实现云平台黄金镜像统一构建和发布](https://mp.weixin.qq.com/s/FnnMnu9i6gFNrAjIlzaNnQ)
- [Image Builder for Cluster API](https://github.com/kubernetes-sigs/image-builder/tree/master/images/capi)
- [Building Images for vSphere](https://image-builder.sigs.k8s.io/capi/providers/vsphere.html#building-images-for-vsphere)
- [VMware vSphere Clone Builder](https://www.packer.io/plugins/builders/vsphere/vsphere-clone)
- [Packer Builder for VMware vSphere](https://www.packer.io/plugins/builders/vsphere/vsphere-iso)
- [packer-plugin-vsphere](https://github.com/hashicorp/packer-plugin-vsphere)
- [packer-examples-for-vsphere](https://github.com/vmware-samples/packer-examples-for-vsphere)
- [Automatic template creation with Packer and deployment with Ansible in a VMware vSphere environment](https://docs.rockylinux.org/guides/automation/templates-automation-packer-vsphere/)
