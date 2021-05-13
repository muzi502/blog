---
title: 使用 Kubespray 本地开发测试部署 kubernetes 集群
date: 2021-04-29
updated: 2021-04-29
slug:
categories: 技术
tag:
  - k8s
  - kubespray
  - kubernetes
copyright: true
comment: true
---

公司 PaaS 平台底层的 kubernetes 集群部署采用的开源的 kubespray，正好我在参与 kubespray 二开工作。在这段时主要完成了 kubespray 自动化打包发布流水线、私有化部署、增加自研 CNI 部署、以及一些 bugfix 等。最近抽空整理并总结一下使用 kubespray 在本地开发测试部署 kubernetes 集群踩的一些坑。

## 准备

劝退三连😂：

- 需要一个部署镜像仓库和 nginx
- 需要一个域名，最好已经设置好 DNS 解析和 SSL 证书
- 集群节点需要至少两台机器，并且可以访问外网

虽然手头里有一大批开发机器，但由于我的域名 `k8s.li` 比较特殊，国内很难进行备案（也不想备案），所以无法将 DNS 解析到这些国内的服务器上。因此我打算将域名解析到一台国外的服务器上，然后再使用 nginx rewrite 重写将请求转发到阿里云的 OSS ；另外 docker registry 的后端存储也可以选择使用阿里云 OSS，这样客户端在拉取镜像的时候，只会通过我的域名获取镜像的 manifest 文件，镜像的 blobs 数据将会转发到阿里云 OSS。在集群部署的时候，下载文件和镜像最主要的流量都会通过阿里云 OSS，这样可以节省集群部署耗时，提高部署效率，同时又能剩下一笔服务器的流量费用。

### 域名 SSL 证书制作

域名 SSL 证书主要是给镜像仓库使用的，假如证书是自签的或者镜像仓库使用的是 HTTP 协议，这样会导致 docker 或者 containerd 无法拉取镜像，需要为集群所有节点配置 `insecure-registries`  这个参数。搞起来比较麻烦，因此还是推荐给镜像仓库加一个非自签的 SSL 证书，这样能减少一些不必要的麻烦。如果有现成的镜像仓库并且配置好了 SSL 证书，可以略过此步。

制作域名证书的方式有很多种，个人比较推荐使用 acme.sh 。它实现了 acme 协议支持的所有验证协议，并且支持支持数十种域名解析商。由于我的域名是托管在 cloudflare 上的，使用 acme.sh 来签发证书特别方便，只需要配置两个参数即可。下面就给 k8s.li 这个域名签发一个泛域名证书。

- 安装  acme.sh

```bash
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --help
```

- 签发证书

```bash
export CF_Email="muzi502.li@gmail.com" # cloudflare 账户的邮箱
export CF_Key="xxxxxx" # "cloudflare中查看你的key"

~/.acme.sh/acme.sh --issue --dns dns_cf -d k8s.li -d *.k8s.li

[Tue Apr 27 07:32:52 UTC 2021] Cert success.
[Tue Apr 27 07:32:52 UTC 2021] Your cert is in  /root/.acme.sh/k8s.li/k8s.li.cer
[Tue Apr 27 07:32:52 UTC 2021] Your cert key is in  /root/.acme.sh/k8s.li/k8s.li.key
[Tue Apr 27 07:32:52 UTC 2021] The intermediate CA cert is in  /root/.acme.sh/k8s.li/ca.cer
[Tue Apr 27 07:32:52 UTC 2021] And the full chain certs is there:  /root/.acme.sh/k8s.li/fullchain.cer
```

> 前面证书生成以后，接下来需要把证书 copy 到真正需要用它的地方。
>
> 注意，默认生成的证书都放在安装目录下`~/.acme.sh/`， 请不要直接使用此目录下的文件，例如: 不要直接让`nginx/apache`的配置文件使用这下面的文件。这里面的文件都是内部使用，而且目录结构可能会变化。
>
> 正确的使用方法是使用`--installcert` 命令，并指定目标位置，然后证书文件会被 copy 到相应的位置

- 安装证书

```bash
acme.sh --install-cert -d k8s.li \
--cert-file      /etc/nginx/ssl/k8s.li.cer  \
--key-file       /etc/nginx/ssl/k8s.li.key  \
--fullchain-file /etc/nginx/ssl/fullchain.cer
```

