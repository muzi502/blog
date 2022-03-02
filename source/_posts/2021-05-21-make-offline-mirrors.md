---
title: 使用 GitHub Actions 自动化构建 yum/apt 离线源
date: 2021-05-23
updated: 2021-09-03
slug:
categories: 技术
tag:
  - docker
  - centos
  - ubuntu
  - docker
  - rpm
  - deb
copyright: true
comment: true
---

## 离线部署

对于 PaaS toB 产品来讲，客户往往会要求产品的部署方案必须做到离线安装，即在部署时不能依赖任何在线的资源，比如安装一些 OS 软件包时依赖的 yum/apt 源；docker.io、k8s.gcr.io 、quay.io 上面的容器镜像；GitHub 上开源软件的二进制下载文件等。

作为平台部署工具的开发者，始终被离线部署这个难题困扰着。在线的容器镜像和二进制文件比较好解决，因为这些资源是与 OS 无关的，只要下载下来放到安装包里，部署的时候启动一个 HTTP 服务器和镜像仓库服务提供这些资源的下载即可。

但是对于 yum/apt 之类的软件来讲并不那么简单：

- 首先由于各个包之间的依赖关系比较复杂，并不能将它们直接下载下来；
- 其次即便下载下来之后也无法直接通过 yum/apt 的方式安装指定的软件包，虽然也可以使用 scp 的方式将这些包复制到部署节点，通过 rpm 或 dpkg 的方式来安装上，但这样并不是很优雅，而且通用性能也不是很好；
- 最后需要适配的 Linux 发行版和包管理器种类也有多种，而且有些包的包名或者版本号在不同的包管理之间也相差甚大，无法做到统一管理。
- 要同时适配 arm64 和 amd64 的源及其困难

综上，将平台部署依赖的在线 yum/apt 之类的软件包资源制作成离线安装包是一件很棘手的事情。个人就这个问题折腾了一段时间，终于找到了一个比较合适的解决方案：即通过一个 YAML 配置文件来管理包，然后使用 Dockerfile 来构建成离线的 tar 包或者容器镜像。如果有类似需求的小伙伴，可以参考一下本方案。

## Docker build

传统制作离线源的方式是找一台相应的 Linux 机器，在上面通过包管理器下载这些软件包，然后再创建这些软件包的 repo 索引文件。

可以看出这种方式十分不灵活，假如我想要制作 Debian 9 的 apt 离线源，我就需要一台 Debian 9 的机器。如果要适配多个 Linux 发行版就需要多个相应的 OS 机器。要管理和使用这么多种类的 OS 不是一件容易的事儿，而如今已经十分普遍使用的容器技术恰恰能帮助我们解决这类问题。比如我想运行一个 Debian9 的操作系统，我只需要运行一个 Debian 9 镜像的容器即可，而且不需要额外的管理成本，使用起来也十分地轻量。

日常工作中我们常使用容器来构建一些 Golang 写的后端组件，那么构建离线源是不是也可以这样做？实践证明确实可以，我们只需要为不同的 OS 和包管理器写一个相应的 Dockerfile 即可。使用 docker build 多阶段构建的特性，可以将多个 Dockerfile 合并成一个，然后最后使用 COPY --from 的方式将这个构建的产物复制到同一个镜像中，比如提供 HTTP 的 nginx 容器，或者使用 BuildKit 的特性将这些构建产物导出为 tar 包 或者为本地目录。

## 适配 OS

根据自己的 PaaS toB 从业经验可知，目前国内的私有云客户生产环境中使用的 OS 中， CentOS 应该是最多的，其次是 Ubuntu 和 Debian。至于 RedHat 则需要付费订阅才能使用，DockerHub 上更是没有免费可使用的镜像，因此本方案无法确保适用于 RedHat。产品方面 CentOS 需要的版本只有 7.9；Ubuntu 需要支持 18.04 和 20.04；Debian 需要支持 9 和 10。因为时间和精力有限，本方案支持的 Linux 发行版和相应的版本只有 CentOS 7, Debian 9/10, Ubuntu 18.04/20.04 这五个。如果要支持其他 OS 的离线源比如 OpenSUSE，也可以参考本方案编写一个 Dockerfile 文件来实现适配。

## 构建

