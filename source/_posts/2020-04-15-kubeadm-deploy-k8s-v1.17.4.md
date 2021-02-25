---
title: 使用 kubeadm 快速部署体验 K8s
date: 2020-04-15
updated: 2020-04-15
slug:
categories: 技术
tag:
  - kubeadm
  - kubernetes
  - 从零开始学习 K8s
copyright: true
comment: true
---

## 炒冷饭

大概是从去年 5 月开始才接触  kubernetes ，时至今日已经快一年，当初写的一篇博客 [ubuntu 1804 使用 kubeadm 部署 kubernetes](https://blog.k8s.li/install-k8s-ubuntu18-04.html) 翻出来重新修改一下，记录一下使用 kubeadm 部署 kubernetes v1.17.4 版的流程。适用于国内网络环境下。

### kubeadm

Kubernetes 从 1.4 版本开始后就引入了 kubeadm 用于简化集群搭建的过程，在 Kubernetes 1.13 版本中，kubeadm 工具进入 GA 阶段，而当前的 kubernetes 最新版 stable 为 1.18.1 ，kubeadm 已经经历过多个版本的迭代，可用于生产环境 Kubernetes 集群搭建。对于刚刚接触 kubernetes  的初学者来讲，kubeadm 也是一个快速部署体验 kubernetes 的不二之选。

## kubernetes 架构

![](https://p.k8s.li/components-of-kubernetes.png)

架构图来自 kubernetes 官方文档 [Kubernetes 组件](https://kubernetes.io/zh/docs/concepts/overview/components/)

### 控制平面

控制平面的组件对集群做出全局决策(比如调度)，以及检测和响应集群事件主要的组件由

- kube-apiserver：主节点上负责提供 Kubernetes API 服务的组件；它是 Kubernetes 控制面的前端。
- etcd：集群中唯一一个有状态的服务，用来存储集群中的所有资源信息数据。
- kube-scheduler：负责调度 Pod 资源到某个 Node 节点上。
- kube-controller-manager：控制器管理器。
- kubelet：如果使用 kubeadm 部署的话需要在 master 节点安装 kubelet

### 工作平面

- kubelet：通过监听 kube-apiserver ，接收一组通过各类机制提供给它的 PodSpecs，确保这些 PodSpecs 中描述的容器处于运行状态且健康。
- kube-proxy：实现 Kubernetes [Service](https://kubernetes.io/docs/concepts/services-networking/service/) 概念的一部分，通过 iptables 规则将 service 负载均衡到各个 Pod。
- CRI容器运行时：根据统计目前 docker 依旧是排名第一的容器运行时

### kubeadm init 流程

在使用 kubeadm 部署时，除了 kubelet 组件需要使用二进制部署外，其他的组件都是用 [static Pod]() 的方式运行在相应的节点。

## 节点初始化

系统建议选择 ubuntu 1804 或者 CentOS 7.7，因为 docker 容器虚拟化以及 kubernetes 这些新技术都是很依赖一些内核特性，比如 overlay2、cgroupv2 等，这些特性在较低版本的内核上并不是很稳定，建议 4.14 或者 4.19 以上的 LTS  内核，及长期稳定支持版内核，在 [kernel.org](https://www.kernel.org/category/releases.html) 上有内核支持支持情况。

### 设置主机名并添加  hosts

每台机器上都要设置相应的主机名并添加 hosts

```shell
hostnamectl set-hostname k8s-maste-01

cat >> /etc/hosts <<EOF
10.20.172.211 k8s-master-01
10.20.172.212 k8s-node-01
10.20.172.213 k8s-node-02
10.20.172.214 k8s-node-03
EOF
```

### 关闭 swap 和 SELinux

```shell
# 临时关闭swap和SELinux
swapoff -a

# ubuntu 默认没有安装 SELinux 因为无需关闭
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX= disabled/' /etc/selinux/config
```

### 设置内核参数

```shell
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
enet.ipv4.ip_forward                = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
```

### 配置镜像源和安装

如果对 docker-ce 版本没有特殊要求，使用以下命令可安装 docker-ce 最新的 stable 版本。

```bash
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
```

#### CentOS7

```shell
yum install -y yum-utils

# 如果 docker 版本使用 18.09 + 且存储驱动使用 overlay2
# 就不用 device-mapper-persistent-data 和 lvm2

# 添加aliyun软件包yum源 docker
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 添加aliyun软件包yum源 kubelet kubeadm kubectl
cat>>/etc/yum.repos.d/kubrenetes.repo<<EOF
[kubernetes]
name=Kubernetes Repo
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
EOF
yum makecache

# 列出可以安装的 docker-ce 版本，安装指定的 docker 版本
yum list docker-ce --showduplicates|sort -r
yum install -y docker-ce-19.03.3-3.el7

# # 列出可以安装的 kubernetes 版本，安装指定的 kubeadm kubelet kubectl
yum list kubeadm --showduplicates|sort -r
yum install kubelet-1.17.4-0 kubeadm-1.17.4-0 kubectl-1.17.4-0 --disableexcludes=kubernetes
```

#### Ubuntu 1804

```shell
apt update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# 添加阿里云 docker-ce 镜像源
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
# 添加阿里云 kubernetes 镜像源
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
apt-get update
# 安装指定版本的 docker-ce
apt list -a docker-ce
apt install docker-ce=5:19.03.8~3-0~ubuntu-bionic
# 安装指定版本的 kubernetes
apt install kubeadm=1.17.4-00 kubelet=1.17.4-00 kubectl=1.17.4-00
```

#### 华为云坑

需要注意的是，如果你使用的华为云 kubernetes 镜像源，目前 （2020-04-15） 华为云上的 kubernetes 版本最高支持到 1.14.2，而 1.14 版本 kubernetes 已经不在维护了，所以推荐换个镜像源安装 v.1.16.8 或者 v1.17.4 这两个版本，v1.18.1 也不建议建议安装使用。关于版本的选择可以参考 [生产环境如何保守地选择 kubernetes 版本](https://blog.k8s.li/How-to-choose-the-right-version-of-kubernetes.html) 。

```shell
╭─root@k8s-master-01 ~
╰─# yum list kubeadm --showduplicates|sort -r
kubeadm.x86_64                       1.6.11-0                         kubernetes
kubeadm.x86_64                       1.6.1-0                          kubernetes
kubeadm.x86_64                       1.6.10-0                         kubernetes
kubeadm.x86_64                       1.6.0-0                          kubernetes
kubeadm.x86_64                       1.14.2-0                         kubernetes
kubeadm.x86_64                       1.14.1-0                         kubernetes
kubeadm.x86_64                       1.14.0-0                         kubernetes
kubeadm.x86_64                       1.13.6-0                         kubernetes
kubeadm.x86_64                       1.13.5-0                         kubernetes
```

### 设置 docker 的daemon.json

安装完成之后先设置以下 docker 的启动参数 `/etc/docker/daemon.json`

```json
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": ["https://xlx9erfu.mirror.aliyuncs.com"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
```

### 设置开机自启并启动

```shell
systemctl enable docker kubelet
systemctl daemon-reload
systemctl start docker kubelet
```

```yaml
╭─root@k8s-master-01 ~
╰─# docker info
Client:
 Debug Mode: false
Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 19.03.3
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
 Kernel Version: 3.10.0-957.el7.x86_64
 Operating System: CentOS Linux 7 (Core)
 OSType: linux
 Architecture: x86_64
 CPUs: 4
 Total Memory: 3.683GiB
 Name: k8s-master-01
 ID: UXD4:IK6C:P3EO:TXRP:GQZD:STGH:GXZH:LO2C:HFBN:LV2B:LEVE:UWT2
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false
```

目前最新版本的 docker 默认优先采用 **overlay2**  的存储驱动，对于已支持该驱动的 Linux 发行版，不需要任何进行任何额外的配置。另外需要注意的是`devicemapper` 存储驱动已经在 docker 18.09 版本中被废弃，docker 官方推荐使用 `overlay2` 替代`devicemapper`。可使用 lsmod 命令查看当前系统内核是否支持 overlay2 。

```shell
╭─root@k8s-master-01 /opt/1.17.4
╰─# lsmod |grep overlay
overlay                71964  16
```

## 部署 master 节点

### 准备镜像

对于 kubernetes 1.17.4 版本的 kubeadm 需要使用到以下 docker 镜像如下，对于墙国网络环境下，你需要找台可以自由访问互联网的服务器，在上面把它 pull 下来，然后 save 成 tar 包传回本地再 docker load 进镜像😂。

```shell
k8s.gcr.io/kube-apiserver:v1.17.4
k8s.gcr.io/kube-controller-manager:v1.17.4
k8s.gcr.io/kube-scheduler:v1.17.4
k8s.gcr.io/kube-proxy:v1.17.4
k8s.gcr.io/pause:3.1
k8s.gcr.io/etcd:3.4.3-0
k8s.gcr.io/coredns:1.6.5
```

需要注意的是，当使用 kubeadm pull 相关镜像时，kubeadm 的版本最好和 --kubernetes-version=${version} 版本一致，不一致的话有些版本的镜像是 pull 不下来的。对应版本的 kubenetes 要使用对应版本的镜像才可以。可以使用下面的脚本在可以自由访问互联网的服务器上将 pull 指定版本的镜像。

```shell
#!/bin/bash
# for: use kubeadm pull kubernetes images
# date: 2019-08-15
# author: muzi502

set -xue
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update

for version in 1.17.4
do
    apt install kubeadm=${version}-00
    mkdir -p ${version}/bin
    docker rmi $(docker images -q)
    kubeadm config images pull --kubernetes-version=${version}
    docker save -o v${version}.tar $(docker images | grep -v TAG | cut -d ' ' -f1)
    gzip v${version}.tar v${version}.tar.gz
done
```

导入之后的镜像

```shell
╭─root@k8s-master-01 /opt/1.17.4
╰─# docker load < v1.17.4.tar.gz
fc4976bd934b: Loading layer [=============>]  53.88MB/53.88MB
f6953727aaba: Loading layer [=============>]   42.1MB/42.1MB
Loaded image: k8s.gcr.io/kube-scheduler:v1.17.4
225df95e717c: Loading layer [=============>]  336.4kB/336.4kB
7c9b0f448297: Loading layer [=============>]  41.37MB/41.37MB
Loaded image: k8s.gcr.io/coredns:1.6.5
fe9a8b4f1dcc: Loading layer [=============>]  43.87MB/43.87MB
ce04b89b7def: Loading layer [=============>]  224.9MB/224.9MB
1b2bc745b46f: Loading layer [=============>]  21.22MB/21.22MB
Loaded image: k8s.gcr.io/etcd:3.4.3-0
e17133b79956: Loading layer [=============>]  744.4kB/744.4kB
Loaded image: k8s.gcr.io/pause:3.1
682fbb19de80: Loading layer [=============>]  21.06MB/21.06MB
2dc2f2423ad1: Loading layer [=============>]  5.168MB/5.168MB
ad9fb2411669: Loading layer [=============>]  4.608kB/4.608kB
597151d24476: Loading layer [=============>]  8.192kB/8.192kB
0d8d54147a3a: Loading layer [=============>]  8.704kB/8.704kB
960d0ce862e2: Loading layer [=============>]  37.81MB/37.81MB
Loaded image: k8s.gcr.io/kube-proxy:v1.17.4
9daac3fed755: Loading layer [=============>]  118.7MB/118.7MB
Loaded image: k8s.gcr.io/kube-apiserver:v1.17.4
99df54617e88: Loading layer [=============>]  108.6MB/108.6MB
Loaded image: k8s.gcr.io/kube-controller-manager:v1.17.4
╭─root@k8s-master-01 /opt/1.17.4
╰─# docker images
REPOSITORY                           TAG                 CREATED             SIZE
k8s.gcr.io/kube-proxy                v1.17.4             4 weeks ago         116MB
k8s.gcr.io/kube-controller-manager   v1.17.4             4 weeks ago         161MB
k8s.gcr.io/kube-apiserver            v1.17.4             4 weeks ago         171MB
k8s.gcr.io/kube-scheduler            v1.17.4             4 weeks ago         94.4MB
k8s.gcr.io/coredns                   1.6.5               5 months ago        41.6MB
k8s.gcr.io/etcd                      3.4.3-0             5 months ago        288MB
k8s.gcr.io/pause                     3.1                 2 years ago         742kB
```

### 初始化 master 节点

使用 kubeadm init 命令初始化 master 节点，关于 kubeadm 的参数可以参考官方文档 [kubeadm init](https://kubernetes.io/zh/docs/reference/setup-tools/kubeadm/kubeadm-init/)

```shell
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=10.20.172.211 --kubernetes-version=1.17.4
```

- --pod-network-cidr= 指定 Pod 网段的 IP 地址块
- --apiserver-advertise-address= 指定 api-server 监听的地址
- --kubernetes-version= 指定 kubernetes 的版本，最好和 kubeadm 版本保持一致

正常完成之后的日志输出如下

```shell
╭─root@k8s-master-01 /opt/1.17.4
╰─# kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=10.20.172.211 --kubernetes-version=1.17.4

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.20.172.211:6443 --token hi66lb.r13y2hottst2ks6f \
    --discovery-token-ca-cert-hash sha256:9b96a436f2897a8371fccb3af4d8f2fff348fcb42763e005e9175a4e925c51d1
```

刚刚安装完之后 coreDNS 的 Pod 会一直出于 pending 状态，而且 Master 的 STATUS 状态也是 `NotReady` 。遇到这种问题`不要慌,问题不大.jpg` 这是因为集群中还没有安装好 CNI 网络插件，等下部署好 flannel 就可以。

```shell
╭─root@k8s-master-01 /opt/1.17.4
╰─# kubectl get node
NAME            STATUS     ROLES    AGE     VERSION
k8s-master-01   NotReady   master   9m19s   v1.17.4
╭─root@k8s-master-01 /opt/1.17.4
╰─# kubectl get pod --all-namespaces
NAMESPACE     NAME                                    READY   STATUS    RESTARTS   AGE
kube-system   coredns-6955765f44-t4b6k                0/1     Pending   0          49s
kube-system   coredns-6955765f44-vm5tm                0/1     Pending   0          49s
kube-system   etcd-k8s-master-01                      1/1     Running   0          62s
kube-system   kube-apiserver-k8s-master-01            1/1     Running   0          62s
kube-system   kube-controller-manager-k8s-master-01   1/1     Running   0          62s
kube-system   kube-proxy-rmgwl                        1/1     Running   0          49s
kube-system   kube-scheduler-k8s-master-01            1/1     Running   0          62s
```

## 加入 node 节点

在另一台 Node 节点上重复节点初始化的内容，并将将所需的镜像导入到 node 节点。之后使用 kubeadm joine 命令将 Node 节点加入到集群中即可。

```shell
╭─root@k8s-node-01 /opt/1.17.4
╰─# kubeadm join 10.20.172.211:6443 --token hi66lb.r13y2hottst2ks6f \
>     --discovery-token-ca-cert-hash sha256:9b96a436f2897a8371fccb3af4d8f2fff348fcb42763e005e9175a4e925c51d1
W0415 00:52:08.127829    9901 join.go:346] [preflight] WARNING: JoinControlPane.controlPlane settings will be ignored when control-plane flag is not set.
[preflight] Running pre-flight checks
        [WARNING Hostname]: hostname "k8s-node-01" could not be reached
        [WARNING Hostname]: hostname "k8s-node-01": lookup k8s-node-01 on 192.168.10.254:53: no such host
        [WARNING Service-Kubelet]: kubelet service is not enabled, please run 'systemctl enable kubelet.service'
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.17" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

如果不出意外的话会提示 `This node has joined the cluster:` ，然后在 master 节点看一下节点是否加入

```shell
╭─root@k8s-master-01 /opt/1.17.4
╰─# kubectl get node
NAME            STATUS     ROLES    AGE   VERSION
k8s-master-01   NotReady   master   31m   v1.17.4
k8s-node-01     NotReady   <none>   58s   v1.17.4
```

如果状态还是 `NotReady` 不要慌，问题不大）。接下来安装 CNI 网络插件即可

## 部署网络插件

在这我们使用 flannel 作为 Kubernetes 网络解决方案，在 kubeadm init 的时候指定的 --pod-network-cidr= 指定 Pod 网段的 IP 地址块，即为 flannel 默认的 IP 段，如果没有修改的话就直接在 master 节点上使用 kubectl apply -f 命令部署即可。

```shell
╭─root@k8s-master-01 /opt/1.17.4
╰─# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

由于墙国网络原因，访问 `raw.githubusercontent.com` 这个域名会比较慢，在这里可以使用 jsdelivr 来进行加速。

```shell
╭─root@k8s-master-01 /opt/1.17.4
╰─# kubectl apply -f https://cdn.jsdelivr.net/gh/coreos/flannel/Documentation/kube-flannel.yml
podsecuritypolicy.policy/psp.flannel.unprivileged created
clusterrole.rbac.authorization.k8s.io/flannel created
clusterrolebinding.rbac.authorization.k8s.io/flannel created
serviceaccount/flannel created
configmap/kube-flannel-cfg created
daemonset.apps/kube-flannel-ds-amd64 created
daemonset.apps/kube-flannel-ds-arm64 created
daemonset.apps/kube-flannel-ds-arm created
daemonset.apps/kube-flannel-ds-ppc64le created
daemonset.apps/kube-flannel-ds-s390x created
```

flannel 的 docker 镜像是在 `quay.io/coreos/flannel` 一般情况下没问题能顺利 pull 下来。然后使用 `kubectl get pod -n kube-system` 命令查看 pod 的状态是不是都在 running 状态。

```shell
╭─root@k8s-master-01 /opt/1.17.4
╰─# kubectl get pod -n kube-system
NAME                                    READY   STATUS    RESTARTS   AGE
coredns-6955765f44-g5fwl                1/1     Running   0          23h
coredns-6955765f44-g7cls                1/1     Running   0          23h
etcd-k8s-master-01                      1/1     Running   0          24h
kube-apiserver-k8s-master-01            1/1     Running   0          24h
kube-controller-manager-k8s-master-01   1/1     Running   0          24h
kube-flannel-ds-amd64-94hfr             1/1     Running   0          23h
kube-flannel-ds-amd64-vpdfd             1/1     Running   0          23h
kube-proxy-rmgwl                        1/1     Running   0          24h
kube-proxy-xqcsq                        1/1     Running   0          24h
kube-scheduler-k8s-master-01            1/1     Running   0          24h

╭─root@k8s-master-01 /opt/1.17.4
╰─# kubectl get node
NAME            STATUS   ROLES    AGE   VERSION
k8s-master-01   Ready    master   29h   v1.17.4
k8s-node-01     Ready    <none>   28h   v1.17.4
```

由此，一个简陋的 kubernetes 集群已经部署完了😂，文章有点水了~~。对于想要入门和学习 kubernetes 的同学来说 kubeadm 是个好工具。后续会更新一些 kubernetes 内容。

## 结束

最后提一下，文中提到的对于下载 github 上文件，可以通过以下规则进行替换，就可以使用 jsdelivr 来 fuck 一下 GFW ，无痛下载 GitHub 上的文件。这还是从 [JsDelivr 全站托管](https://chanshiyu.com/#/post/94) 学来的骚操作😂。

```yaml
GitHub rul: https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh
jsDelivr url: https://cdn.jsdelivr.net/gh/ohmyzsh/ohmyzsh/tools/install.sh
```

规则就是将 `github.com` 替换为 `cdn.jsdelivr.net/gh` ，然后去掉 `/blob/master`，接上 repo 里文件的绝对路径即可。也可以将以下脚本保存为一个可执行脚本文件 /usr/bin/rawg，当使用 rawg https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh 就可以直接将 url 进行替换，快速地下载文件。怎么样，很爽吧😂，对于某些 Linux 机器上没有代理的情况下该方法有效。

```shell
#!/bin/bash
# data: 2020-03-31
# author: muzi502
# for: Fuck GFW and download some raw file form github without proxy using jsDelivr CDN
# usage: save the .she to your local such as /usr/bin/rawg, and chmod +x /usr/bin/rawg
# use rawg https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh to download

set -xue
# GitHub rul: https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh
# jsDelivr url: https://cdn.jsdelivr.net/gh/ohmyzsh/ohmyzsh/tools/install.sh

wget $(echo $1 | sed 's/raw.githubusercontent.com/cdn.jsdelivr.net\/gh/' \
               | sed 's/github.com/cdn.jsdelivr.net\/gh/' \
               | sed 's/\/master//' | sed 's/\/blob//' )

# curl $(echo $1 | sed 's/raw.githubusercontent.com/cdn.jsdelivr.net\/gh/' \
#                | sed 's/github.com/cdn.jsdelivr.net\/gh/' \
#                | sed 's/\/master//' | sed 's/\/blob//' )
```