### 搭建镜像仓库

- config.yml

```yaml
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  oss:
    accesskeyid: xxxx # 这里配置阿里云 OSS 的 accesskeyid
    accesskeysecret: xxxx # 这里配置阿里云 OSS 的 accesskeysecret
    region: oss-cn-beijing # 配置 OSS bucket 的区域，比如 oss-cn-beijing
    internal: false
    bucket: fileserver # 配置存储 bucket 的名称
    rootdirectory: /kubespray/registry # 配置路径
  delete:
    enabled: true
http:
  addr: 0.0.0.0:5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
```

- docker-compose

```yaml
version: '2'
services:
  hub-registry:
    image: registry:2.7.1
    container_name: hub-registry
    restart: always
    volumes:
      - ./config.yml:/etc/docker/registry/config.yml
    ports:
      - 127.0.0.1:5000:5000
```

- nginx.conf

```nginx
server {
    listen       443 ssl;
    listen       [::]:443;
    server_name  hub.k8s.li;
    ssl_certificate /etc/nginx/ssl/fullchain.cer;
    ssl_certificate_key /etc/nginx/ssl/k8s.li.key;
    gzip_static on;
    client_max_body_size 4096m;
    if ($request_method !~* GET) {
         return 403;
    }
    location / {
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass   http://localhost:5000;
    }
}
```

### 文件服务器

文件服务器用于存放一些 kubeadm、kubectl、kubelet 等二进制文件，kubespray 默认的下载地址在国内访问特别慢，因此需要搭建一个 http/https 服务器，用于给集群部署下载这些二进制文件使用。

- nginx.conf

需要注意，这里的 nginx 配置使用的是 rewrite 而不是 proxy_pass，这样客户端在想我的服务器请求文件时，会重写客户端的请求，让客户端去请求阿里云 OSS 的地址。

```nginx
server {
    listen 443;
    listen [::]:443;
    server_name   dl.k8s.li;
    ssl_certificate /etc/nginx/ssl/fullchain.cer;
    ssl_certificate_key /etc/nginx/ssl/k8s.li.key;
    location / {
        rewrite ^/(.*)$ https://fileserver.oss-cn-beijing.aliyuncs.com/kubespray/files/$1;
        proxy_hide_header Content-Disposition;
        proxy_hide_header x-oss-request-id;
        proxy_hide_header x-oss-object-type;
        proxy_hide_header x-oss-hash-crc64ecma;
        proxy_hide_header x-oss-storage-class;
        proxy_hide_header x-oss-force-download;
        proxy_hide_header x-oss-server-time;
    }
}
```

### 编译安装 skopeo

