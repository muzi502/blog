---
title: 流水线中使用 docker in pod 方式构建容器镜像
date: 2022-03-15
updated: 2022-03-16
slug: docker-in-pod
categories: 技术
tag:
  - docker
  - dind
  - dinp
  - kubernetes
  - jenkins
copyright: true
comment: true
---

上个月参加了 Rancher 社区举办的 《[Dockershim 即将被移除，你准备好了么？](https://www.bilibili.com/video/BV1Xa411C78k)》直播分享后，得知自 1.24 版本之后，Kubernetes 社区将正式放弃对 docker CRI 的支持，docker CRI 这部分代码则由 [ cri-dockerd](https://github.com/Mirantis/cri-dockerd) 项目来接盘。目前众多主流的 Kubernetes 私有化部署工具（比如 [kubespray](https://github.com/kubernetes-sigs/kubespray)、[kubekey](https://github.com/kubesphere/kubekey)、[sealos](https://github.com/fanux/sealos)）也逐渐地不再将 docker 作为首选的容器运行时而纷纷转向了 containerd，去 docker 也成为了目前云原生社区热门的讨论话题。

docker 虽然作为一个 CRI 在 Kubernetes 社区一直被人诟病，但我们要知道 CRI 仅仅是 docker 的一部分功能而已。对于本地开发测试或者 CI/CD 流水线镜像构建来讲，依然有很多地方严重地依赖着 docker。比如 GitHub 上容器镜像构建的 Action 里， docker 官方的 [build-push-action](https://github.com/docker/build-push-action) 是众多项目首选的方式。即便是 docker 的竞争对手 [podman](https://github.com/containers/podman) + [skopeo](https://github.com/containers/skopeo) + [buildah](https://github.com/containers/buildah) 三剑客它们自身的容器镜像也是采用 docker 来构建的 [multi-arch-build.yaml](https://github.com/containers/buildah/blob/main/.github/workflows/multi-arch-build.yaml)：

```yaml
jobs:
  multi:
    name: multi-arch image build
    env:
      REPONAME: buildah  # No easy way to parse this out of $GITHUB_REPOSITORY
      # Server/namespace value used to format FQIN
      REPONAME_QUAY_REGISTRY: quay.io/buildah
      CONTAINERS_QUAY_REGISTRY: quay.io/containers
      # list of architectures for build
      PLATFORMS: linux/amd64,linux/s390x,linux/ppc64le,linux/arm64
      # Command to execute in container to obtain project version number
      VERSION_CMD: "buildah --version"

    # build several images (upstream, testing, stable) in parallel
    strategy:
      # By default, failure of one matrix item cancels all others
      fail-fast: false
      matrix:
        # Builds are located under contrib/<reponame>image/<source> directory
        source:
          - upstream
          - testing
          - stable
    runs-on: ubuntu-latest
    # internal registry caches build for inspection before push
    services:
      registry:
        image: quay.io/libpod/registry:2
        ports:
          - 5000:5000
    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v1

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1
        with:
          driver-opts: network=host
          install: true

      - name: Build and locally push image
        uses: docker/build-push-action@v2
        with:
          context: contrib/${{ env.REPONAME }}image/${{ matrix.source }}
          file: ./contrib/${{ env.REPONAME }}image/${{ matrix.source }}/Dockerfile
          platforms: ${{ env.PLATFORMS }}
          push: true
          tags: localhost:5000/${{ env.REPONAME }}/${{ matrix.source }}
```

## Jenkins 流水线

我们的 CI/CD 流水线是使用 Jenkins + Kubernetes plugin 的方式在 Kubernetes 上动态地创建 Pod 作为 Jenkins Slave。在使用 docker 作为容器时的情况下，Jenkins  Slave Pod 将宿主机上的 `/var/run/docker.sock` 文件通过 hostPath 的方式挂载到 pod 容器内，容器内的 docker CLI 就能通过该 sock 与宿主机的 docker 守护进程进行通信，这样在 pod 容器内就可以无缝地使用 docker build 、push 等命令了。

```yaml
// Kubernetes pod template to run.
podTemplate(
    cloud: "kubernetes",
    namespace: "default",
    name: POD_NAME,
    label: POD_NAME,
    yaml: """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: debian
    image: "${JENKINS_POD_IMAGE_NAME}"
    imagePullPolicy: IfNotPresent
    tty: true
    volumeMounts:
    - name: dockersock
      mountPath: /var/run/docker.sock
  - name: jnlp
    args: ["\$(JENKINS_SECRET)", "\$(JENKINS_NAME)"]
    image: "jenkins/inbound-agent:4.3-4-alpine"
    imagePullPolicy: IfNotPresent
  volumes:
    - name: dockersock
      hostPath:
        path: /var/run/docker.sock
""",
)
```

当不再使用 docker 作为 Kubernetes 的容器运行时之后，宿主机上则就没有了 docker 守护进程，挂载 `/var/run/docker.sock` 的方式也就凉凉了，因此我们需要找到一些替代的方法。

目前能想到的有两种方案：方案一是替代掉 docker 使用其他镜像构建工具比如 [podman](https://github.com/containers/podman) + [skopeo](https://github.com/containers/skopeo) + [buildah](https://github.com/containers/buildah)。陈少文博主在《[基于 Kubernetes 的 Jenkins 服务也可以去 Docker 了](https://www.chenshaowen.com/blog/using-podman-to-build-images-under-kubernetes-and-jenkins.html)》详细地讲过该方案。但我们的 Makefile 里缝合了一些 docker buildKit 的特性参数并不能地通过 `alias docker=podman` 别名的方式简单粗暴地给替换掉 😂。

比如 podman 构建镜像就不支持 `--output type=local,dest=path`  [Support custom build outputs #3789](https://github.com/containers/buildah/issues/3789) 这种特性。目前看来 podman 想要完全取代掉 docker 的老大哥地位仍还有很长的路要走，尤其 podman 还没有解决自身的镜像是由 docker 来构建的这个尴尬难题。

方案二就是继续使用 docker 作为镜像构建工具，虽然集群节点上没有了 docker 守护进程，但这并不意味着在 Kubernetes 集群里就无法使用 docker 了。我们可以换种方式将 docker 作为一个 pod 运行在 kubernetes 集群中，而非以 systemd 的方式部署在节点上。然后通过 service IP 或 Node IP 访问 docker 的 TCP 端口进行通信，这样也能无缝地继续使用 docker 。于是在 dind (docker-in-docker) 的基础上就有了 dinp (docker-in-pod) 的套娃操作，其实二者本质上都是相同的，只不过是部署方式和访问方式不太相同而已。

对比一下这两种方案，方案一通过 `alias docker=podman` 使用 podman 替代 docker 有点投机取巧，在正式的生产环境流水线中应该很少会被采用，除非你的 Makefile 或者镜像构建脚本中没有依赖 docker 的特性参数，能够完全兼容 podman；方案二比较稳定可靠，它无非就是将之前的宿主机节点上的 docker 守护进程替换成了集群内的 Pod，对于使用者而言只需要修改一下访问 docker 的方式，即 `DOCKER_HOST` 环境变量即可。因此本文选用方案二来给大家介绍几种在 K8s 集群里部署和使用 dind/dinp 的方式。

## docker in pod

不同于 docker in docker，docker in pod 并不关心底层的容器运行时是什么，可以是 docker 也可以是 containerd。在 pod 内运行和使用 docker 个人总结出以下三种比较合适的方式，可以根据不同的场景选择一个合适的：

### sidecar

将 dind 容器作为 [sidecar 容器](https://kubernetes.io/zh/docs/concepts/workloads/pods/#using-pods) 来运行，主容器通过 localhost 的方式访问 docker 的 2375/2376 TCP 端口。这种方案的好处就是如果创建了多个 Pod，各个 Pod 之间是相互独立的，dind 容器不会共享给其他 pod 使用，隔离性比较好。缺点也比较明显，每一个 Pod 都带一个 dind 容器占用的系统资源比较多，有点大材小用的感觉；

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dinp-sidecar
spec:
  containers:
  - image: docker:20.10.12
    name: debug
    command: ["sleep", "3600"]
    env:
    - name: DOCKER_TLS_VERIFY
      value: ""
    - name: DOCKER_HOST
      value: tcp://localhost:2375
  - name: dind
    image: docker:20.10.12-dind-rootless
    args: ["--insecure-registry=$(REGISTRY)"]
    env:
    # 如果镜像仓库域名为自签证书，需要在这里配置 insecure-registry
    - name: REGISTRY
      value: hub.k8s.li
    - name: DOCKER_TLS_CERTDIR
      value: ""
    - name: DOCKER_HOST
      value: tcp://localhost:2375
    securityContext:
      privileged: true
    tty: true
    # 使用 docker info 命令就绪探针来确保 dind 容器正常启动 
    readinessProbe:
      exec:
        command: ["docker", "info"]
      initialDelaySeconds: 10
      failureThreshold: 6
```

### daemonset

[daemonset](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/) 则是在集群的每一个 Node 节点上运行一个 dind Pod，并且使用 hostNetwork 方式来暴露 2375/2376 TCP 端口。使用者则通过 `status.hostIP` 访问宿主机的 2375/2376 TCP 端口来与 docker 进行通信；另外再通过 hostPath 挂载的方式来将 dind 容器内的 `/var/lib/docker` 数据持久化存储下来，能够缓存一些数据提高镜像构建的效率。

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dinp-daemonset
  namespace: default
spec:
  selector:
    matchLabels:
      name: dinp-daemonset
  template:
    metadata:
      labels:
        name: dinp-daemonset
    spec:
      hostNetwork: true
      containers:
      - name: dind
        image: docker:20.10.12-dind
        args: ["--insecure-registry=$(REGISTRY)"]
        env:
        - name: REGISTRY
          value: hub.k8s.li
        - name: DOCKER_TLS_CERTDIR
          value: ""
        securityContext:
          privileged: true
        tty: true
        volumeMounts:
        - name: docker-storage
          mountPath:  /var/lib/docker
        readinessProbe:
          exec:
            command: ["docker", "info"]
          initialDelaySeconds: 10
          failureThreshold: 6
        livenessProbe:
          exec:
            command: ["docker", "info"]
          initialDelaySeconds: 60
          failureThreshold: 10
      volumes:
      - name: docker-storage
        hostPath:
          path: /var/lib/docker
```

### deployment

Deployment 方式则是在集群中部署一个或多个 dind Pod，使用者通过 service IP 来访问 docker 的 2375/2376 端口，如果是以非 TLS 方式启动 dind 容器，使用 service IP 来访问 docker 要比前面的 daemonset 使用 host IP 安全性要好一些。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dinp-deployment
  namespace: default
  labels:
    name: dinp-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      name: dinp-deployment
  template:
    metadata:
      labels:
        name: dinp-deployment
    spec:
      containers:
      - name: dind
        image: docker:20.10.12-dind
        args: ["--insecure-registry=$(REGISTRY)"]
        env:
        - name: REGISTRY
          value: hub.k8s.li
        - name: DOCKER_TLS_CERTDIR
          value: ""
        - name: DOCKER_HOST
          value: tcp://localhost:2375
        securityContext:
          privileged: true
        tty: true
        volumeMounts:
        - name: docker-storage
          mountPath:  /var/lib/docker
        readinessProbe:
          exec:
            command: ["docker", "info"]
          initialDelaySeconds: 10
          failureThreshold: 6
        livenessProbe:
          exec:
            command: ["docker", "info"]
          initialDelaySeconds: 60
          failureThreshold: 10
      volumes:
      - name: docker-storage
        hostPath:
          path: /var/lib/docker
---
kind: Service
apiVersion: v1
metadata:
  # 定义 service name，使用者通过它来访问 docker 的 2375 端口
  name: dinp-deployment
spec:
  selector:
    name: dinp-deployment
  ports:
  - protocol: TCP
    port: 2375
    targetPort: 2375
```

## Jenkinsfile

在 Jenkins 的 podTemplate 模版里，可以根据 dinp 部署方式的不同选用以下几种不同的模版：

### sidecare

Pod 内容器共享同一个网络协议栈，因此可以通过 localhost 来访问 docker 的 TCP 端口，另外最好使用 rootless 模式启动 dind 容器，这样能在同一节点上运行多个这样的 Pod 实例。

```yaml
def JOB_NAME = "${env.JOB_BASE_NAME}"
def BUILD_NUMBER = "${env.BUILD_NUMBER}"
def POD_NAME = "jenkins-${JOB_NAME}-${BUILD_NUMBER}"
def K8S_CLUSTER = params.k8s_cluster ?: kubernetes

// Kubernetes pod template to run.
podTemplate(
    cloud: K8S_CLUSTER,
    namespace: "default",
    name: POD_NAME,
    label: POD_NAME,
    yaml: """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: runner
    image: golang:1.17-buster
    imagePullPolicy: IfNotPresent
    tty: true
    env:
    - name: DOCKER_HOST
      vaule: tcp://localhost:2375
    - name: DOCKER_TLS_VERIFY
      value: ""
  - name: jnlp
    args: ["\$(JENKINS_SECRET)", "\$(JENKINS_NAME)"]
    image: "jenkins/inbound-agent:4.11.2-4-alpine"
    imagePullPolicy: IfNotPresent
  - name: dind
    image: docker:20.10.12-dind-rootless
    args: ["--insecure-registry=$(REGISTRY)"]
    env:
    - name: REGISTRY
      value: hub.k8s.li
    - name: DOCKER_TLS_CERTDIR
      value: ""
    securityContext:
      privileged: true
    tty: true
    readinessProbe:
      exec:
        command: ["docker", "info"]
      initialDelaySeconds: 10
      failureThreshold: 6
""",
) {
    node(POD_NAME) {
        container("runner") {
            stage("Checkout") {
                retry(10) {
                    checkout([
                        $class: 'GitSCM',
                        branches: scm.branches,
                        doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
                        extensions: [[$class: 'CloneOption', noTags: false, shallow: false, depth: 0, reference: '']],
                        userRemoteConfigs: scm.userRemoteConfigs,
                    ])
                }
            }
            stage("Build") {
                sh """
                # make docker-build
                docker build -t app:v1.0.0-alpha.1 .
                """
            }
        }
    }
}
```

### daemonset

由于使用的是 hostNetwork，因此可以通过 host IP 来访问 docker 的 TCP 端口，当然也可以像 deployment 那样通过 service Name 来访问，在这里就不演示了。

```yaml
def JOB_NAME = "${env.JOB_BASE_NAME}"
def BUILD_NUMBER = "${env.BUILD_NUMBER}"
def POD_NAME = "jenkins-${JOB_NAME}-${BUILD_NUMBER}"
def K8S_CLUSTER = params.k8s_cluster ?: kubernetes

// Kubernetes pod template to run.
podTemplate(
    cloud: K8S_CLUSTER,
    namespace: "default",
    name: POD_NAME,
    label: POD_NAME,
    yaml: """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: runner
    image: golang:1.17-buster
    imagePullPolicy: IfNotPresent
    tty: true
    env:
    - name: DOCKER_HOST
      valueFrom:
        fieldRef:
          fieldPath: status.hostIP
    - name: DOCKER_TLS_VERIFY
      value: ""
  - name: jnlp
    args: ["\$(JENKINS_SECRET)", "\$(JENKINS_NAME)"]
    image: "jenkins/inbound-agent:4.11.2-4-alpine"
    imagePullPolicy: IfNotPresent
""",
) {
    node(POD_NAME) {
        container("runner") {
            stage("Checkout") {
                retry(10) {
                    checkout([
                        $class: 'GitSCM',
                        branches: scm.branches,
                        doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
                        extensions: [[$class: 'CloneOption', noTags: false, shallow: false, depth: 0, reference: '']],
                        userRemoteConfigs: scm.userRemoteConfigs,
                    ])
                }
            }
            stage("Build") {
                sh """
                # make docker-build
                docker build -t app:v1.0.0-alpha.1 .
                """
            }
        }
    }
}
```

### deployment

通过 service name 访问 docker，其他参数和 daemonset 都是相同的

```yaml
def JOB_NAME = "${env.JOB_BASE_NAME}"
def BUILD_NUMBER = "${env.BUILD_NUMBER}"
def POD_NAME = "jenkins-${JOB_NAME}-${BUILD_NUMBER}"
def K8S_CLUSTER = params.k8s_cluster ?: kubernetes

// Kubernetes pod template to run.
podTemplate(
    cloud: K8S_CLUSTER,
    namespace: "default",
    name: POD_NAME,
    label: POD_NAME,
    yaml: """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: runner
    image: golang:1.17-buster
    imagePullPolicy: IfNotPresent
    tty: true
    env:
    - name: DOCKER_HOST
       value: tcp://dinp-deployment:2375
    - name: DOCKER_TLS_VERIFY
      value: ""
  - name: jnlp
    args: ["\$(JENKINS_SECRET)", "\$(JENKINS_NAME)"]
    image: "jenkins/inbound-agent:4.11.2-4-alpine"
    imagePullPolicy: IfNotPresent
""",
) {
    node(POD_NAME) {
        container("runner") {
            stage("Checkout") {
                retry(10) {
                    checkout([
                        $class: 'GitSCM',
                        branches: scm.branches,
                        doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
                        extensions: [[$class: 'CloneOption', noTags: false, shallow: false, depth: 0, reference: '']],
                        userRemoteConfigs: scm.userRemoteConfigs,
                    ])
                }
            }
            stage("Build") {
                sh """
                # make docker-build
                docker build -t app:v1.0.0-alpha.1 .
                """
            }
        }
    }
}
```

## 其他

### readinessProbe

有些时候 dind 无法正常启动，所以一定要设置就绪探针，来确保 diind 容器能够正常启动

```yaml
    readinessProbe:
      exec:
        command: ["docker", "info"]
      initialDelaySeconds: 10
      failureThreshold: 6
```

### 2375/2376 端口

docker 默认是以 TLS 方式启动，监听端口为 2376，如果设置环境变量 `DOCKER_TLS_CERTDIR` 为空则就以非 TLS 模式启动，监听端口为 2375，这时就不会校验 TLS 证书。如果使用 2376 端口，则就需要一个持久化存储来将 docker 生成的证书共享给客户端，这点比较麻烦。因此如果不想瞎折腾还是使用 2375 非 TLS 方式吧 😂。

### dinp 必须以开启 privileged: true

以 pod 方式运行 docker，无论是否是 rootless 模式，都要在 pod 容器的 `securityContext` 中设置 `privileged: true`，否则 pod 无法正常启动。而且 rootless 模式也有一定的限制，需要依赖一些内核的特性，目前也只是实验阶段，没有特殊的需求还是尽量不要使用 rootless 特性吧。

```
[root@localhost ~]# kubectl logs -f dinp-sidecar
error: a container name must be specified for pod dinp-sidecar, choose one of: [debug dind]
[root@localhost ~]# kubectl logs -f dinp-sidecar -c dind
Device "ip_tables" does not exist.
ip_tables              27126  4 iptable_raw,iptable_mangle,iptable_filter,iptable_nat
modprobe: can't change directory to '/lib/modules': No such file or directory
WARN[0000] failed to mount sysfs, falling back to read-only mount: operation not permitted
WARN[0000] failed to mount sysfs: operation not permitted
open: No such file or directory
[rootlesskit:child ] error: executing [[ip tuntap add name tap0 mode tap] [ip link set tap0 address 02:50:00:00:00:01]]: exit status 1
```

### rootless user.max_user_namespaces

rootless 模式下需要依赖一些内核参数 [Run the Docker daemon as a non-root user (Rootless mode)](https://docs.docker.com/engine/security/rootless/)。在 CentOS 7.9 上会出现 [dind-rootless: failed to start up dind rootless in k8s due to max_user_namespaces](https://github.com/docker-library/docker/issues/201) 问题。解决方案是在修改一下 `user.max_user_namespaces=28633` 内核参数。

> Add user.max_user_namespaces=28633 to /etc/sysctl.conf (or /etc/sysctl.d) and run sudo sysctl -p

```bash
[root@localhost ~]# kubectl get pod -w
NAME                              READY   STATUS   RESTARTS     AGE
dinp-deployment-cf488bfd8-g8vxx   0/1     CrashLoopBackOff   1 (2s ago)   4s
[root@localhost ~]# kubectl logs -f dinp-deployment-cf488bfd8-m5cms
Device "ip_tables" does not exist.
ip_tables              27126  5 iptable_raw,iptable_mangle,iptable_filter,iptable_nat
modprobe: can't change directory to '/lib/modules': No such file or directory
error: attempting to run rootless dockerd but need 'user.max_user_namespaces' (/proc/sys/user/max_user_namespaces) set to a sufficiently large value
```

### 非 rootless 模式下同一 node 节点只能运行一个 dinp

如果是使用 deployment 方式部署 dinp，一个 node 节点上只能有一个 dinp Pod，多余的 Pod 无法正常启动。因此如果想要运行多个 dinp Pod，建议使用 daemonset 方式运行它；

```
[root@localhost ~]# kubectl get deploy
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
dinp-deployment   1/3     3            1           4m16s
[root@localhost ~]# kubectl get pod -w
NAME                               READY   STATUS    RESTARTS      AGE
dinp-deployment-547bd9bb6d-2mn6c   0/1     Running   3 (61s ago)   4m9s
dinp-deployment-547bd9bb6d-8ht8l   1/1     Running   0             4m9s
dinp-deployment-547bd9bb6d-x5vpv   0/1     Running   3 (61s ago)   4m9s
[root@localhost ~]# kubectl logs -f dinp-deployment-547bd9bb6d-2mn6c
INFO[2022-03-14T14:14:10.905652548Z] Starting up
WARN[2022-03-14T14:14:10.906986721Z] could not change group /var/run/docker.sock to docker: group docker not found
WARN[2022-03-14T14:14:10.907249071Z] Binding to IP address without --tlsverify is insecure and gives root access on this machine to everyone who has access to your network.  host="tcp://0.0.0.0:2375"
WARN[2022-03-14T14:14:10.907269951Z] Binding to an IP address, even on localhost, can also give access to scripts run in a browser. Be safe out there!  host="tcp://0.0.0.0:2375"
WARN[2022-03-14T14:14:11.908057635Z] Binding to an IP address without --tlsverify is deprecated. Startup is intentionally being slowed down to show this message  host="tcp://0.0.0.0:2375"
WARN[2022-03-14T14:14:11.908103696Z] Please consider generating tls certificates with client validation to prevent exposing unauthenticated root access to your network  host="tcp://0.0.0.0:2375"
WARN[2022-03-14T14:14:11.908114541Z] You can override this by explicitly specifying '--tls=false' or '--tlsverify=false'  host="tcp://0.0.0.0:2375"
WARN[2022-03-14T14:14:11.908125477Z] Support for listening on TCP without authentication or explicit intent to run without authentication will be removed in the next release  host="tcp://0.0.0.0:2375"
INFO[2022-03-14T14:14:26.914587276Z] libcontainerd: started new containerd process  pid=41
INFO[2022-03-14T14:14:26.914697125Z] parsed scheme: "unix"                         module=grpc
INFO[2022-03-14T14:14:26.914710376Z] scheme "unix" not registered, fallback to default scheme  module=grpc
INFO[2022-03-14T14:14:26.914785052Z] ccResolverWrapper: sending update to cc: {[{unix:///var/run/docker/containerd/containerd.sock  <nil> 0 <nil>}] <nil> <nil>}  module=grpc
INFO[2022-03-14T14:14:26.914796039Z] ClientConn switching balancer to "pick_first"  module=grpc
INFO[2022-03-14T14:14:26.930311832Z] starting containerd                           revision=7b11cfaabd73bb80907dd23182b9347b4245eb5d version=v1.4.12
INFO[2022-03-14T14:14:26.953641900Z] loading plugin "io.containerd.content.v1.content"...  type=io.containerd.content.v1
INFO[2022-03-14T14:14:26.953721059Z] loading plugin "io.containerd.snapshotter.v1.aufs"...  type=io.containerd.snapshotter.v1
INFO[2022-03-14T14:14:26.960295816Z] skip loading plugin "io.containerd.snapshotter.v1.aufs"...  error="aufs is not supported (modprobe aufs failed: exit status 1 \"ip: can't find device 'aufs'\\nmodprobe: can't change directory to '/lib/modules': No such file or directory\\n\"): skip plugin" type=io.containerd.snapshotter.v1
INFO[2022-03-14T14:14:26.960329840Z] loading plugin "io.containerd.snapshotter.v1.btrfs"...  type=io.containerd.snapshotter.v1
INFO[2022-03-14T14:14:26.960524514Z] skip loading plugin "io.containerd.snapshotter.v1.btrfs"...  error="path /var/lib/docker/containerd/daemon/io.containerd.snapshotter.v1.btrfs (xfs) must be a btrfs filesystem to be used with the btrfs snapshotter: skip plugin" type=io.containerd.snapshotter.v1
INFO[2022-03-14T14:14:26.960537441Z] loading plugin "io.containerd.snapshotter.v1.devmapper"...  type=io.containerd.snapshotter.v1
WARN[2022-03-14T14:14:26.960558843Z] failed to load plugin io.containerd.snapshotter.v1.devmapper  error="devmapper not configured"
INFO[2022-03-14T14:14:26.960569516Z] loading plugin "io.containerd.snapshotter.v1.native"...  type=io.containerd.snapshotter.v1
INFO[2022-03-14T14:14:26.960593224Z] loading plugin "io.containerd.snapshotter.v1.overlayfs"...  type=io.containerd.snapshotter.v1
INFO[2022-03-14T14:14:26.960678728Z] loading plugin "io.containerd.snapshotter.v1.zfs"...  type=io.containerd.snapshotter.v1
INFO[2022-03-14T14:14:26.960814844Z] skip loading plugin "io.containerd.snapshotter.v1.zfs"...  error="path /var/lib/docker/containerd/daemon/io.containerd.snapshotter.v1.zfs must be a zfs filesystem to be used with the zfs snapshotter: skip plugin" type=io.containerd.snapshotter.v1
INFO[2022-03-14T14:14:26.960827133Z] loading plugin "io.containerd.metadata.v1.bolt"...  type=io.containerd.metadata.v1
WARN[2022-03-14T14:14:26.960839223Z] could not use snapshotter devmapper in metadata plugin  error="devmapper not configured"
INFO[2022-03-14T14:14:26.960848698Z] metadata content store policy set             policy=shared
WARN[2022-03-14T14:14:27.915528371Z] grpc: addrConn.createTransport failed to connect to {unix:///var/run/docker/containerd/containerd.sock  <nil> 0 <nil>}. Err :connection error: desc = "transport: error while dialing: dial unix:///var/run/docker/containerd/containerd.sock: timeout". Reconnecting...  module=grpc
WARN[2022-03-14T14:14:30.722257725Z] grpc: addrConn.createTransport failed to connect to {unix:///var/run/docker/containerd/containerd.sock  <nil> 0 <nil>}. Err :connection error: desc = "transport: error while dialing: dial unix:///var/run/docker/containerd/containerd.sock: timeout". Reconnecting...  module=grpc
WARN[2022-03-14T14:14:35.549453706Z] grpc: addrConn.createTransport failed to connect to {unix:///var/run/docker/containerd/containerd.sock  <nil> 0 <nil>}. Err :connection error: desc = "transport: error while dialing: dial unix:///var/run/docker/containerd/containerd.sock: timeout". Reconnecting...  module=grpc
WARN[2022-03-14T14:14:41.759010407Z] grpc: addrConn.createTransport failed to connect to {unix:///var/run/docker/containerd/containerd.sock  <nil> 0 <nil>}. Err :connection error: desc = "transport: error while dialing: dial unix:///var/run/docker/containerd/containerd.sock: timeout". Reconnecting...  module=grpc
failed to start containerd: timeout waiting for containerd to start
```

### /var/lib/docker 不支持共享存储

陈少文博主曾在 《[/var/lib/docker 能不能挂载远端存储](https://www.chenshaowen.com/blog/can-we-mount-var-lib-docker-to-remote-storage.html)》提到过 docker 目前并支持将 `/var/lib/docker` 挂载远程存储使用，因此建议使用 hostPath 的方式保存 docker 的持久化存储数据。

> 本次测试使用的 Docker 版本为 20.10.6，不能将 `/var/lib/docker` 挂载远程存储使用。主要原因是容器的实现依赖于内核的能力(xttrs)，而类似 NFS Server 这种远程存储无法提供这些能力。如果采用 Device Mapper 进行映射，使用磁盘挂载存在可行性，但只能用于迁移而不能实现共享。

```bash
INFO[2022-03-13T13:43:08.750810130Z] ClientConn switching balancer to "pick_first"  module=grpc
ERRO[2022-03-13T13:43:08.781932359Z] failed to mount overlay: invalid argument     storage-driver=overlay2
ERRO[2022-03-13T13:43:08.782078828Z] exec: "fuse-overlayfs": executable file not found in $PATH  storage-driver=fuse-overlayfs
ERRO[2022-03-13T13:43:08.793311119Z] AUFS was not found in /proc/filesystems       storage-driver=aufs
ERRO[2022-03-13T13:43:08.813505621Z] failed to mount overlay: invalid argument     storage-driver=overlay
ERRO[2022-03-13T13:43:08.813529990Z] Failed to built-in GetDriver graph devicemapper /var/lib/docker
INFO[2022-03-13T13:43:08.897769363Z] Loading containers: start.
WARN[2022-03-13T13:43:08.919252078Z] Running modprobe bridge br_netfilter failed with message: ip: can't find device 'bridge'
[root@localhost dinp]# kubectl exec -it dinp-sidecar -c debug sh
/ # docker pull alpine
Using default tag: latest
Error response from daemon: error creating temporary lease: file resize error: truncate /var/lib/docker/containerd/daemon/io.containerd.metadata.v1.bolt/meta.db: bad file descriptor: unknown
```

## 参考

- [Dockershim 即将被移除，你准备好了么？](https://www.bilibili.com/video/BV1Xa411C78k)
- [为什么 Kubernetes 要替换 Docker](https://draveness.me/whys-the-design-kubernetes-deprecate-docker/)
- [A case for Docker-in-Docker on Kubernetes](https://applatix.com/case-docker-docker-kubernetes-part-2)
- [Run the Docker daemon as a non-root user (Rootless mode)](https://docs.docker.com/engine/security/rootless/)
- [Docker Official Image packaging for Docker](https://github.com/docker-library/docker)
- [/var/lib/docker 能不能挂载远端存储](https://www.chenshaowen.com/blog/can-we-mount-var-lib-docker-to-remote-storage.html)
- [如何在 Docker 中使用 Docker](https://www.chenshaowen.com/blog/how-to-use-docker-in-docker.html)
- [基于 Kubernetes 的 Jenkins 服务也可以去 Docker 了](https://www.chenshaowen.com/blog/using-podman-to-build-images-under-kubernetes-and-jenkins.html)
- [dind-rootless: failed to start up dind rootless in k8s due to max_user_namespaces #201](https://github.com/docker-library/docker/issues/201)
