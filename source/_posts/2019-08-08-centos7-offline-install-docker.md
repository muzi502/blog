---
title: CentOS7 离线安装 Docker-ce
date: 2019-09-03
categories: 技术
slug:
tag:
  - Docker
copyright: true
comment: true
---

## 项目背景

接到新项目的机器无法访问外网，所以只能离线安装 Docker，总体思路是从一台可访问外网的机器上下载下来 docker-ce 的 rpm 包及其依赖，再把这些 rpm 传到要部署的机器上安装就行。其中踩了一些坑，在此记录一下。

新项目的机器是系统是 CentOS 7.5 (1804)，所以在 ESXi 上重新开一台虚拟机，装上 CentOS 7.5 (1804)，这一点比较重要。因为刚开始的时候使用的是 CentOS 7.6 (1810)，但环境不一致导致一些依赖的包版本也不一致，7.6 上一些依赖包版本要比 7.5 高一些，最主要的就是 `libsepol`、 `libsemanage`、 `selinux-policy` 等，都是和 SELinux 相关的依赖，虽然可以加个 `skip-broken` 参数强制安装，但因为是线上生产环境，为了保险起见还是决定将这几个依赖包升级到要求的版本。

## 下载 rpm 包

在另一条可访问外网的机器上下载

```bash
mkdir -p /root/docker-ce
yum install -y yum-utils createrepo
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# yum-utils 用来添加 docker 的 yum 源
# createrepo 用来创建本地 yum 源
```

```bash
# 查看 yum 源中的版本
yum list docker-ce --showduplicates | sort -r
yum list docker-ce-cli --showduplicates | sort -r
yum install --downloadonly --downloaddir=/root/docker-ce docker-ce docker-ce-cli containerd.io
mv /var/cache/yum/x86_64/7/updates/packages/* /root/docker-ce
mv /var/cache/yum/x86_64/7/base/packages/* /root/docker-ce
mv /var/cache/yum/x86_64/7/extras/packages/* /root/docker-ce
# 需要注意的是 --downloadonly 参数只会将所安装的包及其依赖下载到你指定的位置，但需要升级的包,即 Updating dependencies 默认下载到了# /var/cache/yum/x86_64/7/ 这几个目录下，这一点比较坑。
```

提示要安装 3 个包 即 `docker-ce` 、`docker-ce-cli` 、`containerd.io` 加 9 个依赖包，一共十二个包会下载到我们指定路径下，剩余 10 个要升级的依赖包即 `Updating dependencies` 并不会下载到指定的路径下，而是根据对应的 `Repository` 下载到 `/var/cache/yum/x86_64/7/` 目录下，所以也需要将这些包也一同移动到我们指定的路径下。

```bash
Package                            Version                Repository
stalling:
containerd.io                      1.2.6-3.3.el7          docker-ce-stable
docker-ce                          3:19.03.1-3.el7        docker-ce-stable
docker-ce-cli                      1:19.03.1-3.el7        docker-ce-stable

Installing dependencies:
audit-libs-python                  2.8.4-4.el7            base
checkpolicy                        2.5-8.el7              base
container-selinux                  2:2.107-1.el7_6        extras
libcgroup                          0.41-20.el7            base
libseccomp                         2.3.1-3.el7            base
libsemanage-python                 2.5-14.el7             base
policycoreutils-python             2.5-29.el7_6.1         updates
python-IPy                         0.75-6.el7             base
setools-libs                       3.3.8-4.el7            base

Updating dependencies:
audit                              2.8.4-4.el7            base
audit-libs                         2.8.4-4.el7            base
libselinux                         2.5-14.1.el7           base
libselinux-python                  2.5-14.1.el7           base
libselinux-utils                   2.5-14.1.el7           base
libsemanage                        2.5-14.el7             base
libsepol                           2.5-10.el7             base
policycoreutils                    2.5-29.el7_6.1         updates
selinux-policy                     3.13.1-229.el7_6.15    updates
selinux-policy-targeted            3.13.1-229.el7_6.15    updates

Transaction Summary
====================================================
Install  3 Packages (+ 9 Dependent packages)
Upgrade             ( 10 Dependent packages)
```

最终所需要的 rpm 包的如下，包含依赖机器需要升级的包，一共 29 个

