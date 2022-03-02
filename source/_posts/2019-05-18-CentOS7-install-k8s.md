---
title: CentOS7 使用 kubeadm 部署 kubernetes
date: 2019-05-16
categories: 技术
slug:
tag:
  - kubeadm
  - kubernetes
  - k8s
copyright: true
comment: true
---

## 0.准备

1.临时关闭 swap、SELinux、防火墙。官方建议这么做。

```bash
swapoff -a
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX= disabled/' /etc/selinux/config
systemctl disable iptables-services firewalld
systemctl stop iptables-services firewalld
```

2.打开 bridge-nf-call-iptables

```bash
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
enet.ipv4.ip_forward                = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
```

3.加载 br_netfilter 内核模块，安装 docker 后也会默认开启

```bash
modprobe br_netfilter
lsmod | grep br_netfilter
```

## 1.安装 docker

1.安装 yum-utils 提供 yum-config-manager 工具
devicemapper 存储驱动依赖 device-mapper-persistent-data 和 lvm2

`sudo yum install -y yum-utils device-mapper-persistent-data lvm2`

2.添加 aliyun 软件包源
`sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo`

3.安装 docker-ce-stable
官方文档写了建议安装 18.06.2，其他版本的 docker 支持的不太好
On each of your machines, install Docker. Version 18.06.2 is recommended, but 1.11, 1.12, 1.13, 17.03 and 18.09 are known to work as well. Keep track of the latest verified Docker version in the Kubernetes release notes.

`sudo yum list docker-ce.x86_64  --showduplicates |sort -r` 选择 `docker-ce-18.06.1.ce-3.el7` 版

`yum install -y docker-ce-18.06.1.ce-3.el7`

4.添加 Docker 用户和用户组(可选) `sudo usermod -aG docker $USER`

5.修改 docker daemon 配置文件

```bash
mkdir -p /etc/docker/
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
```

不修改的话后面初始化的时候会 warning😂

```bash
[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
```

6.启动 docker 并添加到开机自启

```bash
systemctl enable docker
systemctl restart docker
systemctl daemon-reload
```

## 2.在国外服务器下载所需要的镜像并传输回国内服务器上

