---
title: 无网环境中如何愉快地部署 K8s 集群
date: 2021-08-24
updated: 2021-08-24
slug:
categories:
  - 技术
tag:
  - k8s
copyright: true
comment: true
---

在企业私有云环境当中，出于对数据安全的考虑以及满足等保的要求，会对内部环境中的服务器做出严格的限制。尤其是对于网络的要求，一般来讲生产环境都会禁止访问外部网络。开发人员访问生产环境也必须通过堡垒机或者其他方式进行安全审计登录。在这种无网（无法访问公网）的环境中，想要部署好一个 K8s 集群并不是一件简单的事儿。

市面上 K8s 部署工具也多不胜数，主流一点的有如下几种：

|                           Item                            | Language | Start | Fork | 离线部署支持情况                                     |
| :-------------------------------------------------------: | :------: | :---: | :--: | :--------------------------------------------------- |
|        [kops](https://github.com/kubernetes/kops)         |  Golang  | 13.2k | 4.1k | 不支持                                               |
| [kubespray](https://github.com/kubernetes-sigs/kubespray) | Ansible  | 11.1k | 4.7k | 支持，需自行构建安装包                               |
|       [kubeasz](https://github.com/easzlab/kubeasz)       | Ansible  | 7.2k  | 2.7k | 支持，需自行构建安装包                               |
|         [sealos](https://github.com/fanux/sealos)         |  Golang  | 4.1k  | 790  | 支持，需收费                                         |
|           [RKE](https://github.com/rancher/rke)           |  Golang  | 2.5k  | 480  | 不支持，需自行安装 docker                            |
|     [kubekey](https://github.com/kubesphere/kubekey)      |  Golang  |  471  | 155  | 部分支持，仅镜像可离线                               |
|        [sealer](https://github.com/alibaba/sealer)        |  Golang  |  503  | 112  | 支持，源自 [sealos](https://github.com/fanux/sealos) |

无网环境部署 K8s 往往是作为一个商业服务或者产品来出售的，很少有开源的解决方案，或者虽然提供了离线部署的方案，但想要操作起来十分繁琐，又或者只提供了部署离线部署的方式，一些特殊的资源还是要访问公网来或者。无法在一个完全无法访问公网的环境中进行部署。

## 离线资源

总体来讲使用部署一个 kubernetes 集群大致需要依赖如下三种在线的资源：

- 系统 OS 的 rpm/deb 包：如 docker-ce、containerd、ipvsadm 等；
- 二进制文件：如 kubelet、kubectl、kubeadm、helm、crictl 等；
- 组件容器镜像：如 kube-apiserver、kube-proxy、cordons、calico、flannel 等；

###  OS packages

这类属于 OS 系统层面的依赖，根据不同系统或者支持的功能需要使用相应的包管理器安装相应的依赖包。

- kubernetes 组件依赖

```bash
- conntrack           # kube-proxy 使用 ipvs 模式需要
- ipset               # kube-proxy 使用 ipvs 模式需要
- ipvsadm             # kube-proxy 使用 ipvs 模式需要
- socat               # 用于 port forwarding
```

- 部署依赖

```bash
- rsync               # 分发证书等配置文件需要
- ebtables            # kubeadm 依赖工具
- ethtool             # kubeadm 依赖工具
- chrony              # 时钟同步工具，部署前节点的时候必须一致，不然证书或者 CNI 插件会出现问题
```

- CRI 容器运行运行时

```bash
- containerd.io       # 可单独安装/docker-ce 依赖
- docker-ce           # docker-ce
- libseccomp          # 安装 containerd 需要
- nvidia-container-runtime # 支持 GPU 时需要依赖
```

- 存储客户端依赖

```bash
- nfs-utils/nfs-common# 挂载nfs 共享文件需要 (创建基于 nfs 的PV 需要)
- ceph-common         # ceph 客户端安装包，创建基于 ceph 的 pv 需要
- lvm2                # 创建基于 ceph 的 pv 需要
- glusterfs-client    # 创建基于 glusterfs 的 pv 需要
- glusterfs-common    # 创建基于 glusterfs 的 pv 需要
- cifs-utils          # 创建基于 cifs 的 pv 需要
- fuse                # ceph 或者其他存储客户端依赖
```

想要解决上面这些依赖项十分棘手，也是离线部署场景下最难的一部分，至今并没有一个成熟的方案实现这些依赖的离线部署，基本上所有的 k8s 部署工具都没有提供这些包的离线安装方式。

在 [sealos](https://github.com/fanux/sealos) 和中就极力避免使用包管理器来安装依赖，比如安装 containerd 时的依赖 libseccomp 使用的是编译好的 .so 文件的方式，但这种方式并不通用；安装 docker 的方式也是使用二进制的方式，并不是 docker 官方所建议的使用包管理器安装的方式。

```bash
$ tar -tf kube1.20.0.tar.gz
kube/
kube/lib64/
kube/lib64/README.md
kube/lib64/libseccomp.so.2
kube/lib64/libseccomp.so.2.3.1
```

实际上任何部署工具都会对系统 rpm/deb 包都会有不同程度上的依赖，有一部分依赖可以像 [sealos](https://github.com/fanux/sealos)  这样通过一些投机取巧的方式去规避。但并不是所有的都能规避的，比如提供挂载 PV 需要依赖的存储客户端（nfs-common/nfs-utils，lvm2，gluster-client）这些包，就很难像 sealos 这样去规避掉。

当然如果这些前置的依赖在部署工具之外手动解决或者让用户自行去解决，那么使用 [sealos](https://github.com/fanux/sealos)  这种极其轻量的工具来部署是再适合不过的了，但对于一些 PaaS toB 的产品而言，让用户自己去手动解决这些依赖恐怕不太好。

在 kubekey 中一些依赖项目则是要求用户自己自行安装，并没有提供离线安装的方式：

> - 建议您使用干净的操作系统（不安装任何其他软件），否则可能会有冲突。
> - 请确保每个节点的硬盘至少有 **100G**。
> - 所有节点必须都能通过 `SSH` 访问。
> - 所有节点时间同步。
> - 所有节点都应使用 `sudo`/`curl`/`openssl`。
>
> KubeKey 能够同时安装 Kubernetes 和 KubeSphere。根据要安装的 Kubernetes 版本，需要安装的依赖项可能会不同。您可以参考下方列表，查看是否需要提前在您的节点上安装相关依赖项。
>
> | 依赖项      | Kubernetes 版本 ≥ 1.18 | Kubernetes 版本 < 1.18 |
> | :---------- | :--------------------- | :--------------------- |
> | `socat`     | 必须                   | 可选但建议             |
> | `conntrack` | 必须                   | 可选但建议             |
> | `ebtables`  | 可选但建议             | 可选但建议             |
> | `ipset`     | 可选但建议             | 可选但建议             |
>
> 备注
>
> - 在离线环境中，您可以使用私有包、RPM 包（适用于 CentOS）或者 Deb 包（适用于 Debian）来安装这些依赖项。
> - 建议您事先创建一个操作系统镜像文件，并且安装好所有相关依赖项。这样，您便可以直接使用该镜像文件在每台机器上安装操作系统，提高部署效率，也不用担心任何依赖项问题。
>
> 您的集群必须有一个可用的容器运行时。在离线环境中创建集群之前，您必须手动安装 Docker 或其他容器运行时。

在 《[使用 docker build 制作 yum/apt 离线源](https://blog.k8s.li/make-offline-mirrors.html)》文章中曾提出过使用 docker build 来制作 yum/apt 离线源的方案，可以解决解决这些依赖问题，并且经过两三个月的开发测试，适配了多种发行版屡试不爽。因此我们选择使用这种方案解决系统包依赖的难题。

### files

一些部署过程中需要的二进制文件，如下：

```bash
- kubelet
- kubeadm
- kubectl
- etcd            # systemd 方式部署 etcd 时需要的安装包
- crictl          # k8s 官方的 CRI CLI 工具
- calicoctl       # calico 的 CLI 工具
- helm            # helm 二进制安装包
- nerdctl         # containerd 的 CLI 工具
- cni-plugins     # CNI 插件
- cuda            # GPU 依赖
- nvidia_driver   # GPU 驱动
```

- 在 kubekey 的源码当中，是将所有二进制文件的 URL 硬编码在代码当中的，要修改这些内容必须修改源码重新编译才行，然而重新编译 kubekey 的代码必须访问公网才行，这就十分头疼。

```golang
// FilesDownloadHTTP defines the kubernetes' binaries that need to be downloaded in advance and downloads them.
func FilesDownloadHTTP(mgr *manager.Manager, filepath, version, arch string) error {
	kkzone := os.Getenv("KKZONE")
	etcd := files.KubeBinary{Name: "etcd", Arch: arch, Version: kubekeyapiv1alpha1.DefaultEtcdVersion}
	kubeadm := files.KubeBinary{Name: "kubeadm", Arch: arch, Version: version}
	kubelet := files.KubeBinary{Name: "kubelet", Arch: arch, Version: version}
	kubectl := files.KubeBinary{Name: "kubectl", Arch: arch, Version: version}
	kubecni := files.KubeBinary{Name: "kubecni", Arch: arch, Version: kubekeyapiv1alpha1.DefaultCniVersion}
	helm := files.KubeBinary{Name: "helm", Arch: arch, Version: kubekeyapiv1alpha1.DefaultHelmVersion}

	etcd.Path = fmt.Sprintf("%s/etcd-%s-linux-%s.tar.gz", filepath, kubekeyapiv1alpha1.DefaultEtcdVersion, arch)
	kubeadm.Path = fmt.Sprintf("%s/kubeadm", filepath)
	kubelet.Path = fmt.Sprintf("%s/kubelet", filepath)
	kubectl.Path = fmt.Sprintf("%s/kubectl", filepath)
	kubecni.Path = fmt.Sprintf("%s/cni-plugins-linux-%s-%s.tgz", filepath, arch, kubekeyapiv1alpha1.DefaultCniVersion)
	helm.Path = fmt.Sprintf("%s/helm", filepath)

	if kkzone == "cn" {
		etcd.Url = fmt.Sprintf("https://kubernetes-release.pek3b.qingstor.com/etcd/release/download/%s/etcd-%s-linux-%s.tar.gz", etcd.Version, etcd.Version, etcd.Arch)
		kubeadm.Url = fmt.Sprintf("https://kubernetes-release.pek3b.qingstor.com/release/%s/bin/linux/%s/kubeadm", kubeadm.Version, kubeadm.Arch)
		kubelet.Url = fmt.Sprintf("https://kubernetes-release.pek3b.qingstor.com/release/%s/bin/linux/%s/kubelet", kubelet.Version, kubelet.Arch)
		kubectl.Url = fmt.Sprintf("https://kubernetes-release.pek3b.qingstor.com/release/%s/bin/linux/%s/kubectl", kubectl.Version, kubectl.Arch)
		kubecni.Url = fmt.Sprintf("https://containernetworking.pek3b.qingstor.com/plugins/releases/download/%s/cni-plugins-linux-%s-%s.tgz", kubecni.Version, kubecni.Arch, kubecni.Version)
		helm.Url = fmt.Sprintf("https://kubernetes-helm.pek3b.qingstor.com/linux-%s/%s/helm", helm.Arch, helm.Version)
		helm.GetCmd = mgr.DownloadCommand(helm.Path, helm.Url)
	} else {
		etcd.Url = fmt.Sprintf("https://github.com/coreos/etcd/releases/download/%s/etcd-%s-linux-%s.tar.gz", etcd.Version, etcd.Version, etcd.Arch)
		kubeadm.Url = fmt.Sprintf("https://storage.googleapis.com/kubernetes-release/release/%s/bin/linux/%s/kubeadm", kubeadm.Version, kubeadm.Arch)
		kubelet.Url = fmt.Sprintf("https://storage.googleapis.com/kubernetes-release/release/%s/bin/linux/%s/kubelet", kubelet.Version, kubelet.Arch)
		kubectl.Url = fmt.Sprintf("https://storage.googleapis.com/kubernetes-release/release/%s/bin/linux/%s/kubectl", kubectl.Version, kubectl.Arch)
		kubecni.Url = fmt.Sprintf("https://github.com/containernetworking/plugins/releases/download/%s/cni-plugins-linux-%s-%s.tgz", kubecni.Version, kubecni.Arch, kubecni.Version)
		helm.Url = fmt.Sprintf("https://get.helm.sh/helm-%s-linux-%s.tar.gz", helm.Version, helm.Arch)
		getCmd := mgr.DownloadCommand(fmt.Sprintf("%s/helm-%s-linux-%s.tar.gz", filepath, helm.Version, helm.Arch), helm.Url)
		helm.GetCmd = fmt.Sprintf("%s && cd %s && tar -zxf helm-%s-linux-%s.tar.gz && mv linux-%s/helm . && rm -rf *linux-%s*", getCmd, filepath, helm.Version, helm.Arch, helm.Arch, helm.Arch)
	}
}
```

另外 kubekey 在安装 docker 时，使用的是 docker 官方的脚本来安装的，并没有进行版本的管理，安装的 docker 版本都是最新的 stable 版本，但这个版本和 k8s 官方推荐的版本并不一致。离线部署的情况下也需要自行解决 docker 安装的问题。

- 在 kubespray 中，所有二进制文件的 URL 都是通过变量的方式定义的，想要做到离线部署十分简单，只需要通过 ansible 变量优先级的特性，将它们在 group_vars  覆盖即可。比如这样：

```yaml
# Download URLs
kubelet_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubelet"
kubectl_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubectl"
kubeadm_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubeadm"
```

在构建安装包的时候，将 download_url 变量设置为 `https://` ，在部署的时候将 `download_url` 设置为内网 文件服务器服务器的 URL，比如 `https://172.20.0.25:8080/files`。这样就可以实现文件离线资源构建和部署使用的统一，解决了维护成本。

### images

一些如 kube-proxy、kube-apiserver、coredns、calico 组件镜像：

```bash
k8s.gcr.io/kube-apiserver:v1.20.7
k8s.gcr.io/kube-controller-manager:v1.20.7
k8s.gcr.io/kube-proxy:v1.20.7
k8s.gcr.io/kube-registry-proxy:0.4
k8s.gcr.io/kube-scheduler:v1.20.7
k8s.gcr.io/pause:3.3
k8s.gcr.io/coredns:1.7.0
k8s.gcr.io/cpa/cluster-proportional-autoscaler-amd64:1.8.3
k8s.gcr.io/dns/k8s-dns-node-cache:1.17.1
```

[sealos](https://github.com/fanux/sealos) 将这些镜像使用 docker save 的方式打包成一个 tar 包，在部署的时候使用 docker load 的方式将镜像导入到 docker 存储当中。但这样做又一个比较明显的限制就是kube-apiserver 的 admission 准入控制中不能加入 `AlwaysPullImages` 的特性，不然的 pod 重新调度或者重启之后可能无法拉取镜像导致启动失败。在多租户场景下，出于安全的考虑  `AlwaysPullImages` 准入控制往往是要开启的。因此 [sealos](https://github.com/fanux/sealos) 并不适用于多租户或者对此有要求的环境中。

> 该准入控制器会修改每一个新创建的 Pod 的镜像拉取策略为 Always 。 这在多租户集群中是有用的，这样用户就可以放心，他们的私有镜像只能被那些有凭证的人使用。 如果没有这个准入控制器，一旦镜像被拉取到节点上，任何用户的 Pod 都可以通过已了解到的镜像 的名称（假设 Pod 被调度到正确的节点上）来使用它，而不需要对镜像进行任何授权检查。 当启用这个准入控制器时，总是在启动容器之前拉取镜像，这意味着需要有效的凭证。

[kubekey 官方的文档](https://kubesphere.io/docs/installing-on-linux/introduction/air-gapped-installation/) 中有提到组件镜像离线部署的方式，不过十分繁琐，在 [Offline installation is too troublesome #597](https://github.com/kubesphere/kubekey/issues/597) 中也有人吐槽这个问题 😂。

在私有云环境中，一般都会有镜像仓库比如 harbor 或者 docker registry 用于存放业务组件镜像或者一些其他平台依赖的镜像。在部署kubernetes 集群的时候我们可以将部署依赖的镜像导入到已经存在的镜像仓库中，或者在一个节点上部署一个镜像仓库。再加上 dockerhub 自动去年开始就加入了 pull 镜像次数的限制，如果直接使用 dockerhub 上面的镜像来部署集群，很有可能会导致拉镜像失败的问题。因此在离线部署的场景下我们需要将部署所依赖的镜像制作成离线的方式。可以像  [sealos](https://github.com/fanux/sealos) 那样使用 docker save 和 docker load 的方式，也可以像 kubekey 那样提供一个镜像列表，将镜像导入到已经存在的镜像仓库当中。

## 打包/部署设计



上面简单梳理了一下部署 k8s 集群过程中所依赖的的在线资源，以及如何将它们制作成离线资源的一些分析。提及的部署工具各有各的优缺点，针对以下两种不同的场景可以选择不同的部署工具。

如果仅仅是部署一个简单的 k8s 集群，对集群没有太多定制化的需求，那么使用 [sealos](https://github.com/fanux/sealos) 是最佳的选择，只不过它是收费的 😂。如果动手能力强的话，可以根据它的安装包的目录结构使用 GitHub action 来构建，实现起来也不是很难。

```bash
$ tar -tf kube1.20.0.tar.gz
kube/
kube/lib64/
kube/lib64/README.md
kube/lib64/libseccomp.so.2
kube/lib64/libseccomp.so.2.3.1
kube/shell/
kube/shell/containerd.sh
kube/shell/init.sh
kube/shell/master.sh
kube/README.md
kube/bin/
kube/bin/kubelet
kube/bin/kubectl
kube/bin/conntrack
kube/bin/kubeadm
kube/bin/kubelet-pre-start.sh
kube/conf/
kube/conf/kubeadm.yaml
kube/conf/kubelet.service
kube/conf/calico.yaml
kube/conf/10-kubeadm.conf
kube/conf/net/
kube/conf/net/calico.yaml
kube/containerd/
kube/containerd/README.md
kube/containerd/cri-containerd-cni-linux-amd64.tar.gz
kube/images/
kube/images/images.tar
kube/images/README.md
```

如果是对集群有特殊的要求，比如基于 Kubernetes 的 PaaS 产品，需要在部署节点安装平台本身需要的一些依赖，如存储客户端、GPU 驱动、以及适配国产化 OS 等，那么选择 [kubespray](https://github.com/kubernetes-sigs/kubespray) 比较合适，也是本文选用的方案。

由于部署依赖的二进制文件和镜像大都存放在 GitHub 、dockerhub、gcr.io、quay.io 等国外的平台上，由于众所周知的网络原因，在国内下载和访问将有一定的限制。因此我们选择使用 GitHub Actions 来完成整个离线资源的构建。GitHub 托管的 runner 运行在国外的机房当中，可以很顺畅地获取构这些资源。

选择好的构建场所我们再将这些离线资源进行拆分，目的是为了实现各个离线资源之间的结偶，主要拆分成如下几个模块。

| 模块             | 用途                          | 构建方式        | 运行/使用方式            |
| ---------------- | ----------------------------- | --------------- | ------------------------ |
| compose          | 部署 nginx 和 registry 服务   | skopeo copy     | nerdctl compose          |
| Kubespray        | 用于部署/扩缩容 k8s 集群      | Dockerfile      | 容器或者 pod             |
| os-tools         | 部署 compose 时的一些依赖工具 | Dockerfile 下载 | 二进制安装               |
| os-packages      | 提供 rpm/deb 离线源           | Dockerfile      | nginx 提供 http 方式下载 |
| kubespray-files  | 提供二进制文件依赖            | Dockerfile 下载 | nginx 提供 http 方式下载 |
| kubespray-images | 提供组件镜像                  | skopeo sync     | registry 提供镜像下载    |

### compose

compose 里面主要运两个服务 nginx 和 registry，这两个我们依旧是容器化以类似 docker-compose 的方式来部署，而所依赖的也只有两个镜像而已。对于镜像的构建我们使用 docker save 或者 skopeo copy 的方式来构建即可

### os-packages

- Dockerfile

```dockerfile
FROM centos:7.9.2009 as os-centos7
ARG OS_VERSION=7
ARG DOCKER_MIRROR_URL="https://download.docker.com"
ARG BUILD_TOOLS="yum-utils createrepo epel-release"

RUN yum install -q -y ${BUILD_TOOLS} \
    && yum-config-manager --add-repo ${DOCKER_MIRROR_URL}/linux/centos/docker-ce.repo \
    && yum makecache \
    && yum update -y -q

WORKDIR /centos/$OS_VERSION/os
COPY packages.yaml .
COPY --from=mikefarah/yq:4.11.1 /usr/bin/yq /usr/bin/yq
RUN yq eval '.common[],.yum[],.centos7[],.kubespray.common[],.kubespray.yum[]' packages.yaml | sort -u > packages.list \
    && rpm -qa >> packages.list

RUN ARCH=$(uname -m) \
    && mkdir -p ${ARCH} \
    && cd ${ARCH} \
    && cat ../packages.list | xargs yumdownloader --resolve \
    && createrepo -d .

FROM scratch
COPY --from=os-centos7 /centos /centos
```

- packages.yaml 配置文件

```yaml
---
kubespray:
  common:
    - curl
    - rsync
    - socat
    - unzip
    - e2fsprogs
    - xfsprogs
    - ebtables
    - bash-completion
    - ipvsadm
    - ipset
    - conntrack

  yum:
    - nss
    - libselinux-python
    - device-mapper-libs
  apt:
    - python-apt
    - python3-apt
    - aufs-tools
    - apt-transport-https
    - software-properties-common

common:
  - cifs-utils
  - lsof
  - lvm2
  - openssl
  - sshpass
  - vim
  - wget
  - ethtool
  - net-tools
  - rsync
  - chrony

yum:
  - nfs-utils
  - yum-utils
  - createrepo
  - epel-release
  - nc
  - httpd-tools

apt:
  - nfs-common
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release
  - aptitude
  - dpkg-dev
  - gnupg2
  - netcat
  - apache2-utils

centos7:
  - containerd.io-1.4.6

ubuntu:
  - containerd.io=1.4.6-1

debian10:
  - containerd.io=1.4.6-1
```

### kubespray

- kubespray BASE 镜像

```

```

- kubespray 镜像

```

```

- 集群部署入口 run.sh

将集群部署、移除、扩缩容等操作封装成一个入口的脚本，提供外部工具调用

```

```

- 分层部署

为了能和 kubespray 上游的代码尽量保持同步和兼容，我们在这里引入分层部署的概念。即将集群部署分成若干个层次，每个层之间相互独立。然后在各个 playbook 里因此我们增加的修改。

```

```

### kubespray-files

- 生成文件列表

### kubespray-images

- 生成镜像列表

### build packages

## 安装方式

### install.sh

```bash
#!/usr/bin/env bash
INSTALL_TYPE=$1
: ${INSTALL_TYPE:=all}

# Common utilities, variables and checks for all scripts.
set -o errexit
set -o nounset
set -o pipefail

# Gather variables about bootstrap system
USR_BIN_PATH=/usr/local/bin
export PATH="${PATH}:${USR_BIN_PATH}"
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')

# Define glob variables
KUBE_ROOT="$(cd "$(dirname "$0")" && pwd)"
CERTS_DIR="${KUBE_ROOT}/config/certs"
CONFIG_FILE="${KUBE_ROOT}/config.yaml"
CA_CONFIGFILE="${KUBE_ROOT}/config/rootCA.cnf"
COMPOSE_YAML_FILE="${KUBE_ROOT}/compose.yaml"
IMAGES_DIR="${KUBE_ROOT}/resources/images"
COMPOSE_CONFIG_DIR="${KUBE_ROOT}/config/compose"
OUTPUT_ENV_FILE="${KUBE_ROOT}/.install-env.sh"
RESOURCES_NGINX_DIR="${KUBE_ROOT}/resources/nginx"
KUBESPRAY_CONFIG_DIR="${KUBE_ROOT}/config/kubespray"
INSTALL_STEPS_FILE="${KUBESPRAY_CONFIG_DIR}/.install_steps"

# Include all functions from library/*.sh
for file in ${KUBE_ROOT}/library/*.sh; do source ${file}; done

# Gather os-release variables
if ! source /etc/os-release; then
  errorlog "Every system that we officially support has /etc/os-release"
  exit 1
fi

if [ ! -f ${CONFIG_FILE} ]; then
  errorlog "The ${CONFIG_FILE} file is not existing"
  exit 1
fi

deploy_compose(){
  case ${ID} in
    Debian|debian)
      system::debian::config_repo
      ;;
    CentOS|centos)
      system::centos::disable_selinux
      system::centos::config_repo
      ;;
    Ubuntu|ubuntu)
      system::ubuntu::config_repo
      ;;
    *)
      errorlog "Not support system: ${ID}"
      exit 1
      ;;
  esac
  system::disable_firewalld
  system::install_pkgs
  common::install_tools
  common::rudder_config
  common::update_hosts
  common::generate_domain_certs
  common::load_images
  common::compose_up
  common::health_check
  system::install_chrony
}

main(){
  case ${INSTALL_TYPE} in
    all)
      deploy_compose
      common::push_kubespray_image
      common::run_kubespray "bash /kubespray/run.sh deploy-cluster"
      ;;
    compose)
      deploy_compose
      ;;
    cluster)
      common::rudder_config
      common::push_kubespray_image
      common::run_kubespray "bash /kubespray/run.sh deploy-cluster"
      ;;
    remove)
      common::rudder_config
      remove::remove_cluster
      remove::remove_compose
      ;;
    remove-cluster)
      common::rudder_config
      remove::remove_cluster
      ;;
    remove-compose)
      common::rudder_config
      remove::remove_compose
      ;;
    add-nodes)
      common::run_kubespray "bash /kubespray/run.sh add-node $2"
      ;;
    remove-node)
      common::run_kubespray "bash /kubespray/run.sh remove-node $2"
      ;;
    health-check)
      common::health_check
      ;;
    debug)
      common::run_kubespray "bash"
      ;;
    -h|--help|help)
      common::usage
      ;;
    *)
      echowarn "unknow [TYPE] parameter: ${INSTALL_TYPE}"
      common::usage
      ;;
  esac
}

main "$@"
```

### compose

```yaml
version: '3.1'
services:
  nginx:
    container_name: nginx
    image: nginx:1.20-alpine
    restart: always
    volumes:
      - ./resources/nginx:/usr/share/nginx
      - ./config/compose/certs/domain.crt:/etc/nginx/conf.d/domain.crt
      - ./config/compose/certs/domain.key:/etc/nginx/conf.d/domain.key
      - ./config/compose/nginx.conf:/etc/nginx/conf.d/default.conf
    ports:
      - 443:443
      - 8080:8080

  registry:
    image: registry:2.7.1
    container_name: registry
    restart: always
    volumes:
      - ./resources/registry:/var/lib/registry
    ports:
      - 127.0.0.1:5000:5000
```

### kubespray



## 参考

- [政采云基于 sealer 的私有化业务交付实践](https://mp.weixin.qq.com/s/7hKkdBUXHFZt5q3KbpmU6Q)
- [云原生 PaaS 产品发布&部署方案](https://blog.k8s.li/pass-platform-release.html)
- [使用 docker build 制作 yum/apt 离线源](https://blog.k8s.li/make-offline-mirrors.html)
- [使用 Kubespray 本地开发测试部署 kubernetes 集群](https://blog.k8s.li/deploy-k8s-by-kubespray.html)
- [什么？发布流水线中镜像“同步”速度又提升了 15 倍 ！](https://blog.k8s.li/select-registry-images.html)
- [如何使用 registry 存储的特性](https://blog.k8s.li/skopeo-to-registry.html)