```bash
audit-2.8.4-4.el7.x86_64.rpm
audit-libs-2.8.4-4.el7.x86_64.rpm
audit-libs-python-2.8.4-4.el7.x86_64.rpm
checkpolicy-2.5-8.el7.x86_64.rpm
containerd.io-1.2.6-3.3.el7.x86_64.rpm
container-selinux-2.107-1.el7_6.noarch.rpm
device-mapper-1.02.149-10.el7_6.8.x86_64.rpm
device-mapper-event-1.02.149-10.el7_6.8.x86_64.rpm
device-mapper-event-libs-1.02.149-10.el7_6.8.x86_64.rpm
device-mapper-libs-1.02.149-10.el7_6.8.x86_64.rpm
docker-ce-19.03.1-3.el7.x86_64.rpm
docker-ce-cli-19.03.1-3.el7.x86_64.rpm
libcgroup-0.41-20.el7.x86_64.rpm
libseccomp-2.3.1-3.el7.x86_64.rpm
libselinux-2.5-14.1.el7.x86_64.rpm
libselinux-python-2.5-14.1.el7.x86_64.rpm
libselinux-utils-2.5-14.1.el7.x86_64.rpm
libsemanage-2.5-14.el7.x86_64.rpm
libsemanage-python-2.5-14.el7.x86_64.rpm
libsepol-2.5-10.el7.x86_64.rpm
libtool-ltdl-2.4.2-22.el7_3.x86_64.rpm
lvm2-2.02.180-10.el7_6.8.x86_64.rpm
lvm2-libs-2.02.180-10.el7_6.8.x86_64.rpm
policycoreutils-2.5-29.el7_6.1.x86_64.rpm
policycoreutils-python-2.5-29.el7_6.1.x86_64.rpm
python-IPy-0.75-6.el7.noarch.rpm
selinux-policy-3.13.1-229.el7_6.15.noarch.rpm
selinux-policy-targeted-3.13.1-229.el7_6.15.noarch.rpm
setools-libs-3.3.8-4.el7.x86_64.rpm
```

## 生成本地 yum 源

这一步操作可以在本地这台机器上生成 yum 元数据信息，也可以在生产环境那台机器上执行，不过需要单独安装 createrepo 工具来生成。

```bash
createrepo -d /root/docker-ce/
# 最终会在本地 /root/docker-ce/ 目录的 repodata 目录下生成所含软件包的元数据据信息
tree /root/docker-ce/repodata
.
├── 1a232695bdd68ade6ebd6549ef9267e1b7f870566820f627237bc3db93281aaf-filelists.xml.gz
├── 658e130ccd8e0d62a4b1334ff65c14b223e528c50352a9e2cfc44cc4535693fd-other.sqlite.bz2
├── 6601f7512ba24f28ce37e5afa4c5f48b812dfcb019516e630438a1d11088ecdd-other.xml.gz
├── d3e511a8557503650c8083eb97ef7500afa0f43eb0f66db15aa155226c03054b-primary.sqlite.bz2
├── db2fa3329ff03fd2b70814a57703502c28898ba09b548593abcce1166964554d-primary.xml.gz
├── ff326b22deaf8f3f728203069f42476e35e5c62688fb78691087314edeaf6b13-filelists.sqlite.bz2
└── repomd.xml
0 directories, 7 files
```

`repomd.xml` 包含这些软件包的元数据信息