我自己在 aws 上做了个非官方 k8s 镜像站，仅仅包含了 kubeadm 初始化 k8s 集群时所需要的镜像 [mirror](https://images.k8s.k8s.li)，没有对镜像做任何修改，定时任务每周拉取最新的镜像。你信得过我的话也可以去我的镜像站下载。上面 log 有校验的校验码，下载后记得校验一下。😂。我使用 IDM 下载，开启 16 个线程下载速度能打到 15Mb/s。HTTPS 传输，不用注册。国内的一些博主用百度云 😂 来分享这些镜像，十分不友好。这才是我建这个镜像站的原因。
下载完成后使用 `docker load < k8s.image.tar.gz` 就能加载镜像，无需解压。

你也可以自己在国外的服务器上下载这些镜像并传输回国内的服务器上。

```bash
╭─root@k8s-master ~
╰─# kubeadm config images pull
[config/images] Pulled k8s.gcr.io/kube-apiserver:v1.14.1
[config/images] Pulled k8s.gcr.io/kube-controller-manager:v1.14.1
[config/images] Pulled k8s.gcr.io/kube-scheduler:v1.14.1
[config/images] Pulled k8s.gcr.io/kube-proxy:v1.14.1
[config/images] Pulled k8s.gcr.io/pause:3.1
[config/images] Pulled k8s.gcr.io/etcd:3.3.10
[config/images] Pulled k8s.gcr.io/coredns:1.3.1
# 导出镜像
docker save -o k8s.tar $(docker images | grep k8s.gcr.io | cut -d ' ' -f1)
gzip k8s.tar k8s.tar.gz
```

将这些镜像导出并压缩，传输回国内。http 方式多线程传输最快。IDM64 线程能跑满带宽 😂，不到一分钟就下载到本地。然后再 scp 传输回国内的云服务器上。grep B 是为了过滤掉输出结果第一行显示的 `REPOSITORY  TAG  IMAGE ID  CREATED  SIZE`😂
在使用 docker save 的时候，要指定镜像的名称，不要指定镜像的 ID，不然你装载镜像的时候全是 node 的镜像，是启动不起来的 😥
ps：第一次我使用的是 `docker save $(docker images -q)` 导出了所有的镜像。在装入镜像的时候发现镜像 NAME 全是 node😂。使用 `docker images | grep B | cut -d ' ' -f1` 过滤出的是带 NAME 的镜像。

`docker save -o k8s.tar $(docker images | grep B | cut -d ' ' -f1) | gzip k8s.tar k8s.tar.gz`

然后你在国内的服务器上执行 `docker load < k8s.tar.gz` ，不用手动 gzip 解压，docker load 会自动解压并把镜像加载进去。

## 3.安装 kubelet kubeadm kubectl

添加国内阿里云的 kubernetes 镜像站点

```bash
cat>>/etc/yum.repos.d/kubrenetes.repo<<EOF
[kubernetes]
name=Kubernetes Repo
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
EOF

yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet
```

## 4.初始化集群

使用 kubeadm init 初始化 kubernetes 集群，可以指定配置文件，把 IP 替换为这台机器的内网 IP，要 k8s-node 节点能够访问得到 IP。

`kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=IP`

最后初始化成功的话会出现以下:

```bash
[mark-control-plane] Marking the node k8s-master as control-plane by adding the label "node-role.kubernetes.io/master=''"
[mark-control-plane] Marking the node k8s-master as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: ********
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join IP:6443 --token ******i311md.mhwgl9rr3q26rc4n****** \
    --discovery-token-ca-cert-hash sha256:2**********2a
```

然后查看一下各个容器的运行状态

```bash
╭─root@k8s-master ~
╰─# docker ps -a
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS               NAMES
38d9c698ec37        efb3887b411d           "kube-controller-man…"   7 minutes ago       Up 7 minutes                            k8s_kube-controller-manager_kube-controller-manager-k8s-master_kube-system_f423ac50e24b65e6d66fe37e6d721912_0
c273979e75b6        8931473d5bdb           "kube-scheduler --bi…"   7 minutes ago       Up 7 minutes                            k8s_kube-scheduler_kube-scheduler-k8s-master_kube-system_f44110a0ca540009109bfc32a7eb0baa_0
71f1f40dfa9e        cfaa4ad74c37           "kube-apiserver --ad…"   7 minutes ago       Up 7 minutes                            k8s_kube-apiserver_kube-apiserver-k8s-master_kube-system_d57282173a211f69b917251534760047_0
37636f04f5d6        2c4adeb21b4f           "etcd --advertise-cl…"   7 minutes ago       Up 7 minutes                            k8s_etcd_etcd-k8s-master_kube-system_dcd3914b600c5e8e86b2026688cc6dc5_0
48fc68b067de        k8s.gcr.io/pause:3.1   "/pause"                 7 minutes ago       Up 7 minutes                            k8s_POD_kube-scheduler-k8s-master_kube-system_f44110a0ca540009109bfc32a7eb0baa_0
3c9f8e8224cf        k8s.gcr.io/pause:3.1   "/pause"                 7 minutes ago       Up 7 minutes                            k8s_POD_kube-apiserver-k8s-master_kube-system_d57282173a211f69b917251534760047_0
b4903d8f18ee        k8s.gcr.io/pause:3.1   "/pause"                 7 minutes ago       Up 7 minutes                            k8s_POD_kube-controller-manager-k8s-master_kube-system_f423ac50e24b65e6d66fe37e6d721912_0
f6d2cd0b03cd        k8s.gcr.io/pause:3.1   "/pause"                 7 minutes ago       Up 7 minutes                            k8s_POD_etcd-k8s-master_kube-system_dcd3914b600c5e8e86b2026688cc6dc5_0
74a3699833bc        20a2d7035165           "/usr/local/bin/kube…"   9 minutes ago       Up 4 seconds                            k8s_kube-proxy_kube-proxy-g4nd4_kube-system_afc4ba92-7657-11e9-b684-2aabd22d242a_1
ba61bed68ecc        k8s.gcr.io/pause:3.1   "/pause"                 9 minutes ago       Up 9 minutes                            k8s_POD_kube-proxy-g4nd4_kube-system_afc4ba92-7657-11e9-b684-2aabd22d242a_4
```

---

## 5.将 node 加入到 master 管理当中来

node 节点的安装过程和 master 一样，只是在最后一步时不相同。master 为 init 初始化 k8s 集群，而 node 节点为 join 集群当中来。安装 docker、kubelet 、kubeadm 、kubectl 好，并导入所需要的镜像。再执行

`kubeadm join IP:6443 --token ************ \--discovery-token-ca-cert-hashsha256:******`

也就是 master 节点初始化成功后生成的那个 😂。注意这个 token 是有有效期的，默认是 3h。也可以手动生成 token 给 node 加入 master 来用。ttl 为 token 有效期，为 0 的话就是永久生效。

`kubeadm token create $(kubeadm token generate)  --print-join-command --ttl=0`