安装 skopeo 用来同步一些使用的镜像到私有镜像仓库，性能上比 docker 快很多，强烈推荐。skopeo 的安装方式可参考官方文档 [Installing from packages](https://github.com/containers/skopeo/blob/master/install.md) 。不过个人还是使用 go buid 编译一个静态链接的可执行文件，这样在 Linux 发行版都可以使用。不然在 Debian 上编译的可执行文件无法拿到 CentOS 上使用，因为二者使用的动态链接库不一样！

```bash
root@debian:/root/skopeo git:(master*) # git clone https://github.com/containers/skopeo && cd skopeo

# 本地开发机器已经安装并配置好了 golang 编译环境
root@debian:/root/skopeo git:(master*) # CGO_ENABLE=0 GO111MODULE=on go build -mod=vendor "-buildmode=pie" -ldflags '-extldflags "-static"' -gcflags "" -tags "exclude_graphdriver_devicemapper exclude_graphdriver_btrfs containers_image_openpgp" -o bin/skopeo ./cmd/skopeo

root@debian:/root/skopeo git:(master*) # ldd bin/skopeo
not a dynamic executable
```

### 获取部署需要的二进制文件

kubespray 部署的时候需要到 github.com 或 storage.googleapis.com 下载一些二进制文件，这些地址在国内都都被阻断了，因此需要将部署时依赖的文件上传到自己的文件服务器上。自己写了个脚本用于获取 kubespray 部署需要的二进制文件，在 kubespray repo 的根目录下执行,下载的文件默认会存放在 `temp/files` 目录下。下载完成之后将该目录下的所有子目录上传到自己的文件服务器上。后面配置一些参数在这个地址的参数前面加上自己文件服务器的 URL 即可。

- 首先 clone repo 到本地

```bash
root@debian:/root# git clone https://github.com/kubernetes-sigs/kubespray && cd kubespray
```

- 将该脚本 `generate_list.sh` 保存到 repo 根目录下，并执行该脚下载需要的文件。

> ps: 用 shell 脚本去处理 Jinja2 的 yaml， 写 sed 写得我想吐🤮

```bash
#!/bin/bash
set -eo pipefail

CURRENT_DIR=$(cd $(dirname $0); pwd)
TEMP_DIR="${CURRENT_DIR}/temp"
REPO_ROOT_DIR="${CURRENT_DIR}"

: ${IMAGE_ARCH:="amd64"}
: ${ANSIBLE_SYSTEM:="linux"}
: ${ANSIBLE_ARCHITECTURE:="x86_64"}
: ${DOWNLOAD_YML:="roles/download/defaults/main.yml"}
: ${KUBE_VERSION_YAML:="roles/kubespray-defaults/defaults/main.yaml"}

mkdir -p ${TEMP_DIR}
generate_versions() {
    # ARCH used in convert {%- if image_arch != 'amd64' -%}-{{ image_arch }}{%- endif -%} to {{arch}}
    if [ "${IMAGE_ARCH}" != "amd64" ]; then ARCH="${IMAGE_ARCH}"; fi

    cat > ${TEMP_DIR}/version.sh << EOF
arch=${ARCH}
image_arch=${IMAGE_ARCH}
ansible_system=${ANSIBLE_SYSTEM}
ansible_architecture=${ANSIBLE_ARCHITECTURE}
EOF
    grep 'kube_version:' ${REPO_ROOT_DIR}/${KUBE_VERSION_YAML} \
    | sed 's/: /=/g' >> ${TEMP_DIR}/version.sh
    grep '_version:' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
    | sed 's/: /=/g;s/{{/${/g;s/}}/}/g' | tr -d ' ' >> ${TEMP_DIR}/version.sh
    sed -i 's/kube_major_version=.*/kube_major_version=${kube_version%.*}/g' ${TEMP_DIR}/version.sh
    sed -i 's/crictl_version=.*/crictl_version=${kube_version%.*}.0/g' ${TEMP_DIR}/version.sh
}

generate_files_list() {
    echo "source ${TEMP_DIR}/version.sh" > ${TEMP_DIR}/files.sh
    grep 'download_url:' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
    | sed 's/: /=/g;s/ //g;s/{{/${/g;s/}}/}/g;s/|lower//g;s/^.*_url=/echo /g' >> ${TEMP_DIR}/files.sh
    bash ${TEMP_DIR}/files.sh | sort > ${TEMP_DIR}/files.list
}

generate_images_list() {
    KUBE_IMAGES="kube-apiserver kube-controller-manager kube-scheduler kube-proxy"
    echo "source ${TEMP_DIR}/version.sh" > ${TEMP_DIR}/images.sh
    grep -E '_repo:|_tag:' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
    | sed "s#{%- if image_arch != 'amd64' -%}-{{ image_arch }}{%- endif -%}#{{arch}}#g" \
    | sed 's/: /=/g;s/{{/${/g;s/}}/}/g' | tr -d ' ' >> ${TEMP_DIR}/images.sh
    sed -n '/^downloads:/,/download_defaults:/p' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
    | sed -n "s/repo: //p;s/tag: //p" | tr -d ' ' | sed 's/{{/${/g;s/}}/}/g' \
    | sed 'N;s#\n# #g' | tr ' ' ':' | sed 's/^/echo /g' >> ${TEMP_DIR}/images.sh
    echo "${KUBE_IMAGES}" | tr ' ' '\n' | xargs -L1 -I {} \
    echo 'echo ${kube_image_repo}/{}:${kube_version}' >> ${TEMP_DIR}/images.sh
    bash ${TEMP_DIR}/images.sh | sort > ${TEMP_DIR}/images.list
}

generate_versions
generate_files_list
generate_images_list
wget -x -P ${TEMP_DIR}/files -i ${TEMP_DIR}/files.list
```

最终下载的结果如下，基本上保持了原有的 URL 路径，也方便后续的更新和版本迭代。

```bash
temp/files
├── get.helm.sh
│   └── helm-v3.5.4-linux-amd64.tar.gz
├── github.com
│   ├── containerd
│   │   └── nerdctl
│   │       └── releases
│   │           └── download
│   │               └── v0.8.0
│   │                   └── nerdctl-0.8.0-linux-amd64.tar.gz
│   ├── containernetworking
│   │   └── plugins
│   │       └── releases
│   │           └── download
│   │               └── v0.9.1
│   │                   └── cni-plugins-linux-amd64-v0.9.1.tgz
│   ├── containers
│   │   └── crun
│   │       └── releases
│   │           └── download
│   │               └── 0.19
│   │                   └── crun-0.19-linux-amd64
│   ├── coreos
│   │   └── etcd
│   │       └── releases
│   │           └── download
│   │               └── v3.4.13
│   │                   └── etcd-v3.4.13-linux-amd64.tar.gz
│   ├── kata-containers
│   │   └── runtime
│   │       └── releases
│   │           └── download
│   │               └── 1.12.1
│   │                   └── kata-static-1.12.1-x86_64.tar.xz
│   ├── kubernetes-sigs
│   │   └── cri-tools
│   │       └── releases
│   │           └── download
│   │               └── v1.20.0
│   │                   └── crictl-v1.20.0-linux-amd64.tar.gz
│   └── projectcalico
│       ├── calico
│       │   └── archive
│       │       └── v3.17.3.tar.gz
│       └── calicoctl
│           └── releases
│               └── download
│                   └── v3.17.3
│                       └── calicoctl-linux-amd64
└── storage.googleapis.com
    └── kubernetes-release
        └── release
            └── v1.20.6
                └── bin
                    └── linux
                        └── amd64
                            ├── kubeadm
                            ├── kubectl
                            └── kubelet
```

### 获取部署需要的镜像

对于离线部署，kubespray 支持的并不是很友好。比如获取部署需要的镜像列表，目前的方案是需要先部署一个集群，然后通过 kubectl get 一些资源来获取 pod 使用到的镜像。个人觉得这个方式可以修改一下，比如通过 kubespray 源码来生成一个镜像列表。下面只是简单生成一个镜像列表，内容如下

- images.list

```bash
docker.io/nginx:1.19.0
docker.io/calico/cni:v3.17.3
docker.io/calico/node:v3.17.3
docker.io/calico/kube-controllers:v3.17.3
quay.io/coreos/flannel:v0.13.0
quay.io/coreos/flannel:v0.13.0-amd64
k8s.gcr.io/pause:3.2
k8s.gcr.io/coredns:1.7.0
k8s.gcr.io/kube-apiserver:v1.20.6
k8s.gcr.io/kube-controller-manager:v1.20.6
k8s.gcr.io/kube-proxy:v1.20.6
k8s.gcr.io/kube-scheduler:v1.20.6
k8s.gcr.io/dns/k8s-dns-node-cache:1.17.1
k8s.gcr.io/cpa/cluster-proportional-autoscaler-amd64:1.8.3
```

由于 master 分支的代码一直在更新，当前的 master 分支的版本可能和这里的不太一样，需要修改为自己需要的版本。

- 根据上面的镜像列表，使用 skopeo 将镜像同步到自己的镜像仓库中，如我的 `hub.k8s.li`

```bash
for image in $(cat images.list); do skopeo copy docker://${image} docker://hub.k8s.li/${image#*/}; done
```

同步到我的镜像仓库中，内容就如下，在部署的时候通过修改一些镜像仓库的地址即可

```bash
hub.k8s.li/nginx:1.19.0
hub.k8s.li/calico/cni:v3.17.3
hub.k8s.li/calico/node:v3.17.3
hub.k8s.li/calico/kube-controllers:v3.17.3
hub.k8s.li/coreos/flannel:v0.13.0
hub.k8s.li/coreos/flannel:v0.13.0-amd64
hub.k8s.li/pause:3.2
hub.k8s.li/coredns:1.7.0
hub.k8s.li/kube-apiserver:v1.20.6
hub.k8s.li/kube-controller-manager:v1.20.6
hub.k8s.li/kube-proxy:v1.20.6
hub.k8s.li/kube-scheduler:v1.20.6
hub.k8s.li/dns/k8s-dns-node-cache:1.17.1
hub.k8s.li/cpa/cluster-proportional-autoscaler-amd64:1.8.3
```

至此准备工作大致都已经完成了，接下来开始配置 kubespray 的一些参数和 inventory 文件

## 配置

按照 kubespray 文档说明，将 `inventory/sample` 目录复制一份，然后通过修改里面的参数来控制部署。

```bash
root@debian:/root/kubespray git:(master*) # cp -rf inventory/sample deploy
```

### inventory

- `deploy/inventory`

创建主机 inventory 文件，格式如下：

```ini
[all:vars]
ansible_port=22
ansible_user=root

ansible_ssh_private_key_file=/kubespray/.ssh/id_rsa

[all]
kube-control-1 ansible_host=192.168.4.11
kube-control-2 ansible_host=192.168.4.12
kube-control-3 ansible_host=192.168.4.13
kube-node-1 ansible_host=192.168.4.4

[kube_control_plane]
kube-control-1
kube-control-2
kube-control-3

[etcd]
kube-control-1
kube-control-2
kube-control-3

[kube-node]
kube-control-1
kube-control-2
kube-control-3
kube-node-1

[calico-rr]

[k8s-cluster:children]
kube_control_plane
kube-node
calico-rr
```

- ssh 互信

Kubespray 用到了 ansible 的 [synchronize](https://docs.ansible.com/ansible/latest/collections/ansible/posix/synchronize_module.html) 模块来分发文件，基于 rsync 协议所以必须要使用 ssh 密钥对来连接集群节点。inventory 配置的是 kubespray 容器内的路径，因此需要将 ssh 公钥和私钥复制到 repo 的 .ssh 目录下。如果节点就没有进行 ssh 免密登录，可以用 ansible 的 authorized_key 模块将 ssh 公钥添加到主机的 authorized_key 中。操作步骤如下：

```bash
root@debian:/root/kubespray git:(master*) # mkdir -p .ssh

# 生成 ssh 密钥对
root@debian:/root/kubespray git:(master*) # ssh-keygen -t rsa -f .ssh/id_rsa -P ""

# 将 ssh 公钥添加到所有主机
root@debian:/root/kubespray git:(master*) # ansible -i deploy/inventory all -m authorized_key -a "user={{ ansible_user }} key='{{ lookup('file', '{{ ssh_cert_path }}') }}'" -e ssh_cert_path=./.ssh/id_rsa.pub -e ansible_ssh_pass=passwd
```

### vars

创建并修改以下配置文件

- `deploy/env.yml`

```yml
---
# 定义一些组件的版本
kube_version: v1.20.6
calico_version: "v3.17.3"
pod_infra_version: "3.2"
nginx_image_version: "1.19"
coredns_version: "1.7.0"
image_arch: "amd64"

# docker registry domain
registry_domain: "hub.k8s.li"

# file download server url
download_url: "https://dl.k8s.li"

# docker-ce-repo mirrors
docker_mirrors_url: "https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux"

container_manager: "containerd"

# 由于使用的是 containerd 作为 CRI，目前 etcd 不支持 containerd 容器化部署因此需要将该参数修改为 host ，使用 systemd 来部署
etcd_deployment_type: host
etcd_cluster_setup: true
etcd_events_cluster_setup: true
etcd_events_cluster_enabled: true

# kubernetes CNI type 配置集群 CNI 使用的类型
kube_network_plugin: canal
```

- `deploy/group_vars/all/download.yml`

```yaml
## Container registry define
gcr_image_repo: "{{ registry_domain }}"
kube_image_repo: "{{ registry_domain }}"
docker_image_repo: "{{ registry_domain }}"
quay_image_repo: "{{ registry_domain }}"

# Download URLs
kubelet_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubelet"
kubectl_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kube_version }}/bin/linux/{{ image_arch }}/kubectl"
kubeadm_download_url: "{{ download_url }}/storage.googleapis.com/kubernetes-release/release/{{ kubeadm_version }}/bin/linux/{{ image_arch }}/kubeadm"
etcd_download_url: "{{ download_url }}/github.com/coreos/etcd/releases/download/{{ etcd_version }}/etcd-{{ etcd_version }}-linux-{{ image_arch }}.tar.gz"
cni_download_url: "{{ download_url }}/github.com/containernetworking/plugins/releases/download/{{ cni_version }}/cni-plugins-linux-{{ image_arch }}-{{ cni_version }}.tgz"
calicoctl_download_url: "{{ download_url }}/github.com/projectcalico/calicoctl/releases/download/{{ calico_ctl_version }}/calicoctl-linux-{{ image_arch }}"
calico_crds_download_url: "{{ download_url }}/github.com/projectcalico/calico/archive/{{ calico_version }}.tar.gz"
crictl_download_url: "{{ download_url }}/github.com/kubernetes-sigs/cri-tools/releases/download/{{ crictl_version }}/crictl-{{ crictl_version }}-{{ ansible_system | lower }}-{{ image_arch }}.tar.gz"
helm_download_url: "{{ download_url }}/get.helm.sh/helm-{{ helm_version }}-linux-{{ image_arch }}.tar.gz"
crun_download_url: "{{ download_url }}/github.com/containers/crun/releases/download/{{ crun_version }}/crun-{{ crun_version }}-linux-{{ image_arch }}"
kata_containers_download_url: "{{ download_url }}/github.com/kata-containers/runtime/releases/download/{{ kata_containers_version }}/kata-static-{{ kata_containers_version }}-{{ ansible_architecture }}.tar.xz"
nerdctl_download_url: "{{ download_url }}/github.com/containerd/nerdctl/releases/download/v{{ nerdctl_version }}/nerdctl-{{ nerdctl_version }}-{{ ansible_system | lower }}-{{ image_arch }}.tar.gz"
```

### docker-ce mirrors

kubespray 安装 docker 或者 containerd 容器运行时，需要使用 docker-ce 的源，国内可以使用清华的镜像源。根据不同的 Linux 发行版，在 `deploy/group_vars/all/offline.yml` 文件中添加这些参数即可。其中 `docker_mirrors_url` 这个参数就是在 `env.yml` 里设置的参数。

- CentOS/Redhat

```bash
## CentOS/Redhat
### For EL7, base and extras repo must be available, for EL8, baseos and appstream
### By default we enable those repo automatically
# rhel_enable_repos: false
### Docker / Containerd
docker_rh_repo_base_url: "{{ docker_mirrors_url }}/centos/{{ ansible_distribution_major_version }}/{{ ansible_architecture }}/stable"
docker_rh_repo_gpgkey: "{{ docker_mirrors_url }}/centos/gpg"
```

- Fedora

```yaml
## Fedora
### Docker
docker_fedora_repo_base_url: "{{ docker_mirrors_url }}/fedora/{{ ansible_distribution_major_version }}/{{ ansible_architecture }}/stable"
docker_fedora_repo_gpgkey: "{{ docker_mirrors_url }}/fedora/gpg"
### Containerd
containerd_fedora_repo_base_url: "{{ docker_mirrors_url }}/fedora/{{ ansible_distribution_major_version }}/{{ ansible_architecture }}/stable"
containerd_fedora_repo_gpgkey: "{{ docker_mirrors_url }}/fedora/gpg"
```

- debian

```yaml
## Debian
### Docker
docker_debian_repo_base_url: "{{ docker_mirrors_url }}/debian"
docker_debian_repo_gpgkey: "{{ docker_mirrors_url }}/debian/gpg"
### Containerd
containerd_debian_repo_base_url: "{{ docker_mirrors_url }}/debian"
containerd_debian_repo_gpgkey: "{{ docker_mirrors_url }}/debian/gpg"
# containerd_debian_repo_repokey: 'YOURREPOKEY'
```

- ubuntu

```yaml
## Ubuntu
### Docker
docker_ubuntu_repo_base_url: "{{ docker_mirrors_url }}/ubuntu"
docker_ubuntu_repo_gpgkey: "{{ docker_mirrors_url }}/ubuntu/gpg"
### Containerd
containerd_ubuntu_repo_base_url: "{{ docker_mirrors_url }}/ubuntu"
containerd_ubuntu_repo_gpgkey: "{{ docker_mirrors_url }}/ubuntu/gpg"
```

## 部署

经过以上准备好配置工作之后，接下来可以开始正式部署了。在使用 ansible 进行部署的时候，个人倾向于在 kubespray 容器里进行操作，而非在本地开发机器上安装 python3 等环境。对于离线部署而言，提前构建好镜像，使用 docker 容器更为方便一些。

- 构建镜像

```bash
root@debian:/root/kubespray git:(master*) # docker build -t kubespray:v2.15.1-kube-v1.20.6 .
```

- 运行 kubespray 容器

```bash
root@debian:/root/kubespray git:(master*) # docker run --rm -it --net=host -v $PWD:/kubespray kubespray:v2.15.1-kube-v1.20.6 bash
```

- 测试主机是否连接正常

```bash
root@debian:/kubespray# ansible -i cluster/inventory all -m ping
kube-control-3 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
kube-control-1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
kube-node-1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
kube-control-2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
```

- 开始部署集群

```bash
root@debian:/kubespray# ansible-playbook -i deploy/inventory -e "@deploy/env.yml" cluster.yml
```

- 部署完成日志如下，当 failed 都为 0 时说明 tasks 都已经成功跑完了

```bash
PLAY RECAP ******************************************************************
kube-control-1             : ok=526  changed=67   unreachable=0    failed=0    skipped=978  rescued=0    ignored=0
kube-control-2             : ok=524  changed=66   unreachable=0    failed=0    skipped=980  rescued=0    ignored=0
kube-control-3             : ok=593  changed=76   unreachable=0    failed=0    skipped=1125 rescued=0    ignored=1
kube-node-1                : ok=366  changed=34   unreachable=0    failed=0    skipped=628  rescued=0    ignored=0
localhost                  : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

Wednesday 28 April 2021  10:57:57 +0000 (0:00:00.115)       0:15:21.190 *******
===============================================================================
kubernetes/control-plane : kubeadm | Initialize first master -------------- 65.88s
kubernetes/control-plane : Joining control plane node to the cluster. ----- 50.05s
kubernetes/kubeadm : Join to cluster -------------------------------------- 31.54s
download_container | Download image if required --------------------------- 24.38s
reload etcd --------------------------------------------------------------- 20.56s
Gen_certs | Write etcd member and admin certs to other etcd nodes --------- 19.32s
Gen_certs | Write node certs to other etcd nodes -------------------------- 19.14s
Gen_certs | Write etcd member and admin certs to other etcd nodes --------- 17.45s
network_plugin/canal : Canal | Create canal node manifests ---------------- 15.41s
kubernetes-apps/ansible : Kubernetes Apps | Lay Down CoreDNS Template ----- 13.27s
kubernetes/control-plane : Master | wait for kube-scheduler --------------- 11.97s
download_container | Download image if required --------------------------- 11.76s
Gen_certs | Write node certs to other etcd nodes -------------------------- 10.50s
kubernetes-apps/ansible : Kubernetes Apps | Start Resources ---------------- 8.28s
policy_controller/calico : Create calico-kube-controllers manifests -------- 7.61s
kubernetes/control-plane : set kubeadm certificate key --------------------- 6.32s
download : extract_file | Unpacking archive -------------------------------- 5.51s
Configure | Check if etcd cluster is healthy ------------------------------- 5.41s
Configure | Check if etcd-events cluster is healthy ------------------------ 5.41s
kubernetes-apps/network_plugin/canal : Canal | Start Resources ------------- 4.85s
```

- 集群状态

```shell
[root@kube-control-1 ~]# kubectl get node -o wide
NAME             STATUS   ROLES                  AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION           CONTAINER-RUNTIME
kube-control-1   Ready    control-plane,master   5m24s   v1.20.6   192.168.4.11   <none>        CentOS Linux 7 (Core)   3.10.0-1160.el7.x86_64   containerd://1.4.4
kube-control-2   Ready    control-plane,master   5m40s   v1.20.6   192.168.4.12   <none>        CentOS Linux 7 (Core)   3.10.0-1160.el7.x86_64   containerd://1.4.4
kube-control-3   Ready    control-plane,master   6m28s   v1.20.6   192.168.4.13   <none>        CentOS Linux 7 (Core)   3.10.0-1160.el7.x86_64   containerd://1.4.4
kube-node-1      Ready    <none>                 3m53s   v1.20.6   192.168.4.14   <none>        CentOS Linux 7 (Core)   3.10.0-1160.el7.x86_64   containerd://1.4.4
```

- 集群组件状态

```bash
[root@kube-control-1 ~]# kubectl get all -n kube-system
NAME                                           READY   STATUS             RESTARTS   AGE
pod/calico-kube-controllers-67d6cdb559-cwf62   0/1     CrashLoopBackOff   5          4m10s
pod/canal-node-46x2b                           2/2     Running            0          4m25s
pod/canal-node-5rkhq                           2/2     Running            0          4m25s
pod/canal-node-fcsgn                           2/2     Running            0          4m25s
pod/canal-node-nhkp8                           2/2     Running            0          4m25s
pod/coredns-5d578c6f84-5nnp8                   1/1     Running            0          3m33s
pod/coredns-5d578c6f84-w2kvf                   1/1     Running            0          3m39s
pod/dns-autoscaler-6b675c8995-vp282            1/1     Running            0          3m34s
pod/kube-apiserver-kube-control-1              1/1     Running            0          6m51s
pod/kube-apiserver-kube-control-2              1/1     Running            0          7m7s
pod/kube-apiserver-kube-control-3              1/1     Running            0          7m41s
pod/kube-controller-manager-kube-control-1     1/1     Running            0          6m52s
pod/kube-controller-manager-kube-control-2     1/1     Running            0          7m7s
pod/kube-controller-manager-kube-control-3     1/1     Running            0          7m41s
pod/kube-proxy-5dfx8                           1/1     Running            0          5m17s
pod/kube-proxy-fvrqk                           1/1     Running            0          5m17s
pod/kube-proxy-jd84p                           1/1     Running            0          5m17s
pod/kube-proxy-l2mjk                           1/1     Running            0          5m17s
pod/kube-scheduler-kube-control-1              1/1     Running            0          6m51s
pod/kube-scheduler-kube-control-2              1/1     Running            0          7m7s
pod/kube-scheduler-kube-control-3              1/1     Running            0          7m41s
pod/nginx-proxy-kube-node-1                    1/1     Running            0          5m20s
pod/nodelocaldns-77kq9                         1/1     Running            0          3m32s
pod/nodelocaldns-fn5pd                         1/1     Running            0          3m32s
pod/nodelocaldns-lfjzb                         1/1     Running            0          3m32s
pod/nodelocaldns-xnc6n                         1/1     Running            0          3m32s

NAME              TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
service/coredns   ClusterIP   10.233.0.3   <none>        53/UDP,53/TCP,9153/TCP   3m38s

NAME                          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/canal-node     4         4         4       4            4           <none>                   4m25s
daemonset.apps/kube-proxy     4         4         4       4            4           kubernetes.io/os=linux   7m53s
daemonset.apps/nodelocaldns   4         4         4       4            4           <none>                   3m32s

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/calico-kube-controllers   0/1     1            0           4m12s
deployment.apps/coredns                   2/2     2            2           3m39s
deployment.apps/dns-autoscaler            1/1     1            1           3m34s

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/calico-kube-controllers-67d6cdb559   1         1         0       4m12s
replicaset.apps/coredns-5d578c6f84                   2         2         2       3m39s
replicaset.apps/dns-autoscaler-6b675c8995            1         1         1       3m34s
```

## 吐槽

在国内这种十分糟糕的网络环境下，对于普通的开发者或者学生来讲，部署一个 kubernetes 集群是十分痛苦的事情，这也进一步阻碍了这门技术的普及和使用。也想起了几年前在一次 docker 技术分享时的 QA 问答：

> Q：如何摆脱网络的依赖来创建个 Docker 的 image 呢，我觉得这个是 Docker 用户自己的基本权利？

**A：这个基本权利我觉得还是要问 GFW ，国外的开发人员是非常难理解有些他们认为跟水电一样普及的基础设施在某些地方还是很困难的。**
