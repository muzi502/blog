---
title: 万字长文详解 PaaS toB 场景下 K8s 离线部署方案
date: 2021-08-30
updated: 2021-08-30
slug:
categories:
  - 技术
tag:
  - k8s
  - toB
  - PaaS
  - kubernetes
copyright: true
comment: true
---

在企业私有云环境当中，出于对数据安全的考虑以及满足 [网络安全等级保护](http://www.djbh.net/) 的要求，往往会对内部环境中的服务器做出严格的访问限制。一般来讲生产环境都会禁止访问外部网络，开发人员要访问生产环境也必须通过堡垒机或者其他方式进行安全审计登录。在这种无网（无法访问公网）的环境中，想要部署好一个 K8s 集群并不是一件轻松的事儿。市面上 K8s 部署工具也多不胜数，对于离线部署的支持情况也各不相同：

|                           Item                            | Language | Start | Fork | 离线部署支持情况                                     |
| :-------------------------------------------------------: | :------: | :---: | :--: | :--------------------------------------------------- |
|        [kops](https://github.com/kubernetes/kops)         |  Golang  | 13.2k | 4.1k | 不支持                                               |
| [kubespray](https://github.com/kubernetes-sigs/kubespray) | Ansible  | 11.1k | 4.7k | 支持，需自行构建安装包                               |
|       [kubeasz](https://github.com/easzlab/kubeasz)       | Ansible  | 7.2k  | 2.7k | 支持，需自行构建安装包                               |
|         [sealos](https://github.com/fanux/sealos)         |  Golang  | 4.1k  | 790  | 支持，需付费充值会员                                 |
|           [RKE](https://github.com/rancher/rke)           |  Golang  | 2.5k  | 480  | 不支持，需自行安装 docker                            |
|        [sealer](https://github.com/alibaba/sealer)        |  Golang  |  503  | 112  | 支持，源自 [sealos](https://github.com/fanux/sealos) |
|     [kubekey](https://github.com/kubesphere/kubekey)      |  Golang  |  471  | 155  | 部分支持，仅镜像可离线                               |

无网环境离线部署 K8s 往往是作为一个商业服务或者商业付费产品来出售（如 [sealos](https://www.sealyun.com/) ），很少有开源免费的解决方案；或者虽然提供了离线部署方案，但想要操作起来十分繁琐，很难顺畅地做到一键部署；又或者只支持部分离线部署，还有一部分资源需要在部署的时候通过公网获取。

针对上述问题，本文调研主流的 K8s 部署工具，并基于这些工具设计并实现一种从构建离线安装包到一键部署 K8s 集群全流程的解决方案，以满足在无网的环境中一键部署 K8s 集群的需求，比较适合基于 K8s 的 PaaS toB 产品使用。

## 离线资源

总体来讲部署一个 K8s 集群大致需要依赖如下三种资源：

- 系统 OS 的 rpm/deb 包：如 docker-ce、containerd、ipvsadm、conntrack 等；
- 二进制文件：如 kubelet、kubectl、kubeadm、crictl 等；
- 组件容器镜像：如 kube-apiserver、kube-proxy、coredns、calico、flannel 等；

###  OS packages

这类属于 OS 系统层面的依赖，根据不同系统或者支持的功能需要使用相应的包管理器安装相应的依赖包，大致分为如下几种：

- kubernetes 组件依赖

```bash
- conntrack           # kube-proxy 依赖
- ipset               # kube-proxy 使用 ipvs 模式需要
- ipvsadm             # kube-proxy 使用 ipvs 模式需要
- socat               # 用于 port forwarding
```

> [Implementation details](https://kubernetes.io/docs/reference/setup-tools/kubeadm/implementation-details/):
>
> [Error] if conntrack, ip, iptables, mount, nsenter commands are not present in the command path
> [warning] if ebtables, ethtool, socat, tc, touch, crictl commands are not present in the command path

- 部署依赖

```bash
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
- nfs-utils/nfs-common # 创建基于 nfs 的 PV 需要
- ceph-common          # ceph 客户端安装包，创建基于 ceph 的 pv 需要
- lvm2                 # 创建基于 ceph 的 pv 需要
- glusterfs-client     # 创建基于 glusterfs 的 pv 需要
- glusterfs-common     # 创建基于 glusterfs 的 pv 需要
- cifs-utils           # 创建基于 cifs 的 pv 需要
- fuse                 # ceph 或者其他存储客户端依赖
```

想要解决上面这些依赖项十分棘手，也是离线部署场景下最难的一部分，至今并没有一个成熟的方案实现这些依赖的离线部署，基本上所有的 k8s 部署工具都没有提供这些包的离线安装方式。对于这些包的依赖，目前主要有避免安装这些依赖和制作离线源这两种解决方案。

#### sealos

在 [sealos](https://github.com/fanux/sealos) 中就极力避免使用包管理器来安装依赖，比如安装 containerd 时的依赖 libseccomp 使用的是编译好的 .so 文件的方式。

```bash
$ tar -tf kube1.20.0.tar.gz
kube/
kube/lib64/
kube/lib64/README.md
kube/lib64/libseccomp.so.2
kube/lib64/libseccomp.so.2.3.1
```

安装 docker 使用的二进制的方式，但 docker 官方文档中也明确说明**不建议使用二进制的方式来安装 docker**，应该使用发行版自带的包管理器来安装。

> If you want to try Docker or use it in a testing environment, but you’re not on a supported platform, you can try installing from static binaries. **If possible, you should use packages built for your operating system**, and use your operating system’s package management system to manage Docker installation and upgrades.
>
> [Install Docker Engine from binaries](https://docs.docker.com/engine/install/binaries/)

实际上任何部署工具都会对系统 rpm/deb 包都会有不同程度上的依赖，有一部分依赖可以像 [sealos](https://github.com/fanux/sealos)  这样通过某种方式去规避掉。但着并不是所有的依赖都能规避的，比如提供挂载 PV 需要依赖的存储客户端（nfs-common/nfs-utils，lvm2，gluster-client）这些包，基本上是没有任何规避的途径，必须通过包管理器来安装才行。

当然如果这些前置的依赖项在部署工具之外手动解决或者让用户自行去解决，那么使用 [sealos](https://github.com/fanux/sealos)  这种轻量级的工具来部署 K8s 是比较合适的。但对于一些 PaaS toB 的产品而言，让用户自己去手动解决这些依赖恐怕不太好。站在客户的角度来考虑既然平台提供了这部分功能，就应该在部署的时候解决所有的依赖问题，而不是让我自己手动临时来解决。

#### kubekey

在 kubekey 中一些依赖项目则是要求用户自行安装，并没有提供离线安装的方式：

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
>
> [Requirements and Recommendations](https://github.com/kubesphere/kubekey#requirements-and-recommendations)

#### 构建离线源

对于系统 rpm/deb 包的依赖，我们还是踏踏实实地使用包管理器来安装这些包较为妥当，因此我们有必要为这些依赖的 rpm/deb 包构建成离线源，部署的时候使用这个离线源来安装这些依赖。在 《[使用 docker build 制作 yum/apt 离线源](https://blog.k8s.li/make-offline-mirrors.html)》一文中曾分析过制作和使用离线源这么难的原因：

> 作为平台部署工具的开发者，始终被离线部署这个难题困扰着。在线的容器镜像和二进制文件比较好解决，因为这些资源是与 OS 无关的，只要下载下来放到安装包里，部署的时候启动一个 HTTP 服务器和镜像仓库服务提供这些资源的下载即可。
>
> 但是对于 yum/apt 之类的软件来讲并不那么简单：
>
> - 首先由于各个包之间的依赖关系比较复杂，并不能将它们直接下载下来；
> - 其次即便下载下来之后也无法直接通过 yum/apt 的方式安装指定的软件包，虽然也可以使用 scp 的方式将这些包复制到部署节点，通过 rpm 或 dpkg 的方式来安装上，但这样并不是很优雅，而且通用性能也不是很好；
> - 最后需要适配的 Linux 发行版和包管理器种类也有多种，而且有些包的包名或者版本号在不同的包管理之间也相差甚大，无法做到统一管理。
> - 离线源同时适配适配 ARM64 和 AMD64 有一定的难度

好在文中也给出了一个比较通用的解决方案，即通过 Dockerfile 来构建离线源，具体的实现细节可以翻看《[使用 docker build 制作 yum/apt 离线源](https://blog.k8s.li/make-offline-mirrors.html)》一文。使用这个方案可以解决 PaaS 或者 IaaS 层面的离线源制作的难题，同样也适用于我们部署 K8s 集群的场景，并且采用 Dockerfile 的方式来构建离线源可以完美地解决同时适配 arm64 和 amd64 的难题。

### files

一些部署过程中需要的二进制文件，如下：

```bash
- kubelet
- kubeadm
- kubectl
- etcd            # systemd 方式部署 etcd 时需要的安装包
- crictl          # k8s 官方的 CRI CLI 工具
- calicoctl       # calico 的 CLI 工具
- helm            # 安装 helm 需要的二进制安装包
- nerdctl         # containerd 的 CLI 工具
- cni-plugins     # CNI 插件
- cuda            # GPU 依赖
- nvidia_driver   # GPU 驱动
```

#### sealos

sealos 对二进制文件的处理比较好，全部打包在离线安装包里，部署的时候会分发到集群节点上，整个部署过程都无需访问公网。

```bash
$ tar -tf kube1.20.0.tar.gz
kube/bin/kubelet
kube/bin/kubectl
kube/bin/conntrack
kube/bin/kubeadm
```

#### kubekey

在 kubekey 的源码当中，是将所有二进制文件的 URL 硬编码在代码当中的。如果在部署的时候需要根据部署环境来修改二进制文件的下载地址，比如从内网 nginx 服务器上下载，就需要修改这部分源码把 `https://kubernetes-release.pek3b.qingstor.com` 修改成内网地址，比如 `http://172.20.0.25:8080/files` ，然而在部署的时候重新编译 kubekey 的代码又必须能访问公网才行，这就很僵硬。所以以目前开源的 kubekey 来看，是没有办法做到无网环境中愉快地部署 k8s 的，可能商业版的支持（猜测。

- [kubekey/blob/master/pkg/kubernetes/preinstall/preinstall.go](https://github.com/kubesphere/kubekey/blob/master/pkg/kubernetes/preinstall/preinstall.go)

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

此外 kubekey 在安装 docker 时，是直接调用的 [docker 官方的脚本](https://get.docker.com/) 来安装，安装过程也必须访问公网才行。

- [kubekey/blob/master/pkg/container-engine/docker/docker.go](https://github.com/kubesphere/kubekey/blob/master/pkg/container-engine/docker/docker.go)

```go
func installDockerOnNode(mgr *manager.Manager, _ *kubekeyapiv1alpha1.HostCfg) error {
	dockerConfig, err := GenerateDockerConfig(mgr)
	if err != nil {
		return err
	}
	dockerConfigBase64 := base64.StdEncoding.EncodeToString([]byte(dockerConfig))
	output, err1 := mgr.Runner.ExecuteCmd(fmt.Sprintf("sudo -E /bin/sh -c \"if [ -z $(which docker) ] || [ ! -e /var/run/docker.sock ]; then curl https://kubernetes.pek3b.qingstor.com/tools/kubekey/docker-install.sh | sh && systemctl enable docker; if [ ! -f /etc/docker/daemon.json ]; then mkdir -p /etc/docker && echo %s | base64 -d > /etc/docker/daemon.json; fi; systemctl daemon-reload && systemctl restart docker; fi\"", dockerConfigBase64), 0, false)
	if err1 != nil {
		return errors.Wrap(errors.WithStack(err1), fmt.Sprintf("Failed to install docker:\n%s", output))
	}

	return nil
}
```

使用 docker 官方的安装脚本来安装 docker 是有一个明显的问题就是：比如没有版本控制，不能指定 docker 的版本，每次安装的 docker 版本都是最新的 stable 版本。没有版本控制就会导致不同时间部署的集群或者加入的节点，docker 版本可能就不一样，在这里可能会埋下一些坑，可能会带来一定的维护成本或者将来升级时遇到问题。

编译过 kubernetes 组件的可能都知道 k8s 源码当中存在一个 [build/dependencies.yaml](https://github.com/kubernetes/kubernetes/blob/master/build/dependencies.yaml) 的文件，里面记录的是 k8s 组件与其他组件 (如 docker, etcd, coredns, cni, pause) 所匹配的最佳版本。

> On each of your nodes, install the Docker for your Linux distribution as per [Install Docker Engine](https://docs.docker.com/engine/install/#server). You can find the latest validated version of Docker in this [dependencies](https://git.k8s.io/kubernetes/build/dependencies.yaml) file.

- [kubernetes/blob/release-1.20/build/dependencies.yaml](https://github.com/kubernetes/kubernetes/blob/release-1.20/build/dependencies.yaml)

```yaml
dependencies:
  # zeitgeist (https://github.com/kubernetes-sigs/zeitgeist) was inspired by
  # (and now replaces) the cmd/verifydependencies tool to verify external
  # dependencies across the repo.
  #
  # The zeitgeist dependencies.yaml file format is intended to be
  # backwards-compatible with the original tooling.
  #
  # In instances where the file format may change across versions, this meta
  # dependency check exists to ensure we're pinned to a known good version.
  #
  # ref: https://github.com/kubernetes/kubernetes/pull/98845

  # Docker
  - name: "docker"
    version: 19.03
    refPaths:
    - path: vendor/k8s.io/system-validators/validators/docker_validator.go
      match: latestValidatedDockerVersion
```

以 1.20.x 版本的 k8s 为例，它所依赖的 docker 版本为 19.03，而现在最新的 docker 版本如 20.10.8，并不是 K8s 官方所建议的最佳版本。总之，我们在部署 K8s 时，可以参考 [build/dependencies.yaml](https://github.com/kubernetes/kubernetes/blob/master/build/dependencies.yaml) 来确定与 K8s 相关的组件应该选择哪一个最佳的版本，而不是随便装一个最新的版本就完事儿了。

#### kubespray

在 kubespray 中，所有二进制文件的 URL 都是通过变量的方式定义的，想要做到离线部署十分简单，只需要通过 ansible 变量优先级的特性，将它们在 group_vars 通过 overrides 的方式覆盖即可。比如这样：

```yaml
# Download URLs
kubelet_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubelet"
kubectl_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubectl"
kubeadm_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubeadm"
```

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

#### sealos

sealos 将这些镜像使用 docker save 的方式打包成一个 tar 包，在部署的时候使用 docker/ctr load 的方式将镜像导入到容器运行时的存储目录当中，源码如下：

- [fanux/sealos/blob/develop/install/send.go](https://github.com/fanux/sealos/blob/develop/install/send.go)

```go
// SendPackage is send new pkg to all nodes.
func (u *SealosUpgrade) SendPackage() {
	all := append(u.Masters, u.Nodes...)
	pkg := path.Base(u.NewPkgUrl)
	// rm old sealos in package avoid old version problem. if sealos not exist in package then skip rm
	var kubeHook string
	if For120(Version) {
		// TODO update need load modprobe -- br_netfilter modprobe -- bridge.
		// https://github.com/fanux/cloud-kernel/issues/23
		kubeHook = fmt.Sprintf("cd /root && rm -rf kube && tar zxvf %s  && cd /root/kube/shell && rm -f ../bin/sealos && (ctr -n=k8s.io image import ../images/images.tar || true) && cp -f ../bin/* /usr/bin/ ", pkg)
	} else {
		kubeHook = fmt.Sprintf("cd /root && rm -rf kube && tar zxvf %s  && cd /root/kube/shell && rm -f ../bin/sealos && (docker load -i ../images/images.tar || true) && cp -f ../bin/* /usr/bin/ ", pkg)

	}

	PkgUrl = SendPackage(pkg, all, "/root", nil, &kubeHook)
}
```

使用这种方式加载镜像有一个比较明显的限制就是 kube-apiserver 的 admission 准入控制中不能加入 `AlwaysPullImages` 参数。不然与这些镜像相关的 pod 重新调度或者重启之后会重新从源镜像仓库拉取镜像，在无网或者网络限制的环境中可能无法拉取镜像导致这些 Pod 启动失败，从而导致集群异常。

而在多租户场景下，出于安全的考虑  `AlwaysPullImages` 准入控制往往是要开启的。因此 sealos 可能并不适用于多租户或者对此有要求的环境中（最常见的就是 PaaS 平台）。

> 该准入控制器会修改每一个新创建的 Pod 的镜像拉取策略为 Always 。 这在多租户集群中是有用的，这样用户就可以放心，他们的私有镜像只能被那些有凭证的人使用。 如果没有这个准入控制器，一旦镜像被拉取到节点上，任何用户的 Pod 都可以通过已了解到的镜像的名称（假设 Pod 被调度到正确的节点上）来使用它，而不需要对镜像进行任何授权检查。 当启用这个准入控制器时，总是在启动容器之前拉取镜像，这意味着需要有效的凭证。

#### kubekey

[kubekey 官方的文档](https://kubesphere.io/docs/installing-on-linux/introduction/air-gapped-installation/) 中有提到组件镜像离线部署的方式，不过十分繁琐(劝退😂)，在 [Offline installation is too troublesome #597](https://github.com/kubesphere/kubekey/issues/597) 中也有人吐槽这个问题。不过目前 kubekey 开发团队已经在重构这部分内容了，至于结果如何，只能等了。

#### 镜像仓库

在私有云环境中，企业一般都会有自己的镜像仓库（比如 harbor ）用于存放业务组件镜像或者一些其他平台依赖的镜像。再加上 Docker Hub 自从去年开始就加入了 pull 镜像次数的限制，如果直接使用 Docker Hub 上面的镜像来部署集群，很有可能会因为 [429 toomanyrequests](https://www.docker.com/increase-rate-limit) 或者一些网络原因导致拉取镜像失败。因此对于 k8s 集群部署而言，建议使用内部自己的镜像仓库，而非公网上镜像仓库。如果没有的话可以使用 harbor 或者 docker registry 在本地部署一个镜像仓库。我们将部署依赖的镜像导入到已经存在的镜像仓库中，部署的时候从该镜像仓库拉取即可。

## 部署工具选择

上面简单梳理了一下部署 k8s 集群过程中所依赖的的在线资源，以及如何将它们制作成离线资源的一些分析。上面提及的部署工具各有各的优缺点，针对以下两种不同的场景可以选择不同的部署工具。

### sealos

如果仅仅是部署一个简单的 k8s 集群，对集群没有太多定制化的需求，那么使用 [sealos](https://github.com/fanux/sealos) 可能是最佳的选择，只不过它是收费的，[需要充值会员](https://www.sealyun.com/) 😂。

> ### 现在开始 ~~￥99~~ ￥69/年
>
> 欢迎成为年费会员，任意下载所有版本软件包!
>
> > @F-liuhui 离线包居然要收费？那还是开源项目吗？
>
> 开源与付费不冲突，100%开源 100%付费
>
> [sealyun.com](https://www.sealyun.com/)

如果动手能力强的话，可以根据 selaos 离线安装包的目录结构使用 GitHub Actions 来构建，实现起来也不是很难。只不过砸别人饭碗的事儿还是不做为好，因此我们应该选择另一种方案来实现，这样也能避免一些商业纠纷问题。

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

### kubekey

由于 kubekey 部署时二进制文件需要公网获取，docker 无法离线部署以及需要手动安装一些前置依赖，没有办法做到完整的离线部署，因此离线部署的方案也就直接放弃掉了，抽空他们提个 Issue 或 PR 看看能否支持这部分 😅。

### kubespray

如果想找一个即开源又免费的离线部署方案，或者对集群部署有特殊的要求，比如基于 K8s 的 PaaS toB 产品，需要在部署时安装平台本身需要的一些依赖（如存储客户端、GPU 驱动等）。那么不妨先看一下 kubernetes-sig 社区的 [kubespray](https://github.com/kubernetes-sigs/kubespray) 如何 🤔，主要的特性如下：

- 支持的 10 种 CNI 插件

```bash
- cni-plugins v0.9.1
- calico v3.17.4
- canal (given calico/flannel versions)
- cilium v1.9.9
- flanneld v0.14.0
- kube-ovn v1.7.1
- kube-router v1.3.0
- multus v3.7.2
- ovn4nfv v1.1.0
- weave v2.8.1
```

- 支持 3 种容器运行时以及 [Kata Containers](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/kata-containers.md) 还有 nvidia-gpu-device-plugin 等

```bash
- docker v20.10
- containerd v1.4.6
- cri-o v1.21
```

- 适配了 10 种 Linux 发行版，覆盖了绝大多数私有云场景

```bash
- Flatcar Container Linux by Kinvolk
- Debian Buster, Jessie, Stretch, Wheezy
- Ubuntu 16.04, 18.04, 20.04
- CentOS/RHEL 7, 8
- Fedora 33, 34
- Fedora CoreOS (see fcos Note)
- openSUSE Leap 15.x/Tumbleweed
- Oracle Linux 7, 8
- Alma Linux 8
- Amazon Linux 2
```

- 丰富的插件和扩展

```bash
## 工具类
- helm
- krew
- nerdctl

## 一些 controller 和 provisioner
- ambassador: v1.5
- cephfs-provisioner v2.1.0-k8s1.11
- rbd-provisioner v2.1.1-k8s1.11
- cert-manager v0.16.1
- coredns v1.8.0
- ingress-nginx v0.43.0
```

- 依赖的文件和镜像支持离线部署 [Offline environment](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/offline-environment.md)

kubespray 对所有的依赖资源都做到了离线下载的支持：比如所有依赖文件的 URL 都通过变量的方式来定义，而非 kubekey 那样硬编码在代码中；所有镜像的 repo 和 tag 都是通过变量的方式来定义。这样的好处就是在部署的时候可以根据客户环境的的镜像仓库地址和文件服务器的 URL 地址来填写相应的参数，无需通过公网来获取。

```yaml
# Registry overrides
kube_image_repo: "{{ registry_host }}"
gcr_image_repo: "{{ registry_host }}"
docker_image_repo: "{{ registry_host }}"
quay_image_repo: "{{ registry_host }}"

kubeadm_download_url: "{{ files_repo }}/kubernetes/{{ kube_version }}/kubeadm"
kubectl_download_url: "{{ files_repo }}/kubernetes/{{ kube_version }}/kubectl"
kubelet_download_url: "{{ files_repo }}/kubernetes/{{ kube_version }}/kubelet"
# etcd is optional if you **DON'T** use etcd_deployment=host
etcd_download_url: "{{ files_repo }}/kubernetes/etcd/etcd-{{ etcd_version }}-linux-amd64.tar.gz"
cni_download_url: "{{ files_repo }}/kubernetes/cni/cni-plugins-linux-{{ image_arch }}-{{ cni_version }}.tgz"
crictl_download_url: "{{ files_repo }}/kubernetes/cri-tools/crictl-{{ crictl_version }}-{{ ansible_system | lower }}-{{ image_arch }}.tar.gz"
# If using Calico
calicoctl_download_url: "{{ files_repo }}/kubernetes/calico/{{ calico_ctl_version }}/calicoctl-linux-{{ image_arch }}"
```

和上述几种部署工具对比不难发现，kubespray 灵活性和可扩展性要领先其他工具（支持 10 种 CNI、10种 Linux  发行版、3 种 CRI、以及多种插件和扩展）并在参数层面上做到了离线部署的支持。因此我们首先选用 kubespray 作为集群部署的底层工具。

还有一个问题就是 kubespray 虽然在参数配置上支持离线部署，但是从制作离线安装包到一键部署，目前为止还未有一个完整的实现方案。因此需要为 kubespray 设计一套从离线安装包的构建到集群一键部署的流程和方案，为此我们新建一个名为 [kubeplay](https://github.com/k8sli/kubeplay) 的 repo 来完成这部分内容。

另外值得一提的是 kubesphere 早期的版本 v2.x 使用也是 kubespray 部署的 k8s，至今 ks-installer 代码中仍残留着 [部分 kubespray 的代码](https://github.com/kubesphere/ks-installer/commits/master/roles/download/tasks) ，到了 3.0 的时候开始使用自研的 kubekey 来部署 K8s 了。

> 基于 Ansible 的安装程序具有大量软件依赖性，例如 Python。KubeKey 是使用 Go 语言开发的，可以消除在各种环境中出现的问题，从而提高安装成功率。
>
> [README_zh-CN.md](https://github.com/kubesphere/kubekey/blob/master/README_zh-CN.md)

不过 ansible 的依赖问题当时为什么没有考虑采用容器化的方式运行 kubespray 🤔，至于 ansible 的性能问题也不是没有优化的余地。

## [kubeplay](https://github.com/k8sli/kubeplay)

kubeplay 这个项目主要是实现 K8s 离线安装包的构建和一键部署功能，目前只适配了 kubespray，等到后面会适配一些其他部署工具如 kubekey。

### 打包方式

由于部署依赖的二进制文件和组件镜像大都存放在 GitHub 、Docker Hub、gcr.io（Google Container Registry）、quay.io 这些国外的平台上，在国内环境获取这些资源是有一定的网络限制。而 GitHub 托管的 runner 运行在国外的机房当中，可以很顺畅地获取这些资源。因此我们选择使用 GitHub Actions 来进行离线安装包的构建。

像 selos 那样将安装包存放在阿里云 OSS 上，在国内能十分顺畅地高速下载，收费也是理所当然。但我们的方案是 100% 开源 100% 免费，每个人都可以 fork 代码到自己的 repo，根据自己的需求进行构建。因此选择 GitHub 来构建和存放我们的安装包是最合适的选择，这样也不用去额外考虑安装包下载的问题。至于从 GitHub 上下载安装包慢的问题，那应该由使用者自行去解决，而非本方案所关心的问题。

> Q：如何摆脱网络的依赖来创建个 Docker 的 image 呢，我觉得这个是 Docker 用户自己的基本权利？
>
> A：这个基本权利我觉得还是要问 GFW ，国外的开发人员是非常难理解有些他们认为跟水电一样普及的基础设施在某些地方还是很困难的。
>
> 此处引用 [DockOne技术分享（二十四）：容器和IaaS：谁动了谁的奶酪](http://dockone.io/article/722)

选择好的构建场所为 GitHub Actions 之后我们再将这些离线资源进行拆分，目的是为了实现各个离线资源之间的解耦，这样做灵活性更好一些，比如能够适配多种 OS、支持多个 k8s 版本等。主要拆分成如下几个模块。

| 模块             | Repo                                                | 用途                            | 运行/使用方式            |
| ---------------- | --------------------------------------------------- | ------------------------------- | ------------------------ |
| compose          | [kubeplay](https://github.com/k8sli/kubeplay)       | 用于部署 nginx 和 registry 服务 | nerdctl compose          |
| os-tools         | [kubeplay](https://github.com/k8sli/kubeplay)       | 部署 compose 时的一些依赖工具   | 二进制安装               |
| os-packages      | [os-packages](https://github.com/k8sli/os-packages) | 提供 rpm/deb 离线源             | nginx 提供 http 方式下载 |
| kubespray        | [kubespray](https://github.com/k8sli/kubespray)     | 用于部署/扩缩容 k8s 集群        | 容器或者 pod             |
| kubespray-files  | [kubespray](https://github.com/k8sli/kubespray)     | 提供二进制文件依赖              | nginx 提供 http 方式下载 |
| kubespray-images | [kubespray](https://github.com/k8sli/kubespray)     | 提供组件镜像                    | registry 提供镜像下载    |

拆分完成之后，我们最终还是需要将它们组合成一个完成的离线安装包。为了减少维护成本，我们将每个模块的构建操作都放在 Dockerfile 中，即 `All in Dockerfile` 🤣。这样每个模块的 GitHub Actions 流水线最终交付的都是一个镜像，然后镜像都推送到  `ghcr.io` 上，这样就解决了模块间产物传递以及镜像缓存的问题。最终通过一个最终的 [Dockerfile](https://github.com/k8sli/kubeplay/blob/main/Dockerfile) 将这些模块的镜像全部 COPY 到一个镜像当中，只要打包这个最终的镜像为离线安装包即可；另一个好处就使用 buildx 构建这些离线资源就原生支持多 CPU 体系架构，能够同时适配 amd64 和 arm64 体系架构，这样 arm64 也能愉快地玩耍了，真是一举两得。

下面就详细讲解每个模块的功能以及是如何打包的：

### compose

compose 模块里面主要运两个服务： 用于提供文件下载的 nginx 和组件镜像拉取的 registry。这两个我们依旧是容器化以类似 docker-compose 的方式来部署，而所依赖的也只有两个镜像和一些配置文件而已。

- [kubeplay/blob/main/compose.yaml](https://github.com/k8sli/kubeplay/blob/main/compose.yaml)

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
      # 443 端口反向代理 registr 的 5000 端口，仅用于 pull 镜像
      - 443:443
      - 8080:8080

  registry:
    image: registry:2.7.1
    container_name: registry
    restart: always
    volumes:
      - ./resources/registry:/var/lib/registry
    ports:
      # 只允许本地 5000 端口 push 镜像
      - 127.0.0.1:5000:5000
```

这两个镜像我们使用 skopeo copy 的方式保存为 tar 包，部署的时候 load 到容器运行时的存储中。

> Q：为什么要用 skopeo 而不是 docker？
>
> A：因为 Dockerfile 构建过程中不支持运行 docker 命令 save 镜像

- Dockerfile

```dockerfile
FROM alpine:latest as downloader
ARG SKOPEO_VERSION=v1.4.0
ARG NGINX_VERSION=1.20-alpine
ARG RERGISRRY_VERSION=2.7.1

WORKDIR /tools
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && apk --no-cache add wget ca-certificates \
    && wget -q -k https://github.com/k8sli/skopeo/releases/download/v1.4.0/skopeo-linux-${ARCH} -O /tools/skopeo-linux-${ARCH} \
    && chmod a+x /tools/* \
    && ln -s /tools/skopeo-linux-${ARCH} /usr/bin/skopeo

WORKDIR /images
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && skopeo copy --insecure-policy --src-tls-verify=false --override-arch ${ARCH} --additional-tag nginx:${NGINX_VERSION} \
       docker://docker.io/library/nginx:${NGINX_VERSION} docker-archive:nginx-${NGINX_VERSION}.tar \
    && skopeo copy --insecure-policy --src-tls-verify=false --override-arch ${ARCH} --additional-tag registry:${RERGISRRY_VERSION} \
       docker://docker.io/library/registry:${RERGISRRY_VERSION} docker-archive:registry-${RERGISRRY_VERSION}.tar
```

在部署的时候我们使用 nerdctl compose 的方式启动即可，使用方式有点类似于 docker-compose。

> Q: 为什么不用 docker 和 docker-compose
>
> A：K8s 去 docker 是大势所趋，选择 containerd 更符合主流发展方向

```bash
# 将镜像 load 进 containerd 存储
$ find ${IMAGES_DIR} -type f -name '*.tar' | xargs -L1 nerdctl load -i
# nerdctl compose 启动 nginx 和 registry
$ nerdctl compose -f compose.yaml up
```

### os-packages

这部分是 rpm/deb 离线源的构建，其详细的过程和原理可以参考我之前写的博客 《[使用 docker build 制作 yum/apt 离线源](https://blog.k8s.li/make-offline-mirrors.html)》，下面只列举一下 CentOS7 离线源的构建配置：

- [Dockerfile](https://github.com/k8sli/os-packages/blob/main/build/Dockerfile.os.centos7)

```dockerfile
FROM centos:7.9.2009 as os-centos7
ARG OS_VERSION=7
ARG DOCKER_MIRROR_URL="https://download.docker.com"
ARG BUILD_TOOLS="yum-utils createrepo epel-release wget"

# 安装构建工具，配置 docker 官方 yum 源
RUN yum install -q -y ${BUILD_TOOLS} \
    && yum-config-manager --add-repo ${DOCKER_MIRROR_URL}/linux/centos/docker-ce.repo \
    && yum makecache

WORKDIR /centos/$OS_VERSION/os
COPY packages.yaml .
COPY --from=mikefarah/yq:4.11.1 /usr/bin/yq /usr/bin/yq

# 根据配置文件解析该 OS 需要构建的包，并获取这些包的下载 url
RUN yq eval '.common[],.yum[],.centos7[],.kubespray.common[],.kubespray.yum[]' packages.yaml > packages.list \
    && sort -u packages.list | xargs repotrack --urls | sort -u > packages.urls

# 通过 wget 的方式下载 rpm 包，使用 createrepo 创建 repo 索引文件
RUN ARCH=$(uname -m) \
    && wget -q -x -P ${ARCH} -i packages.urls \
    && createrepo -d ${ARCH}

# 将构建的内容 COPY 成单独的一层
FROM scratch
COPY --from=os-centos7 /centos /centos
```

- [packages.yaml](https://github.com/k8sli/os-packages/blob/main/packages.yaml) 配置文件

这个是需要安装包的配置文件，可以根据平台或者客户的一些要求配置上不同的包

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

> 对于 toB 产品，建议将下面这些常见的运维调试工具（如 tcpdump, strace, lsof, net-tools 等）也构建在离线源中。这样也不至于在客户的环境中排查问题的时候机器上连个 tcpdump 都没有，尤其是在无网的环境中，如果没有这些常用的运维工具，排查问题将会十分棘手。

```yaml
tools:
  - bash-completion
  - chrony
  - cifs-utils
  - curl
  - dstat
  - e2fsprogs
  - ebtables
  - expect
  - gdb
  - htop
  - iftop
  - iotop
  - ipset
  - ipvsadm
  - jq
  - lsof
  - lvm2
  - ncdu
  - net-tools
  - nethogs
  - nload
  - ntpdate
  - openssl
  - pciutils
  - psmisc
  - rsync
  - smartmontools
  - socat
  - sshpass
  - strace
  - sysstat
  - tcpdump
  - telnet
  - tmux
```

### kubespray

kubespray 是部署 K8s 集群、增加节点、删除节点、移除集群等涉及对集群操作的主要工具。我们依旧采用容器化的方式运行 kubespray，主要有以下场景会用到 kubespray：

- 在部署工具运行节点，使用 nerdctl 来运行 kubespray 容器部署  K8s 集群
- K8s 集群部署完毕后，以 Job pod 的方式运行部署另一个 K8s 集群，实现多集群部署的基本能力
- K8s 集群部署完毕后，以 Job pod 的方式运行 kubespray 对该集群集群节点进行扩缩容

Job pod 方式对集群进行扩缩容的设计的是为了从一定程度上解决部署大规模集群时 ansible 性能问题。即我们一开始不必就部署一个上千节点的集群，而是先把一个规模较小的集群部署起来，然后通过创建批量的 Job 的方式运行 kubespray 再将集群慢慢扩容起来，比如扩容到上千台节点。

kubespray 官方的 Dockerfile 构建出来的镜像有 1.4GB，实在是太大了，因此我们需要优化一下，减少镜像大小

- kubespray BASE 镜像

首先构建一个 base 镜像，对于不经常变动的内容我们把它封装在一个 base 镜像里，只有当相关依赖更新了才需要重新构建这个 base 镜像，`Dockerfile.base` 如下：

```dockerfile
FROM python:3 as builder
ARG KUBE_VERSION=v1.21.3
COPY requirements.txt requirements.txt
COPY tests/requirements.txt tests/requirements.txt
RUN echo 'shellcheck-py==0.7.2.1' >> requirements.txt \
    && grep -E '^yamllint|^ansible-lint' tests/requirements.txt >> requirements.txt \
    && pip3 install --user -r requirements.txt

RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && wget -O /root/.local/bin/kubectl -q https://dl.k8s.io/${KUBE_VERSION}/bin/linux/${ARCH}/kubectl \
	&& chmod a+x /root/.local/bin/kubectl

FROM python:3-slim
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y -qq \
    && apt-get install -y -qq --no-install-recommends \
        ca-certificates libssl-dev openssh-client sshpass curl gnupg2 rsync \
        jq moreutils vim iputils-ping wget tcpdump xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /root/.local /usr/local
WORKDIR /kubespray
```

- [kubespray 镜像]()

FROM 的 base 镜像就使用我们刚刚构建好的镜像，相关依赖已经在 base 镜像中安装好了，这里构建的时候只需要把 repo 源码复制到 /kubespray 目录下即可，内容如下：

```dockerfile
ARG BASE_IMAGE=ghcr.io/k8sli/kubespray-base
ARG BASE_IMAGE_VERSION=latest
FROM $BASE_IMAGE:$BASE_IMAGE_VERSION
WORKDIR /kubespray
COPY . .
```

- kubespray 集群部署入口 `run.sh`

将集群部署、增加节点、删除节点、删除集群等操作封装成一个入口的脚本，提供外部工具调用该脚本，不然外部调用的时候直接运行 `ansible-playbook` 命令实在是不太方便。

```bash
#!/bin/bash
TYPE=$1
NODES=$2

KUBE_ROOT="$(cd "$(dirname "$0")" && pwd)"

: ${TYPE:=deploy-cluster}
: ${ANSIBLE_FORKS:=10}
: ${BECOME_USER:=root}
: ${ANSIBLE_LOG_FORMAT:=yaml}
: ${INVENTORY:=${KUBE_ROOT}/config/inventory}
: ${ENV_FILE:=${KUBE_ROOT}/config/env.yml}
: ${INSTALL_STEPS_FILE:=${KUBE_ROOT}/config/.install_steps}

export ANSIBLE_STDOUT_CALLBACK=${ANSIBLE_LOG_FORMAT}
export ANSIBLE_ARGS="-f ${ANSIBLE_FORKS} --become --become-user=${BECOME_USER} -i ${INVENTORY} -e @${ENV_FILE}"

#
# Set logging colors
#

NORMAL_COL=$(tput sgr0)
RED_COL=$(tput setaf 1)
WHITE_COL=$(tput setaf 7)
GREEN_COL=$(tput setaf 76)
YELLOW_COL=$(tput setaf 202)

debuglog(){ printf "${WHITE_COL}%s${NORMAL_COL}\n" "$@"; }
infolog(){ printf "${GREEN_COL}✔ %s${NORMAL_COL}\n" "$@"; }
warnlog(){ printf "${YELLOW_COL}➜ %s${NORMAL_COL}\n" "$@"; }
errorlog(){ printf "${RED_COL}✖ %s${NORMAL_COL}\n" "$@"; }

set -eo pipefail

if [[ ! -f ${INVENTORY} ]]; then
  errorlog "${INVENTORY} file is missing, please check the inventory file is exists"
  exit 1
fi

deploy_cluster(){
:
}

main(){
  case $TYPE in
    deploy-cluster)
      infolog "######  start deploy kubernetes cluster  ######"
      deploy_cluster
      infolog "######  kubernetes cluster successfully installed  ######"
      ;;
    remove-cluster)
      infolog "######  start remove kubernetes cluster  ######"
      if ansible-playbook ${ANSIBLE_ARGS} ${KUBE_ROOT}/reset.yml >/dev/stdout 2>/dev/stderr; then
        rm -f ${INSTALL_STEP_FILE}
        infolog "######  kubernetes cluster successfully removed ######"
      fi
      ;;
    add-node)
      check_nodename
      infolog "######  start add worker to kubernetes cluster  ######"
      ansible-playbook ${ANSIBLE_ARGS} --limit="${NODES}" ${KUBE_ROOT}/playbooks/10-scale-nodes.yml >/dev/stdout 2>/dev/stderr
      ;;
    remove-node)
      check_nodename
      infolog "######  start remove worker from kubernetes cluster  ######"
      ansible-playbook ${ANSIBLE_ARGS} -e node="${NODES}" -e reset_nodes=true ${KUBE_ROOT}/remove-node.yml >/dev/stdout 2>/dev/stderr
      ;;
    *)
      errorlog "unknow [TYPE] parameter: ${TYPE}"
      ;;
  esac
}

main "$@"
```

- 分层部署 [playbooks](https://github.com/k8sli/kubespray/tree/main/playbooks)

不同于 kubespray 官方使用一个完整的 [cluster.yaml](https://github.com/kubernetes-sigs/kubespray/blob/master/cluster.yml) 来完成整个 K8s 集群的部署，我们在这里引入了分层部署的特性。即将集群部署分成若干个相互独立的 playbook，然后在各个 playbook 里引入我们增加的 roles 以及二开内容。这样的好处就是能和 kubespray 上游的代码保持相互独立，在 rebase 或者 cherry-pick 上游最新的代码能够避免出现冲突的现象。

```bash
playbooks
├── 00-default-ssh-config.yml    # 配置 ssh 连接
├── 01-cluster-bootstrap-os.yml  # 初始化集群节点
├── 02-cluster-etcd.yml          # 部署 etcd 集群
├── 03-cluster-kubernetes.yml    # 部署 k8s master 和 node
├── 04-cluster-network.yml       # 部署 CNI 插件
├── 05-cluster-apps.yml          # 部署一些 addon 组件如 coredns
└── 10-scale-nodes.yml           # 增删节点
```

分层部署的时候通过一个文件来记录已经部署成功的步骤，这样如果本次因为一些原因导致部署失败（如网络中断），那么下次重新部署的时候会跳过已经部署好的步骤，从失败的地方继续部署，以提升整体的部署效率。

```bash
deploy_cluster(){
  touch ${INSTALL_STEPS_FILE}
  STEPS="00-default-ssh-config 01-cluster-bootstrap-os 02-cluster-etcd 03-cluster-kubernetes 04-cluster-network 05-cluster-apps"
  for step in ${STEPS}; do
    if ! grep -q "${step}" ${INSTALL_STEPS_FILE}; then
      infolog "start deploy ${step}"
      if ansible-playbook ${ANSIBLE_ARGS} ${KUBE_ROOT}/playbooks/${step}.yml; then
        echo ${step} >> ${INSTALL_STEPS_FILE}
        infolog "${step} successfully installed"
      else
        errorlog "${step} installation failed"
        exit 1
      fi
    else
      warnlog "${step} is already installed, so skipped..."
    fi
  done
}
```

### 文件和镜像

我们需要提取出 kubespray 部署的时候依赖的文件和镜像，生成一个文件列表和镜像列表，然后根据这些列表下载并构建到一个镜像里。

- 文件

```yaml
# Download URLs
kubelet_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubelet"
kubectl_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubectl"
kubeadm_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubeadm"
etcd_download_url: "{{ download_url }}/github.com/coreos/etcd/releases/download/{{ etcd_version }}/etcd-{{ etcd_version }}-linux-{{ image_arch }}.tar.gz"
cni_download_url: "{{ download_url }}/github.com/containernetworking/plugins/releases/download/{{ cni_version }}/cni-plugins-linux-{{ image_arch }}-{{ cni_version }}.tgz"
calicoctl_download_url: "{{ download_url }}/github.com/projectcalico/calicoctl/releases/download/{{ calico_ctl_version }}/calicoctl-linux-{{ image_arch }}"
calico_crds_download_url: "{{ download_url }}/github.com/projectcalico/calico/archive/{{ calico_version }}.tar.gz"
crictl_download_url: "{{ download_url }}/github.com/kubernetes-sigs/cri-tools/releases/download/{{ crictl_version }}/crictl-{{ crictl_version }}-{{ ansible_system | lower }}-{{ image_arch }}.tar.gz"
helm_download_url: "{{ download_url }}/get.helm.sh/helm-{{ helm_version }}-linux-{{ image_arch }}.tar.gz"
nerdctl_download_url: "{{ download_url }}/github.com/containerd/nerdctl/releases/download/v{{ nerdctl_version }}/nerdctl-{{ nerdctl_version }}-{{ ansible_system | lower }}-{{ image_arch }}.tar.gz"
patched_kubeadm_download_url: "{{ download_url }}/github.com/k8sli/kubernetes/releases/download/{{ kubeadm_patch_version }}/kubeadm-linux-{{ image_arch }}"
```

在构建安装包的时候，将 download_url 变量设置为 `https://` ，在部署的时候将 `download_url` 设置为内网 文件服务器服务器的 URL，比如 `https://172.20.0.25:8080/files`，这样就可以实现文件构建和部署使用的统一，节省维护成本。

- 镜像

```yaml
# Define image repo and tag overwrite role/download/default/main.yml
pod_infra_image_tag: "{{ pod_infra_version }}"
pod_infra_image_repo: "{{ kube_image_repo }}/pause"

kube_proxy_image_repo: "{{ kube_image_repo }}/kube-proxy"
kube_apiserver_image_repo: "{{ kube_image_repo }}/kube-apiserver"
kube_scheduler_image_repo: "{{ kube_image_repo }}/kube-scheduler"
kube_controller_manager_image_repo: "{{ kube_image_repo }}/kube-controller-manager"

coredns_image_tag: "{{ coredns_version }}"
dnsautoscaler_image_tag: "{{ dnsautoscaler_version }}"
coredns_image_repo: "{{ docker_image_repo }}/coredns"
dnsautoscaler_image_repo: "{{ kube_image_repo }}/cluster-proportional-autoscaler-{{ image_arch }}"

# Full image name for generate images list
kube_proxy_image_name: "{{ kube_proxy_image_repo }}:{{ kube_version }}"
kube_apiserver_image_name: "{{ kube_apiserver_image_repo }}:{{ kube_version }}"
kube_scheduler_image_name: "{{ kube_scheduler_image_repo }}:{{ kube_version }}"
kube_controller_manager_image_name: "{{ kube_controller_manager_image_repo }}:{{ kube_version }}"
coredns_image_name: "{{ coredns_image_repo }}:{{ coredns_image_tag }}"
dnsautoscaler_image_name: "{{ dnsautoscaler_image_repo }}:{{ dnsautoscaler_image_tag }}"
nginx_image_name: "{{ nginx_image_repo }}:{{ nginx_image_tag }}"
pod_infra_image_name: "{{ pod_infra_image_repo }}:{{ pod_infra_image_tag }}"
calico_policy_image_name: "{{ calico_policy_image_repo }}:{{ calico_policy_image_tag }}"
calico_cni_image_name: "{{ calico_cni_image_repo }}:{{ calico_cni_image_tag }}"
calico_node_image_name: "{{ calico_node_image_repo }}:{{ calico_node_image_tag }}"
flannel_image_name: "{{ flannel_image_repo }}:{{ flannel_image_tag }}"
```

- `generate.sh` 列表生成脚本

我们根据上面 group_vars 中定义的版本号和一些参数，使用脚本的方式自动生成一个文件列表和镜像列表，构建的时候根据这些列表来下载所需要的文件和镜像。

```bash
#!/bin/bash
set -eo pipefail

SCRIPT_PATH=$(cd $(dirname $0); pwd)
REPO_PATH="${SCRIPT_PATH%/build}"

: ${IMAGE_ARCH:="amd64"}
: ${ANSIBLE_ARCHITECTURE:="x86_64"}
: ${DOWNLOAD_YML:="config/group_vars/all/download.yml"}

# ARCH used in convert {%- if image_arch != 'amd64' -%}-{{ image_arch }}{%- endif -%} to {{arch}}
if [[ "${IMAGE_ARCH}" != "amd64" ]]; then ARCH="-${IMAGE_ARCH}"; fi

cat > /tmp/generate.sh << EOF
arch=${ARCH}
download_url=https:/
image_arch=${IMAGE_ARCH}
ansible_system=linux
ansible_architecture=${ANSIBLE_ARCHITECTURE}
registry_project=library
registry_domain=localhost
EOF

# generate all component version by $DOWNLOAD_YML
grep '_version:' ${REPO_PATH}/${DOWNLOAD_YML} \
| sed 's/: /=/g;s/{{/${/g;s/}}/}/g' | tr -d ' ' >> /tmp/generate.sh

# generate download files url list
grep '_download_url:' ${REPO_PATH}/${DOWNLOAD_YML} \
| sed 's/: /=/g;s/ //g;s/{{/${/g;s/}}/}/g;s/|lower//g;s/^.*_url=/echo /g' >> /tmp/generate.sh

# generate download images list
grep -E '_image_tag:|_image_repo:|_image_name:' ${REPO_PATH}/${DOWNLOAD_YML} \
| sed "s#{%- if image_arch != 'amd64' -%}-{{ image_arch }}{%- endif -%}#{{arch}}#g" \
| sed 's/: /=/g;s/{{/${/g;s/}}/}/g' | tr -d ' ' >> /tmp/generate.sh

grep '_image_name:' ${REPO_PATH}/${DOWNLOAD_YML} \
| cut -d ':' -f1 | sed 's/^/echo $/g' >> /tmp/generate.sh
```

为了同时支持 amd64 和 arm64 的 CPU 架构，需要为两种架构各自生成列表，需要特殊处理一下。在这里踩的一个坑就是不同的组件镜像的命名方法千差万别，大致可以分为如下四种情况：

- 像 kube-apiserver 这些 k8s 组件的镜像，镜像名称和镜像 tag 是不需要加上 CPU 体系架构的；
- cluster-proportional-autoscaler 的镜像则是在镜像的名称后面加上了 CPU 体系架构的名称如 cluster-proportional-autoscaler-amd64，cluster-proportional-autoscaler-arm64；
- flannel 则是将 CPU 体系架构名称定义在镜像 tag 后面比如 `flannel:v0.14.0-amd64`；
- 还有 calico 更奇葩，amd64 架构的镜像不需要加体系架构的名称如 `calico/cni:v3.18.4`，而 arm64 的则必须要在镜像 tag 后面带上 CPU 体系架构比如 `calico/cni:v3.18.4-arm64`；

![](https://p.k8s.li/2021-08-31-pass-tob-k8s-offline-deploy-2.jpeg)

在这里需要强调一下，文件列表和镜像列表一定要使用自动化的方式来管理，切勿手动更新，这样能节省大量的维护成本，不然的话每次都手动去更新这些列表成本实在是太高了，而且特别容易出出错或者遗漏某个组件。

### kubespray-files

我们将 kubespray 部署所依赖的二进制文件构建在一个名为 kubespray-files 的镜像当中：

- 生成的文件列表

```bash
https://get.helm.sh/helm-v3.6.3-linux-amd64.tar.gz
https://github.com/containerd/nerdctl/releases/download/v0.8.1/nerdctl-0.8.1-linux-amd64.tar.gz
https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz
https://github.com/coreos/etcd/releases/download/v3.4.13/etcd-v3.4.13-linux-amd64.tar.gz
https://github.com/k8sli/kubernetes/releases/download/v1.21.3-patch-1.0/kubeadm-linux-amd64
https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.21.0/crictl-v1.21.0-linux-amd64.tar.gz
https://github.com/projectcalico/calico/archive/v3.18.4.tar.gz
https://github.com/projectcalico/calicoctl/releases/download/v3.18.4/calicoctl-linux-amd64
https://storage.googleapis.com/kubernetes-release/release/v1.21.3/bin/linux/amd64/kubeadm
https://storage.googleapis.com/kubernetes-release/release/v1.21.3/bin/linux/amd64/kubectl
https://storage.googleapis.com/kubernetes-release/release/v1.21.3/bin/linux/amd64/kubelet
```

- Dockerfile

```dockerfile
FROM alpine:latest as files
RUN apk --no-cache add wget ca-certificates
WORKDIR /build
COPY build/kubespray-files/files_*.list /build/
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && sed '/#/d' *${ARCH}.list > all_files.list \
    && wget -q -x -P /files -i all_files.list

FROM scratch
COPY --from=files /files /files
```

- 构建后的目录结构，通过目录层级的方式保留原有的 URL 地址，维护和使用起来比较方便

```bash
files/
├── get.helm.sh
│   └── helm-v3.6.3-linux-amd64.tar.gz
├── github.com
│   ├── containerd
│   │   └── nerdctl
│   │       └── releases
│   │           └── download
│   │               └── v0.8.1
│   │                   └── nerdctl-0.8.1-linux-amd64.tar.gz
│   ├── containernetworking
│   │   └── plugins
│   │       └── releases
│   │           └── download
│   │               └── v0.9.1
│   │                   └── cni-plugins-linux-amd64-v0.9.1.tgz
│   ├── coreos
│   │   └── etcd
│   │       └── releases
│   │           └── download
│   │               └── v3.4.13
│   │                   └── etcd-v3.4.13-linux-amd64.tar.gz
│   ├── k8sli
│   │   └── kubernetes
│   │       └── releases
│   │           └── download
│   │               └── v1.21.3-patch-1.0
│   │                   └── kubeadm-linux-amd64
│   ├── kubernetes-sigs
│   │   └── cri-tools
│   │       └── releases
│   │           └── download
│   │               └── v1.21.0
│   │                   └── crictl-v1.21.0-linux-amd64.tar.gz
│   └── projectcalico
│       ├── calico
│       │   └── archive
│       │       └── v3.18.4.tar.gz
│       └── calicoctl
│           └── releases
│               └── download
│                   └── v3.18.4
│                       └── calicoctl-linux-amd64
└── storage.googleapis.com
    └── kubernetes-release
        └── release
            └── v1.21.3
                └── bin
                    └── linux
                        └── amd64
                            ├── kubeadm
                            ├── kubectl
                            └── kubelet
```

### kubespray-images

我们同样将 kubespray 部署所需要的组件镜像构建在一个名为 kubespray-images 的镜像当中：

- 镜像列表

```bash
library/calico-cni:v3.18.4
library/calico-kube-controllers:v3.18.4
library/calico-node:v3.18.4
library/calico-pod2daemon-flexvol:v3.18.4
library/cluster-proportional-autoscaler-amd64:1.8.3
library/coredns:v1.8.0
library/flannel:v0.14.0-amd64
library/kube-apiserver:v1.21.3
library/kube-controller-manager:v1.21.3
library/kube-proxy:v1.21.3
library/kube-scheduler:v1.21.3
library/nginx:1.19
library/pause:3.3
```

- Dockerfile

在 Dockerfile 里完成所有镜像的下载，并使用 《[如何使用 registry 存储的特性](https://blog.k8s.li/skopeo-to-registry.html)》文中提到的骚操作，利用 registry 存储复用相同 layer 的特性，将 skopeo sync 下载的镜像转换成 registry 存储的结构。这样在部署的时候直接把这个 registry 存储目录挂载进 registry 容器的 `/var/lib/registry` 即可。特点是性能方面无论是构建和部署，都比常规使用 docker save 和 docker load 的方式要快至少 5 到 10 倍。

```bash
FROM alpine:3.12 as images
ARG SKOPEO_VERSION=v1.4.0
ARG YQ_VERSION=v4.11.2
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && apk --no-cache add bash wget ca-certificates \
    && wget -q -k https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH} -O /usr/local/bin/yq \
    && wget -q -k https://github.com/k8sli/skopeo/releases/download/${SKOPEO_VERSION}/skopeo-linux-${ARCH} -O /usr/local/bin/skopeo \
    && chmod a+x /usr/local/bin/*

WORKDIR /build
COPY build/kubespray-images/*  /build/
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && IMAGE_ARCH=${ARCH} bash build.sh

FROM scratch
COPY --from=images /build/docker /docker
```

- images_origin.yaml 镜像配置文件

考虑到有将镜像导入到已经存在的镜像仓库中的场景，这里我们需要修改一下镜像仓库的 repo。因为 `library` 这个 repo 在 harbor 中是默认自带的，在导入到 harbor 的过程中也不需要创建一些额外的 project ，所以将所有镜像的 repo 全部统一为 `library` 更通用一些。

这里用一个 yaml 配置文件来记录原镜像地址和 library 镜像的地址的对应关系。比如上游的 `k8s.gcr.io/kube-apiserver` 映射为 `library/kube-apiserver`， `quay.io/calico/node` 映射为 `library/calico-node`。

```yaml
---
# kubeadm core images
- src: k8s.gcr.io/kube-apiserver
  dest: library/kube-apiserver
- src: k8s.gcr.io/kube-controller-manager
  dest: library/kube-controller-manager
- src: k8s.gcr.io/kube-proxy
  dest: library/kube-proxy
- src: k8s.gcr.io/kube-scheduler
  dest: library/kube-scheduler
- src: k8s.gcr.io/coredns/coredns
  dest: library/coredns
- src: k8s.gcr.io/pause
  dest: library/pause

# kubernetes addons
- src: k8s.gcr.io/dns/k8s-dns-node-cache
  dest: library/k8s-dns-node-cache
- src: k8s.gcr.io/cpa/cluster-proportional-autoscaler-amd64
  dest: library/cluster-proportional-autoscaler-amd64
- src: k8s.gcr.io/cpa/cluster-proportional-autoscaler-arm64
  dest: library/cluster-proportional-autoscaler-arm64

# network plugin
- src: quay.io/calico/cni
  dest: library/calico-cni
- src: quay.io/calico/node
  dest: library/calico-node
- src: quay.io/calico/kube-controllers
  dest: library/calico-kube-controllers
- src: quay.io/calico/pod2daemon-flexvol
  dest: library/calico-pod2daemon-flexvol

- src: quay.io/calico/typha
  dest: library/calico-typha
- src: quay.io/coreos/flannel
  dest: library/flannel


# nginx for daemonset and offline
- src: docker.io/library/nginx
  dest: library/nginx
```

### kubeplay

kubeplay 部署的代码主要是由一些 shell 脚本和配置文件构成，用于完成 nginx 服务和 registry 服务的部署，以及最后调用 kubespray 来完成集群部署。

- 代码结构

```bash
kubeplay/
├── Dockerfile          # 构建完整安装包的 Dockerfile
├── compose.yaml        # compose 启动配置 yaml 文件
├── config
│   ├── compose
│   │   └── nginx.conf  # nginx 配置文件
│   └── rootCA.cnf      # 生成镜像仓库证书用到的 openssl 配置文件
├── config-sample.yaml  # 主配置文件
├── install.sh          # 安装操作然后
└── library             # 一些 shell 函数库
```

- Dockerfile

```dockerfile
FROM alpine:latest as downloader
ARG SKOPEO_VERSION=v1.4.0
ARG YQ_VERSION=v4.11.2
ARG NERDCTL_VERSION=0.11.0
ARG NGINX_VERSION=1.20-alpine
ARG RERGISRRY_VERSION=2.7.1
ARG KUBESPRAY_VERSION=latest
ARG KUBESPRAY_IMAGE=ghcr.io/k8sli/kubespray

# 下载部署时需要的工具，如 yq、skopeo、nerdctl-fullsss
WORKDIR /tools
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && apk --no-cache add wget ca-certificates \
    && wget -q -k https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}  -O /tools/yq-linux-${ARCH} \
    && wget -q -k https://github.com/k8sli/skopeo/releases/download/v1.4.0/skopeo-linux-${ARCH} -O /tools/skopeo-linux-${ARCH} \
    && wget -q -k https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-${ARCH}.tar.gz \
    && chmod a+x /tools/* \
    && ln -s /tools/skopeo-linux-${ARCH} /usr/bin/skopeo

# 下载一些镜像，如 nginx、registry、kubespray
WORKDIR /images
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && skopeo copy --insecure-policy --src-tls-verify=false --override-arch ${ARCH} --additional-tag nginx:${NGINX_VERSION} \
       docker://docker.io/library/nginx:${NGINX_VERSION} docker-archive:nginx-${NGINX_VERSION}.tar \
    && skopeo copy --insecure-policy --src-tls-verify=false --override-arch ${ARCH} --additional-tag registry:${RERGISRRY_VERSION} \
       docker://docker.io/library/registry:${RERGISRRY_VERSION} docker-archive:registry-${RERGISRRY_VERSION}.tar \
    && skopeo copy --insecure-policy --src-tls-verify=false --override-arch ${ARCH} --additional-tag kubespray:${KUBESPRAY_VERSION} \
       docker://${KUBESPRAY_IMAGE}:${KUBESPRAY_VERSION} docker-archive:kubespray-${KUBESPRAY_VERSION}.tar


FROM scratch
COPY . .
 # 将其它模块中的内容复制到 scratch 镜像中，构建的时候导出为 local 方式
COPY --from=downloader /tools /resources/nginx/tools
COPY --from=downloader /images /resources/images
COPY --from=${OS_PACKAGES_IMAGE}:${OS_PACKAGE_REPO_TAG} / /resources/nginx
COPY --from=${KUBESPRAY_FILES_IMAGE}:${KUBESPRAY_REPO_TAG} / /resources/nginx
COPY --from=${KUBESPRAY_IMAGES_IMAGE}:${KUBESPRAY_REPO_TAG} / /resources/registry
```

### 构建

由于最终的构建涉及多个模块和 repo，其流程比较复杂，详细的代码可参考源码 [build.yaml](https://github.com/k8sli/kubeplay/blob/main/.github/workflows/build.yaml) ，在这里只讲几个关键的部分

- checkout repo，将 kubespray 和 os-packages repo clone 到工作目录

```yaml
jobs:
  build-package:
    # 以 tag 的事件触发构建流水线
    if: startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-20.04
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        with:
          # fetch all git repo tag for define image tag
          fetch-depth: 0

      - name: Checkout kubespray repo
        uses: actions/checkout@v2
        with:
          ref: main
          fetch-depth: 0
          path: kubespray
          repository: ${{ github.repository_owner }}/kubespray

      - name: Checkout os-packages repo
        uses: actions/checkout@v2
        with:
          ref: main
          fetch-depth: 0
          path: os-packages
          repository: ${{ github.repository_owner }}/os-packages
```

- 获取 kubespray 和 os-packages 的 repo tag，根据它来确定 os-packages, kubespray-files, kubespray-images 这个三个镜像的 tag，并生成一个 All in One 的 Dockerfile 用于完成后续安装包的构建。

```yaml
      # 获取一些组件的版本和变量传递给 Dockerfile
      - name: Prepare for build images
        shell: bash
        run: |
          git describe --tags --always | sed 's/^/IMAGE_TAG=/' >> $GITHUB_ENV

          cd kubespray && git describe --tags --always | sed 's/^/KUBESPRAY_VERSION=/' >> $GITHUB_ENV && cd ..
          cd os-packages && git describe --tags --always | sed 's/^/OS_PACKAGE_REPO_TAG=/' >> $GITHUB_ENV && cd ..
          cp -rf kubespray/config config/kubespray && rm -rf kubespray os-packages

          source $GITHUB_ENV
          echo "" >> Dockerfile
          echo "COPY --from=${OS_PACKAGES_IMAGE}:${OS_PACKAGE_REPO_TAG} / /resources/nginx" >> Dockerfile
          echo "COPY --from=${KUBESPRAY_FILES_IMAGE}:${KUBESPRAY_VERSION} / /resources/nginx" >> Dockerfile
          echo "COPY --from=${KUBESPRAY_IMAGES_IMAGE}:${KUBESPRAY_VERSION} / /resources/registry" >> Dockerfile

          sed -n 's|image: nginx:|NGINX_VERSION=|p' compose.yaml | tr -d ' ' >> $GITHUB_ENV
          sed -n 's|image: registry:|RERGISRRY_VERSION=|p' compose.yaml | tr -d ' ' >> $GITHUB_ENV
```

- 使用 `outputs: type=local,dest=./` 构建镜像到本地目录而非 push 到 registry

```yaml
      - name: Build kubeplay image to local
        uses: docker/build-push-action@v2
        with:
          context: .
          file: Dockerfile
          platforms: linux/amd64,linux/arm64
          build-args: |
            NGINX_VERSION=${{ env.NGINX_VERSION }}
            RERGISRRY_VERSION=${{ env.RERGISRRY_VERSION }}
            KUBESPRAY_IMAGE=${{ env.KUBESPRAY_IMAGE }}
            KUBESPRAY_VERSION=${{ env.KUBESPRAY_VERSION }}
          outputs: type=local,dest=./
```

- 打包并上传安装包到 GitHub release 存储

```yaml
      - name: Prepare for upload package
        shell: bash
        run: |
          rm -rf linux_{amd64,arm64}/{Dockerfile,LICENSE}
          mv linux_amd64 kubeplay
          tar -I pigz -cf kubeplay-${IMAGE_TAG}-linux-amd64.tar.gz kubeplay --remove-files
          mv linux_arm64 kubeplay
          tar -I pigz -cf kubeplay-${IMAGE_TAG}-linux-arm64.tar.gz kubeplay --remove-files
          sha256sum kubeplay-${IMAGE_TAG}-linux-{amd64,arm64}.tar.gz > sha256sum.txt

      - name: Release and upload packages
        uses: softprops/action-gh-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          files: |
            sha256sum.txt
            kubeplay-${{ env.IMAGE_TAG }}-linux-amd64.tar.gz
            kubeplay-${{ env.IMAGE_TAG }}-linux-arm64.tar.gz
```

由此一个完整的离线安装包就构建完成了，接下来再讲一下安装流程

## 安装流程

在 [GitHub release 页面](https://github.com/k8sli/kubeplay/releases) 将我们的离线安装包下载到本地，需要根据 CPU 架构的类型选择相应的安装包。

![image](https://p.k8s.li/2021-08-24-offline-deploy-k8s-1.png)

下载完成之后再将安装包通过 scp 或者其他方式上传到内网的部署节点上，部署的文档可参考 [README](https://github.com/k8sli/kubeplay) 。过程十分简单：只需要填写好 `config.yaml` 配置文件然后执行 `bash install.sh` 即可完成 K8s 集群的一键部署。

下面从源码而非 README 文档的角度来讲一下部署流程的实现细节

### 安装包结构

- 配置文件 `config.yaml`

```yaml
# nginx 端口和 registry 域名配置参数
compose:
  # Compose bootstrap node ip, default is local internal ip
  internal_ip: 172.20.0.25
  # Nginx http server bind port for download files and packages
  nginx_http_port: 8080
  # Registry domain for CRI runtime download images
  registry_domain: kube.registry.local

# kubespray 参数
kubespray:
  # Kubernetes version by default, only support v1.20.6
  kube_version: v1.21.3
  # For deploy HA cluster you must configure a external apiserver access ip
  external_apiserver_access_ip: 127.0.0.1
  # Set network plugin to calico with vxlan mode by default
  kube_network_plugin: calico
  #Container runtime, only support containerd if offline deploy
  container_manager: containerd
  # Now only support host if use containerd as CRI runtime
  etcd_deployment_type: host
  # Settings for etcd event server
  etcd_events_cluster_setup: true
  etcd_events_cluster_enabled: true

# 集群节点 ssh 登录 inventory 配置
# Cluster nodes inventory info
inventory:
  all:
    vars:
      ansible_port: 22
      ansible_user: root
      ansible_ssh_pass: Password
      # ansible_ssh_private_key_file: /kubespray/config/id_rsa
    hosts:
      node1:
        ansible_host: 172.20.0.21
      node2:
        ansible_host: 172.20.0.22
      node3:
        ansible_host: 172.20.0.23
      node4:
        ansible_host: 172.20.0.24
    children:
      kube_control_plane:
        hosts:
          node1:
          node2:
          node3:
      kube_node:
        hosts:
          node1:
          node2:
          node3:
          node4:
      etcd:
        hosts:
          node1:
          node2:
          node3:
      k8s_cluster:
        children:
          kube_control_plane:
          kube_node:
      gpu:
        hosts: {}
      calico_rr:
        hosts: {}

# 一些默认的配置，一般情况下无需修改
### Default parameters ###
## This filed not need config, will auto update,
## if no special requirement, do not modify these parameters.
default:
  # NTP server ip address or domain, default is internal_ip
  ntp_server:
    - internal_ip
  # Registry ip address, default is internal_ip
  registry_ip: internal_ip
  # Offline resource url for download files, default is internal_ip:nginx_http_port
  offline_resources_url: internal_ip:nginx_http_port
  # Use nginx and registry provide all offline resources
  offline_resources_enabled: true
  # Image repo in registry
  image_repository: library
  # Kubespray container image for deploy user cluster or scale
  kubespray_image: "kubespray"
  # Auto generate self-signed certificate for registry domain
  generate_domain_crt: true
  # For nodes pull image, use 443 as default
  registry_https_port: 443
  # For push image to this registry, use 5000 as default, and only bind at 127.0.0.1
  registry_push_port: 5000
  # Set false to disable download all container images on all nodes
  download_container: false
```

- 安装包目录

```bash
kubeplay/
.
├── compose.yaml                 # compose 配置文件
├── config
│   ├── compose
│   │   └── nginx.conf           # nginx 配置文件
│   ├── kubespray
│   │   ├── env.yml
│   │   ├── group_vars           # kubespray group_vars  配置文件
│   │   └── inventory.ini
│   └── rootCA.cnf               # openssl 配置文件
├── config-sample.yaml           # 主配置文件
├── install.sh                   # 安装包入口脚本
├── library
└── resources                    # 所有离线资源
    ├── images
    │   ├── kubespray-v2.16.tar  # kubespray 镜像
    │   ├── nginx-1.20-alpine.tar# nginx 镜像
    │   └── registry-2.7.1.tar   # registry 镜像
    ├── nginx                    # rpm/deb 包以及一些二进制文件
    │   ├── centos               # centos rpm 包
    │   ├── debian               # debian deb 包
    │   ├── files                # 一些二进制文件
    │   ├── repos                # yum/apt 配置文件
    │   ├── tools                # 一些部署时依赖的工具
    │   └── ubuntu               # ubuntu deb 包
    └── registry
        └── docker               # 组件镜像 registry 存储目录
```

### compose 节点

需要单独划分出一个节点用户部署 nginx 和镜像仓库服务，并在该节点上运行 kubespray 来部署 K8s 集群。大致流程的代码如下：

```bash
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
    *)
      echowarn "unknow [TYPE] parameter: ${INSTALL_TYPE}"
      common::usage
      ;;
  esac
}

main "$@"
```

- 首先初始化节点，关闭防火墙和 `SELinux`
- 配置部署节点 yum/apt 离线源
- 安装一些部署依赖包，如 chrony、 libseccomp  等
- 安装一些工具如 yq, skopeo, kubectl 等
- 安装 nerdctl-full (containerd)
- 使用 nerdctl load -i 的方式导入nginx, registry, kubespray 镜像
- 使用 yq 渲染配置文件，生成 kubespray 需要的 env 文件和 inventory 文件
- 生成镜像仓库域名证书并将自签证书添加到主机的 CA trust 信任当中
- 在 `/etc/hosts` 中添加镜像仓库域名 hosts 映射
- 使用 nerdctl compose 启动 nginx 和 registry 服务
- 部署时钟同步服务 chrony
- 检查各个服务的状态
- 最后使用 nerdctl run 启动 kubespray 容器来部署 k8s 集群

### kubespray

部署的流程上基本上和 kubespray 官方大体一致，只不过我们引入里分层部署的特性

```bash
deploy_cluster(){
  touch ${INSTALL_STEPS_FILE}
  STEPS="00-default-ssh-config 01-cluster-bootstrap-os 02-cluster-etcd 03-cluster-kubernetes 04-cluster-network 05-cluster-apps"
  for step in ${STEPS}; do
    if ! grep -q "${step}" ${INSTALL_STEPS_FILE}; then
      infolog "start deploy ${step}"
      if ansible-playbook ${ANSIBLE_ARGS} ${KUBE_ROOT}/playbooks/${step}.yml; then
        echo ${step} >> ${INSTALL_STEPS_FILE}
        infolog "${step} successfully installed"
      else
        errorlog "${step} installation failed"
        exit 1
      fi
    else
      warnlog "${step} is already installed, so skipped..."
    fi
  done
}
```

- 配置堡垒机 ssh 登录（可选）
- 配置节点 yum/apt 源为 nginx 服务提供的源
- 将自签的域名证书添加到主机的 CA trust 信任当中
- 在 `/etc/hosts` 中添加镜像仓库域名 hosts 映射
- 关闭防火墙，安装时钟同步服务，进行同步时钟
- 初始化集群节点，安装部署依赖
- 安装容器运行时，下载文件和组件镜像
- 部署 etcd 集群
- 部署 K8s 集群
- 部署 CNI 插件
- 安装一些额外的 addon 组件如 (coredns)

至此整个打包和部署流程就完毕了，下面再讲几个打包/部署常见的问题

## 其他

### kubeadm 证书

通过修改 kubeadm 源码的方式将证书续命到 10 年，开启 `kubeadm_patch_enabled` 参数部署时就将 kubeadm 替换为修改后的 kubeadm。关于 kubeadm 的修改和构建和参考我之前写过的《[使用 GitHub Actions 编译 kubernetes 组件](https://blog.k8s.li/build-k8s-binary-by-github-actions.html)》。

- [roles/cluster/download/tasks/main.yml](https://github.com/k8sli/kubespray/blob/main/roles/cluster/download/tasks/main.yml)

```yaml
---
- name: Relpace kubeadm binary file as patched version
  get_url:
    url: "{{ patched_kubeadm_download_url }}"
    dest: "{{ bin_dir }}/kubeadm"
    mode: 0755
    owner: root
    group: root
  tags:
    - kubeadm
  when: kubeadm_patch_enabled | default(true) | bool
```

### 镜像缓存

os-packages, kubespray-base, kubespray-files, kubespray-images 这四个镜像在构建的时候都会采用 md5 值的方式校验是否需要重新构建镜像，这样能够大大提升 CI 的执行效率，下面以 kubespray-base 这个镜像为例介绍其原理和实现：

- 在构建镜像前会有一个 md5 计算和校验的步骤，将与该镜像紧密相关的文件内容进行汇总并生成 md5 值，并将这个值得以 label 的方式保存在镜像的元数据信息当中。如果该值与上个最新的镜像中的 md5 值相等，那么就不需要重新构建该镜像，只需要进行 retag 即可。

```yaml
      - name: Prepare for build images
        shell: bash
        run: |
          git describe --tags --always | sed 's/^/IMAGE_TAG=/' >> $GITHUB_ENV
          git branch --show-current | sed 's/^/BRANCH_NAME=/' >> $GITHUB_ENV
          git branch --show-current | sed 's/master/latest/;s/main/latest/;s/^/IMAGE_TAG_BY_BRANCH=/' >> $GITHUB_ENV
          sed -n 's/^kube_version: /KUBE_VERSION=/p' roles/kubespray-defaults/defaults/main.yaml >> $GITHUB_ENV
          cat build/kubespray-base/Dockerfile requirements.txt tests/requirements.txt .github/workflows/build.yaml \
          | md5sum | tr -d '\ -' | sed 's/^/BASE_MD5=md5-/' >> $GITHUB_ENV

          source $GITHUB_ENV
          if skopeo inspect docker://${BASE_IMAGE_REPO}:${BRANCH_NAME} > mainfest.json; then
            jq -r '.Labels.BASE_MD5' mainfest.json | sed 's/^/LATEST_BASE_MD5=/' >> $GITHUB_ENV
          else
            echo 'LATEST_BASE_MD5=null' >> $GITHUB_ENV
          fi
```

- 如果当前md5 的值与最新的 md5 值相等，就重新生成一个新的 Dockerfile 来进行镜像 retag 的操作。

```yaml
      - name: Replace Dockerfile if MD5 not update
        if: ${{ env.BASE_MD5 == env.LATEST_BASE_MD5 }}
        run: |
          echo "FROM ${{ env.BASE_IMAGE_REPO }}:${{ env.BASE_MD5 }}" > build/kubespray-base/Dockerfile

```

- 构建镜像并将 md5 值作为 labels 填充到镜像的元数据信息当中。

```yaml
      - name: Build and push kubespray-base images
        uses: docker/build-push-action@v2
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          file: build/kubespray-base/Dockerfile
          platforms: linux/amd64,linux/arm64
          cache-from: type=local,src=/tmp/.buildx-cache
          cache-to: type=local,dest=/tmp/.buildx-cache-new
          build-args: KUBE_VERSION=${{ env.KUBE_VERSION }}
          labels: BASE_MD5=${{ env.BASE_MD5 }}
          tags: |
            ${{ env.BASE_IMAGE_REPO }}:${{ env.IMAGE_TAG }}
            ${{ env.BASE_IMAGE_REPO }}:${{ env.BASE_MD5 }}
            ${{ env.BASE_IMAGE_REPO }}:${{ env.BRANCH_NAME }}
            ${{ env.BASE_IMAGE_REPO }}:${{ env.IMAGE_TAG_BY_BRANCH }}
```

使用这种方式的好处就在于在不需要构建镜像的时候能大幅度提升 CI 的运行效率。

## 推荐阅读

- [云原生 PaaS 产品发布&部署方案](https://blog.k8s.li/pass-platform-release.html)
- [政采云基于 sealer 的私有化业务交付实践](https://mp.weixin.qq.com/s/7hKkdBUXHFZt5q3KbpmU6Q)
- [使用 docker build 制作 yum/apt 离线源](https://blog.k8s.li/make-offline-mirrors.html)
- [使用 Kubespray 本地开发测试部署 kubernetes 集群](https://blog.k8s.li/deploy-k8s-by-kubespray.html)
- [什么？发布流水线中镜像“同步”速度又提升了 15 倍 ！](https://blog.k8s.li/select-registry-images.html)
- [如何使用 registry 存储的特性](https://blog.k8s.li/skopeo-to-registry.html)
