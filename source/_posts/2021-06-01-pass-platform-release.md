---
title: 云原生 PaaS 产品发布&部署方案
date: 2021-06-10
updated: 2021-06-10
slug:
categories: 技术
tag:
  - kubernetes
  - PaaS
  - toB
copyright: true
comment: true
---

## 背景

对于一款基于 kubernetes 的容器云平台来讲，它需要给用户提供资源调度、服务编排、应用部署、监控日志、配置管理、镜像构建、CI/CD、存储和网络管理等功能。一个 PaaS 产品想要实现这些面面俱全的功能并不是一件轻松的事儿。从软件研发流程上来讲，不同于传统的单体应用或客户端应用，容器云平台本从底层的 Kubernetes 集群部署到上层的用户应用部署，所涉及到的技术栈十分复杂，最终导致平台的开发流程变得十分繁琐。

当然业界也有一些主流解决方案，比如平台组件容器化部署，以及使用微服务架构将平台拆分成若干个独立的模块，比如监控告警模块、应用管理模块、多集群管理模块等等。使用微服务架构可以解决容器云平台本身的复杂性，将平台拆分成单独的模块进行独立开发和部署，这样可以让某一特定的团队专门负责该模块的开发。

而使用微服务架构之后，也引入了新的问题：组件数量多了、对应模块开发人员多了、产品代码仓库多了、组件镜像多了、部署变得复杂了等。一个很好的例子就是 [ks-installer](https://github.com/kubesphere/ks-installer)  这个开源项目，里面包含了 20 多个组件和 140 多个容器镜像。想要管理这么多的组件和镜像绝非易事儿，个人认为这需要从产品发布和平台部署两个维度去解决众多组件管理的难题，因此本文就梳理了个人在 PaaS 容器云平台产品发布和部署方面的一些经验总结。

## 术语定义

本文中会有一些专业术语，在这先解释一下：

| **术语**         | 定义                                                                 |
| ---------------- | -------------------------------------------------------------------- |
| Platform/平台    | 即平台，本文指基于 kubernetes 的 PaaS 容器云平台                     |
| Addon/组件       | 某个独立的模块，一个 PaaS 容器云平台由多个组件构成                   |
| Chart/Charts     | 指一个或多个 Helm Chart，里面包含定义组件部署所需要的 manifests 文件 |
| Helm             | 部署组件 Charts 所使用的命令行工具                                   |
| Release/发布     | 收集产品所包含所有组件的部署需要的文件和镜像列表到 git repo          |
| Package/打包     | 根据发布流程中收集过来的部署文件和镜像列表将它们打包成离线安装包     |
| helm-controller  | 基于 Helm 开发的控制器，用于部署平台组件                             |
| 标准产品         | 指 PaaS 容器云平台本身，无任何定制化开发                             |
| OEM 产品         | 基于标准产品二次开发或使用 OEM 补丁包定制化开发的二开产品            |
| Jenkins 流水线   | Release 自动化打包发布产品包使用的工具                               |
| platform-release | 产品发布专用的 git repo，收集和管理各个组件发布相关的配置            |
| PR/MR            | Pull Request / Merge Request                                         |

## 部署

对于一个基于 kubernetes 的 PaaS 平台来讲，整个平台的部署可以大致划分为平台底层的 Kubernetes 集群部署和平台组件的部署这两部分。比如 Kubesphere 3.x 这个产品，kubernetes 集群部署工具是使用 Golang 开发的  [kubekey](https://github.com/kubesphere/kubekey)，平台组件部署工具是使用 Ansible 开发的 [ks-installer](https://github.com/kubesphere/ks-installer)。

个人认为 Kubesphere 的部署流程是比较合理的。平台底层的 Kubernetes 集群部署做的很简单（一个二进制可执行文件），平台组件部署工具依赖的也仅仅是一个已经部署好的 Kubernetes 集群和一个存储 StorageClass。这样就可以实现平台组件的部署与底层 Kubernetes 集群部署的解耦，使得平台组件可以部署在一个已经部署好的 kubernetes 集群中，比如 AKS。同时对于用户来讲，平台组件的部署也变得十分简单，只需要几条 kubectl 命令就能轻松完成。

因此在设计部署方案时，结合客户的需求，我们对部署方案做出如下几点要求：

- 需要做到离线部署，即私有化部署时不能依赖任何在线的资源；
- 平台底层 Kubernetes 集群部署与平台组件部署进行解耦；
- 平台组件部署仅仅依赖于一个已经部署好的 Kubernetes 集群和存储 StorageClass；
- 平台组件部署的方式做到统一，比如 Helm Chart 部署；
- 尽量将上层的组件放到平台组件里，不要放在 Kubernetes 集群部署中，比如负载均衡器、持久化存储、镜像仓库等；

为了满足以上几点部署的需求，我们又将整个平台的部署拆分成三部分，在产品发布的时候会使用 Jenkins 流水线自动化构建出对应的离线安装包：

- offline-resources：部署 nginx 服务和镜像仓库服务用于提供离线安装依赖的所有资源；
- Kubernetes：基于 Kubespray 使用 offline-resources 提供的资源部署 Kubernetes 集群；
- platform：在 Kubernetes 集群之上部署我们的 PaaS 容器云平台；

Kubernetes 集群部署和平台部署是相互分开的，两者在部署的层面尽量地做到了解耦，发布的时候也做到了解耦，这样就可以避免 K8s 部署工具里更新一个镜像而又要将平台安装包跟着一起更新的情况。

两者可以作为独立的产品进行交付，而没有和我们的 PaaS 平台绑定在一起。因为公司内的其他团队也有 K8s 集群部署的需求，这样也能将我们的 K8s 集群部署工具单独交付给其他团队使用。平台组件多集群部署的工具，也是没有和平台自身绑定在一起。只要是部署在 K8s 上并且组件使用 Helm Chart 部署，都可以使用这个工具来实现多集群部署和更新。

### offline-resources 服务

offline-resources  即离线资源服务，这一步很简单：就一个安装包，解压后修改配置文件，然后执行一条 `bash install.sh` 命令就能安装完成。由于在 Kubernetes 集群部署层面我们已经去除对 Docker 容器运行时的依赖，offline-resources 服务同样也要考虑去除对 Docker 的依赖。因此我们选择了 Containerd 官方的 CLI 工具 [nerdctl](https://github.com/containerd/nerdctl) ，使用 nerdctl-full 的安装包来配置好 Containerd 运行时所需的依赖，并使用 nerdctl compose 方式一键启动 Nginx 和镜像仓库服务。后续的 Kubernetes 集群部署和平台组件部署都会依赖 offline-resources 提供的 rpm/deb 包、二进制文件、容器镜像等资源。

### Kubernetes 集群部署

Kubernetes 集群部署采用的是 Kubernetes 社区的 [Kubespray](https://github.com/kubernetes-sigs/kubespray)，因为它比较适用于私有化交付的场景，相关特性如下：

- 支持的 K8s 从 1.19.0～1.21.1 的所有版本；
- 支持 10 种主流的 Linux 发行版和公有云 Linux 发行版；
- 支持 10 种 CNI 插件；
- 支持 4 种容器运行时 (Docker, Containerd, CRI-O, Kata)。

我们对 Kubespray 进行了二次开发，加入了离线部署需要适配的内容，比如配置系统 OS 的 yum/apt 的源为 offline-resources 服务所提供的源；将镜像仓库的域名 CA 证书在节点进行信任；将集群部署拆分成若干个子步骤；一些平台自身 self-host 特性等。

同时我们又对 Kubespray 进行容器化封装，在部署的时候会使用脚本调用 nerdctl CLI 工具来运行 Kubespray 容器，只需要传入集群节点 inventory 文件和一个集群配置文件就能一键完成 Kubernetes 集群部署。集群部署完成之后会将集群的一些信息如镜像仓库的域名、CA 证书、负载均衡 VIP 等信息保存为一个 system-info 的 configmap 为后续的平台部署使用。

### 平台组件部署

平台组件部署我们并没有像 [ks-installer](https://github.com/kubesphere/ks-installer) 那样为每一个组件都单独写一个 Ansible 的 roles，然后 controller 通过调用 ansible-playbook 来部署这些组件。而是将所有平台组件的部署方式都统一成为 Helm Chart，没有对任何组件做特殊处理。在安装的时候使用 Helm CLI 或者基于 Helm SDK 开发的 helm controller 来将所有的平台组件进行统一的部署和更新。这样在发布的时候对这些组件也能通过 git repo 做到统一的管理。这样的设计对一些 OEM 定制化开发或者增量补丁包的发布也十分友好。

## 发布

介绍完了平台部署的整体流程后我们再来谈一下发布流水线是如下设计和实现的。

根据内部产品版本迭代的流程要求，发布流水线大致可以划分为如下几部分：

- RD 在发布前一天完成冒烟测试，并在内部 DevOps 平台构建组件镜像和打 repo tag；
- 本次发布如有增删组件的情况，组件负责人提交 PR/MR 到发布 repo 修改发布配置；
- RD 冒烟完成和所有准备工组就绪之后，PM 通知发布人员开始发布；
- 发布人员执行流水线任务，自动化收集组件最新的 repo tag，并发送群消息通知组件 Onwer 确认；
- 组件 repo tag 确认完毕之后，合并 PR/MR 到发布分支，自动化收集组件的 Chart 文件；
- 根据收集的 Chart 文件更新镜像列表和平台组件部署配置文件，以及检查镜像列表中的镜像是否存在；
- 将收集的 Chart 和镜像列表等文件提交 PR/MR 合并到发布分支；
- 剩下的就是打包了，打包可以看作是发布的收尾环节，将产品打包成离线安装包并上传到存储服务器；

### offline-resources 安装包发布

对于平台部署而言，依赖的在线资源主要分为以下三种：

- 第一类：一些 OS 依赖的包，比如用包管理器安装 Containerd, ceph-common, nfs-utils 等
- 第二类：二进制文件：比如 Kubelet, Kubeadm, Kubectl, CNI，还有一些工具类如 Helm, Skopeo 等
- 第三类：容器镜像，比如 kube-apiserver, CoreDNS, 平台组件镜像等

对于这三种在线的资源，我们都统一成 Docker build 的方式，使用与之对应的自动化工具进行构建。

- 对于第一种，我们采用配置文件 + Dockerfile 的方式进行一键构建出所有依赖的 yum/apt 包，制作成离线源。具体的实现细节可以参考我之前的博客 [使用 docker build 制作 yum/apt 离线源](https://blog.k8s.li/make-offline-mirrors.html)；
- 对于第二种，我们会根据部署的配置文件自动生成一个在线的文件列表，并放到 Dockerfile 里进行构建下载；
- 对于第三种，我们也是根据部署的配置文件生成一些镜像列表，在一个 Dockerfile  里将镜像打包出来。

最后我们将所有的 Dockerfile 合并成一个 all-in-one 的 Dockerfile，并使用 Docker 的多阶段构建和  `BUILDKIT`  的特性充分利用了构建缓存，使得构建效率比非 Docker build 的方式提高了很多。

### K8s 部署安装包发布

由于 Kubernetes 集群部署涉及的研发人员只有五六个，因此将发布流程涉及的十分轻量。大致可以分为如下几步：

- 发布人员执行发布流水线，流水线根据部署的源码生成镜像列表和文件列表，若两者更新了就自动提交 PR/MR 到发布分支；
- 研发人员 review PR/MR 检查生成的镜像列表和文件列表是否正确。因为镜像列表和文件列表就是集群部署里所有组件的版本，可以根据这些列表判断组件版本是否正确；
- 流水线自动检查镜像列表中的镜像是否存在，流水线成功之后，repo 负责人合并 PR/MR；
- 合并完成 MR 之后，会打上相应版本的 repo tag，为后续补丁包发布使用；
- 流水线构建 Kubespray 镜像推送到公司内部的镜像仓库，并将镜像追加到镜像列表中；
- 流水线调用 offline-resources 构建工具，根据镜像列表打包镜像、根据文件列表下载二进制文件、根据配置文件打包离线安装依赖的 rpm/deb 包；
- 复制配置文件和 install.sh 脚本到安装包内，将上述内容打包成一个安装包，并上传至存储服务器；
- 发送群消息通知流水线发布完成。

### 平台安装包发布流程

由于平台组件数量比较多，所涉及的研发人员也较多，为了提高发布效率和团队整体的研发效率，我们将所有平台组件都统一使用 Helm Chart 的方式来部署。使用 Helm Chart 的好处就在于这些文件都是声明式的，组件的版本可以定义在这些 Chart.yaml 文件中，为后续维护平台各个组件的版本提供了便利。

为了管理这些平台组建的 Charts 文件，我们将所有组件部署的 Chart 使用自动化的工具统一收集到一个 Git repo 中，利用 Git 作为声明基础设施与应用程序的单一事实来源。使用 git tag 的方式管理和记录平台的版本和各个组件的版本；使用 git diff 的方式做差异比较，为增量的补丁包发布提供了便利；使用分支的方式来管理不同的 OEM 定制化开发项目。

#### 发布配置

以下这些文件和目录记录了如何使用 git repo 来管理平台组件的：

| 目录/文件   | 作用                                                                               | 更新方式                                         |
| ----------- | ---------------------------------------------------------------------------------- | ------------------------------------------------ |
| addons      | 用于存放平台组件部署需要的 Helm Chart                                              | 根据 repos 目录下的配置文件自动更新              |
| repos       | 用于存放平台组件 git  repo 配置，根据它来收集组件指定 repo 指定版本号的 Chart 文件 | 增删组件需要手动添加相应配置，组件版本号自动更新 |
| images      | 用于存放平台所需镜像的列表                                                         | 根据 addons 目录下的组件自动更新                 |
| scripts     | 用于存放一些部署依赖脚本文件                                                       | 手动更新或自动从其他 repo 中收集                 |
| configs     | 用于存放平台或组件需要的配置文件                                                   | 手动更新或自动从其他 repo 中收集                 |
| version.yml | 记录平台组件版本                                                                   | 根据组件 Chart 中的 version 自动更新             |
| install.sh  | 平台安装脚本                                                                       | 手动更新                                         |

Git Repo 的目录结构如下

```bash
$ tree platform-release
platform-release
├── addons
│   ├── cyclone
│   │   ├── Chart.yaml
│   │   ├── templates
│   │   └── values.yaml
│   ├── mongo
│   │   ├── Chart.yaml
│   │   ├── templates
│   │   └── values.yaml
│   ├── rook-ceph
│   │   ├── Chart.yaml
│   │   ├── crds
│   │   ├── templates
│   │   └── values.yaml
│   └── swagger-ui
│       ├── Chart.yaml
│       ├── templates
│       └── values.yaml
├── configs
│   ├── mongo-config-secret.yaml.j2
│   ├── platform-config.yaml.j2
│   └── platform-info.yaml.j2
├── env.yml
├── images
│   ├── images_app_store.list
│   ├── images_base.list
│   ├── images_extra.list
│   └── images_platform.list
├── install.sh
├── repos
│   ├── app.yaml
│   ├── auth.yaml
│   ├── common.yaml
│   ├── devops.yaml
│   ├── insight.yaml
│   ├── net.yaml
│   ├── resource.yaml
│   └── web.yaml
└── scripts

    └── init.sh
```

#### 修改 repo 配置文件

版本发布前，如果有增删组件的情况，需要对应组件的负责人修改自己负责模块的发布配置文件。

```yaml
# GitHub 上repo 的名称，如：muzi502/xxx
- repositoryFullName: muzi502/cyclone
  # 组件的最新 tag
  currentTag: v0.5.3
  # 从指定 repo 拉取 helm chart 的目录
  chartPaths:
  - manifests/cyclone       # 拉取 chart 的路径，可以配置多条
  targetChartPath: addons
```

比如 `repos/devops.yaml` 中用于配置收集流水线组件的 helm Chart。

```yaml
metadata:
  description: A set of files to collect.
  name: collect set
spec:
- repositoryFullName: muzi502/cyclone
  baseVersion: v1.2
  currentTag: v1.2.0
  chartPaths:
  - manifests/cyclone
  targetChartPath: addons
```

这一步只需要添加一次即可，后续无增删组件的情况无需再关心这些配置，配置中的 repo 版本也会使用自动化的工具来完成自动更新，无需手动维护，这样能减少研发们的维护成本。

#### 更新组件 repo 版本

发布前置工作都完成之后，PM 会通知发布人员开始发布。因为参数化构建和 Job 集中式管理等强依赖的特性其他 CI 工具无法很好地替代，目前我们的发布流水线依旧是使用的 Jenkins 。

发布人员在 Jenkins 上执行发布流水线的任务，流水线中首先使用自动化工具解析 repo 配置文件，根据组件打 repo tag 时候的 message 信息收集最新的 tag 版本号。收集完毕之后发布流水线自动提交一个 PR/MR 到 repo 的发布分支。并通自动发送群消息通知让所有 repo 的负责人确认收集到的 repo tag 是否正确。确认无误之后，将 PR/MR 自动合并到发布分支。

#### 更新组件 Chart 文件

更新完组件 repo 的 tag 之后，这样就能确定本次发布需要到哪些 repo 的哪个 repo tag 下去收集组件部署的 Chart 文件，在这一步会使用自动化工具，根据 repos 目录下的配置文件，收集对应组件的 Chart 文件到发布 repo 的指定目录下，一般默认为 addons 目录。

#### 更新组件版本配置文件

根据收集到的组件 Chart 版本号更新 `version.yml ` 这个组件版本配置文件中对应的版本，部署的时候会根据这个文件去部署哪些组件以及部署组件的版本是什么。

```yaml
spec:
  modules: # 模块列表，一个平台可以有多个 modules
  - name: # 模块名
    description: # 模块的描述信息
    enable: # 是否启用模块
    addons: # 模块中的组件列表
    - name: # 组件的名称， 必须和组件名以及 Chart.yaml name 保持一致
      description: # 组件的描述信息
      enable: # 是否启用模块
      namespace: # 组件运行的 namespace
      version: # 组件的版本号，必须和 repo tag Chart.yaml version 保持一致
```

#### 更新平台镜像列表

使用 Helm Template 渲染出原生的 K8s YAML 内容，使用 grep 过滤出平台组件部署所需要的镜像，并将输出的结果重定向到 `images/images_platform.list` 文件中，这些镜像是部署部署组件必须用到的镜像。另外还有三种其他的镜像如下：

- images_extra.list：一些额外的镜像第三方镜像。
- images_base.list：一些平台 DevOps 组件用到的 base 镜像，比如 golang, nodejs, maven 等。
- images_app_store.list： 平台应用商店中应用部署需要的镜像，比如 Wordpress，GitLab，Harbor 等。

处理这些镜像列表时也很简单，即使用 find 查找各个组件 Chart 中的 images_xxx.list 文件，将这些镜像统一合并到 images 目录下对应的文件中。

在发布 repo 中这些镜像列表都是自动化完成了，并且禁止个人手动在发布 repo 中进行更新，这样能避免一些人为的低级错误，比如镜像版本错误。我们使用这种方式来管理平台所需要的 200 多个镜像，很少因为镜像列表的错误而导致发布事故，极大地提高了版本发布的效率。

#### 提交收集产物

上述步骤都完成之后会将这些收集的文件提交一个 PR/MR 到发布 repo，发布 repo 会触发一个额外的流水线去检查镜像列表中的镜像是否存在于内部的镜像仓库中，如果不存在则会发送群消息通知研发准备好镜像。

等镜像都准备完毕之后，会将这个 PR/MR 合并到发布 repo 相应的分支。合并完 PR/MR 之后至此研发需要参与的发布流程已经完毕，repo 的发布分支无需再修改其他的内容，这时会给当前发布分支的最新 commit 打上一个 repo tag，repo tag 的名称就是产品的版本号，比如 `v2.10.2` 。

到此为止完成了发布环节的绝大多数任务，剩下的只有打包安装包这个收尾工作。

#### 打包流程

以上发布流程需要众多研发来参与确保发布环节收集到的组件 Chart 和镜像是正确的，收集完成这些文件之后就继续进行打包操作。打包的目的是将产品部署依赖的文件和镜像打包在一起，制作成一个离线安装包。打包流程很简单，大致可分为三部分：

- 打包 Helm Chart

```bash
mkdir -p charts && rm -rf charts/* || true

for dir in $(find ${ADDONS_PATH} -type f | sed -n 's/Chart.yaml//p'); do helm package ${dir} -d charts; done

chown -R 10000:10000 charts && tar -cpvf charts.tar.gz charts
```

- 打包镜像

根据 images 目录下的镜像列表将镜像同步到一个指定的 Registry 中，为了提升打包效率，这个 Registry 长期保留。然后使用硬连接的方式将镜像文件直接从这个 Registry 存储目录中直接提取出来，并打包成一个 tar 格式的文件放到产品安装包中。关于镜像同步的详细原理和一些之前做的优化可以参考 [overlay2 在打包发布流水线中的应用](https://blog.k8s.li/overlay2-on-package-pipline.html) 和 [什么？发布流水线中镜像“同步”速度又提升了 15 倍 ！](https://blog.k8s.li/select-registry-images.html)这两篇文章。

- 打包上传

镜像和组件 Chart 都打包完成之后，再将一些安装脚本和配置文件复制到安装包中。最后将这些内容一并打包在一起，并将它上传特性的存储服务器上。之后会有专门的测试团队来对打出来安装包进行测试，测试通过之后就可以对外发布交付给客户使用。

#### 发布 release 分支

至此平台组件发布流程到此完毕，当一个正式的版本发布完成之后，我们会采用 Kubernetes 社区版本管理的方式给发布 repo 创建一个 release 分支，比如 release-2.10 分支。后续所有的补丁包和一些 OEM 定制化开发的项目都会基于这种 release 分支来进行开发。

## 其他

### 镜像管理

为了适配这套发布流程，我们将 Kubernetes 集群部署和平台组部署将所使用的镜像收敛到 library 和 release 两个 project：

- 对于开源的镜像，即直接使用 docker.io、k8s.gcr.io、quay.io 这些官方 registry 中的镜像，将会统一使用 library 这个 project，比如 `library/nginx:1.19.0`。
- 对于平台组件自身的镜像，如自研组件使用自己的 Dockerfile build 出来的镜像则统一使用 release 这个 project，比如 `release/cyclone:v1.2.0` 。

release project 中的镜像是我们平台组件的镜像，能很方便地知道该镜像来自哪个组件以及是如何构建的。但将一些上游官方的镜像统一到 library 这个 project 之后，就很难知道该镜像的原镜像是什么了。比如 `library/coredns:1.7.0` 这个镜像，仅仅通过这个名字很难辨别出它是来自 docker.io 还是 k8s.gcr.io。因此为了解决这类问题和方便追溯上游原镜像，我们使用了统一的镜像同步配置文件来处理这种转换关系，在打包发布的时候我们会将这些镜像进行自动地转换和处理，这样避免了很多手动 push 镜像的麻烦和使用镜像错误的问题。

- images_origin.yaml

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
- src: k8s.gcr.io/coredns
 dest: library/coredns
- src: k8s.gcr.io/pause
 dest: library/pause

# kubernetes addons
- src: k8s.gcr.io/dns/k8s-dns-node-cache
 dest: library/k8s-dns-node-cache
- src: k8s.gcr.io/cpa/cluster-proportional-autoscaler-amd64
 dest: library/cluster-proportional-autoscaler-amd64
# network plugin
- src: quay.io/calico/cni
 dest: library/calico-cni
- src: quay.io/calico/kube-controllers
 dest: library/calico-kube-controllers
- src: quay.io/calico/node
 dest: library/calico-node
- src: quay.io/calico/typha
 dest: library/calico-typha
- src: quay.io/coreos/flannel
 dest: library/flannel
# nginx for daemonset and offline resources
- src: docker.io/library/nginx
 dest: library/nginx
# docker registry for offline resources
- src: docker.io/library/registry
 dest: library/registry
# helm chartmuseum for offline resources
- src: ghcr.io/helm/chartmuseum
 dest: library/chartmuseum
# yq eval -j images.yml | jq -r '.[]|select(.dest=="'"${image}"'") | .src'
```

### 补丁包管理

产品的正式版本在发布不久之后，在客户使用的过程中如果发现新的 bug 或者客户提出一些新的需求。我们这时会基于这些需求发布一个热更新补丁包，而不是发布一个新版本。因为热更新补丁包所涉及修改的组件比较少，需要参与的研发人员也比较少，这样能够节省很多人力成本。同时采用补丁包的方式进行热更新能够保障客户环境的稳定运行，平台稳定性也能够得到保障。

在发布流程中我们曾提到，发布过程中会给 repo 打上一个产品版本的 tag，比如 `v2.10.2`，在这里需要强调一下，**这版本号特别重要。**后续所有的补丁包发布都会强依赖于此版本号，因此我们会在 repo 的保护 tag 里将这种正式发布的 repo tag 进行锁定保护起来，禁止 `--force` 方式覆盖。在部署的时候，这个版本号也会以 configmap 的方式记录起来，用于在前端 web 页面上展示平台版本和后续安装补丁包时进行版本校验。

补丁包发布的频率也是蛮高的，从去年五月份到现在一年左右的时间里，自己负责的补丁包发布数量大约有 50 个左右，平均每周一个。同一个版本或 OEM 项目，补丁包发布的数量也大不相同（少则三四个，多则十七八个）。当补丁包的数量越来越多时，就需要一套机制来管理这些复杂环境的补丁包。不然的话版本发布将会变得十分混乱，导致客户生产环境安装上错误版本的组件，由此可能导致生产事故。

因此在设计补丁包发布方案的时候，我们依旧和标准产品的发布流程结合起来，使用 git repo tag + 分支的方式来管理这些补丁包的发布工作。整体的发布流程如下：

- PM 安排研发人员修复组件 bug；
- 组件负责人完成冒烟测试，并在内部 DevOps 平台打镜像和 repo tag；
- 组件负责人修改发布 repo 中 addons 目录下对应组件的 chart 文件；
- PM 通知发布人员开始发布补丁包；
- 发布人员运行流水线任务自动化打补丁包；
- 测试人员验证补丁包的质量；

在打包补丁包的时候我们采用 git diff 的方式，将本次补丁包发布所修改的组件 Chart 文件筛选出来，只对这些修改的组件进行打包操作。

```bash
for chart in $(git diff --name-only --diff-filter=AM --ignore-space-at-eol --ignore-space-change ${DENPENDENCY_VERSION} ${NEW_VERSION} ${ADDONS_PATH} | sed -n 's/Chart.yaml//p' | sort -u );do cp -rf ${chart} ${HOTFIX_YAML_DIR}; done
```

对于一些 OEM 项目，我们会基于产品版本的分支创建一个与该 OEM 产品相对应的发布分支，如 `release-2.10/muzi502`，即代表 muzi502 这个客户使用的产品版本是基于 2.10 版本的。在这个分支上我们基于上述步骤进行 OEM 补丁包的发布。
