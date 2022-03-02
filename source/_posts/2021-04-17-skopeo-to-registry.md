---
title: 如何使用 registry 存储的特性
date: 2021-04-17
updated: 2021-04-17
slug:
categories: 技术
tag:
  - registry
  - image
copyright: true
comment: true
---

## 苦命打包工具人 😭

目前在负责公司 PaaS toB 产品的打包发布工作（苦命发版 + 打包工具人 😣）。日常的一项工作就是跑完自动化打包流水线，再将打出来的安装包更新到 QA 测试环境中。因为打包环境和测试环境分布在两个不同的机房，产品的安装包需要跨公网从打包机器上同步到 QA 环境中，因此产品安装包的大小就决定着两者间同步的耗时。优化和减少产品安装包的大小就成为了提升流水线效率的途径之一。最近做的一项工作就是将产品补丁包的大小减少 30%～60%，大大节省了补丁包上传下载和安装的耗时，提升了产品打包流水线的效率。因此今天就总结一下从中学到的一点人生经验 👓。

## 再次优化

因为产品所有的组件都是容器化的形式部署的，所以产品的补丁包中最主要的就是镜像文件以及一些部署脚本，想要优化和见减小补丁包基本上等同于减小这些镜像的大小。众所周知 docker 镜像是由一层一层的 layer + 镜像的元数据信息构成的，其中镜像的元数据信息就是镜像的 image config + manifests，这些都是 json 格式的文本内容，相对于镜像的 layer 的大小，这些文本内容往往可以忽略不计。

