---
title: kubespray 部署常见问题和优化汇总
date: 2021-05-13
updated: 2021-05-13
slug:
categories: 技术
tag:
  - kubespray
  - kubernetes
copyright: true
comment: true
---

kubespray v2.16 版本即将发布，整理一下自己在使用 kubespray 过程中遇到的问题和一些优化建议。

## 二进制文件

在 kubespray 上游的 [#7561](https://github.com/kubernetes-sigs/kubespray/pull/7561)  PR 中实现了根据 kubespray 的源码生成需要的文件列表和镜像列表。只需要在 repo 的 `contrib/offline` 目录下执行 ` bash generate_list.sh` 就可以生成一个 files.list 和一个 images.list  文件。然后就可以根据这个文件来下载依赖的文件和镜像。如下

```bash
$ cd contrib/offline
$ bash generate_list.sh
$ tree temp
temp
├── files.list
├── generate.sh
└── images.list
```

- files.list 内容如下

```bash
$ cat temp/files.list
https://get.helm.sh/helm-v3.5.4-linux-amd64.tar.gz
https://github.com/containerd/nerdctl/releases/download/v0.8.0/nerdctl-0.8.0-linux-amd64.tar.gz
https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz
https://github.com/containers/crun/releases/download/0.19/crun-0.19-linux-amd64
https://github.com/coreos/etcd/releases/download/v3.4.13/etcd-v3.4.13-linux-amd64.tar.gz
https://github.com/kata-containers/runtime/releases/download/1.12.1/kata-static-1.12.1-x86_64.tar.xz
https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.20.0/crictl-v1.20.0-linux-amd64.tar.gz
https://github.com/kubernetes-sigs/krew/releases/download/v0.4.1/krew.tar.gz
https://github.com/projectcalico/calico/archive/v3.17.4.tar.gz
https://github.com/projectcalico/calicoctl/releases/download/v3.17.4/calicoctl-linux-amd64
https://storage.googleapis.com/kubernetes-release/release/v1.20.6/bin/linux/amd64/kubeadm
https://storage.googleapis.com/kubernetes-release/release/v1.20.6/bin/linux/amd64/kubectl
https://storage.googleapis.com/kubernetes-release/release/v1.20.6/bin/linux/amd64/kubelet
```

然后通过 wget 进行下载

```bash
$ wget -x -P temp/files -i temp/files.list
```

- 下载后的文件如下

```bash
 tree temp/files
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
│   │   ├── cri-tools
│   │   │   └── releases
│   │   │       └── download
│   │   │           └── v1.20.0
│   │   │               └── crictl-v1.20.0-linux-amd64.tar.gz
│   │   └── krew
│   │       └── releases
│   │           └── download
│   │               └── v0.4.1
│   │                   └── krew.tar.gz
│   └── projectcalico
│       ├── calico
│       │   └── archive
│       │       └── v3.17.4.tar.gz
│       └── calicoctl
│           └── releases
│               └── download
│                   └── v3.17.4
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

保持这个目录结构不变，把它们上传到自己的文件服务器上，然后再修改这个文件的下载参数，只需要在前面加上文件服务器的 URL 即可，比如我的配置：

```yaml
# Download URLs
download_url: "https://dl.k8s.li"
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

- images.list 是 kubespray 所有可能会用到的镜像，如下：

```bash
# cat temp/images.list
docker.io/amazon/aws-alb-ingress-controller:v1.1.9
docker.io/amazon/aws-ebs-csi-driver:v0.5.0
docker.io/cloudnativelabs/kube-router:v1.2.2
docker.io/integratedcloudnative/ovn4nfv-k8s-plugin:v1.1.0
docker.io/k8scloudprovider/cinder-csi-plugin:v1.20.0
docker.io/kubeovn/kube-ovn:v1.6.2
docker.io/kubernetesui/dashboard-amd64:v2.2.0
docker.io/kubernetesui/metrics-scraper:v1.0.6
docker.io/library/haproxy:2.3
docker.io/library/nginx:1.19
docker.io/library/registry:2.7.1
docker.io/nfvpe/multus:v3.7
docker.io/rancher/local-path-provisioner:v0.0.19
docker.io/weaveworks/weave-kube:2.8.1
docker.io/weaveworks/weave-npc:2.8.1
docker.io/xueshanf/install-socat:latest
k8s.gcr.io/addon-resizer:1.8.11
k8s.gcr.io/coredns:1.7.0
k8s.gcr.io/cpa/cluster-proportional-autoscaler-amd64:1.8.3
k8s.gcr.io/dns/k8s-dns-node-cache:1.17.1
k8s.gcr.io/ingress-nginx/controller:v0.43.0
k8s.gcr.io/kube-apiserver:v1.20.6
k8s.gcr.io/kube-controller-manager:v1.20.6
k8s.gcr.io/kube-proxy:v1.20.6
k8s.gcr.io/kube-registry-proxy:0.4
k8s.gcr.io/kube-scheduler:v1.20.6
k8s.gcr.io/metrics-server/metrics-server:v0.4.2
k8s.gcr.io/pause:3.3
quay.io/calico/cni:v3.17.4
quay.io/calico/kube-controllers:v3.17.4
quay.io/calico/node:v3.17.4
quay.io/calico/typha:v3.17.4
quay.io/cilium/cilium-init:2019-04-05
quay.io/cilium/cilium:v1.8.9
quay.io/cilium/operator:v1.8.9
quay.io/coreos/etcd:v3.4.13
quay.io/coreos/flannel:v0.13.0-amd64
quay.io/datawire/ambassador-operator:v1.2.9
quay.io/external_storage/cephfs-provisioner:v2.1.0-k8s1.11
quay.io/external_storage/local-volume-provisioner:v2.3.4
quay.io/external_storage/rbd-provisioner:v2.1.1-k8s1.11
quay.io/jetstack/cert-manager-cainjector:v1.0.4
quay.io/jetstack/cert-manager-controller:v1.0.4
quay.io/jetstack/cert-manager-webhook:v1.0.4
quay.io/k8scsi/csi-attacher:v2.2.0
quay.io/k8scsi/csi-node-driver-registrar:v1.3.0
quay.io/k8scsi/csi-provisioner:v1.6.0
quay.io/k8scsi/csi-resizer:v0.5.0
quay.io/k8scsi/csi-snapshotter:v2.1.1
quay.io/k8scsi/snapshot-controller:v2.0.1
quay.io/l23network/k8s-netchecker-agent:v1.0
quay.io/l23network/k8s-netchecker-server:v1.0
```

可使用 skopeo 将镜像同步到自己的 registry 中，如下：

```bash
for image in $(cat temp/images.list); do skopeo copy docker://${image} docker://hub.k8s.li/${image#*/}; done
```

> 当时写这个脚本的时候一堆蛇皮 sed 替换操作写得想 🤮，比如有些变量会有 ansible 的 if else 判断，这就意味着也要用 shell 去实现它的判断逻辑。比如使用 shell 处理的时候需要将这下面坨转换成 shell 的 if else，而且还不能换行：

```yaml
coredns_image_repo: "{{ kube_image_repo }}{{'/coredns/coredns' if (coredns_image_is_namespaced | bool) else '/coredns' }}"
coredns_image_tag: "{{ coredns_version if (coredns_image_is_namespaced | bool) else (coredns_version | regex_replace('^v', '')) }}"
```

```bash
# special handling for https://github.com/kubernetes-sigs/kubespray/pull/7570
sed -i 's#^coredns_image_repo=.*#coredns_image_repo=${kube_image_repo}$(if printf "%s\\n%s\\n" v1.21 ${kube_version%.*} | sort --check=quiet --version-sort; then echo -n /coredns/coredns;else echo -n /coredns; fi)#' ${TEMP_DIR}/generate.sh

sed -i 's#^coredns_image_tag=.*#coredns_image_tag=$(if printf "%s\\n%s\\n" v1.21 ${kube_version%.*} | sort --check=quiet --version-sort; then echo -n ${coredns_version};else echo -n ${coredns_version/v/}; fi)#' ${TEMP_DIR}/generate.sh
```

当时还学会了一手，在 shell 中使用 `printf "%s\\n%s\\n" $v1 $v2 | sort --check=quiet --version-sort` 这种方式可以判断两个版本号的大小，而且是最简单便捷的。

## 镜像仓库

之前提到的是根据镜像列表将需要的镜像同步到自己的 registry 中，但对于本地开发测试来讲，这种手动导入比较费事费力。在看了大佬写的 [Docker 镜像加速教程](https://fuckcloudnative.io/posts/docker-registry-proxy/) 和 [如何搭建一个私有的镜像仓库 mirror](https://www.chenshaowen.com/blog/how-to-run-a-private-registry-mirror.html)  就想到了可以使用 docker registry 的 proxy 特性来部署几个 kubespray 需要的镜像仓库。如下

| origin     | mirror      |
| ---------- | ----------- |
| docker.io  | hub.k8s.li  |
| k8s.gcr.io | gcr.k8s.li  |
| quay.io    | quay.k8s.li |

- config.yml

```yml
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
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
```

- docker-compose.yml

```yml
version: '3'
services:
  gcr-registry:
    image: registry:2
    container_name: gcr-registry
    restart: always
    volumes:
      - ./config.yml:/etc/docker/registry/config.yml
    ports:
      - 127.0.0.1:5001:5001
    environment:
      - REGISTRY_HTTP_ADDR=0.0.0.0:5001
      - REGISTRY_PROXY_REMOTEURL=https://k8s.gcr.io

  hub-registry:
    image: registry:2
    container_name: hub-registry
    restart: always
    volumes:
      - ./config.yml:/etc/docker/registry/config.yml
    ports:
      - 127.0.0.1:5002:5002
    environment:
      - REGISTRY_HTTP_ADDR=0.0.0.0:5002
      - REGISTRY_PROXY_REMOTEURL=https://docker.io

  quay-registry:
    image: registry:2
    container_name: quay-registry
    restart: always
    volumes:
      - ./config.yml:/etc/docker/registry/config.yml
    ports:
      - 127.0.0.1:5003:5003
    environment:
      - REGISTRY_HTTP_ADDR=0.0.0.0:5003
      - REGISTRY_PROXY_REMOTEURL=https://quay.io
```

- nginx.conf

```nginx
server {
    listen       443 ssl;
    listen       [::]:443;
    server_name  gcr.k8s.li;
    ssl_certificate domain.crt;
    ssl_certificate_key domain.key;
    gzip_static on;
    client_max_body_size 100000m;
    if ($request_method !~* GET|HEAD) {
         return 403;
    }
    location / {
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass   http://localhost:5001;
    }
}

server {
    listen       443 ssl;
    listen       [::]:443;
    server_name  hub.k8s.li;
    ssl_certificate domain.crt;
    ssl_certificate_key domain.key;
    gzip_static on;
    client_max_body_size 100000m;
    if ($request_method !~* GET|HEAD) {
         return 403;
    }
    location / {
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass   http://localhost:5002;
    }
}

server {
    listen       443 ssl;
    listen       [::]:443;
    server_name  quay.k8s.li;
    ssl_certificate domain.crt;
    ssl_certificate_key domain.key;
    gzip_static on;
    client_max_body_size 100000m;
    if ($request_method !~* GET|HEAD) {
         return 403;
    }
    location / {
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass   http://localhost:5003;
    }
}
```

相关配置文件在 [registry-mirrors](https://github.com/muzi502/registry-mirrors) 这个 repo 中。

## 优化 kubespray 镜像大小

kubespray v1.25.1 版本官方构建的镜像大小为 `1.41GB`，对于一些场景下希望镜像小一些，可以通过如下方法构建一个体积较小的镜像。

- 首先构建一个 base 镜像，对于不经常变动的我们把它封装在一个 base 镜像里，只有当相关依赖更新了才需要重新构建这个 base 镜像，`Dockerfile.base` 如下：

```Dockerfile
FROM python:3.6-slim
ENV KUBE_VERSION v1.20.6

RUN apt update -y \
 && apt install -y \
 libssl-dev sshpass apt-transport-https jq moreutils vim moreutils iputils-ping \
 ca-certificates curl gnupg2 software-properties-common rsync wget tcpdump \
 && rm -rf /var/lib/apt/lists/* \
 && wget -q https://dl.k8s.io/$KUBE_VERSION/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl \
 && chmod a+x /usr/local/bin/kubectl

WORKDIR /kubespray
COPY . .
RUN python3 -m pip install -r requirements.txt
```

构建 kubespray 镜像：FROM 的 base 镜像就使用我们刚刚构建好的镜像，对于 kubespray 来讲，相关依赖已经在 base 镜像中安装好了，这里构建的时候只需要把 repo 复制到 /kubespray 目录下即可，如下：

```Dockerfile
FROM kubespray:v2.16.0-base-kube-v1.20.6
COPY . /kubespray
```

这样构建出来的镜像大小不到 600MB，比之前小了很多，而且每次构建镜像的时候也比较快。只不过当 `requirements.txt`  文件更新后需要重新构建 base 镜像，并修改 kubespray 的 FROM 镜像为新的 base 镜像。

```shell
kubespray     v2.15.1                  73294562105a    1.41GB
kubespray     v2.16-kube-v1.20.6-1.0   80b735995e48    579MB
```

- kubespray 默认没有加如 `.dockerignore`，这就意味着构建镜像的时候会把当前目录下的所有内容复制到镜像里，会导致镜像工作目录下可能很混乱，在容器里 debug 的时候不太美观，强迫症患者可以在 repo 中加入如下的 `.dockerignore` 文件。

```bash
.ansible-lint
.editorconfig
.git
.github
.gitignore
.gitlab-ci
.gitlab-ci.yml
.gitmodules
.markdownlint.yaml
.nojekyll
CNAME
CONTRIBUTING.md
Dockerfile
Makefile
OWNERS
README.md
RELEASE.md
SECURITY_CONTACTS
build
code-of-conduct.md
docs
index.html
logo
```

## docker registry 禁止 push 镜像

默认直接使用 docker registry 来部署镜像仓库的话，比如我的 hub.k8s.li ，因为没有权限限制会导致任何可访问该镜像仓库的客户端可以 push 镜像，这有点不安全，需要安全加固一下。因为 pull 镜像的时候客户端走的都是 HTTP GET 请求，可以通过 nginx 禁止 POST、PUT 这种请求方法，这样就可以禁止 push 镜像。在 nginx 的 server 字段中添加如下内容：

```nginx
server {
    if ($request_method !~* GET) {
         return 403;
    }
}
```

这样在 push 镜像的时候会返回 403 的错误

```shell
root@debian:/root # docker pull hub.k8s.li/calico/node:v3.17.3
v3.17.3: Pulling from calico/node
282bf12aa8be: Pull complete
4ac1bb9354ad: Pull complete
Digest: sha256:3595a9a945a7ba346a12ee523fc7ae15ed35f1e6282b76bce7fec474d28d68bb
Status: Downloaded newer image for hub.k8s.li/calico/node:v3.17.3
root@debian:/root # docker push !$
root@debian:/root # docker push hub.k8s.li/calico/node:v3.17.3
The push refers to repository [hub.k8s.li/calico/node]
bc19ae092bb4: Preparing
94333d52d45d: Preparing
error parsing HTTP 403 response body: invalid character '<' looking for beginning of value: "<html>\r\n<head><title>403 Forbidden</title></head>\r\n<body bgcolor=\"white\">\r\n<center><h1>403 Forbidden</h1></center>\r\n<hr><center>nginx</center>\r\n</body>\r\n</html>\r\n"
```

那么需要 push 镜像的时候怎么办？

docker registry 启动的时候 bind 在 127.0.0.1 上，而不是 0.0.0.0，通过 localhost:5000 来 push 镜像。

## 镜像仓库自签证书

如果镜像仓库使用的是自签证书，可以跑下面这个 playbook 将自签证书添加到所有节点的 trusted CA dir 中，这样无需配置 `insecure-registries` 也能拉取镜像。

`add-registry-ca.yml`

```yml
---
- hosts: all
  gather_facts: False
  tasks:
    - name: Gen_certs | target ca-certificate store file
      set_fact:
        ca_cert_path: |-
          {% if ansible_os_family == "Debian" -%}
          /usr/local/share/ca-certificates/registry-ca.crt
          {%- elif ansible_os_family == "RedHat" -%}
          /etc/pki/ca-trust/source/anchors/registry-ca.crt
          {%- elif ansible_os_family in ["Flatcar Container Linux by Kinvolk"] -%}
          /etc/ssl/certs/registry-ca.pem
          {%- elif ansible_os_family == "Suse" -%}
          /etc/pki/trust/anchors/registry-ca.pem
          {%- elif ansible_os_family == "ClearLinux" -%}
          /usr/share/ca-certs/registry-ca.pem
          {%- endif %}
      tags:
        - facts

    - name: Gen_certs | add CA to trusted CA dir
      copy:
        src: "{{ registry_cert_path }}"
        dest: "{{ ca_cert_path }}"
      register: registry_ca_cert

    - name: Gen_certs | update ca-certificates (Debian/Ubuntu/SUSE/Flatcar)  # noqa 503
      command: update-ca-certificates
      when: registry_ca_cert.changed and ansible_os_family in ["Debian", "Flatcar Container Linux by Kinvolk", "Suse"]

    - name: Gen_certs | update ca-certificates (RedHat)  # noqa 503
      command: update-ca-trust extract
      when: registry_ca_cert.changed and ansible_os_family == "RedHat"

    - name: Gen_certs | update ca-certificates (ClearLinux)  # noqa 503
      command: clrtrust add "{{ ca_cert_path }}"
      when: registry_ca_cert.changed and ansible_os_family == "ClearLinux"
```

- 将自签的 registry 证书放到本地，执行 playbook 并指定 `registry_cert_path` 为正确的路径

```shell
root@debian:/kubespray# ansible-playbook -i deploy/inventory -e registry_cert_path=/kubespray/registry_ca.pem add-registry-ca.yml

PLAY [all] **********************************************************************************
Thursday 29 April 2021  08:18:25 +0000 (0:00:00.077)       0:00:00.077 ********

TASK [Gen_certs | target ca-certificate store file] *****************************************
ok: [kube-control-2]
ok: [kube-control-3]
ok: [kube-control-1]
ok: [kube-node-1]
Thursday 29 April 2021  08:18:25 +0000 (0:00:00.389)       0:00:00.467 ********

TASK [Gen_certs | add CA to trusted CA dir] *************************************************
changed: [kube-control-2]
changed: [kube-control-3]
changed: [kube-control-1]
changed: [kube-node-1]
Thursday 29 April 2021  08:18:29 +0000 (0:00:04.433)       0:00:04.901 ********
Thursday 29 April 2021  08:18:30 +0000 (0:00:00.358)       0:00:05.259 ********

TASK [Gen_certs | update ca-certificates (RedHat)] ******************************************
changed: [kube-control-1]
changed: [kube-control-3]
changed: [kube-control-2]
changed: [kube-node-1]
Thursday 29 April 2021  08:18:33 +0000 (0:00:02.938)       0:00:08.197 ********

PLAY RECAP **********************************************************************************
kube-control-1             : ok=3    changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
kube-control-2             : ok=3    changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
kube-control-3             : ok=3    changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
kube-node-1                : ok=3    changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0

Thursday 29 April 2021  08:18:33 +0000 (0:00:00.355)  0:00:08.553 ********
================================================================
Gen_certs | add CA to trusted CA dir ------------------------------------------------------------- 4.43s
Gen_certs | update ca-certificates (RedHat) ------------------------------------------------------------- 2.94s
Gen_certs | target ca-certificate store file ------------------------------------------------------------- 0.39s
Gen_certs | update ca-certificates (Debian/Ubuntu/SUSE/Flatcar) ------------------------------------------------------------- 0.36s
Gen_certs | update ca-certificates (ClearLinux) -------------------------------------------------------------- 0.36s
```

## containerd 无法加载 CNI 配置导致节点 NotReady

偶现问题，重启一下 containerd 就可以了，具体原因还没排查出来

```bash
root@debian:/kubespray# ansible all -i deploy/inventory -m service -a "name=containerd state=restarted"
```

## 优化部署速度

Kubespray 部署的时候有个 task 专门用来下载部署需要的镜像，由于是操作的所有节点，会将一些不需要的镜像拉取到该节点上。比如 kube-apiserver、kube-controller-manager、kube-scheduler 这些在 node 节点上不会用到的镜像也会在 node 节点上拉取，这样会导致 download 的 task 比较耗时。

```bash
TASK [download : set_container_facts | Display the name of the image being processed] ********************************************************************************************
ok: [kube-control-3] => {
    "msg": "gcr.k8s.li/kube-controller-manager"
}
ok: [kube-control-2] => {
    "msg": "gcr.k8s.li/kube-controller-manager"
}
ok: [kube-control-1] => {
    "msg": "gcr.k8s.li/kube-controller-manager"
}
ok: [kube-node-1] => {
    "msg": "gcr.k8s.li/kube-controller-manager"
}

ok: [kube-control-3] => {
    "msg": "gcr.k8s.li/kube-scheduler"
}
ok: [kube-control-2] => {
    "msg": "gcr.k8s.li/kube-scheduler"
}
ok: [kube-control-1] => {
    "msg": "gcr.k8s.li/kube-scheduler"
}
ok: [kube-node-1] => {
    "msg": "gcr.k8s.li/kube-scheduler"
```

可用通过 `download_container: false` 这个参数来禁用 download container 这个 task，这样在 pod 启动的时候只拉取需要的镜像，可以节省一些部署耗时。

## 启用插件

Kubespray 官方支持的插件列表如下，默认是 false 禁用了插件。

```yaml
# Kubernetes dashboard
# RBAC required. see docs/getting-started.md for access details.
dashboard_enabled: false

# Addons which can be enabled
helm_enabled: false
krew_enabled: false
registry_enabled: false
metrics_server_enabled: false
enable_network_policy: true
local_path_provisioner_enabled: false
local_volume_provisioner_enabled: false
local_volume_provisioner_directory_mode: 0700
cinder_csi_enabled: false
aws_ebs_csi_enabled: false
azure_csi_enabled: false
gcp_pd_csi_enabled: false
vsphere_csi_enabled: false
persistent_volumes_enabled: false
cephfs_provisioner_enabled: false
rbd_provisioner_enabled: false
ingress_nginx_enabled: false
ingress_ambassador_enabled: false
ingress_alb_enabled: false
cert_manager_enabled: false
expand_persistent_volumes: false
metallb_enabled: false

# containerd official CLI tool
nerdctl_enabled: false
```

在部署的时候如果想启动某些插件可以在自己本地对应的 inventory 目录下的 `group_vars/k8s_cluster/addons.yml` 文件中选择开启相应的插件，比如 `inventory/sample/group_vars/k8s_cluster/addons.yml`。

## 分层部署

这个是我们对 kubespray 二开的一个优化项。kubespray 在部署集群的时候运行的 playbook 是 `cluster.yml`，在集群部署的过程中可能会因为你一些不稳定因素导致集群部署失败，失败后再次尝试部署的话，kubespray 会从头开始再跑一遍已经成功运行的 task，这样的效率会比较低。因此需要使用某种方法记录一下已经成功执行的 task 或 roles，失败后重新部署的时候就跳过这些已经成功运行的 task，然后从上次失败的地方开始运行。

大体的思路是根据 `cluster.yml` 中的 roles 拆分为不同的层即 layer，如 bootstrap-os、download、kubernetes、network、apps ，在部署的过程中每运行完一个 layer 就将它记录在一个文件中，部署的时候会根据这个文件来判断是否需要部署，如果文件中记录存在的话就说明已经成功部署完成了，就跳过它，继续执行未执行的 layer。

至于拆分的方式大概有两种，一种是根据 tag 、一种是将 `cluster.yml` 文件拆分成若干个 playbook 文件。通过 tag 的方式可能会比较复杂一些，在这里还是选择拆分的方式。拆分的粒度有大有小，以下是我认为比较合理的拆封方式：

```bash
playbooks
├── 00-default-ssh-config.yml # 默认需要运行的 playbook，用于配置堡垒机和配置 ssh 认证
├── 01-cluster-bootstrap-os.yml # 初始化集群节点 OS，安装容器运行时，下载部署依赖的文件
├── 02-cluster-etcd.yml # 部署 etcd 集群
├── 03-cluster-kubernetes.yml # 部署 kubernetes 集群
├── 04-cluster-network.yml # 部署网络插件
├── 05-cluster-apps.yml # 部署一些 addons 组件，如 coredns 等
├── 06-cluster-self-host.yml # 平台 self-host 自托管的部分
└── 11-reset-reset.yml # 移除集群
```

- 00-default-ssh-config.yml

该 playbook 用于配置堡垒机和 ssh 认证，kubespray 需要使用  public key 的方式 ssh 连接到部署节点，如果部署节点没有配置 ssh public key 的方式，可以指定 `ssh_cert_path` 这个变量的路径，将公钥添加到主机的 authorized_key 中。

```yaml
---
- hosts: bastion[0]
  gather_facts: False
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: bastion-ssh-config, tags: ["localhost", "bastion"] }

- hosts: k8s_cluster:etcd
  gather_facts: False
  tasks:
    - name: Setting up ssh public key authentication
      authorized_key: "user={{ ansible_user }} key={{ lookup('file', '{{ ssh_cert_path }}') }}"
      when: ssh_cert_path is defined
  tags: ssh-config
```

- 01-cluster-bootstrap-os.yml

这个 playbook 用于初始化部署节点 OS、安装一些依赖的 rpm/deb 包、安装容器运行时、下载二进制文件等

```yaml
---
- name: Gather facts
  import_playbook: ../facts.yml

- hosts: k8s_cluster:etcd
  strategy: linear
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  gather_facts: false
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: bootstrap-os, tags: bootstrap-os}

- hosts: k8s_cluster:etcd
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: kubernetes/preinstall, tags: preinstall }
    - { role: "container-engine", tags: "container-engine", when: deploy_container_engine|default(true) }
    - { role: download, tags: download, when: "not skip_downloads" }
```

- 02-cluster-etcd.yml

这个主要是部署 etcd 集群和分发 etcd 集群的证书到集群节点。

```yaml
---
- name: Gather facts
  import_playbook: ../facts.yml

- hosts: etcd
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - role: etcd
      tags: etcd
      vars:
        etcd_cluster_setup: true
        etcd_events_cluster_setup: "{{ etcd_events_cluster_enabled }}"
      when: not etcd_kubeadm_enabled| default(false)

- hosts: k8s_cluster
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - role: etcd
      tags: etcd
      vars:
        etcd_cluster_setup: false
        etcd_events_cluster_setup: false
      when: not etcd_kubeadm_enabled| default(false)
```

- 03-cluster-kubernetes.yml

这个主要是部署 kubernetes 集群，虽然这里的 roles 很多，但并没有做过多的拆分，个人还是觉着这部分可以作为一个整体。

```yaml
---
- name: Gather facts
  import_playbook: ../facts.yml

- hosts: k8s_cluster
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: kubernetes/node, tags: node }

- hosts: kube_control_plane
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: kubernetes/control-plane, tags: master }
    - { role: kubernetes/client, tags: client }
    - { role: kubernetes-apps/cluster_roles, tags: cluster-roles }

- hosts: k8s_cluster
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: kubernetes/kubeadm, tags: kubeadm}
    - { role: kubernetes/node-label, tags: node-label }
```

- 04-cluster-network.yml

这个主要是部署网络插件

```yaml
---
- name: Gather facts
  import_playbook: ../facts.yml

- hosts: k8s_cluster
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: network_plugin, tags: network }

- hosts: kube_control_plane
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: kubernetes-apps/network_plugin, tags: network }
    - { role: kubernetes-apps/policy_controller, tags: policy-controller }
```

- 05-cluster-apps.yml

这个主要是部署一些 addons 插件，必须 coredns, ingress-controller，以及一些外置的 provisioner 等。

```yaml
---
- name: Gather facts
  import_playbook: ../facts.yml

- hosts: kube_control_plane
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: kubernetes-apps/external_cloud_controller, tags: external-cloud-controller }
    - { role: kubernetes-apps/ingress_controller, tags: ingress-controller }
    - { role: kubernetes-apps/external_provisioner, tags: external-provisioner }

- hosts: kube_control_plane
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: kubernetes-apps, tags: apps }
```

拆分的时候可以根据自己的实际情况去除一些不必要的 roles，比如 `calico_rr` , `win_nodes` ，我们的产品本身就不支持 calico 路由反射器、也不支持 windows 节点，因此直接将这两部分给去除了，这样也能避免去执行这些 task 的判断，能节省一定的时间。

```yaml
- hosts: calico_rr
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: network_plugin/calico/rr, tags: ['network', 'calico_rr'] }

- hosts: kube_control_plane[0]
  gather_facts: False
  any_errors_fatal: "{{ any_errors_fatal | default(true) }}"
  environment: "{{ proxy_disable_env }}"
  roles:
    - { role: kubespray-defaults }
    - { role: win_nodes/kubernetes_patch, tags: ["master", "win_nodes"] }
```
