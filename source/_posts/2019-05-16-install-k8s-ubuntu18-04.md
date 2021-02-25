---
title: ubuntu 1804 使用 kubeadm 部署 kubernetes
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

注意: 这个部署在了 digital ocean 的 VPS 上，国内的机器需要代理。

## 1.主机要求

0.硬件要求 2CPU 2GB RAM

1.临时关闭 swap `swapoff -a`

2.打开bridge-nf-call-iptables

```bash
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
enet.ipv4.ip_forward                = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
```

3.加载 br_netfilter 内核模块，安装 docker 后会默认开启

```bash
modprobe br_netfilter
lsmod | grep br_netfilter
```

4.临时关闭一下SELinux，怎么关闭的？？貌似我的 digital ocean Ubuntu18.04 没有安装SELinux🤔

在网上找了一篇文章临时关闭SELinux的[turn-off-selinux](https://www.revsys.com/writings/quicktips/turn-off-selinux.html)

```bash
Test if SELinux is running
You can test to see if SELinux is currently enabled with the following command:

selinuxenabled && echo enabled || echo disabled
Turning off SELinux temporarily
Disabling SELinux temporarily is the easiest way to determine if the problem you are experiencing is related to your SELinux settings. To turn it off, you will need to become the root users on your system and execute the following command:

echo 0 > /sys/fs/selinux/enforce
This temporarily turns off SELinux until it is either re-enabled or the system is rebooted. To turn it back on you simply execute this command:

echo 1 > /sys/fs/selinux/enforce
As you can see from these commands what you are doing is setting the file /selinux/enforce to either '1' or '0' to denote 'true' and 'false'.
```

5.VPS需要在国外或代理，因为需要下载gcr上的镜像。国内用户可以考虑装个软路由然后设置为旁路网关，这样能透明代理，只需要修改部署机器的网关为软路由即可。也可以在部署机器上安装代理，不过比较麻烦和坑。还是软路由、旁路网关、透明代理三连方便😂。

----

## 2.安装Docker或其他容器运行时

官方文档写了建议安装18.06.2，其他版本的docker支持的不太好
On each of your machines, install Docker. Version 18.06.2 is recommended, but 1.11, 1.12, 1.13, 17.03 and 18.09 are known to work as well. Keep track of the latest verified Docker version in the Kubernetes release notes.

### 1.使用kubernetes官方建议的安装方式😂

```bash
## Set up the repository:
### Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install apt-transport-https ca-certificates curl software-properties-common

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

### Add Docker apt repository.
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

## Install Docker CE.
apt-get update && apt-get install docker-ce=18.06.2~ce~3-0~ubuntu
```

### 2.修改一下Docker的daemon.json文件

在这里需要把 `native.cgroupdriver=` 修改为 systemd，默认的是 docker。

```bash
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

不修改的话后面初始化的时候会warning😂

```bash
[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
```

最后将docker加入开机自启，并重启一下docker

```bash
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker
```

3.(可选)CRI-O 容器运行时

```bash
#Prerequisites
modprobe overlay
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.

# Install prerequisites
apt-get update
apt-get install software-properties-common

add-apt-repository ppa:projectatomic/ppa
apt-get update

# Install CRI-O
apt-get install cri-o-1.11

# Start CRI-O
systemctl start crio
```

4.(可选)Containerd

```bash
# Prerequisites
modprobe overlay
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

# Install containerd
## Set up the repository
### Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common

### Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

### Add Docker apt repository.
add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

## Install containerd
apt-get update && apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd

# 使用systemd
systemd
To use the systemd cgroup driver, set plugins.cri.systemd_cgroup = true in /etc/containerd/config.toml. When using kubeadm, manually configure the cgroup driver for kubelet as well
```

----

## 3.安装kubelet kubeadm kubectl

官方推荐的安装方式

```bash
# Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install -y apt-transport-https curl

# Add Google’s official GPG key
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

# Add kubernetes apt repository.
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update && apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl daemon-reload && systemctl restart kubelet
```

----

## 4.初始化kubernetes集群

可以先把所需要的镜像pull下来 `kubeadm config images pull`

执行期间不能中断shell，不然重新弄得话很头疼，最好先开个tmux
使用kubeadm init初始化kubernetes集群，可以指定配置文件，把IP替换为这台机器的内网IP，要k8s-node节点能够访问得到

`kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=IP`

最后初始化成功的话会出现以下，

```bash
[mark-control-plane] Marking the node k8s-master as control-plane by adding the label "node-role.kubernetes.io/master=''"
[mark-control-plane] Marking the node k8s-master as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: i311md.mhwgl9rr3q26rc4n
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

kubeadm join IP:6443 --token i311md.mhwgl9rr3q26rc4n \
    --discovery-token-ca-cert-hash sha256:21db38130a6868b5f07be1435c5ad29c0880fea481c50005d654de06fd95db2a
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

----

我第一次初始化因为shell中断失败了😱报错

```bash
[kubelet-check] Initial timeout of 40s passed.
error execution phase upload-config/kubelet: Error writing Crisocket information for the control-plane node: timed out waiting for the condition
```

第二次初始化还是失败😭

```bash
╭─root@k8s-master ~
╰─# kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=
[init] Using Kubernetes version: v1.14.1
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Activating the kubelet service
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [k8s-master localhost] and IPs [IP 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [k8s-master localhost] and IPs [IP 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [k8s-master kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 IP]
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[kubelet-check] Initial timeout of 40s passed.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get http://localhost:10248/healthz: dial tcp 127.0.0.1:10248: connect: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get http://localhost:10248/healthz: dial tcp 127.0.0.1:10248: connect: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get http://localhost:10248/healthz: dial tcp 127.0.0.1:10248: connect: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get http://localhost:10248/healthz: dial tcp 127.0.0.1:10248: connect: connection refused.
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get http://localhost:10248/healthz: dial tcp 127.0.0.1:10248: connect: connection refused.

Unfortunately, an error has occurred:
        timed out waiting for the condition

This error is likely caused by:
        - The kubelet is not running
        - The kubelet is unhealthy due to a misconfiguration of the node in some way (required cgroups disabled)

If you are on a systemd-powered system, you can try to troubleshoot the error with the following commands:
        - 'systemctl status kubelet'
        - 'journalctl -xeu kubelet'

Additionally, a control plane component may have crashed or exited when started by the container runtime.
To troubleshoot, list all containers using your preferred container runtimes CLI, e.g. docker.
Here is one example how you may list all Kubernetes containers running in docker:
        - 'docker ps -a | grep kube | grep -v pause'
        Once you have found the failing container, you can inspect its logs with:
        - 'docker logs CONTAINERID'
error execution phase wait-control-plane: couldn't initialize a Kubernetes cluster
```

~~如果你初始化失败的话，那就删除所有的容器，删除/etc/kubernetes/* 删除 /var/lib/etcd/*~~

其实进行kubeadm reset重置再执行kubeadm init也行，这样更方便些😂
然后再重新初始化 `kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=157.220.164.247`

加个参数`--ignore-preflight-errors=all`重新初始化

----

## 5.将k8s-node节点加入到k8s-master

node节点也是和master节点一样，安装docker，kubelet kubeadm kubectl。不过最后不需要初始化集群，不用kubeadm init，而是直接加入到master当中来。如果master初始化后找不到kubeadm join所需要的token，可以使用以下命令重新生成一个token,注意 tty参数为0则这个token永久不会失效。可以自定义失效期限。

```bash
kubeadm token generate
kubeadm token create ljfmu1.5kek1jy2xdb8sopv  --print-join-command --ttl=0
kubeadm token create $(kubeadm token generate)  --print-join-command --ttl=0
```

只需要一个命令就可以将 k8s-node 节点加入到 master 的管理之下

`kubeadm join IP:6443 --token ljfmu1.5kek1jy2xdb8sopv --discovery-token-ca-cert-hash sha256:3b18b4cc1debc63d57e03da52424a3b3bacf03cc290b94cbe5b6aaf9c152f0cf`

加入成功后会提示以下内容😘

```bash
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.14" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Activating the kubelet service
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

注意: 如果hostname如果是随机生成的带有`_`是不行的，那就使用 ```hostnamectl set-hostname k8s-node2 && bash```设置一下下😂

```bash
name: Invalid value: "vm_158_35_centos": a DNS-1123 subdomain must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')
```