其实去年的时候已经做过了一次优化，将补丁包镜像打包的方式由原来的 docker save 的方式替换成了 skopeo copy 到目录的方式，优化的效果就是：将补丁包的大小减少了 60%～80%；流水线的速度提升了 5 倍；补丁包安装速度也提升了 5 倍。这项优化的原理可以参考我之前的博客 [深入浅出容器镜像的一生](https://blog.k8s.li/Exploring-container-image.html)。虽然第一次已经有了这么明显的优化，但咱仍然觉得还有可以优化的空间。

经过第一次优化之后，产品补丁包中镜像存在的形式如下：

```bash
root@debian:/root/kube # tree images -h
images
├── [4.0K]  kube-apiserver:v1.20.5
│   ├── [707K]  742efefc8a44179dcc376b969cb5e3f8afff66f87ab618a15164638ad07bf722
│   ├── [ 28M]  98d681774b176bb2fd6b3499377d63ff4b1b040886dd9d3641bb93840815a1e7
│   ├── [2.6K]  d7e24aeb3b10210bf6a2dc39f77c1ea835b22af06dfd2933c06e0421ed6d35ac
│   ├── [642K]  fefd475334af8255ba693de12951b5176a2853c2f0d5d2b053e188a1f3b611d9
│   ├── [ 949]  manifest.json
│   └── [  33]  version
├── [4.0K]  kube-controller-manager:v1.20.5
│   ├── [ 27M]  454a7944c47b608efb657a1bef7f4093f63ceb2db14fd78c5ecd2a08333da7cf
│   ├── [2.6K]  6f0c3da8c99e99bbe82920a35653f286bd8130f0662884e77fa9fcdca079c07f
│   ├── [707K]  742efefc8a44179dcc376b969cb5e3f8afff66f87ab618a15164638ad07bf722
│   ├── [642K]  fefd475334af8255ba693de12951b5176a2853c2f0d5d2b053e188a1f3b611d9
│   ├── [ 949]  manifest.json
│   └── [  33]  version
└── [4.0K]  kube-scheduler:v1.20.5
    ├── [ 12M]  565677e452d17c4e2841250bbf0cc010d906fbf7877569bb2d69bfb4e68db1b5
    ├── [707K]  742efefc8a44179dcc376b969cb5e3f8afff66f87ab618a15164638ad07bf722
    ├── [2.6K]  8d13f1db8bfb498afb0caff6bf3f8c599ecc2ace74275f69886067f6af8ffdf6
    ├── [642K]  fefd475334af8255ba693de12951b5176a2853c2f0d5d2b053e188a1f3b611d9
    ├── [ 949]  manifest.json
    └── [  33]  version
```

仔细分析可以发现这样打包出来的镜像要比它们在 registry 中的所占存储空间要大一些，这是因为每一个镜像存储目录下都保存在该镜像的所有 layer ，不能像 registry 存储那样可以复用相同的 layer。比如 `kube-apiserver`  `kube-controller-manager` `kube-scheduler` 这三个镜像都是使用的 `k8s.gcr.io/build-image/go-runner` 这个 base 镜像。在 registry 中，它只需要存储一份 `go-runner` base 镜像即可。而使用 skopeo copy 存储在目录中时，就需要分别存储一份这个 base 镜像了。

从文件名和文件大小也可以大致推断出 `707K` 大小的 742efefc8a 就是 `go-runner` 镜像的根文件系统；`642K` 大小的 fefd47533 就是 go-runner 的二进制文件；`2.x` 左右大小的应该就是镜像的 image config 文件；剩下那个十几二十几 M 的就是  `kube-apiserver`  `kube-controller-manager` `kube-scheduler`  的二进制文件；manifest.json 文件就是镜像在 registry 存储中的 manifest 。

- 使用 find 来统计这些文件的数量，经过去重之后可以发现镜像的 layer 文件和 config 文件总数量从原来的 12 个减少到 8 个。做一个简单的加法计算也就是：3 个 image config 文件 + 3 个二进制文件 + 1 个 base 镜像 layer 文件 + 1 个 go-runner 二进制文件，这不正好就是 8 嘛 😂

```bash
root@debian:/root/kube # find images -type f | grep -Eo "\b[a-f0-9]{64}\b" | wc
12
root@debian:/root/kube # find images -type f | grep -Eo "\b[a-f0-9]{64}\b" | sort -u | wc -l
8
```

既然补丁包中的镜像文件有一些相同的 layer，那么去重这些相同的 layer 文件岂不就能减少补丁包的大小了？于是就拿了一个历史的补丁包测试一下。

```bash
root@debian:/root $ du -sh images
3.3G	images
root@debian:/root $ find images -type f ! -name 'version' ! -name 'manifest.json' | wc -l
279
root@debian:/root $ mkdir -p images2
root@debian:/root $ find images -type f -exec mv {} images2 \;
root@debian:/root $ du -sh images2
1.3G	images2
root@debian:/root $ $ find images2 -type f ! -name 'version' ! -name 'manifest.json' | wc -l
187
```

没有对比就没有伤害，经过测试之后发现：补丁包中镜像文件的总数量由原来的 279 个减小至 187 个，总大小从原来的 3.3G 减小到 1.3G，减小了 60%！当时兴奋得我拍案叫绝，如获珍宝。其实这得益于我们产品组件使用的 base 镜像基本上是相同的，因此可以去除掉很多相同的 base 镜像 layer 文件。

既然找到了减小补丁包中镜像大小的思路，那么只要找到一种方式来去重这些镜像 layer 就可以了。首先想到的就是使用 registry 存储：根据 registry 存储的特性，镜像在 registry 中是可以复用相同的 layer 的。所以大体的思路就是将这些补丁包中的镜像转换为 registry 存储的格式，在安装的时候再将 registry 存储的格式转换为 skopeo copy 支持的 dir 格式。

## 构建 skopeo dir 镜像存储

- 为了方便演示，需要找个合适的镜像列表，看了一下 [ks-installer](https://github.com/kubesphere/ks-installer) 项目中有个镜像列表，看样子比较合适那就用它吧 😃

```bash
root@debian:/root # curl -L -O https://github.com/kubesphere/ks-installer/releases/download/v3.0.0/images-list.txt
```

- 首先将镜像使用 skopeo sync 同步到本地目录，并统计一下镜像的大小和文件的数量

```bash
root@debian:/root # for img in $(cat cat images-list.txt | grep -v "#");do skopeo sync --insecure-policy --src docker --dest dir ${img} images; done

root@debian:/root # tree images -d -L 1
images
├── alpine:3.10.4
├── busybox:1.31.1
├── calico
├── coredns
├── csiplugin
├── docker:19.03
├── elastic
├── fluent
├── haproxy:2.0.4
├── istio
├── jaegertracing
├── java:openjdk-8-jre-alpine
├── jenkins
├── jimmidyson
├── joosthofman
├── kubesphere
├── minio
├── mirrorgooglecontainers
├── mysql:8.0.11
├── nginx:1.14-alpine
├── nginxdemos
├── openpitrix
├── osixia
├── perl:latest
├── prom
├── redis:5.0.5-alpine
└── wordpress:4.8-apache
```

- 使用 skopeo sync 将镜像同步到本地 images 目录后，统计可得所有镜像的大小为 11G、总的文件为 1264 个。

```bash
root@debian:/root # du -sh images
11G	images
root@debian:/root # find images -type f ! -name "version" | wc -l
1264
```

## 转换成 registry 存储目录

根据下图所示的 registry 存储结构，我们要将镜像的 layer、image config、manifests 这三种文件根据它们的 sha256 值存放到 blobs/sha256 目录下，然后再在 repositories 目录下创建相应 link 文件，这样就可以将镜像转换成 registry 存储的格式了。

![](https://p.k8s.li/registry-storage.jpeg)

为方便演示我们先以单个镜像为例，将 `images/alpine:3.10.4` 这个镜像在转换成 docker registry 存储目录的形式

```bash
root@debian:/root # tree -h images/alpine:3.10.4
images/alpine:3.10.4
└── [4.0K]  alpine:3.10.4
    ├── [2.7M]  4167d3e149762ea326c26fc2fd4e36fdeb7d4e639408ad30f37b8f25ac285a98
    ├── [1.5K]  af341ccd2df8b0e2d67cf8dd32e087bfda4e5756ebd1c76bbf3efa0dc246590e
    ├── [ 528]  manifest.json
    └── [  33]  version
```

根据镜像文件大小我们可以得知： `2.7M` 大小的 `4167d3e1497……` 文件就是镜像的 layer 文件，由于 alpine 是一个 base 镜像，该 layer 就是 alpine 的根文件系统；`1.5K` 大小的 `af341ccd2……` 显而易见就是镜像的 images config 文件；`manifest.json` 文件则是镜像在 registry 存储中的 manifest.json 文件。

- 先创建该镜像在 registry 存储中的目录结构

```bash
root@debian:/root # mkdir -p docker/registry/v2/{blobs/sha256,repositories/alpine}
root@debian:/root # tree docker
docker
└── registry
    └── v2
        ├── blobs
        │   └── sha256
        └── repositories
            └── alpine
```

- 构建镜像 layer 的 link 文件

```bash
grep -Eo "\b[a-f0-9]{64}\b" images/alpine:3.10.4/manifest.json | sort -u | xargs -L1 -I {} mkdir -p docker/registry/v2/repositories/alpine/_layers/sha256/{}

grep -Eo "\b[a-f0-9]{64}\b" images/alpine:3.10.4/manifest.json | sort -u | xargs -L1 -I {} sh -c "echo -n 'sha256:{}' > docker/registry/v2/repositories/alpine/_layers/sha256/{}/link"
```

- 构建镜像 tag 的 link 文件

```bash
manifests_sha256=$(sha256sum images/alpine:3.10.4/manifest.json | awk '{print $1}')
mkdir -p docker/registry/v2/repositories/alpine/_manifests/revisions/sha256/${manifests_sha256}
echo -n "sha256:${manifests_sha256}" > docker/registry/v2/repositories/alpine/_manifests/revisions/sha256/${manifests_sha256}/link

mkdir -p docker/registry/v2/repositories/alpine/_manifests/tags/3.10.4/index/sha256/${manifests_sha256}
echo -n "sha256:${manifests_sha256}" > docker/registry/v2/repositories/alpine/_manifests/tags/3.10.4/index/sha256/${manifests_sha256}/link

mkdir -p docker/registry/v2/repositories/alpine/_manifests/tags/3.10.4/current
echo -n "sha256:${manifests_sha256}" > docker/registry/v2/repositories/alpine/_manifests/tags/3.10.4/current/link
```

- 构建镜像的 blobs 目录

```bash
mkdir -p docker/registry/v2/blobs/sha256/${manifests_sha256:0:2}/${manifests_sha256}
ln -f images/alpine:3.10.4/manifest.json docker/registry/v2/blobs/sha256/${manifests_sha256:0:2}/${manifests_sha256}/data

for layer in $(grep -Eo "\b[a-f0-9]{64}\b" images/alpine:3.10.4/manifest.json); do
    mkdir -p docker/registry/v2/blobs/sha256/${layer:0:2}/${layer}
    ln -f  images/alpine:3.10.4/${layer} docker/registry/v2/blobs/sha256/${layer:0:2}/${layer}/data
done
```

- 最终得到的 registry 存储目录如下

```bash
docker
└── registry
    └── v2
        ├── blobs
        │   └── sha256
        │       ├── 41
        │       │   └── 4167d3e149762ea326c26fc2fd4e36fdeb7d4e639408ad30f37b8f25ac285a98
        │       │       └── data
        │       ├── af
        │       │   └── af341ccd2df8b0e2d67cf8dd32e087bfda4e5756ebd1c76bbf3efa0dc246590e
        │       │       └── data
        │       └── de
        │           └── de78803598bc4c940fc4591d412bffe488205d5d953f94751c6308deeaaa7eb8
        │               └── data
        └── repositories
            └── alpine
                ├── _layers
                │   └── sha256
                │       ├── 4167d3e149762ea326c26fc2fd4e36fdeb7d4e639408ad30f37b8f25ac285a98
                │       │   └── link
                │       └── af341ccd2df8b0e2d67cf8dd32e087bfda4e5756ebd1c76bbf3efa0dc246590e
                │           └── link
                └── _manifests
                    ├── revisions
                    │   └── sha256
                    │       └── de78803598bc4c940fc4591d412bffe488205d5d953f94751c6308deeaaa7eb8
                    │           └── link
                    └── tags
                        └── 3.10.4
                            ├── current
                            │   └── link
                            └── index
                                └── sha256
                                    └── de78803598bc4c940fc4591d412bffe488205d5d953f94751c6308deeaaa7eb8
                                        └── link
```

- 测试是否正常，本地 docker run 一个 registry 容器，将刚刚转换的 registry 存储目录挂载到容器的 /var/lib/registry，然后再使用 docker pull 的方式拉取镜像，在使用 docker run 测试一下能否正常使用。经过验证之后确实可以使用，那就说明这样的转换是没有问题的 😊。

```bash
root@debian:/root # docker pull localhost/alpine:3.10.4
3.10.4: Pulling from alpine
4167d3e14976: Pull complete
Digest: sha256:de78803598bc4c940fc4591d412bffe488205d5d953f94751c6308deeaaa7eb8
Status: Downloaded newer image for localhost/alpine:3.10.4
root@debian:/root # docker run --rm -it localhost/alpine:3.10.4 cat /etc/os-release
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.10.4
PRETTY_NAME="Alpine Linux v3.10"
HOME_URL="https://alpinelinux.org/"
BUG_REPORT_URL="https://bugs.alpinelinux.org/"
```

- 将上述步骤整合成一个 shell 脚本，内容如下

```bash
#!/bin/bash
set -eo pipefail

IMAGES_DIR="images"
REGISTRY_DIR="docker"

rm -rf ${REGISTRY_DIR}
BLOBS_PATH="${REGISTRY_DIR}/registry/v2/blobs"
REPO_PATH="${REGISTRY_DIR}/registry/v2/repositories"

for image in $(find ${IMAGES_DIR} -type f | sed -n 's|/manifest.json||p' | sort -u); do
    image_name=$(echo ${image%%:*} | sed "s|${IMAGES_DIR}/||g")
    image_tag=${image##*:}; mfs="${image}/manifest.json"
    mfs_sha256=$(sha256sum ${image}/manifest.json | awk '{print $1}')
    mkdir -p ${BLOBS_PATH}/sha256/${mfs_sha256:0:2}/${mfs_sha256}
    ln -f ${mfs} ${BLOBS_PATH}/sha256/${mfs_sha256:0:2}/${mfs_sha256}/data

    # make image repositories dir
    mkdir -p ${REPO_PATH}/${image_name}/{_layers,_manifests/revisions}/sha256
    mkdir -p ${REPO_PATH}/${image_name}/_manifests/revisions/sha256/${mfs_sha256}
    mkdir -p ${REPO_PATH}/${image_name}/_manifests/tags/${image_tag}/{current,index/sha256}
    mkdir -p ${REPO_PATH}/${image_name}/_manifests/tags/${image_tag}/index/sha256/${mfs_sha256}

    # create image tag manifest link file
    echo -n "sha256:${mfs_sha256}" > ${REPO_PATH}/${image_name}/_manifests/tags/${image_tag}/current/link
    echo -n "sha256:${mfs_sha256}" > ${REPO_PATH}/${image_name}/_manifests/revisions/sha256/${mfs_sha256}/link
    echo -n "sha256:${mfs_sha256}" > ${REPO_PATH}/${image_name}/_manifests/tags/${image_tag}/index/sha256/${mfs_sha256}/link

    # link image layers file to registry blobs file
    for layer in $(grep -Eo "\b[a-f0-9]{64}\b" ${mfs}); do
        mkdir -p ${BLOBS_PATH}/sha256/${layer:0:2}/${layer}
        mkdir -p ${REPO_PATH}/${image_name}/_layers/sha256/${layer}
        echo -n "sha256:${layer}" > ${REPO_PATH}/${image_name}/_layers/sha256/${layer}/link
        ln -f ${image}/${layer} ${BLOBS_PATH}/sha256/${layer:0:2}/${layer}/data
    done
done
```

- 使用该脚本对 images 中所有镜像进行一下转换，最终得到的 registry 存储大小为 8.3 G，比之前减少了 2.7G。

```bash
root@debian:/root # du -sh docker
8.3G	docker
root@debian:/root # find docker -type f -name "data" | wc -l
1046
```

## 再还原回 Dir 格式

经过上述步骤一番折腾之后，将补丁包中镜像文件的总大小的确实减少了很多，但同时又引入了另一个问题：skopeo 无法直接使用 registry 存储的格式。因此我们还需要再做一次转换，将镜像由 registry 存储的格式还原回 skopeo 所支持的 dir 格式。至于还原的原理和方法我在 [docker registry 迁移至 harbor](https://blog.k8s.li/docker-registry-to-harbor.html) 中有详细地介绍，感兴趣的小伙伴可以再去看一下。

```bash
#!/bin/bash
REGISTRY_DOMAIN="harbor.k8s.li"
REGISTRY_PATH="/var/lib/registry"

# 切换到 registry 存储主目录下
cd ${REGISTRY_PATH}

gen_skopeo_dir() {
   # 定义 registry 存储的 blob 目录 和 repositories 目录，方便后面使用
    BLOB_DIR="docker/registry/v2/blobs/sha256"
    REPO_DIR="docker/registry/v2/repositories"
    # 定义生成 skopeo 目录
    SKOPEO_DIR="docker/skopeo"
    # 通过 find 出 current 文件夹可以得到所有带 tag 的镜像，因为一个 tag 对应一个 current 目录
    for image in $(find ${REPO_DIR} -type d -name "current"); do
        # 根据镜像的 tag 提取镜像的名字
        name=$(echo ${image} | awk -F '/' '{print $5"/"$6":"$9}')
        link=$(cat ${image}/link | sed 's/sha256://')
        mfs="${BLOB_DIR}/${link:0:2}/${link}/data"
        # 创建镜像的硬链接需要的目录
        mkdir -p "${SKOPEO_DIR}/${name}"
        # 硬链接镜像的 manifests 文件到目录的 manifest 文件
        ln ${mfs} ${SKOPEO_DIR}/${name}/manifest.json
        # 使用正则匹配出所有的 sha256 值，然后排序去重
        layers=$(grep -Eo "\b[a-f0-9]{64}\b" ${mfs} | sort -u)
        for layer in ${layers}; do
          # 硬链接 registry 存储目录里的镜像 layer 和 images config 到镜像的 dir 目录
            ln ${BLOB_DIR}/${layer:0:2}/${layer}/data ${SKOPEO_DIR}/${name}/${layer}
        done
    done
}

sync_image() {
    # 使用 skopeo sync 将 dir 格式的镜像同步到 harbor
    for project in $(ls ${SKOPEO_DIR}); do
        skopeo sync --insecure-policy --src-tls-verify=false --dest-tls-verify=false \
        --src dir --dest docker ${SKOPEO_DIR}/${project} ${REGISTRY_DOMAIN}/${project}
    done
}

gen_skopeo_dir
sync_image
```