构建的过程十分简单，使用一个 YAML 格式的配置文件来管理不同的包管理器或 Linux 发行版安装不同的包，并在一个 Dockerfile 里完成所有的构建操作。实现源码在 [github.com/muzi502/scripts/build-packages-repo](https://github.com/muzi502/scripts/tree/master/build-packages-repo)。

```bash
build
├── Dockerfile
├── Dockerfile.centos
├── Dockerfile.debian
├── Dockerfile.ubuntu
└── packages.yaml
```

### 构建过程

使用 docker build 的方式构建离线源大致可以分为如下几个步骤：

- 在构建容器内配置 yum/apt 源，安装构建时需要工具；
- 生成系统内的 rpm/deb 包的列表和需要下载的包列表，解决一些软件包依赖的问题；
- 根据生成的包列表使用相应的包管理器工具下载需要的软件包；
- 生用相应的包管理器生成这些包的 index 文件，如 repodata 或 Packages.gz 文件；
- 将上述的构建产物 COPY 到同一个容器镜像里，比如 nginx ；也可以导出为 tar 包或目录；

### packages.yaml

这个文件用来管理不同的包管理器或者 Linux 发行版需要安装的软件包。根据不同的包管理器和发行版我们可以将这些包大致划分为 4 类。

- common：适用于一些所有包管理器中包名相同或者对版本无要求的包，比如 vim 、curl、wget 这类工具。一般情况下使用这些工具我们并不关心它的版本，并且这类包的包名在所有的包管理器中都是相同的，所以这类可以划分为公共包。
- yum/apt/dnf：适用于不同的发行版使用相同的包管理器。比如 nfs 的包，在 yum 中包名为 nfs-utils 但在 apt 中为 nfs-common，这类软件包可以划分为一类。
- OS：适用于一些该 OS 独有的包，比如安装一个 Ubuntu 中有但 Debian 中没有的包（比如 debian-builder 或 ubuntu-dev-tools）。
- OS-发行版代号：这类包的版本和发行版代号绑定在一起，比如 `docker-ce=5:19.03.15~3-0~debian-stretch。`

```yaml
common:
  - vim
  - curl
  - wget
  - tree
  - lvm2

yum:
  - nfs-utils
  - yum-utils
  - createrepo
  - centos-release-gluster
  - epel-release

apt:
  - nfs-common
  - apt-transport-https
  - ca-certificates
  - lsb-release
  - software-properties-common
  - aptitude
  - dpkg-dev

centos:
  - centos-release

debian:
  - debian-builder

debian-buster:
  - docker-ce=5:19.03.15~3-0~debian-buster

ubuntu:
  - ubuntu-dev-tools
```

在这里需要额外注意一下，在不同的包管理器之间指定包版本的方式也各不相同，比如在 yum 中如果要安装 19.03.15 版本的 docker-ce 包名为 `docker-ce-19.03.15`，而在 debian 中包名则为 `docker-ce=5:19.03.15~3-0~debian-stretch`。可以使用包管理器查看相同的一个包如 docker-ce 在不同的包管理器之前的差异，如下：

```bash
[root@centos:]# yum list docker-ce --showduplicates | grep 19.03.15
docker-ce.x86_64            3:19.03.15-3.el7                    docker-ce-stable

root@debian:/# apt-cache policy docker-ce
docker-ce:
  Installed: (none)
  Candidate: 5:19.03.15~3-0~debian-stretch
  Version table:
     5:19.03.15~3-0~debian-stretch 500
        500 https://download.docker.com/linux/debian stretch/stable amd64 Packages
```

这个版本号的问题在 kubespray 的源码中也是同样做了特殊处理，目前确实没有太好的方案来解决，只能手动维护这个版本号。

- roles/container-engine/docker/vars/redhat.yml

```yaml
---
# https://docs.docker.com/engine/installation/linux/centos/#install-from-a-package
# https://download.docker.com/linux/centos/<centos_version>>/x86_64/stable/Packages/
# or do 'yum --showduplicates list docker-engine'
docker_versioned_pkg:
  'latest': docker-ce
  '18.09': docker-ce-18.09.9-3.el7
  '19.03': docker-ce-19.03.15-3.el{{ ansible_distribution_major_version }}
  '20.10': docker-ce-20.10.5-3.el{{ ansible_distribution_major_version }}
  'stable': docker-ce-19.03.15-3.el{{ ansible_distribution_major_version }}
  'edge': docker-ce-19.03.15-3.el{{ ansible_distribution_major_version }}

docker_cli_versioned_pkg:
  'latest': docker-ce-cli
  '18.09': docker-ce-cli-18.09.9-3.el7
  '19.03': docker-ce-cli-19.03.15-3.el{{ ansible_distribution_major_version }}
  '20.10': docker-ce-cli-20.10.5-3.el{{ ansible_distribution_major_version }}

docker_package_info:
  enablerepo: "docker-ce"
  pkgs:
    - "{{ containerd_versioned_pkg[containerd_version | string] }}"
    - "{{ docker_cli_versioned_pkg[docker_cli_version | string] }}"
    - "{{ docker_versioned_pkg[docker_version | string] }}"
```

- roles/container-engine/docker/vars/ubuntu.yml

```yaml
# https://download.docker.com/linux/ubuntu/
docker_versioned_pkg:
  'latest': docker-ce
  '18.09': docker-ce=5:18.09.9~3-0~ubuntu-{{ ansible_distribution_release|lower }}
  '19.03': docker-ce=5:19.03.15~3-0~ubuntu-{{ ansible_distribution_release|lower }}
  '20.10': docker-ce=5:20.10.5~3-0~ubuntu-{{ ansible_distribution_release|lower }}
  'stable': docker-ce=5:19.03.15~3-0~ubuntu-{{ ansible_distribution_release|lower }}
  'edge': docker-ce=5:19.03.15~3-0~ubuntu-{{ ansible_distribution_release|lower }}

docker_cli_versioned_pkg:
  'latest': docker-ce-cli
  '18.09': docker-ce-cli=5:18.09.9~3-0~ubuntu-{{ ansible_distribution_release|lower }}
  '19.03': docker-ce-cli=5:19.03.15~3-0~ubuntu-{{ ansible_distribution_release|lower }}
  '20.10': docker-ce-cli=5:20.10.5~3-0~ubuntu-{{ ansible_distribution_release|lower }}

docker_package_info:
  pkgs:
    - "{{ containerd_versioned_pkg[containerd_version | string] }}"
    - "{{ docker_cli_versioned_pkg[docker_cli_version | string] }}"
    - "{{ docker_versioned_pkg[docker_version | string] }}"
```

### CentOS7

介绍完上述的包配置文件之后，接下来我们就根据这个 packages.yml 配置文件使用 Dockerfile 构建这些包的离线源。以下是构建 CentOS 7 离线源的 Dockerfile。

```dockerfile
# 使用 centos 7.9 作为 base 构建镜像
FROM centos:7.9.2009 as builder

# 定义 centos 的版本和处理器体系架构
ARG OS_VERSION=7
ARG ARCH=x86_64

# 在这里定义一些构建时需要的软件包
ARG BUILD_TOOLS="yum-utils createrepo centos-release-gluster epel-release curl"

# 安装构建工具和配置一些软件源 repo
RUN yum install -q -y $BUILD_TOOLS \
    && yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo \
    && yum makecache && yum update -y -q

# 需要安装 yq 个工具来处理 packages.yaml 配置文件
RUN curl -sL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.9.3/yq_linux_amd64 \
    && chmod a+x /usr/local/bin/yq

# 解析 packages.yml 配置文件，生成所需要的 packages.list 文件
WORKDIR /centos/$OS_VERSION/os/$ARCH
COPY packages.yaml packages.yaml

# 使用 yq 先将 YAML 文件转换成 json 格式的内容，再使用 jq 过滤出所需要的包，输出为一个列表
RUN yq eval '.common[],.yum[],.centos[]' packages.yaml | sort -u > packages.list \
    && rpm -qa >> packages.list

# 下载 packages.list 中的软件包，并生成 repo 索引文件
RUN cat packages.list | xargs yumdownloader --resolve \
    && createrepo -d .
# 将构建产物复制到一层空的镜像中，方便导出为 tar 包或目录的格式
FROM scratch
COPY --from=centos7 /centos /centos
```

在最后的一个 FROM 镜像中，这里指定的是 `scratch`，这是一个特殊的镜像名，它代表的是一个空的镜像 layer。

```dockerfile
# 将构建产物复制到一层空的镜像中，方便导出为 tar 包或目录的格式
FROM scratch
COPY --from=centos7 /centos /centos
```

也可以直接将构建出来的产物放到 nginx 容器中，这样直接运行 nginx 容器就能提供 yum/apt 源的服务

```bash
FROM nginx:1.19
COPY --from=centos7 /centos /usr/share/nginx/html
```

- 如果要构建为 tar 包或者本地目录的方式，需要为 Docker 开启 `DOCKER_BUILDKIT=1` 这个特性

```bash
# 构建为本地目录
root@debian: ~ # DOCKER_BUILDKIT=1 docker build -o type=local,dest=$PWD -f Dockerfile.centos .
# 构建为 tar 包
root@debian: ~ # DOCKER_BUILDKIT=1 docker build -o type=tar,dest=$PWD/centos7.tar -f Dockerfile.centos .
```

- 构建日志如下

```bash

[+] Building 30.9s (13/13) FINISHED
 => [internal] load .dockerignore                                                                                                                                            0.0s
 => => transferring context: 109B                                                                                                                                            0.0s
 => [internal] load build definition from Dockerfile.centos                                                                                                                  0.0s
 => => transferring dockerfile: 979B                                                                                                                                         0.0s
 => [internal] load metadata for docker.io/library/centos:7.9.2009                                                                                                           2.6s
 => [centos7 1/7] FROM docker.io/library/centos:7.9.2009@sha256:0f4ec88e21daf75124b8a9e5ca03c37a5e937e0e108a255d890492430789b60e                                             0.0s
 => [internal] load build context                                                                                                                                            0.0s
 => => transferring context: 818B                                                                                                                                            0.0s
 => CACHED [centos7 2/7] RUN yum install -q -y yum-utils createrepo centos-release-gluster epel-release curl     && yum-config-manager --add-repo https://download.docker.c  0.0s
 => [centos7 3/7] WORKDIR /centos/7/os/x86_64                                                                                                                                0.0s
 => [centos7 4/7] RUN curl -sL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.9.3/yq_linux_amd64     && chmod a+x /usr/local/bin/yq     && curl   3.2s
 => [centos7 5/7] COPY packages.yaml packages.yaml                                                                                                                           0.1s
 => [centos7 6/7] RUN yq eval packages.yaml -j | jq -r '.common[],.yum[],.centos[]' | sort -u > packages.list     && rpm -qa >> packages.list                                1.0s
 => [centos7 7/7] RUN cat packages.list | xargs yumdownloader --resolve     && createrepo -d .                                                                              21.6s
 => [stage-1 1/1] COPY --from=centos7 /centos /centos                                                                                                                        0.5s
 => exporting to client                                                                                                                                                      0.7s
 => => copying files 301.37MB
```

- 构建产物如下

```bash
root@debian:/build # tree centos
centos
└── 7
    └── os
        └── x86_64
            ├── acl-2.2.51-15.el7.x86_64.rpm
            ├── ansible-2.9.21-1.el7.noarch.rpm
            ├── at-3.1.13-24.el7.x86_64.rpm
            ├── attr-2.4.46-13.el7.x86_64.rpm
            ├── audit-libs-2.8.5-4.el7.x86_64.rpm
            ├── audit-libs-python-2.8.5-4.el7.x86_64.rpm
            ├── avahi-libs-0.6.31-20.el7.x86_64.rpm
            ├── basesystem-10.0-7.el7.centos.noarch.rpm
            ├── bash-4.2.46-34.el7.x86_64.rpm
            ……………………………………
            ├── redhat-lsb-submod-security-4.1-27.el7.centos.1.x86_64.rpm
            ├── repodata
            │   ├── 28d2fe2d1dbd9b76d3e5385d42cf628ac9fc34d69e151edfe8d134fe6ac6a6d9-primary.xml.gz
            │   ├── 5264ca1af13ec7c870f25b2a28edb3c2843556ca201d07ac681eb4af7a28b47c-primary.sqlite.bz2
            │   ├── 591d9c2d5be714356e8db39f006d07073f0e1e024a4a811d5960d8e200a874fb-other.xml.gz
            │   ├── c035d2112d55d23a72b6d006b9e86a2f67db78c0de45345e415884aa0782f40c-other.sqlite.bz2
            │   ├── cd756169c3718d77201d08590c0613ebed80053f84a2db7acc719b5b9bca866f-filelists.xml.gz
            │   ├── ed0c5a36b12cf1d4100f90b4825b93dac832e6e21f83b23ae9d9753842801cee-filelists.sqlite.bz2
            │   └── repomd.xml
            ├── yum-utils-1.1.31-54.el7_8.noarch.rpm
            └── zlib-1.2.7-19.el7_9.x86_64.rpm

4 directories, 368 files
```

### Debian9

下面是 Debian9 构建 Dockerfile，流程上和 CentOS 相差不多，只是包管理器的使用方式不太相同而已，这里就不再做详细的源码介绍。

- Dockerfile.debian

```dockerfile
FROM debian:stretch-slim as stretch
ARG OS_VERSION=stretch
ARG ARCH=amd64

ARG DEP_PACKAGES="apt-transport-https ca-certificates curl gnupg aptitude dpkg-dev"
RUN apt update -y -q \
    && apt install -y --no-install-recommends $DEP_PACKAGES \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian ${OS_VERSION} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update -y -q

WORKDIR /debian/${OS_VERSION}

RUN curl -sL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.9.3/yq_linux_amd64 \
    && chmod a+x /usr/local/bin/yq

COPY packages.yaml packages.yaml

RUN yq eval '.common[],.apt[],.debian[]' packages.yaml | sort -u > packages.list \
    && dpkg --get-selections | grep -v deinstall | cut -f1 >> packages.list

RUN chown -R _apt /debian/$OS_VERSION \
    && cat packages.list | xargs -L1 -I {} apt-cache depends --recurse --no-recommends --no-suggests \
    --no-conflicts --no-breaks --no-replaces --no-enhances {}  | grep '^\w' | sort -u | xargs apt-get download

RUN cd ../ && dpkg-scanpackages $OS_VERSION | gzip -9c > $OS_VERSION/Packages.gz

FROM scratch
COPY --from=builder /debian /debian
```

### Ubuntu

Ubuntu 离线源的制作步骤和 Debian 差不太多，只需要简单修改一下 Debian 的 Dockerfile 应该就 OK ，比如 `'s/debian/ubuntu/g'` ，毕竟 Debian 是 Ubuntu 的爸爸嘛 ～～，所以 apt 使用的方式和包名几乎一模一样，这里就不再赘述了。

### All-in-Oone

将上述几个 Linux 发行版的 Dockerfile 整合成一个，这样只需要一个 docker build 命令就能构建出所需要的所有 OS 的离线源了。

- Dockerfile

```dockerfile
# CentOS 7.9 2009
FROM centos:7.9.2009 as centos7
ARG OS_VERSION=7
ARG ARCH=x86_64
ARG BUILD_TOOLS="yum-utils createrepo centos-release-gluster epel-release curl"

RUN yum install -q -y $BUILD_TOOLS \
    && yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo \
    && yum makecache && yum update -y -q

RUN curl -sL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.9.3/yq_linux_amd64 \
    && chmod a+x /usr/local/bin/yq \
    && curl -sL -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
    && chmod a+x /usr/local/bin/jq

WORKDIR /centos/$OS_VERSION/os/$ARCH
COPY packages.yaml packages.yaml
RUN yq eval packages.yaml -j | jq -r '.common[],.yum[],.centos[]' | sort -u > packages.list \
    && rpm -qa >> packages.list
RUN cat packages.list | xargs yumdownloader --resolve \
    && createrepo -d .

# Debian 9 stretch
FROM debian:stretch-slim as stretch
ARG OS_VERSION=stretch
ARG ARCH=amd64

ARG DEP_PACKAGES="apt-transport-https ca-certificates curl gnupg aptitude dpkg-dev"
RUN apt update -y -q \
    && apt install -y --no-install-recommends $DEP_PACKAGES \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian ${OS_VERSION} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update -y -q

RUN curl -sL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.9.3/yq_linux_amd64 \
    && chmod a+x /usr/local/bin/yq \
    && curl -sL -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
    && chmod a+x /usr/local/bin/jq

WORKDIR /debian/${OS_VERSION}
COPY packages.yaml packages.yaml
RUN yq eval packages.yaml -j | jq -r '.common[],.apt[],.debian[]' | sort -u > packages.list \
    && dpkg --get-selections | grep -v deinstall | cut -f1 >> packages.list

RUN chown -R _apt /debian/$OS_VERSION \
    && cat packages.list | xargs -L1 -I {} apt-cache depends --recurse --no-recommends --no-suggests \
    --no-conflicts --no-breaks --no-replaces --no-enhances {}  | grep '^\w' | sort -u | xargs apt-get download

RUN cd ../ && dpkg-scanpackages $OS_VERSION | gzip -9c > $OS_VERSION/Packages.gz

# Debian 10 buster
FROM debian:buster-slim as buster
ARG OS_VERSION=buster
ARG ARCH=amd64

ARG DEP_PACKAGES="apt-transport-https ca-certificates curl gnupg aptitude dpkg-dev"
RUN apt update -y -q \
    && apt install -y --no-install-recommends $DEP_PACKAGES \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian ${OS_VERSION} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update -y -q

RUN curl -sL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.9.3/yq_linux_amd64 \
    && chmod a+x /usr/local/bin/yq \
    && curl -sL -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
    && chmod a+x /usr/local/bin/jq

WORKDIR /debian/${OS_VERSION}
COPY packages.yaml packages.yaml
RUN yq eval packages.yaml -j | jq -r '.common[],.apt[],.debian[]' | sort -u > packages.list \
    && dpkg --get-selections | grep -v deinstall | cut -f1 >> packages.list

RUN chown -R _apt /debian/$OS_VERSION \
    && cat packages.list | xargs -L1 -I {} apt-cache depends --recurse --no-recommends --no-suggests \
    --no-conflicts --no-breaks --no-replaces --no-enhances {}  | grep '^\w' | sort -u | xargs apt-get download

RUN cd ../ && dpkg-scanpackages $OS_VERSION | gzip -9c > $OS_VERSION/Packages.gz

# Ubuntu 18.04 bionic
FROM ubuntu:bionic as bionic
ARG OS_VERSION=bionic
ARG ARCH=amd64

ARG DEP_PACKAGES="apt-transport-https ca-certificates curl gnupg aptitude dpkg-dev"
RUN apt update -y -q \
    && apt install -y --no-install-recommends $DEP_PACKAGES \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu ${OS_VERSION} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update -y -q

RUN curl -sL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.9.3/yq_linux_amd64 \
    && chmod a+x /usr/local/bin/yq \
    && curl -sL -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
    && chmod a+x /usr/local/bin/jq

WORKDIR /ubuntu/${OS_VERSION}
COPY packages.yaml packages.yaml
RUN yq eval packages.yaml -j | jq -r '.common[],.apt[],.ubuntu[]' | sort -u > packages.list \
    && dpkg --get-selections | grep -v deinstall | cut -f1 >> packages.list

RUN chown -R _apt /ubuntu/$OS_VERSION \
    && cat packages.list | xargs -L1 -I {} apt-cache depends --recurse --no-recommends --no-suggests \
    --no-conflicts --no-breaks --no-replaces --no-enhances {}  | grep '^\w' | sort -u | xargs apt-get download

RUN cd ../ && dpkg-scanpackages $OS_VERSION | gzip -9c > $OS_VERSION/Packages.gz

# Ubuntu 20.04 focal
FROM ubuntu:focal as focal
ARG OS_VERSION=focal
ARG ARCH=amd64

ARG DEP_PACKAGES="apt-transport-https ca-certificates curl gnupg aptitude dpkg-dev"
RUN apt update -y -q \
    && apt install -y --no-install-recommends $DEP_PACKAGES \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu ${OS_VERSION} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update -y -q

RUN curl -sL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.9.3/yq_linux_amd64 \
    && chmod a+x /usr/local/bin/yq \
    && curl -sL -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
    && chmod a+x /usr/local/bin/jq

WORKDIR /ubuntu/${OS_VERSION}
COPY packages.yaml packages.yaml
RUN yq eval packages.yaml -j | jq -r '.common[],.apt[],.ubuntu[]' | sort -u > packages.list \
    && dpkg --get-selections | grep -v deinstall | cut -f1 >> packages.list

RUN chown -R _apt /ubuntu/$OS_VERSION \
    && cat packages.list | xargs -L1 -I {} apt-cache depends --recurse --no-recommends --no-suggests \
    --no-conflicts --no-breaks --no-replaces --no-enhances {}  | grep '^\w' | sort -u | xargs apt-get download

RUN cd ../ && dpkg-scanpackages $OS_VERSION | gzip -9c > $OS_VERSION/Packages.gz

FROM scratch
COPY --from=centos7 /centos /centos
COPY --from=stretch /debian /debian
COPY --from=buster /debian /debian
COPY --from=bionic /ubuntu /ubuntu
COPY --from=focal /ubuntu /ubuntu
```

## 使用

构建好了离线源之后，在部署的机器上运行一个 Nginx 服务，用于提供 HTTP 方式下载这些软件包，同时需要配置一下机器的包管理器 repo 配置文件。

- CentOS 7

```bash
[Inra-Mirror]
name=Infra Mirror Repository
baseurl=http://172.20.0.10/centos/7/
enabled=1
gpgcheck=1
```

- Debian 9 stretch

```bash
deb [trusted=yes] http://172.20.0.10:8080/debian stretch/
```

- Debian 10 buster

```
deb [trusted=yes] http://172.20.0.10:8080/debian buster/
```

- Ubuntu 18.04 bionic

```bash
deb [trusted=yes] http://172.20.0.10:8080/ubuntu bionic/
```

- Ubuntu 20.04 focal

```
deb [trusted=yes] http://172.20.0.10:8080/debian focal/
```

## GitHub Action 自动构建

准备好上面这些 Dockerfile 之后，接下来就要考虑构建的问题了。对于一个 PaaS 或者 IaaS 产品需要适配主流的 Linux 发行版，有时还需要适配 arm64 架构的机器。如果本地手动 docker build 来构建的话，效率很低。因此我们需要使用 GitHub actions 自动构建这些 rpm/deb 包的离线源，具体实现代码可参考 [k8sli/os-packages](https://github.com/k8sli/os-packages)

### 代码结构

在 build 目录里存放各种发行版的 Dockerfile。由于不同的发行版以及每个发行版的版本构建方法千差万别，因此每个发行版 OS 在一个单独的 Dockerfile 里构建。

```bash
os-packages/
├── LICENSE
├── Makefile
├── README.md
├── build
│   ├── Dockerfile.os.centos7
│   ├── Dockerfile.os.centos8
│   ├── Dockerfile.os.debian10
│   ├── Dockerfile.os.debian9
│   ├── Dockerfile.os.fedora33
│   ├── Dockerfile.os.fedora34
│   ├── Dockerfile.os.ubuntu1804
│   └── Dockerfile.os.ubuntu2004
├── packages.yaml
└── repos
    ├── CentOS-All-in-One.repo
    ├── Debian-buster-All-in-One.list
    ├── Fedora-All-in-One.repo
    └── Ubuntu-focal-All-in-One.list
```

### Workflow

- 触发方式

```yaml
---
name: Build os-packages image
on:
  push:
    tag:
      - 'v*'
    branch: [main, release-*, master]
  workflow_dispatch:
```

- 全局变量

```yaml
env:
  # 镜像仓库域名
  IMAGE_REGISTRY: "ghcr.io"
  # 镜像仓库用户名
  REGISTRY_USER: "${{ github.repository_owner }}"
  # 镜像仓库登录凭据
  REGISTRY_TOKEN: "${{ secrets.GITHUB_TOKEN }}"
  # 镜像仓库推送 repo
  IMAGE_REPO: "ghcr.io/${{ github.repository_owner }}"
```

- 构建矩阵，这些 job 会各自运行一个 runner 来进行并行构建

```yaml
jobs:
  build:
    runs-on: ubuntu-20.04
    strategy:
      fail-fast: false
      matrix:
        include:
          - name: ubuntu-bionic
            image_name: os-packages-ubuntu1804
            dockerfile: build/Dockerfile.os.ubuntu1804
          - name: ubuntu-focal
            image_name: os-packages-ubuntu2004
            dockerfile: build/Dockerfile.os.ubuntu2004
          - name: centos-7
            image_name: os-packages-centos7
            dockerfile: build/Dockerfile.os.centos7
          - name: centos-8
            image_name: os-packages-centos8
            dockerfile: build/Dockerfile.os.centos8
          - name: debian-buster
            image_name: os-packages-debian10
            dockerfile: build/Dockerfile.os.debian10
          - name: debian-stretch
            image_name: os-packages-debian9
            dockerfile: build/Dockerfile.os.debian9
```

- checkout 代码，配置 buildx 构建环境

```yaml
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        with:
          # fetch all git repo tag for define image tag
          fetch-depth: 0

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v1

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1

      - name: Log in to GitHub Docker Registry
        uses: docker/login-action@v1
        with:
          registry: ${{ env.IMAGE_REGISTRY }}
          username: ${{ env.REGISTRY_USER }}
          password: ${{ env.REGISTRY_TOKEN }}
```

- 通过 `git describe --tags` 方式生成一个唯一的镜像 tag

```yaml
      - name: Prepare for build images
        shell: bash
        run: |
          git describe --tags --always | sed 's/^/IMAGE_TAG=/' >> $GITHUB_ENV
```

- 构建镜像并 push 到镜像仓库，后面打包一个 All-in-one 的包时候会用到

```yaml
      - name: Build and push os-package images
        uses: docker/build-push-action@v2
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          file: ${{ matrix.dockerfile }}
          platforms: linux/amd64,linux/arm64
          tags: |
            ${{ env.IMAGE_REPO }}/${{ matrix.image_name }}:${{ env.IMAGE_TAG }}
```

- 生成新的 Dockerfile，导出镜像到本地目录

```yaml
      - name: Gen new Dockerfile
        shell: bash
        run: |
          echo -e "FROM scratch\nCOPY --from=${{ env.IMAGE_REPO }}/${{ matrix.image_name }}:${{ env.IMAGE_TAG }} / /" > Dockerfile

      - name: Build kubeplay image to local
        uses: docker/build-push-action@v2
        with:
          context: .
          file: Dockerfile
          platforms: linux/amd64,linux/arm64
          outputs: type=local,dest=./
```

- 将最终构建产物打包上传到 GitHub release

```yaml
      - name: Prepare for upload package
        shell: bash
        run: |
          mv linux_amd64/resources resources
          tar -I pigz -cf resources-${{ matrix.image_name }}-${IMAGE_TAG}-amd64.tar.gz resources --remove-files
          mv linux_arm64/resources resources
          tar -I pigz -cf resources-${{ matrix.image_name }}-${IMAGE_TAG}-arm64.tar.gz resources --remove-files
          sha256sum resources-${{ matrix.image_name }}-${IMAGE_TAG}-{amd64,arm64}.tar.gz > resources-${{ matrix.image_name }}-${IMAGE_TAG}.sha256sum.txt

      - name: Release and upload packages
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          files: |
            resources-${{ matrix.image_name }}-${{ env.IMAGE_TAG }}.sha256sum.txt
            resources-${{ matrix.image_name }}-${{ env.IMAGE_TAG }}-amd64.tar.gz
            resources-${{ matrix.image_name }}-${{ env.IMAGE_TAG }}-arm64.tar.gz
```

- All-in-one 合并所有构建的镜像

```yaml
  upload:
    needs: [build]
    runs-on: ubuntu-20.04
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        with:
          # fetch all git repo tag for define image tag
          fetch-depth: 0

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v1

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1

      - name: Log in to GitHub Docker Registry
        uses: docker/login-action@v1
        with:
          registry: ${{ env.IMAGE_REGISTRY }}
          username: ${{ env.REGISTRY_USER }}
          password: ${{ env.REGISTRY_TOKEN }}

      - name: Prepare for build images
        shell: bash
        run: |
          git describe --tags --always | sed 's/^/IMAGE_TAG=/' >> $GITHUB_ENV
          source $GITHUB_ENV
          echo "FROM scratch" > Dockerfile
          echo "COPY --from=${{ env.IMAGE_REPO }}/os-packages-ubuntu1804:${IMAGE_TAG} / /" >> Dockerfile
          echo "COPY --from=${{ env.IMAGE_REPO }}/os-packages-ubuntu2004:${IMAGE_TAG} / /" >> Dockerfile
          echo "COPY --from=${{ env.IMAGE_REPO }}/os-packages-centos7:${IMAGE_TAG} / /" >> Dockerfile
          echo "COPY --from=${{ env.IMAGE_REPO }}/os-packages-centos8:${IMAGE_TAG} / /" >> Dockerfile
          echo "COPY --from=${{ env.IMAGE_REPO }}/os-packages-debian9:${IMAGE_TAG} / /" >> Dockerfile
          echo "COPY --from=${{ env.IMAGE_REPO }}/os-packages-debian10:${IMAGE_TAG} / /" >> Dockerfile

      - name: Build os-packages images to local
        uses: docker/build-push-action@v2
        with:
          context: .
          file: Dockerfile
          platforms: linux/amd64,linux/arm64
          outputs: type=local,dest=./

      - name: Prepare for upload package
        shell: bash
        run: |
          mv linux_amd64/resources resources
          tar -I pigz -cf resources-os-packages-all-${IMAGE_TAG}-amd64.tar.gz resources --remove-files
          mv linux_arm64/resources resources
          tar -I pigz -cf resources-os-packages-all-${IMAGE_TAG}-arm64.tar.gz resources --remove-files
          sha256sum resources-os-packages-all-${IMAGE_TAG}-{amd64,arm64}.tar.gz > resources-os-packages-all-${IMAGE_TAG}.sha256sum.txt

      - name: Release and upload packages
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          files: |
            resources-os-packages-all-${{ env.IMAGE_TAG }}.sha256sum.txt
            resources-os-packages-all-${{ env.IMAGE_TAG }}-amd64.tar.gz
            resources-os-packages-all-${{ env.IMAGE_TAG }}-arm64.tar.gz
```

## 优化

### Dockerfile

可以考虑将 Dockerfile 中的构建过程合并成一个 shell 脚本，然后在 Dockerfile 中调用这个脚本即可，这样可优化 Dockerfile 代码的可维护性，同时后续适配多种 OS 的时候也可以复用部分相同的代码，但这样可能会导致 docker build 缓存的失效问题。

当然也可以使用脚本将多个 Dockerfile 合并成一个，如下：

```shell
# Merge all Dockerfile.xx to an all-in-one file
ls Dockerfile.* | xargs -L1 grep -Ev 'FROM scratch|COPY --from=' > Dockerfile
echo "FROM scratch" >> Dockerfile
ls Dockerfile.* | xargs -L1 grep 'COPY --from=' >> Dockerfile
```

其实如果使用 GitHub actions 来构建的话，就不需要进行合并了，使用 actions 矩阵构建的特性可并行构建。

### Package version

对于一些版本中包含 Linux 发行版本代号的包来讲，手动维护这个代号不太方便，可以考虑将它魔改成占位变量的方式，在构建容器内生成 package.list 文件后统一使用 sed 把这些占位的变量给替换一下，如下：

```bash
apt:
  - docker-ce=5:19.03.15~3-0~__ID__-__VERSION_CODENAME__
```

使用 sed 处理一下生成的 packages.list 中的这些占位符变量

```bash
sed -i "s|__ID__|$(sed -n 's|^ID=||p' /etc/os-release)|;s|__VERSION_CODENAME__|$(sed -n 's|^VERSION_CODENAME=||p' /etc/os-release)|" packages.list
```

虽然这样做很不美观，但这种方式确实可行 😂，最终能够的到正确的版本号。总之我们尽量地少维护一些包的版本，比如使用这种方式就可以将某个版本的 docker-ce 包放在配置文件的 apt 中，而不是 debian/ubuntu 中，通过一些环境变量或者 shell 脚本自动添加上这些特殊项，这样能减少一些维护成本。

## 踩坑

- Fedora 指定包的版本时，也需要加上 Fedora 的版本
- CentOS 7 和 CentOS 8 有些包的包名不同，需要单独处理一下
- CentOS 7 和 CentOS 8 构建方式不同，最后生成 repodata 的时候 CentOS 8 需要单独处理一下
- Fedora 33 和 Fedora34 使用 GitHub action 构建的时候 arm64 架构的会一直卡住，是由于 buildx 的 bug 所致，因此只给出了 Dockerfile，并未放在 GitHub actions 构建流水线中。

## 参考

- [aptly.info](https://www.aptly.info/tutorial/mirror/)
- [jq 常用操作](https://mozillazg.com/2018/01/jq-use-examples-cookbook.html)
- [yq 之读写篇](https://lyyao09.github.io/2019/08/02/tools/The-usage-of-yq-read-write/)
- [Build images with BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/)
- [kubernetes-sigs/kubespray/pull/6766](https://github.com/kubernetes-sigs/kubespray/pull/6766)
- [万字长文：彻底搞懂容器镜像构建](https://moelove.info/2021/03/14/%E4%B8%87%E5%AD%97%E9%95%BF%E6%96%87%E5%BD%BB%E5%BA%95%E6%90%9E%E6%87%82%E5%AE%B9%E5%99%A8%E9%95%9C%E5%83%8F%E6%9E%84%E5%BB%BA/)
- [为 CentOS 与 Ubuntu 制作离线本地源](https://www.xiaocoder.com/2017/09/12/offline-local-source/)