```xml
<?xml version="1.0" encoding="UTF-8"?>
<repomd xmlns="http://linux.duke.edu/metadata/repo" xmlns:rpm="http://linux.duke.edu/metadata/rpm">
 <revision>1567506793</revision>
<data type="filelists">
  <checksum type="sha256">1a232695bdd68ade6ebd6549ef9267e1b7f870566820f627237bc3db93281aaf</checksum>
  <open-checksum type="sha256">9653a695d402fdd138ca4ca0ab4387e1687b67a8486af6955cdae070c0a6a7c1</open-checksum>
  <location href="repodata/1a232695bdd68ade6ebd6549ef9267e1b7f870566820f627237bc3db93281aaf-filelists.xml.gz"/>
  <timestamp>1567506794</timestamp>
  <size>15489</size>
  <open-size>181439</open-size>
</data>
<data type="primary">
  <checksum type="sha256">db2fa3329ff03fd2b70814a57703502c28898ba09b548593abcce1166964554d</checksum>
  <open-checksum type="sha256">1ab8f25d3566bee756fa62cf7f6c5d944d52d6440cb00ef37779d0e6a38d81fe</open-checksum>
  <location href="repodata/db2fa3329ff03fd2b70814a57703502c28898ba09b548593abcce1166964554d-primary.xml.gz"/>
  <timestamp>1567506794</timestamp>
  <size>19103</size>
  <open-size>198571</open-size>
</data>
<data type="primary_db">
  <checksum type="sha256">d3e511a8557503650c8083eb97ef7500afa0f43eb0f66db15aa155226c03054b</checksum>
  <open-checksum type="sha256">d6df45954bb239439baa86c486159ca009ad076107729f69df6cfb06d04b76d1</open-checksum>
  <location href="repodata/d3e511a8557503650c8083eb97ef7500afa0f43eb0f66db15aa155226c03054b-primary.sqlite.bz2"/>
  <timestamp>1567506794</timestamp>
  <database_version>10</database_version>
  <size>55692</size>
  <open-size>344064</open-size>
</data>
<data type="other_db">
  <checksum type="sha256">658e130ccd8e0d62a4b1334ff65c14b223e528c50352a9e2cfc44cc4535693fd</checksum>
  <open-checksum type="sha256">f0d99fae751fa3f6cd7b6e4e69cd0cf80a569b972d83103469fe21f4464aa569</open-checksum>
  <location href="repodata/658e130ccd8e0d62a4b1334ff65c14b223e528c50352a9e2cfc44cc4535693fd-other.sqlite.bz2"/>
  <timestamp>1567506794</timestamp>
  <database_version>10</database_version>
  <size>15817</size>
  <open-size>64512</open-size>
</data>
<data type="other">
  <checksum type="sha256">6601f7512ba24f28ce37e5afa4c5f48b812dfcb019516e630438a1d11088ecdd</checksum>
  <open-checksum type="sha256">905cc2a9cdc825e3bf9f790219661f36f5adb733b4238cf9d9f6b0db596a1936</open-checksum>
  <location href="repodata/6601f7512ba24f28ce37e5afa4c5f48b812dfcb019516e630438a1d11088ecdd-other.xml.gz"/>
  <timestamp>1567506794</timestamp>
  <size>10380</size>
  <open-size>60522</open-size>
</data>
<data type="filelists_db">
  <checksum type="sha256">ff326b22deaf8f3f728203069f42476e35e5c62688fb78691087314edeaf6b13</checksum>
  <open-checksum type="sha256">1a2a1ddbf42881778fc5c4603545d730db0d833c711166a82ff9f589092459f0</open-checksum>
  <location href="repodata/ff326b22deaf8f3f728203069f42476e35e5c62688fb78691087314edeaf6b13-filelists.sqlite.bz2"/>
  <timestamp>1567506794</timestamp>
  <database_version>10</database_version>
  <size>24426</size>
  <open-size>123904</open-size>
</data>
</repomd>

```

## 离线安装 docker-ce

将上面生成的文件夹 `/root/docker-ce`  利用 scp 的方式上传到需要安装的机器上

```bash
# 备份原有的 yum repo
ls /etc/yum.repos.d | xargs -I{} mv /etc/yum.repos.d/{} /etc/yum.repos.d/{}.bak
```

```bash
cat >>/etc/yum.repos.d/docker-ce.repo << EOF
[local-yum]
name=local-yum
baseurl=file:///root/docker-ce
enabled=1
gpgcheck=0
EOF
```

```bash
yum clean all
rm -rf /var/cache/yum
yum makecache
yum list | grep docker
yum install docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker
docker info
```

这样就大功告成啦

```ini
docker info
Client:
 Debug Mode: false

Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 19.03.1
 Storage Driver: overlay2
  Backing Filesystem: extfs
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
 containerd version: 894b81a4b802e4eb2a91d1ce216b8817763c29fb
 runc version: 425e105d5a03fabd737a126ad93d62a9eeede87f
 init version: fec3683
 Security Options:
  seccomp
   Profile: default
 Kernel Version: 3.10.0-862.el7.x86_64
 Operating System: CentOS Linux 7 (Core)
 OSType: linux
 Architecture: x86_64
 CPUs: 2
 Total Memory: 1.779GiB
 Name: centos1804
 ID: SAFG:3ERG:A52Y:NIDH:65B5:QMKS:DYPH:XVW4:CA6M:UFMR:AKDJ:WQJK
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false
```

## 经验？

1. 通过 yum history 回滚是不会回滚升级的版本的
2. 需要注意的是 --downloadonly 参数只会将所安装的包及其依赖下载到你指定的位置，但需要升级的包,即 Updating dependencies 默认下载到了# /var/cache/yum/x86_64/7/ 这几个目录下，这一点比较坑
3. createrepo  创建本地 yum 源
4. 此方案不仅仅是用与 docker ，离线安装其他包也是支持的
