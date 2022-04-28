---
title: 使用 Packer 构建虚拟机模版
date: 2022-04-23
updated: 2022-04-23
slug:
categories: 技术
tag:
  - packer
  - esxi
  - k3s
  - vSphere
copyright: true
comment: true
---
## 三连

假如给你三台物理服务器，CPU、内存、硬盘、HBA 卡等硬件设备安装好，在没有安装任何操作系统的情况下你如何将这三台服务器变成一个 K8s 集群；

售前实施工程师在客户机房中进行部署，有时对于新建的机房物理服务器还没有安装任何操作系统。因为操作系统

在进行超融合产品部署的时候，往往客户机房中的物理服务器还没有安装任何操作系统。将集群部署工具容器化部署，并

借助 argo-workflow 工作流编排引擎我们可以很

为什么要用 k3s

将 k3s 在构建虚拟机模版的时候安装好，构建虚拟机的时候 IP 地址和导入 之后的 IP 地址很大概率是不相同的。

## 劝退三连

- 需要一个 vCenter 以及一台 ESXi 主机
- VM Network 网络中需要有一台 DHCP 服务器用于给 VM 分配 IP

## Packer 简介

Packer 是 hashicorp 公司开源的一个虚拟机镜像构建工具，支持主流的公有云以及私有云环境

## 构建流程

- 下载 ISO 文件，并以 checksum.iso 保存，这样的好处就是便于缓存 ISO 文件，避免重复下载
- 上传本地 ISO 文件到 vCenter 的 datastore 中，默认保存在 packer_cache 目录下
- 创建虚拟机，配置虚拟机硬件，挂载 ISO 文件到虚拟机上
- 虚拟机开启，通过 vCenter API 发送键盘输入，插入 kickstart 配置执行自动化安装
- ISO 中的 OS 安装程序读取 kickstart 进行 OS 安装，并为 OS 安装上 open-vm-tools 软件
- 等待 OS 安装完成，安装完成重启后进入 OS，通过 DHCP 获取 IP
- 通过 vm-tools 获取虚拟机的 IP 地址，通过 ssh 连接到虚拟机执行关机命令
- 虚拟机关机，卸载 ISO 和软驱等不需要的设备文件
- 创建快照/将虚拟机转换为模版

```bash
[root@localhost:/vmfs/volumes/622aec5b-de94a27c-948e-00505680fb1d] pwd
/vmfs/volumes/Packer
[root@localhost:/vmfs/volumes/622aec5b-de94a27c-948e-00505680fb1d] ls packer_cache/
51511394170e64707b662ca8db012be4d23e121f.iso  d3e175624fc2d704975ce9a149f8f270e4768727.iso  e476ea1d3ef3c2e3966a7081ac4239cd5ae5e8a3.iso
[root@localhost:/vmfs/volumes/622aec5b-de94a27c-948e-00505680fb1d]
```

```bash
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
-rw-------    1 root     root       81.0M Apr  1 09:17 vmx-base-os-centos7-91f34e6b5057bacd98170dd0824534160e7b007d-1.vswp

root@devbox-fedora:/root # scp 192.168.24.43:/vmfs/volumes/Packer/base-os-centos7/packer-tmp-created-floppy.flp .
packer-tmp-created-floppy.flp                                                                                100% 1440KB  89.4MB/s   00:00
root@devbox-fedora:/root # mount packer-tmp-created-floppy.flp /mnt
root@devbox-fedora:/root # readlink /dev/disk/by-label/packer
../../loop2
root@devbox-fedora:/root # df -h /
Filesystem                      Size  Used Avail Use% Mounted on
/dev/mapper/fedora_fedora-root  255G  210G   46G  83% /
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

### Photon OS 3

```bash
root@devbox-fedora:/root/usr/src/github.com/muzi502/packer-vsphere-example git:(master*) # make build-template PACKER_BASE_OS=photon3 PACKER_FORCE=true
packer build --force=true --var ova_name=k3s-photon3-c4e81da-dirty --var release_version=c4e81da-dirty --var template=base-os-photon3 -only vsphere-iso-base -var-file=/root/usr/src/github.com/muzi502/packer-vsphere-example/vsphere.json -var-file=/root/usr/src/github.com/muzi502/packer-vsphere-example/photon3.json -var-file=/root/usr/src/github.com/muzi502/packer-vsphere-example/common.json /root/usr/src/github.com/muzi502/packer-vsphere-example/builder.json
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

### CentOS 7

```root@devbox-fedora:/root/usr/src/github.com/muzi502/packer-vsphere-example git:(master*) # make build-template PACKER_BASE_OS=centos7 PACKER_FORCE=true
packer build --force=true --var ova_name=k3s-centos7-c4e81da-dirty --var release_version=c4e81da-dirty --var template=base-os-centos7 -only vsphere-iso-base -var-file=/root/usr/src/github.com/muzi502/packer-vsphere-example/vsphere.json -var-file=/root/usr/src/github.com/muzi502/packer-vsphere-example/centos7.json -var-file=/root/usr/src/github.com/muzi502/packer-vsphere-example/common.json /root/usr/src/github.com/muzi502/packer-vsphere-example/builder.json
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
```

## 克隆构建

## 使用感受

虚拟机资源的构建比容器镜像的构建要复杂很多，更没有一个想 OCI 那样统一工业标准，这就导致。

## 参考

- [Image Builder for Cluster API](https://github.com/kubernetes-sigs/image-builder/tree/master/images/capi)
- [Building Images for vSphere](https://image-builder.sigs.k8s.io/capi/providers/vsphere.html#building-images-for-vsphere)
- [Packer Builder for VMware vSphere](https://www.packer.io/plugins/builders/vsphere/vsphere-iso)
- [Automatic template creation with Packer and deployment with Ansible in a VMware vSphere environment](https://docs.rockylinux.org/guides/automation/templates-automation-packer-vsphere/)
