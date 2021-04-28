---
title: 什么？发布流水线中镜像“同步”速度又提升了 15 倍 ！
date: 2021-04-28
updated: 2021-04-28
slug:
categories: 技术
tag:
  - registry
  - skopeo
  - images
copyright: true
comment: true
---

## overlay2 优化

前段时间写过一篇 [overlay2 在打包发布流水线中的应用](https://blog.k8s.li/overlay2-on-package-pipline.html)，来介绍在产品发布流水线中使用 overlay2 和 registry 组合的技术来优化镜像同步的流程，感兴趣的小伙伴可以去阅读一下。最近**忽然**发现了一个可以完美替代 overlay2 的方案，而且性能更好，流程更简单。

![](https://p.k8s.li/2021-03-01-002.jpeg)

根据在文章中提到的镜像同步流程可以得知：在打包发布流水线中，会进行两次镜像同步。第一次是根据一个镜像列表将镜像从 cicd.registry.local 仓库同步到 overlay2.registry.local；第二次是将 overlay2.registry.local 镜像同步到 package.registry.local。overlay2.registry.local 和 package.registry.local 这两个镜像仓库是在同一台机器上，而且 overlay2.registry.lcoal 的 registry 存储目录将作为 overlay2 挂载的 lower 给 package.registry.local 使用。

在 [如何使用 registry 存储的特性](https://blog.k8s.li/skopeo-to-registry.html) 文章我提到过 skopeo dir 格式的镜像可以还原回 registry 存储的格式；在 [docker registry 迁移至 harbor](https://blog.k8s.li/docker-registry-to-harbor.html) 文章中提到了可以将 registry 存储的格式转换为 skopeo dir 的格式，因此总结出 skopeo dir 和 docker registry 这两种镜像存储格式可以互相转换。

掌握了这两种镜像存储格式之间互相转换之后，突然意识到**为何不直接从 registry 存储提取特定的镜像（镜像列表），并保取为 registry 存储的格式？** 这样根本就不需要 overlay2 和 skopeo，可以直接对 registry 的存储进行操作，将镜像一个一个地硬链接出来。而且对 registry 文件系统的 I/O 操作从理论上来讲性能会远远高于 skopeo 这种通过 HTTP 协议传输。

## 玩转 registry 存储

再一次搬来这张 registry 存储的结构图，如果想要看懂这系列的文章，一定要理解这张图：

![](https://p.k8s.li/registry-storage.jpeg)

### registry to skopeo dir

之前在 [docker registry 迁移至 harbor](https://blog.k8s.li/docker-registry-to-harbor.html)  文章中提到过将 registry 存储中的镜像转换为 skopeo dir 的格式，然后使用 skopeo 将转换后的镜像 push 到 harbor 中。大致流程如下：

- 首先要得到镜像的 manifests 文件，从 manifests 文件中可以得到该镜像的所有 blob 文件。例如对于 registry 存储目录中的 `library/alpine:latest` 镜像来讲，它在 registry 中是这样存放的：

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# tree
.
├── blobs
│   └── sha256
│       ├── 21
│       │   └── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
│       │       └── data
│       ├── a1
│       │   └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
│       │       └── data
│       └── be
│           └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
│               └── data
└── repositories
    └── library
        └── alpine
            ├── _layers
            │   └── sha256
            │       ├── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
            │       │   └── link
            │       └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
            │           └── link
            ├── _manifests
            │   ├── revisions
            │   │   └── sha256
            │   │       └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
            │   │           └── link
            │   └── tags
            │       └── latest
            │           ├── current
            │           │   └── link
            │           └── index
            │               └── sha256
            │                   └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
            │                       └── link
            └── _uploads

26 directories, 8 files
```

- 步骤一：通过 `repositories/library/alpine/_manifests/tags/latest/current/link` 文件得到 alpine 镜像 lasts 这个 tag 的 manifests 文件的 sha256 值，然后根据这个 sha256 值去 blobs 找到镜像的 manifests 文件;

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2/repositories/library/alpine/_manifests/tags/latest/current/
╰─# cat link
sha256:39eda93d15866957feaee28f8fc5adb545276a64147445c64992ef69804dbf01#
```

- 步骤二：根据 `current/link` 文件中的 sha256 值在 blobs 目录下找到与之对应的文件，blobs 目录下对应的 manifests 文件为 blobs/sha256/39/39eda93d15866957feaee28f8fc5adb545276a64147445c64992ef69804dbf01/data;

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2/repositories/library/alpine/_manifests/tags/latest/current
╰─# cat /var/lib/registry/docker/registry/v2/blobs/sha256/39/39eda93d15866957feaee28f8fc5adb545276a64147445c64992ef69804dbf01/data
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
   "config": {
      "mediaType": "application/vnd.docker.container.image.v1+json",
      "size": 1507,
      "digest": "sha256:f70734b6a266dcb5f44c383274821207885b549b75c8e119404917a61335981a"
   },
   "layers": [
      {
         "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
         "size": 2813316,
         "digest": "sha256:cbdbe7a5bc2a134ca8ec91be58565ec07d037386d1f1d8385412d224deafca08"
      }
   ]
}
```

- 步骤三：使用正则匹配，过滤出 manifests 文件中的所有 sha256 值，这些 sha256 值就对应着 blobs 目录下的 image config 文件和 image layer 文件;

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2/repositories/library/alpine/_manifests/tags/latest/current
╰─# grep -Eo "\b[a-f0-9]{64}\b" /var/lib/registry/docker/registry/v2/blobs/sha256/39/39eda93d15866957feaee28f8fc5adb545276a64147445c64992ef69804dbf01/data
f70734b6a266dcb5f44c383274821207885b549b75c8e119404917a61335981a
cbdbe7a5bc2a134ca8ec91be58565ec07d037386d1f1d8385412d224deafca08
```

- 步骤四：根据 manifests 文件就可以得到 blobs 目录中镜像的所有 layer 和 image config 文件，然后将这些文件拼成一个 dir 格式的镜像，在这里使用 cp 的方式将镜像从 registry 存储目录里复制出来，过程如下：

```shell
# 首先创建一个文件夹，为了保留镜像的 name 和 tag，文件夹的名称就对应的是 NAME:TAG
╭─root@sg-02 /var/lib/registry/docker
╰─# mkdir -p skopeo/library/alpine:latest

# 复制镜像的 manifest 文件
╭─root@sg-02 /var/lib/registry/docker
╰─# cp /var/lib/registry/docker/registry/v2/blobs/sha256/39/39eda93d15866957feaee28f8fc5adb545276a64147445c64992ef69804dbf01/data skopeo/library/alpine:latest/manifest

# 复制镜像的 blob 文件
# cp /var/lib/registry/docker/registry/v2/blobs/sha256/f7/f70734b6a266dcb5f44c383274821207885b549b75c8e119404917a61335981a/data skopeo/library/alpine:latest/f70734b6a266dcb5f44c383274821207885b549b75c8e119404917a61335981a
# cp /var/lib/registry/docker/registry/v2/blobs/sha256/cb/cbdbe7a5bc2a134ca8ec91be58565ec07d037386d1f1d8385412d224deafca08/data skopeo/library/alpine:latest/cbdbe7a5bc2a134ca8ec91be58565ec07d037386d1f1d8385412d224deafca08
```

最终得到的镜像格式如下：

```shell
╭─root@sg-02 /var/lib/registry/docker
╰─# tree skopeo/library/alpine:latest
skopeo/library/alpine:latest
├── cbdbe7a5bc2a134ca8ec91be58565ec07d037386d1f1d8385412d224deafca08
├── f70734b6a266dcb5f44c383274821207885b549b75c8e119404917a61335981a
└── manifest

0 directories, 3 files
```

### skopeo dir to registry

在 [如何使用 registry 存储的特性](https://blog.k8s.li/skopeo-to-registry.html) 文章我提到过 skopeo dir 格式的镜像可以还原回 registry 存储的格式，大致流程如下：

将 `images/alpine:latest` 这个镜像在转换成 docker registry 存储目录的形式

```shell
root@debian:/root # tree -h images/alpine:latest
images/alpine:latest
└── [4.0K]  alpine:latest
    ├── [2.7M]  4167d3e149762ea326c26fc2fd4e36fdeb7d4e639408ad30f37b8f25ac285a98
    ├── [1.5K]  af341ccd2df8b0e2d67cf8dd32e087bfda4e5756ebd1c76bbf3efa0dc246590e
    ├── [ 528]  manifest.json
    └── [  33]  version
```

根据镜像文件大小我们可以得知： `2.7M` 大小的 `4167d3e1497……` 文件就是镜像的 layer 文件，由于 alpine 是一个 base 镜像，该 layer 就是 alpine 的根文件系统；`1.5K` 大小的 `af341ccd2……` 显而易见就是镜像的 images config 文件；`manifest.json` 文件则是镜像在 registry 存储中的 manifest.json 文件。

- 步骤一：先创建该镜像在 registry 存储中的目录结构

```shell
root@debian:/root # mkdir -p docker/registry/v2/{blobs/sha256,repositories/alpine}
root@debian:/root # tree docker
docker
└── registry
    └── v2
        ├── blobs
        │   └── sha256
        └── repositories
            └── alpine
```

- 步骤二：构建镜像 layer 的 link 文件

```shell
grep -Eo "\b[a-f0-9]{64}\b" images/alpine:latest/manifest.json | sort -u | xargs -L1 -I {} mkdir -p docker/registry/v2/repositories/alpine/_layers/sha256/{}

grep -Eo "\b[a-f0-9]{64}\b" images/alpine:latest/manifest.json | sort -u | xargs -L1 -I {} sh -c "echo -n 'sha256:{}' > docker/registry/v2/repositories/alpine/_layers/sha256/{}/link"
```

- 步骤三：构建镜像 tag 的 link 文件

```shell
manifests_sha256=$(sha256sum images/alpine:latest/manifest.json | awk '{print $1}')
mkdir -p docker/registry/v2/repositories/alpine/_manifests/revisions/sha256/${manifests_sha256}
echo -n "sha256:${manifests_sha256}" > docker/registry/v2/repositories/alpine/_manifests/revisions/sha256/${manifests_sha256}/link

mkdir -p docker/registry/v2/repositories/alpine/_manifests/tags/latest/index/sha256/${manifests_sha256}
echo -n "sha256:${manifests_sha256}" > docker/registry/v2/repositories/alpine/_manifests/tags/latest/index/sha256/${manifests_sha256}/link

mkdir -p docker/registry/v2/repositories/alpine/_manifests/tags/latest/current
echo -n "sha256:${manifests_sha256}" > docker/registry/v2/repositories/alpine/_manifests/tags/latest/current/link
```

- 步骤四：构建镜像的 blobs 目录

```shell
mkdir -p docker/registry/v2/blobs/sha256/${manifests_sha256:0:2}/${manifests_sha256}
ln -f images/alpine:latest/manifest.json docker/registry/v2/blobs/sha256/${manifests_sha256:0:2}/${manifests_sha256}/data

for layer in $(grep -Eo "\b[a-f0-9]{64}\b" images/alpine:latest/manifest.json); do
    mkdir -p docker/registry/v2/blobs/sha256/${layer:0:2}/${layer}
    ln -f  images/alpine:latest/${layer} docker/registry/v2/blobs/sha256/${layer:0:2}/${layer}/data
done
```

- 最终得到的 registry 存储目录如下

```shell
docker
└── registry
    └── v2
        ├── blobs
        │   └── sha256
        │       ├── 41
        │       │   └── 4167d3e149762ea326c26fc2fd4e36fdeb7d4e639408ad30f37b8f25ac285a98
        │       │       └── data
        │       ├── af
        │       │   └── af341ccd2df8b0e2d67cf8dd32e087bfda4e5756ebd1c76bbf3efa0dc246590e
        │       │       └── data
        │       └── de
        │           └── de78803598bc4c940fc4591d412bffe488205d5d953f94751c6308deeaaa7eb8
        │               └── data
        └── repositories
            └── alpine
                ├── _layers
                │   └── sha256
                │       ├── 4167d3e149762ea326c26fc2fd4e36fdeb7d4e639408ad30f37b8f25ac285a98
                │       │   └── link
                │       └── af341ccd2df8b0e2d67cf8dd32e087bfda4e5756ebd1c76bbf3efa0dc246590e
                │           └── link
                └── _manifests
                    ├── revisions
                    │   └── sha256
                    │       └── de78803598bc4c940fc4591d412bffe488205d5d953f94751c6308deeaaa7eb8
                    │           └── link
                    └── tags
                        └── latest
                            ├── current
                            │   └── link
                            └── index
                                └── sha256
                                    └── de78803598bc4c940fc4591d412bffe488205d5d953f94751c6308deeaaa7eb8
                                        └── link
```

### registry to registry  by images list

熟悉了如何将 registry 存储转换为 skopeo dir 以及镜像 skopeo dir 转换为 registry 存储的流程之后，我们就可以根据一个镜像列表，将镜像从一个很大的 registry 存储中（里面几千个镜像）提取出一些特定的镜像。比如镜像列表如下

```bash
library/alpine:latest
library/alpine:3.6
library/alpine:3.7
library/busybox:1.30.0
library/centos:6.7
library/centos:7.4.1708
library/default-http-backend:v0.1.0
library/elasticsearch:6.5.4
library/examples-bookinfo-details-v1:1.8.0
library/examples-bookinfo-productpage-v1:1.8.0
library/examples-bookinfo-ratings-v1:1.8.0
library/examples-bookinfo-reviews-v1:1.8.0
library/examples-bookinfo-reviews-v2:1.8.0
library/examples-bookinfo-reviews-v3:1.8.0
library/galera:5.7.20
library/gitlab-ce:10.3.3-ce.0
library/golang:1.10.1-alpine3.7
library/golang:1.9.5-alpine3.7
library/gradle:5.5.1
library/haproxy:1.6.14-alpine
library/haproxy:1.7.10-alpine
library/influxdb:1.4.2-alpine
library/influxdb:1.4.3
library/influxdb:1.5.2-alpine
library/jenkins:2.101-alpine-enhanced
library/kibana:6.5.4
library/mariadb:10.2.12
library/maven:3.5.3-ibmjava-8-alpine
library/maven:3.5.3-jdk-8-alpine
library/memcached:1.5.4-alpine
library/mongo:3.4.14-jessie
library/mongo:3.6.1
library/mongo:3.6.13
library/mongo:3.7.3-jessie
library/mysql:5.6.39
library/mysql:5.7.20
library/nginx:1.11.12-alpine
library/nginx:1.12.2
library/nginx:1.13.8-alpine
library/nginx-ingress-controller:0.23.0-cps-1.3
library/node:9-alpine
library/openjdk:8u151-alpine3.7
library/openjdk:8u151-jre-alpine3.7
library/php:7.1-apache
library/python:2.7.14-alpine3.6
library/python:3.6.5-alpine3.6
library/rabbitmq:3.7.2-alpine
library/redis:3.2.11-alpine
library/redis:4.0.6-alpine
library/redis:4.0.9-alpine
library/redmine:3.4.4
library/sbt:8u232_1.3.13
library/wordpress:4.9.1
```

我们先以单个镜像为例子如： `library/alpine:latest`

- 首先要得到镜像的 manifest 文件，从 manifest 文件中可以得到该镜像的所有 blob 文件。例如对于 registry 存储目录中的 `library/alpine:latest` 镜像来讲，它在 registry 中是这样存放的：

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# tree
.
├── blobs
│   └── sha256
│       ├── 21
│       │   └── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
│       │       └── data
│       ├── a1
│       │   └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
│       │       └── data
│       └── be
│           └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
│               └── data
└── repositories
    └── library
        └── alpine
            ├── _layers
            │   └── sha256
            │       ├── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
            │       │   └── link
            │       └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
            │           └── link
            ├── _manifests
            │   ├── revisions
            │   │   └── sha256
            │   │       └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
            │   │           └── link
            │   └── tags
            │       └── latest
            │           ├── current
            │           │   └── link
            │           └── index
            │               └── sha256
            │                   └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
            │                       └── link
            └── _uploads

26 directories, 8 files
```

- 首先定义一些需要用到的变量

```bash
# 定义镜像列表
IMAGES_LIST="images.list"

# 定义 registry 存储目录的绝对路径
REGISTRY_PATH="/var/lib/registry"

# 定义输出的存储目录路径，要和 registay 存储在同一分区
OUTPUT_DIR="/var/lib/images"

# 定义这两个固定变量
BLOB_DIR="docker/registry/v2/blobs/sha256"
REPO_DIR="docker/registry/v2/repositories"

# 定义单个镜像
image="library/alpine:latest"
# 使用 bash 内置的变量替换截取出镜像的 name
image_tag=${image##*:}
# 使用 bash 内置的变量替换截取出镜像的 tag
image_name=${image%%:*}
```

- 步骤一：通过 `${REGISTRY_PATH}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/current/link` 文件得到 alpine 镜像 lasts 这个 tag 的 manifests 文件的 sha256 值，然后根据这个 sha256 值去 blobs 目录下找到镜像的 manifests 文件;

```bash
tag_link=${REGISTRY_PATH}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/current/link
manifest_sha256=$(sed 's/sha256://' ${tag_link})
manifest=${REGISTRY_PATH}/${BLOB_DIR}/${manifest_sha256:0:2}/${manifest_sha256}/data
```

- 步骤二：找到镜像的 manifest 文件之后，在输出目录下创建相应的目录，并通过硬链接的方式将镜像的 manifest 链接到输出对应的目录

```bash
mkdir -p ${OUTPUT_DIR}/${BLOB_DIR}/${manifest_sha256:0:2}/${manifest_sha256}
ln -f ${manifest} ${OUTPUT_DIR}/${BLOB_DIR}/${manifest_sha256:0:2}/${manifest_sha256}/data
```

- 步骤三：参照 **skopeo dir to registry** 中的步骤三创建镜像 tag 的 link 文件，路径基本上保持一致，只不过前面需要加上输出目录的路径，步骤如下：

```bash
# make image repositories dir
mkdir -p ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/{_uploads,_layers,_manifests}
mkdir -p ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/revisions/sha256/${manifest_sha256}
mkdir -p ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/{current,index/sha256}
mkdir -p ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/index/sha256/${manifest_sha256}

# create image tag manifest link file
echo -n "sha256:${manifest_sha256}" > ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/current/link
echo -n "sha256:${manifest_sha256}" > ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/revisions/sha256/${manifest_sha256}/link
echo -n "sha256:${manifest_sha256}" > ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/index/sha256/${manifest_sha256}/link
```

- 步骤四：通过正则匹配  sha256 值获取该镜像 manifest 文件中的所有 image layer 和 image config，并在一个 for 循环中将对应 sha256 值对应的 blob 文件硬链接到输出目录，并在 _layer 目录下创建相应的 link 文件。这一步和 **skopeo dir to registry** 中的步骤四及其相似。

```bash
for layer in $(sed '/v1Compatibility/d' ${manifest} | grep -Eo '\b[a-f0-9]{64}\b' | sort -u); do
    mkdir -p ${OUTPUT_DIR}/${BLOB_DIR}/${layer:0:2}/${layer}
    mkdir -p ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_layers/sha256/${layer}
    ln -f ${BLOB_DIR}/${layer:0:2}/${layer}/data ${OUTPUT_DIR}/${BLOB_DIR}/${layer:0:2}/${layer}/data
    echo -n "sha256:${layer}" > ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_layers/sha256/${layer}/link
done
```

- 将上述步骤整合成一个 shell 脚本 `select_registry_images.sh` 如下：

```shell
#!/bin/bash
set -eo pipefail

IMAGES_LIST="$1"
REGISTRY_PATH="$2"
OUTPUT_DIR="$3"
BLOB_DIR="docker/registry/v2/blobs/sha256"
REPO_DIR="docker/registry/v2/repositories"

rm -rf ${OUTPUT_DIR}; mkdir -p ${OUTPUT_DIR}
for image in $(find ${IMAGES_LIST} -type f -name "*.list" | xargs grep -Ev '^#|^/' | grep ':'); do
    image_tag=${image##*:}
    image_name=${image%%:*}
    tag_link=${REGISTRY_PATH}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/current/link
    manifest_sha256=$(sed 's/sha256://' ${tag_link})
    manifest=${REGISTRY_PATH}/${BLOB_DIR}/${manifest_sha256:0:2}/${manifest_sha256}/data
    mkdir -p ${OUTPUT_DIR}/${BLOB_DIR}/${manifest_sha256:0:2}/${manifest_sha256}
    ln -f ${manifest} ${OUTPUT_DIR}/${BLOB_DIR}/${manifest_sha256:0:2}/${manifest_sha256}/data

    # make image repositories dir
    mkdir -p ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/{_uploads,_layers,_manifests}
    mkdir -p ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/revisions/sha256/${manifest_sha256}
    mkdir -p ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/{current,index/sha256}
    mkdir -p ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/index/sha256/${manifest_sha256}

    # create image tag manifest link file
    echo -n "sha256:${manifest_sha256}" > ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/current/link
    echo -n "sha256:${manifest_sha256}" > ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/revisions/sha256/${manifest_sha256}/link
    echo -n "sha256:${manifest_sha256}" > ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_manifests/tags/${image_tag}/index/sha256/${manifest_sha256}/link
    for layer in $(sed '/v1Compatibility/d' ${manifest} | grep -Eo '\b[a-f0-9]{64}\b' | sort -u); do
        mkdir -p ${OUTPUT_DIR}/${BLOB_DIR}/${layer:0:2}/${layer}
        mkdir -p ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_layers/sha256/${layer}
        ln -f ${BLOB_DIR}/${layer:0:2}/${layer}/data ${OUTPUT_DIR}/${BLOB_DIR}/${layer:0:2}/${layer}/data
        echo -n "sha256:${layer}" > ${OUTPUT_DIR}/${REPO_DIR}/${image_name}/_layers/sha256/${layer}/link
    done
done
```

执行该脚本，将 images.list 中的 183 个镜像通过硬链接的方式，从 registry 存储中提取到另一个 registry 存储目录下，用时才 6s 左右。

```bash
root@debian:~$ wc images.list
 183  183 5644 images.list

root@debian:~$ time bash select_registry_images.sh images.list /var/lib/registry /var/lib/images
bash select_registry_images.sh images.list /var/lib/registry   4.39s user 2.48s system 109% cpu 6.283 total
```

## 效果如何？

之前使用 overlay2 技术已经将流水线的镜像同步优化得很好了，由原来的最长 2h30min 缩短到了几分钟。

经过本次的优化，将流水线中第二次的镜像同步耗时从原来的  90s 缩短到了 6s，速度提升了 15 倍，而且过程比之前更简单了一些，也不再需要引入 overlay2 这种技术。看来之前被我吹了这么久的 overlay2 + registry 组合技术和这次优化相比也不过如此。
