---
title: 使用 BuildKit on Kubernetes 构建多架构容器镜像
date: 2023-04-20
updated: 2023-04-20
slug:
categories:
- 技術
tag:
- kubernetes
- BuildKit
copyright: true
comment: true
---

去年曾写过一篇介绍如何使用 docker in pod 的方式在 Kubernetes 集群上构建容器镜像的博客 ➡️《[流水线中使用 docker in pod 方式构建容器镜像](https://blog.k8s.li/docker-in-pod.html)》。自己负责的项目中稳定使用了一年多没啥问题，用着还是挺香的。虽然说众多 Kubernetes PaaS 平台都逐渐抛弃了 docker 作为容器运行时，但 docker 在镜像构建领域还是占据着统治地位滴。不过最近的一些项目需要构建多 CPU 架构的容器镜像，docker in pod 的方式就不太行了。于是就调研了一下 BuildKit，折腾出来 BuildKit on Kubernetes 构建镜像的新玩法分享给大家。

## qemu VS native

默认情况下，docker build 只能构建出与 docker 主机相同 CPU 架构的容器镜像。如果要在同一台主机上构建多 CPU 架构的镜像，需要配置 qemu 或 binfmt。例如，在 amd64 主机上构建 arm64 架构的镜像，可以使用 [tonistiigi/binfmt](https://github.com/tonistiigi/binfmt) 项目，在主机上运行 `docker run --privileged --rm tonistiigi/binfmt --install arm64` 命令来安装一个 CPU 指令集的模拟器，以处理不同 CPU 架构之间的指令集翻译问题。同样我们在 GitHub 上通过 GitHub Action 提供的 [runner](https://github.com/actions/runner-images) 来构建多 CPU 架构的容器镜像，也是采用类似的方式。

```yaml
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Build open-vm-tool rpms to local
        uses: docker/build-push-action@v2
        with:
          context: .
          file: Dockerfile
          platforms: linux/${{ matrix.arch }}
          outputs: type=local,dest=artifacts
```

然而，这种方式构建多 CPU 架构的镜像存在着比较严重的性能问题。尤其是在编译构建一些 C/C++ 项目时，由于 CPU 指令需要翻译的问题，会导致编译速度十分慢缓慢。例如，使用 GitHub 官方提供的机器上构建 open-vm-tools 这个 RPM 包，构建相同 CPU 架构的 amd64 镜像只需要不到 10 分钟就能完成，而构建异构的 arm64 镜像则接近一个小时，构建速度相差 6 倍之多。如果将 arm64 的镜像放到相同 CPU 架构的主机上来构建，构建时间和 amd64 差不太多。

![](https://p.k8s.li/2023-04-20-build-open-vm-tools.png)

由此可见，在同一台机器上构建异构的容器镜像有着比较严重的性能问题。因此构建多 CPU 架构的容器镜像性能最好的方案就是在对应 CPU 架构的机器上来构建，这种原生的构建方式由于没有 CPU 指令翻译这一开销性能当然是最棒滴，这种方式也被称之为 [native nodes provide](https://docs.docker.com/build/building/multi-platform/#building-multi-platform-images)。

## BuildKit

[BuildKit](https://github.com/moby/buildkit) 是一个将 source code 通过自定义的构建语法转换为 build artifacts 的开源构建工具，被称为下一代镜像构建工具。同时它也是 docker 的一部分，负责容器镜像的构建。我们平时使用 docker build 命令时就是它负责后端容器镜像的构建。BuildKit 它支持四种不同的驱动来执行镜像的构建：

- docker：使用内嵌在 Docker 守护程序中的 BuildKit 库。默认情况下 docker build 就是这种方式；
- docker-container：创建一个专门的 BuildKit 容器，将 BuildKit 运行在容器中，有点类似于 docker in docker；
- kubernetes：在 kubernetes 集群中创建  BuildKit pod，类似于我之前提到的 docker in pod 的方式；
- remote：通过 TCP 或 SSH 等方式连接一个远端的 BuildKit  守护进程；

不同的驱动所支持的特性也不太一样：

| Feature                      |  `docker`  | `docker-container` | `kubernetes` |      `remote`      |
| :--------------------------- | :---------: | :----------------: | :----------: | :----------------: |
| **Automatically load image** |     ✅     |                    |              |                    |
| **Cache export**             | Inline only |         ✅         |      ✅      |         ✅         |
| **Tarball output**           |            |         ✅         |      ✅      |         ✅         |
| **Multi-arch images**        |            |         ✅         |      ✅      |         ✅         |
| **BuildKit configuration**   |            |         ✅         |      ✅      | Managed externally |

如果想要使用原生方式构建多 CPU 架构的容器镜像，则需要为 BuildKit 创建多个不同的 driver。同时，由于该构建方案运行在 Kubernetes 集群上，我们当然是采用 Kubernetes 这个 driver 啦。然而，这要求 Kubernetes 集群必须是一个异构集群，即集群中的 node 节点必须同时包含对应 CPU 架构的机器。然而，这也引出了另一个尴尬难题：目前主流的 Kubernetes 部署工具对异构 Kubernetes 集群的支持并不是十分完善，因为异构的 kubernetes 集群有点奇葩需求不多的缘故吧。在此，咱推荐使用 [k3s](https://github.com/k3s-io/k3s) 或 [kubekey](https://github.com/kubesphere/kubekey) 来部署异构 Kubernetes 集群。

## BuildKit on Kubernetes

其实在 kubernetes 集群中部署 buildkit 官方是提供了一些 [manifest](https://github.com/moby/buildkit/tree/master/examples/kubernetes)，不过并不适合我们现在的这个场景，因此我们使用 [buildx](https://github.com/docker/buildx) 来部署。Buildx 是一个 Docker CLI 插件，它扩展了 docker build 命令的镜像构建功能，完全支持 BuildKit builder 工具包提供的特性。它提供了与 docker build 相似的操作体验，并增加了许多新的构建特性，例如多架构镜像构建和并发构建。

在部署 BuildKit 前我们需要先把异构的 kubernetes 集群部署好，部署的方式和流程本文就不在赘述了，可以参考 k3s 或 kubekey 的官方文档。部署好之后我们将 kubeconfig 文件复制到本机并配置好 kubectl 连接这个 kubernetes 集群。

```bash
$ kubectl get node -o wide --show-labels
NAME                             STATUS   ROLES                  AGE   VERSION        INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME          LABELS
product-builder-ci-arm-node-02   Ready    <none>                 11d   v1.26.3+k3s1   192.168.26.20    <none>        Ubuntu 22.04.1 LTS   5.15.0-69-generic   containerd://1.6.19-k3s1   beta.kubernetes.io/arch=arm64,beta.kubernetes.io/os=linux,kubernetes.io/arch=arm64,kubernetes.io/hostname=product-builder-ci-arm-node-02,kubernetes.io/os=linux
cluster-installer                Ready    control-plane,master   11d   v1.26.3+k3s1   192.168.28.253   <none>        Ubuntu 20.04.2 LTS   5.4.0-146-generic   containerd://1.6.19-k3s1   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=cluster-installer,kubernetes.io/os=linux,node-role.kubernetes.io/control-plane=true,node-role.kubernetes.io/master=true
```

准备好 kubernetes 集群后我们我们还需要安装 docker-cli 以及 buildx 插件

```bash
# 安装 docker，如果已经安装可以跳过该步骤
$ curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装 buildx docker-cli 插件
$ BUILDX_VERSION=v0.10.4
$ mkdir -p $HOME/.docker/cli-plugins
$ wget https://github.com/docker/buildx/releases/download/$BUILDX_VERSION/buildx-$BUILDX_VERSION.linux-amd64
$ mv buildx-$BUILDX_VERSION.linux-amd64 $HOME/.docker/cli-plugins/docker-buildx
$ chmod +x $HOME/.docker/cli-plugins/docker-buildx
$ docker buildx version
github.com/docker/buildx v0.10.4 c513d34049e499c53468deac6c4267ee72948f02
```

接着我们参考 [docker buildx create](https://docs.docker.com/engine/reference/commandline/buildx_create/) 和 [Kubernetes driver](https://docs.docker.com/build/drivers/kubernetes/) 文档在 kubernetes 集群中部署 amd64 和 arm64 CPU 架构对应的 builder。

```bash
# 创建一个单独的 namespace 来运行 buildkit
$ kubectl create namespace buildkit --dry-run=client -o yaml | kubectl apply -f -

# 创建 linux/amd64 CPU 架构的 builder
$ docker buildx create \
  --bootstrap \
  --name=kube \
  --driver=kubernetes \
  --platform=linux/amd64 \
  --node=builder-amd64 \
  --driver-opt=namespace=buildkit,replicas=2,nodeselector="kubernetes.io/arch=amd64"

# 创建 linux/arm64 CPU 架构的 builder
$ docker buildx create \
  --append \
  --bootstrap \
  --name=kube \
  --driver=kubernetes \
  --platform=linux/arm64 \
  --node=builder-arm64 \
  --driver-opt=namespace=buildkit,replicas=2,nodeselector="kubernetes.io/arch=arm64"

# 查看 builder 的 deployment 是否正常运行
$ kubectl get deploy -n buildkit
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
builder-amd64   2/2     2            2           60s
builder-arm64   2/2     2            2           30s

# 最后将 docker 默认的的 builder 设置为我们创建的这个
$ docker buildx use kube
```

docker buildx create 参数

| 名称                                                                                                                                | 描述                                                        |
| ----------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| [`--append`](https://www.zhaowenyu.com/docker-doc/reference/dockercmd/dockercmd-docker-buildx-create.html#append)                   | 追加一个构建节点到 builder 实例中                           |
| `--bootstrap`                                                                                                                       | builder 实例创建后进行初始化启动                            |
| [`--buildkitd-flags`](https://www.zhaowenyu.com/docker-doc/reference/dockercmd/dockercmd-docker-buildx-create.html#buildkitd-flags) | 配置 buildkitd 进程的参数                                   |
| [`--config`](https://www.zhaowenyu.com/docker-doc/reference/dockercmd/dockercmd-docker-buildx-create.html#config)                   | 指定 BuildKit 配置文件                                      |
| [`--driver`](https://www.zhaowenyu.com/docker-doc/reference/dockercmd/dockercmd-docker-buildx-create.html#driver)                   | 指定驱动 (支持: `docker`, `docker-container`, `kubernetes`) |
| [`--driver-opt`](https://www.zhaowenyu.com/docker-doc/reference/dockercmd/dockercmd-docker-buildx-create.html#driver-opt)           | 驱动选项                                                    |
| [`--leave`](https://www.zhaowenyu.com/docker-doc/reference/dockercmd/dockercmd-docker-buildx-create.html#leave)                     | 从 builder 实例中移除一个构建节点                           |
| [`--name`](https://www.zhaowenyu.com/docker-doc/reference/dockercmd/dockercmd-docker-buildx-create.html#name)                       | 指定 Builder 实例的名称                                     |
| [`--node`](https://www.zhaowenyu.com/docker-doc/reference/dockercmd/dockercmd-docker-buildx-create.html#node)                       | 创建或修改一个构建节点                                      |
| [`--platform`](https://www.zhaowenyu.com/docker-doc/reference/dockercmd/dockercmd-docker-buildx-create.html#platform)               | 强制指定节点的平台信息                                      |
| [`--use`](https://www.zhaowenyu.com/docker-doc/reference/dockercmd/dockercmd-docker-buildx-create.html#use)                         | 创建成功后，自动切换到该 builder 实例                       |

`--driver-opt` kubernetes driver 参数

| Parameter         | Description                                                                                                                                                                                                                                                 |
| :---------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `image`           | buildkit 的容器镜像                                                                                                                                                                                                                                         |
| `namespace`       | buildkit 部署在哪个 namespace                                                                                                                                                                                                                               |
| `replicas`        | deployment 的副本数                                                                                                                                                                                                                                         |
| `requests.cpu`    | pod 的资源限额配置，如果并发构建的任务比较多建议多给点或者不配置                                                                                                                                                                                            |
| `requests.memory` | 同上                                                                                                                                                                                                                                                        |
| `limits.cpu`      | 同上                                                                                                                                                                                                                                                        |
| `limits.memory`   | 同上                                                                                                                                                                                                                                                        |
| `nodeselector`    | node 标签选择器，这里我们给对应 CPU 架构的 builder 添加上 `kubernetes.io/arch=$arch` 这个 node 标签选择器来限制运行在指定节点上。                                                                                                                           |
| `tolerations`     | 污点容忍配置                                                                                                                                                                                                                                                |
| `rootless`        | 是否选择 rootless 模式。不过要求 kubernetes 版本在 1.19 以上并推荐使用 Ubuntu 内核 [Using Ubuntu host kernel is recommended](https://github.com/moby/buildkit/blob/master/docs/rootless.md)。个人感觉 rootless 模式限制比较多而且也有一堆问题，不建议使用。 |
| `loadbalance`     | 负载均衡模式，无特殊要求使用默认值即可。                                                                                                                                                                                                                    |
| `qemu.install`    | 是否安装 qemu 以支持在同一台机器上构建多架构的镜像，这种方式就倒车回去了，违背了我们这个方案的初衷，不建议使用                                                                                                                                              |
| `qemu.image`      | qemu 模拟器的镜像，不建议使用                                                                                                                                                                                                                               |

部署好之后我们运行 `docker buildx inspect` 就可以查看到 builder 的详细信息

```bash
$ docker buildx inspect kube
Name:          kube
Driver:        kubernetes
Last Activity: 2023-04-19 00:27:57 +0000 UTC

Nodes:
Name:           builder-amd64
Endpoint:       kubernetes:///kube?deployment=builder-amd64&kubeconfig=
Driver Options: nodeselector="kubernetes.io/arch=amd64" replicas="2" namespace="buildkit"
Status:         running
Buildkit:       v0.11.5
Platforms:      linux/amd64*, linux/amd64/v2, linux/amd64/v3, linux/386

Name:           builder-amd64
Endpoint:       kubernetes:///kube?deployment=builder-amd64&kubeconfig=
Driver Options: replicas="2" namespace="buildkit" nodeselector="kubernetes.io/arch=amd64"
Status:         running
Buildkit:       v0.11.5
Platforms:      linux/amd64*, linux/amd64/v2, linux/amd64/v3, linux/386

Name:           builder-arm64
Endpoint:       kubernetes:///kube?deployment=builder-arm64&kubeconfig=
Driver Options: image="docker.io/moby/buildkit:v0.11.5" namespace="buildkit" nodeselector="kubernetes.io/arch=arm64" replicas="2"
Status:         running
Buildkit:       v0.11.5
Platforms:      linux/arm64*

Name:           builder-arm64
Endpoint:       kubernetes:///kube?deployment=builder-arm64&kubeconfig=
Driver Options: nodeselector="kubernetes.io/arch=arm64" replicas="2" image="docker.io/moby/buildkit:v0.11.5" namespace="buildkit"
Status:         running
Buildkit:       v0.11.5
Platforms:      linux/arm64*
```

同时 buildx 会在当前用户的 `~/.docker/buildx/instances/kube` 路径下 生成一个 json 格式的配置文件，通过这个配置文件再加上 kubeconfig 文件就可以使用 buildx 来连接 buildkit 构建镜像啦。

```json
{
  "Name": "kube",
  "Driver": "kubernetes",
  "Nodes": [
    {
      "Name": "builder-amd64",
      "Endpoint": "kubernetes:///kube?deployment=builder-amd64&kubeconfig=",
      "Platforms": [
        {
          "architecture": "amd64",
          "os": "linux"
        }
      ],
      "Flags": null,
      "DriverOpts": {
        "namespace": "buildkit",
        "nodeselector": "kubernetes.io/arch=amd64",
        "replicas": "2"
      },
      "Files": null
    },
    {
      "Name": "builder-arm64",
      "Endpoint": "kubernetes:///kube?deployment=builder-arm64&kubeconfig=",
      "Platforms": [
        {
          "architecture": "arm64",
          "os": "linux"
        }
      ],
      "Flags": null,
      "DriverOpts": {
        "image": "docker.io/moby/buildkit:v0.11.5",
        "namespace": "buildkit",
        "nodeselector": "kubernetes.io/arch=arm64",
        "replicas": "2"
      },
      "Files": null
    }
  ],
  "Dynamic": false
}
```

我们将 buildx 生成的配置文件创建为 configmap 保存在 kubernetes 集群中，后面我们需要将这个 configmap 挂载到 pod 里。

```bash
$ kubectl create cm buildx.config --from-file=data=$HOME/.docker/buildx/instances/kube
```

## 构建测试

是骡子是马拉出来遛遛，我们就以构建 **[open-vm-tools-oe2003](https://github.com/muzi502/open-vm-tools-oe2003)** RPM 为例来验证一下咱的这个方案究竟靠不靠谱 🤣。这个项目是给某为的 openEuler 2003 构建 open-vm-tools rpm 包用的 Dockerfile 如下。

```dockerfile
FROM openeuler/openeuler:20.03 as builder
RUN sed -i "s#repo.openeuler.org#repo.huaweicloud.com/openeuler#g" /etc/yum.repos.d/openEuler.repo && \
    dnf install rpmdevtools* dnf-utils -y && \
    rpmdev-setuptree

# clone open-vm-tools source code and update spec file for fixes oe2003 build error
ARG COMMIT_ID=8a7f961
ARG GIT_REPO=https://gitee.com/src-openeuler/open-vm-tools.git
WORKDIR /root/rpmbuild/SOURCES
RUN git clone $GIT_REPO . && \
    git reset --hard $COMMIT_ID && \
    sed -i 's#^%{_bindir}/vmhgfs-fuse$##g' open-vm-tools.spec && \
    sed -i 's#^%{_bindir}/vmware-vmblock-fuse$##g' open-vm-tools.spec && \
    sed -i 's#gdk-pixbuf-xlib#gdk-pixbuf2-xlib#g' open-vm-tools.spec

# install open-vm-tools rpm build dependencies
RUN yum-builddep -y open-vm-tools.spec
RUN rpmbuild --define "dist .oe1" -ba open-vm-tools.spec --quiet

# download rpm runtime dependencies
FROM openeuler/openeuler:20.03 as dep
COPY --from=builder /root/rpmbuild/RPMS/ /root/rpmbuild/RPMS/
RUN sed -i "s#repo.openeuler.org#repo.huaweicloud.com/openeuler#g" /etc/yum.repos.d/openEuler.repo && \
    dnf install -y --downloadonly --downloaddir=/root/rpmbuild/RPMS/$(arch) /root/rpmbuild/RPMS/$(arch)/*.rpm

# copy rpms to local
FROM scratch
COPY --from=dep /root/rpmbuild/RPMS/ /
COPY --from=builder /root/rpmbuild/RPMS/ /
```

其中 `RUN rpmbuild --define "dist .oe1" -ba open-vm-tools.spec --quiet` 这个步骤是构建和编译 RPM 里的二进制文件因此十分耗费 CPU 资源，也是整个镜像构建最耗时的一部分。

```dockerfile
# copy rpms to local
FROM scratch
COPY --from=dep /root/rpmbuild/RPMS/ /
COPY --from=builder /root/rpmbuild/RPMS/ /
```

因为我们构建的目标产物是 RPM 包文件并不需要把镜像 push 到镜像仓库中，所以 `Dockerfile` 最后面这一段是为了将构建产物捞出来输出到我们本地的目录上，buildx 对应的参数就是 `--output type=local,dest=path`。同时为了排除 cache 的影响，我们再加上 `--no-cache` 参数构建过程中不使用缓存。接着我们运行 docker build 命令进行构建，看一下构建的用时是多久 🤓

```bash
DOCKER_BUILDKIT=1 docker buildx build \
	--no-cache \
	--ulimit nofile=1024:1024 \
	--platform linux/amd64,linux/arm64 \
	-f /root/usr/src/github.com/muzi502/open-vm-tools-oe2003/Dockerfile \
	--output type=local,dest=/root/usr/src/github.com/muzi502/open-vm-tools-oe2003/output \
	/root/usr/src/github.com/muzi502/open-vm-tools-oe2003
[+] Building 364.6s (30/30) FINISHED
 => [internal] load .dockerignore                                                                                                         0.0s
 => => transferring context: 2B                                                                                                           0.0s
 => [internal] load build definition from Dockerfile                                                                                      0.0s
 => => transferring dockerfile: 1.35kB                                                                                                    0.0s
 => [internal] load .dockerignore                                                                                                         0.0s
 => => transferring context: 2B                                                                                                           0.0s
 => [internal] load build definition from Dockerfile                                                                                      0.0s
 => => transferring dockerfile: 1.35kB                                                                                                    0.0s
 => [linux/amd64 internal] load metadata for docker.io/openeuler/openeuler:20.03                                                          2.1s
 => [linux/arm64 internal] load metadata for docker.io/openeuler/openeuler:20.03                                                          2.1s
 => [auth] openeuler/openeuler:pull token for registry-1.docker.io                                                                        0.0s
 => [auth] openeuler/openeuler:pull token for registry-1.docker.io                                                                        0.0s
 => CACHED [linux/arm64 builder 1/6] FROM docker.io/openeuler/openeuler:20.03@sha256:4aef44f5d6af7b07b02a9a3b29cbac5f1f109779209d7649a2e  0.0s
 => => resolve docker.io/openeuler/openeuler:20.03@sha256:4aef44f5d6af7b07b02a9a3b29cbac5f1f109779209d7649a2ea196a681a52ee                0.0s
 => [linux/arm64 builder 2/6] RUN sed -i "s#repo.openeuler.org#repo.huaweicloud.com/openeuler#g" /etc/yum.repos.d/openEuler.repo &&      54.6s
 => CACHED [linux/amd64 builder 1/6] FROM docker.io/openeuler/openeuler:20.03@sha256:4aef44f5d6af7b07b02a9a3b29cbac5f1f109779209d7649a2e  0.0s
 => => resolve docker.io/openeuler/openeuler:20.03@sha256:4aef44f5d6af7b07b02a9a3b29cbac5f1f109779209d7649a2ea196a681a52ee                0.0s
 => [linux/amd64 builder 2/6] RUN sed -i "s#repo.openeuler.org#repo.huaweicloud.com/openeuler#g" /etc/yum.repos.d/openEuler.repo &&      65.1s
 => [linux/arm64 builder 3/6] WORKDIR /root/rpmbuild/SOURCES                                                                              0.3s
 => [linux/arm64 builder 4/6] RUN git clone https://gitee.com/src-openeuler/open-vm-tools.git . &&     git reset --hard 8a7f961 &&     s  1.8s
 => [linux/arm64 builder 5/6] RUN yum-builddep -y open-vm-tools.spec                                                                     58.8s
 => [linux/amd64 builder 3/6] WORKDIR /root/rpmbuild/SOURCES                                                                              0.3s
 => [linux/amd64 builder 4/6] RUN git clone https://gitee.com/src-openeuler/open-vm-tools.git . &&     git reset --hard 8a7f961 &&     s  2.1s
 => [linux/amd64 builder 5/6] RUN yum-builddep -y open-vm-tools.spec                                                                     71.9s
 => [linux/arm64 builder 6/6] RUN rpmbuild --define "dist .oe1" -ba open-vm-tools.spec --quiet                                          175.2s
 => [linux/amd64 builder 6/6] RUN rpmbuild --define "dist .oe1" -ba open-vm-tools.spec --quiet                                          181.4s
 => [linux/arm64 dep 2/3] COPY --from=builder /root/rpmbuild/RPMS/ /root/rpmbuild/RPMS/                                                   0.1s
 => [linux/arm64 dep 3/3] RUN sed -i "s#repo.openeuler.org#repo.huaweicloud.com/openeuler#g" /etc/yum.repos.d/openEuler.repo &&     dnf  31.6s
 => [linux/amd64 dep 2/3] COPY --from=builder /root/rpmbuild/RPMS/ /root/rpmbuild/RPMS/                                                   0.1s
 => [linux/amd64 dep 3/3] RUN sed -i "s#repo.openeuler.org#repo.huaweicloud.com/openeuler#g" /etc/yum.repos.d/openEuler.repo &&     dnf  39.2s
 => [linux/arm64 stage-2 1/2] COPY --from=dep /root/rpmbuild/RPMS/ /                                                                      0.1s
 => [linux/arm64 stage-2 2/2] COPY --from=builder /root/rpmbuild/RPMS/ /                                                                  0.2s
 => exporting to client directory                                                                                                         2.4s
 => => copying files linux/arm64 35.93MB                                                                                                  2.3s
 => [linux/amd64 stage-2 1/2] COPY --from=dep /root/rpmbuild/RPMS/ /                                                                      0.1s
 => [linux/amd64 stage-2 2/2] COPY --from=builder /root/rpmbuild/RPMS/ /                                                                  0.2s
 => exporting to client directory                                                                                                         1.6s
 => => copying files linux/amd64 36.59MB                                                                                                  1.6s
tree rpms
```

| 用时对比     | amd64 (Intel(R) Xeon(R) Silver 4110 CPU @ 2.10GHz) | arm64（HUAWEI Kunpeng 920 5250 2.6 GHz） |
| ------------ | -------------------------------------------------- | ---------------------------------------- |
| yum-builddep | 71.9s                                              | 58.8s                                    |
| rpmbuild     | 181.4s                                             | 175.2s                                   |

通过上面的构建用时对比可以看到 arm64 的机器上构建比 amd64 要快一点，是由于 Kunpeng 920 5250 CPU 主频比 Intel Xeon 4110 高的缘故，如果主频拉齐的话二者的构建速度应该是差不多的。可惜我们 IDC 内部的机器 CPU 大多是**十几块钱包邮还送硅脂的钥匙串**（某宝上搜 E5 v3/v4）找不到合适的机器进行 PK 对比，大家自己脑补一下吧🥹，要不汝给咱点 CPU 😂。

总之我们这套方案实现的效果还是蛮不错滴，比用 qemu 模拟多架构的方式不知道高到哪里去了 🤓。

## Jenkins 流水线

首先，我们需要定制自己的 Jenkins slave pod 的基础镜像，将 docker 和 buildx 这两个二进制工具添加进来。需要注意的是，这里的 docker 命令行只是作为客户端使用，因此我们可以直接从 docker 的官方镜像中提取此二进制文件。不同的项目需要不同的工具集，可以参考我的 [Dockerfile](https://github.com/muzi502/buildkit-on-k8s-example/blob/master/Dockerfile)。

```dockerfile
FROM python:3.10-slim
ARG BUILDER_NAME=kube
COPY --from=docker.io/library/docker:20.10.12-dind-rootless /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker.io/docker/buildx-bin:v0.10 /buildx /usr/libexec/docker/cli-plugins/docker-buildx
```

这里还有一个冷门的 Dockerfile 的小技巧：通过 `COPY --from=` 的方式来下载一些二进制工具。基本上我写的 Dockerfile 都会用它，可谓是屡试不爽 `身经百战了`😎。别再用 wget/curl 这种方式傻乎乎地安装这些二进制工具啦，一句 `COPY --from= ` 不知道高到哪里去了。

{% raw %}

<blockquote class="twitter-tweet"><p lang="zh" dir="ltr">分享一个比较冷门的 Dockerfile 的小技巧：<br>当你要安装一个 binary 工具时（比如 jq、yq、kubectl、helm、docker 等等），可以考虑直接从它们的镜像里 COPY 过来，替代使用 wget/curl 下载安装的方式，比如：<br>COPY --from=docker:20.10.12-dind-rootless /usr/local/bin/docker /usr/local/bin/docker <a href="https://t.co/4ZWFqk5EEv">pic.twitter.com/4ZWFqk5EEv</a></p>&mdash; Reimu (@muzi_ii) <a href="https://twitter.com/muzi_ii/status/1522599179918647296?ref_src=twsrc%5Etfw">May 6, 2022</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

{% endraw %}

接下来，我们需要自定义 Jenkins Kubernetes 插件的 Pod 模板，将我们上面创建的 buildx 配置文件的 configMap 通过 volume 挂载到 Pod 中。这个 Jenkins slave Pod 就可以在 k8s 中通过 Service Accounts 加上 buildx 配置文件来连接 buildkit 了。可以参考我这个 [Jenkinsfile](https://github.com/muzi502/buildkit-on-k8s-example/blob/master/Jenkinsfile)。

```yaml
// Kubernetes pod template to run.
podTemplate(
    cloud: JENKINS_CLOUD,
    namespace: POD_NAMESPACE,
    name: POD_NAME,
    label: POD_NAME,
    yaml: """
apiVersion: v1
kind: Pod
metadata:
 annotations:
    kubectl.kubernetes.io/default-container: runner
spec:
  nodeSelector:
    kubernetes.io/arch: amd64
  containers:
  - name: runner
    image: ${POD_IMAGE}
    imagePullPolicy: Always
    tty: true
    volumeMounts:
    # 将 buildx 配置文件挂载到当前用户的 /root/.docker/buildx/instances/kube 目录下
    - name: buildx-config
      mountPath: /root/.docker/buildx/instances/kube
      readOnly: true
      subPath: kube
    env:
    - name: HOST_IP
      valueFrom:
        fieldRef:
          fieldPath: status.hostIP
  - name: jnlp
    args: ["\$(JENKINS_SECRET)", "\$(JENKINS_NAME)"]
    image: "docker.io/jenkins/inbound-agent:4.11.2-4-alpine"
    imagePullPolicy: IfNotPresent
  volumes:
    # 配置 configmap 挂载
    - name: buildx-config
      configMap:
        name: buildx.config
        items:
          - key: data
            path: kube
"""
```

当 Jenkins slave pod 创建好之后，我们还需要进行一些初始化配置，例如设置 buildx 和登录镜像仓库等。我们可以在 Jenkins pipeline 中增加一个 Init 的 stage 来完成这些操作。

```shell
stage("Init") {
    withCredentials([usernamePassword(credentialsId: "${REGISTRY_CREDENTIALS_ID}", passwordVariable: "REGISTRY_PASSWORD", usernameVariable: "REGISTRY_USERNAME")]) {
        sh """
        # 将 docker buildx build 重命名为 docker build
        docker buildx install
        # 设置 buildx 使用的 builder，不然会默认使用 unix:///var/run/docker.sock
        docker buildx use kube
        # 登录镜像仓库
        docker login ${REGISTRY} -u '${REGISTRY_USERNAME}' -p '${REGISTRY_PASSWORD}'
        """
    }
}
```

## 其他

构建镜像时，我们可以在 buildkit 部署节点上运行 pstree 命令，来查看构建的过程。

```bash
root@product-builder-master:~# pstree -l -c -a -p -h -A 2637
buildkitd,2637
  |-buildkit-runc,989505 --log /var/lib/buildkit/runc-overlayfs/executor/runc-log.json --log-format json run --bundle /var/lib/buildkit/runc-overlayfs/executor/82zvcfesf5g19t2682g3j9hrr 82zvcfesf5g19t2682g3j9hrr
  |   |-rpmbuild,989519 --define dist .oe1 -ba open-vm-tools.spec --quiet
  |   |   `-sh,989562 -e /var/tmp/rpm-tmp.xKly7N
  |   |       `-make,995708 -O -j64 V=1 VERBOSE=1
```

通过 buildkitd 的进程树，我们可以看到 buildkitd 进程中有一个 buildkit-runc 的子进程。它会在一个 runc 容器中运行 Dockerfile 中对应的命令。因此，我们可以得知 buildkit on kubernetes 和之前的 docker in pod 实现原理是类似的，只不过这里的 buildkit 只用于构建镜像而已。

## 参考

- [buildkit-on-k8s-example](https://github.com/muzi502/buildkit-on-k8s-example)
- [docker buildx create](https://docs.docker.com/engine/reference/commandline/buildx_create/#driver)
- [Kubernetes driver](https://docs.docker.com/build/drivers/kubernetes/)
- [Docker BuildKit 介绍](https://yanhang.me/post/2019-04-08-buildkit/)
- [「Docker Buildx」- 构建“跨平台”镜像](https://meaninglive.com/2022/02/14/%E3%80%8Cdocker-buildx%E3%80%8D-%E6%9E%84%E5%BB%BA%E8%B7%A8%E5%B9%B3%E5%8F%B0%E9%95%9C%E5%83%8F/)
- [OCI 与下一代镜像构建工具](https://moelove.info/2021/11/03/OCI-%E4%B8%8E%E4%B8%8B%E4%B8%80%E4%BB%A3%E9%95%9C%E5%83%8F%E6%9E%84%E5%BB%BA%E5%B7%A5%E5%85%B7/)
- [万字长文：彻底搞懂容器镜像构建](https://moelove.info/2021/03/14/%E4%B8%87%E5%AD%97%E9%95%BF%E6%96%87%E5%BD%BB%E5%BA%95%E6%90%9E%E6%87%82%E5%AE%B9%E5%99%A8%E9%95%9C%E5%83%8F%E6%9E%84%E5%BB%BA/)
- [Attestations from buildx ](https://github.com/docker/buildx/pull/1412)
