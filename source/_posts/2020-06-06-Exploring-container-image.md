---
title: 深入浅出容器镜像的一生🤔
date: 2020-06-14
updated: 2020-06-14
slug:
categories: 技术
tag:
  - docker
  - image
  - registry
copyright: true
comment: true
---

上周在写[《镜像搬运工 skopeo 》](https://blog.k8s.li/skopeo.html) 的时候看了很多关于容器镜像相关的博客，从大佬们那里偷偷学了不少知识，对容器镜像有了一点点深入的了解。这周末一个人闲着宅在家里没事就把最近所学的知识整理一下分享出来，供大家一起来食用。内容比较多，耐心看完的话，还是能收获一些~~没用的~~知识滴😂。

## 更新记录

- 2020-06-13：还有一些没有写完，后续补充
- 2020-06-06：初稿
- 2020-09-02：补充

## 镜像是怎样炼成的🤔

所谓炼成像就是构建镜像啦，下面用到的**搓**和**炼制**都是指的构建镜像啦，只是个人习惯用语而已😂。

提到容器镜像就不得不提一下 OCI ，即 Open Container Initiative 旨在围绕容器格式和运行时制定一个开放的工业化标准。目前 OCI 主要有三个规范：运行时规范 [runtime-spec](https://github.com/opencontainers/runtime-spec) ，镜像规范 [image-spec](http://www.github.com/opencontainers/image-spec) 以及不常见的镜像仓库规范 [distribution-spec](https://github.com/opencontainers/distribution-spec) 。关于 OCI 这些规范的作用的作用，就引用一下 [容器开放接口规范（CRI OCI）](https://wilhelmguo.cn/blog/post/william/%E5%AE%B9%E5%99%A8%E5%BC%80%E6%94%BE%E6%8E%A5%E5%8F%A3%E8%A7%84%E8%8C%83%EF%BC%88CRI-OCI%EF%BC%89-2) 中的内容，我也就懒得自己组织语言灌水了😂（凑字数

> 制定容器格式标准的宗旨概括来说就是不受上层结构的绑定，如特定的客户端、编排栈等，同时也不受特定的供应商或项目的绑定，即不限于某种特定操作系统、硬件、CPU架构、公有云等。
>
> 这两个协议通过 OCI runtime filesytem bundle 的标准格式连接在一起，OCI 镜像可以通过工具转换成 bundle，然后 OCI 容器引擎能够识别这个 bundle 来运行容器
>
> - 操作标准化：容器的标准化操作包括使用标准容器创建、启动、停止容器，使用标准文件系统工具复制和创建容器快照，使用标准化网络工具进行下载和上传。
> - 内容无关：内容无关指不管针对的具体容器内容是什么，容器标准操作执行后都能产生同样的效果。如容器可以用同样的方式上传、启动，不管是PHP应用还是MySQL数据库服务。
> - 基础设施无关：无论是个人的笔记本电脑还是AWS S3，亦或是OpenStack，或者其它基础设施，都应该对支持容器的各项操作。
> - 为自动化量身定制：制定容器统一标准，是的操作内容无关化、平台无关化的根本目的之一，就是为了可以使容器操作全平台自动化。
> - 工业级交付：制定容器标准一大目标，就是使软件分发可以达到工业级交付成为现实

其实 OCI 规范就是一堆 markdown 文件啦，内容也很容易理解，不像 RFC 和 ISO 那么高深莫测，所以汝想对容器镜像有个深入的了解还是推荐大家去读一下这些 markdown 文件😂。OCI 规范是免费的哦，不像大多数 ISO 规范还要交钱才能看（︶^︶）哼。

### OCI image-spec

OCI 规范中的镜像规范 [image-spec](http://www.github.com/opencontainers/image-spec) 决定了我们的镜像按照什么标准来构建，以及构建完镜像之后如何存放，接着下文提到的 Dockerfile 则决定了镜像的 layer 内容以及镜像的一些元数据信息。一个镜像规范 image-spec 和一个 Dockerfile 就指导着我们构建一个镜像，那么接下来我们就简单了解一下这个镜像规范，看看镜像是长什么样子的，对镜像有个大体的主观认识。

根据官方文档的描述，OCI 镜像规范的主要由以下几个 markdown 文件组成：

> - [Image Manifest](https://github.com/opencontainers/image-spec/blob/master/manifest.md) - a document describing the components that make up a container image
> - [Image Index](https://github.com/opencontainers/image-spec/blob/master/image-index.md) - an annotated index of image manifests
> - [Image Layout](https://github.com/opencontainers/image-spec/blob/master/image-layout.md) - a filesystem layout representing the contents of an image
> - [Filesystem Layer](https://github.com/opencontainers/image-spec/blob/master/layer.md) - a changeset that describes a container's filesystem
> - [Image Configuration](https://github.com/opencontainers/image-spec/blob/master/config.md) - a document determining layer ordering and configuration of the image suitable for translation into a [runtime bundle](https://github.com/opencontainers/runtime-spec)
> - [Conversion](https://github.com/opencontainers/image-spec/blob/master/conversion.md) - a document describing how this translation should occur
> - [Descriptor](https://github.com/opencontainers/image-spec/blob/master/descriptor.md) - a reference that describes the type, metadata and content address of referenced content

```shell
├── annotations.md         # 注解规范
├── config.md              # image config 文件规范
├── considerations.md      # 注意事项
├── conversion.md          # 转换为 OCI 运行时
├── descriptor.md          # OCI Content Descriptors 内容描述
├── image-index.md         # manifest list 文件
├── image-layout.md        # 镜像的布局
├── implementations.md     # 使用 OCI 规范的项目
├── layer.md               # 镜像层 layer 规范
├── manifest.md            # manifest 规范
├── media-types.md         # 文件类型
├── README.md              # README 文档
├── spec.md                # OCI 镜像规范的概览
```

总结以上几个 markdown 文件， OCI 容器镜像规范主要包括以下几块内容：

#### layer

[文件系统](https://github.com/opencontainers/image-spec/blob/master/layer.md)：以 layer （镜像层）保存的文件系统，每个 layer 保存了和上层之间变化的部分，layer 应该保存哪些文件，怎么表示增加、修改和删除的文件等。

#### image config

[image config 文件](https://github.com/opencontainers/image-spec/blob/master/config.md)：保存了文件系统的层级信息（每个层级的 hash 值，以及历史信息），以及容器运行时需要的一些信息（比如环境变量、工作目录、命令参数、mount 列表），指定了镜像在某个特定平台和系统的配置，比较接近我们使用 `docker inspect <image_id>` 看到的内容。

- example

```json
{
  "architecture": "amd64",
  "config": {
    "Hostname": "",
    "Domainname": "",
    "User": "",
    "AttachStdin": false,
    "AttachStdout": false,
    "AttachStderr": false,
    "Tty": false,
    "OpenStdin": false,
    "StdinOnce": false,
    "Env": [
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    ],
    "Cmd": [
      "bash"
    ],
    "Image": "sha256:ba8f577813c7bdf6b737f638dffbc688aa1df2ff28a826a6c46bae722977b549",
    "Volumes": null,
    "WorkingDir": "",
    "Entrypoint": null,
    "OnBuild": null,
    "Labels": null
  },
  "container": "38501d5aa48c080884f4dc6fd4b1b6590ff1607d9e7a12e1cef1d86a3fdc32df",
  "container_config": {
    "Hostname": "38501d5aa48c",
    "Domainname": "",
    "User": "",
    "AttachStdin": false,
    "AttachStdout": false,
    "AttachStderr": false,
    "Tty": false,
    "OpenStdin": false,
    "StdinOnce": false,
    "Env": [
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    ],
    "Cmd": [
      "/bin/sh",
      "-c",
      "#(nop) ",
      "CMD [\"bash\"]"
    ],
    "Image": "sha256:ba8f577813c7bdf6b737f638dffbc688aa1df2ff28a826a6c46bae722977b549",
    "Volumes": null,
    "WorkingDir": "",
    "Entrypoint": null,
    "OnBuild": null,
    "Labels": {}
  },
  "created": "2020-06-07T01:59:47.348924716Z",
  "docker_version": "19.03.5",
  "history": [
    {
      "created": "2020-06-07T01:59:46.877600299Z",
      "created_by": "/bin/sh -c #(nop) ADD file:a82014afc29e7b364ac95223b22ebafad46cc9318951a85027a49f9ce1a99461 in / "
    },
    {
      "created": "2020-06-07T01:59:47.348924716Z",
      "created_by": "/bin/sh -c #(nop)  CMD [\"bash\"]",
      "empty_layer": true
    }
  ],
  "os": "linux",
  "rootfs": {
    "type": "layers",
    "diff_ids": [
      "sha256:d1b85e6186f67d9925c622a7a6e66faa447e767f90f65ae47cdc817c629fa956"
    ]
  }
}
```

#### manifest

[manifest 文件](https://github.com/opencontainers/image-spec/blob/master/manifest.md) ：镜像的 config 文件索引，有哪些 layer，额外的 annotation 信息，manifest 文件中保存了很多和当前平台有关的信息。另外 manifest 中的 layer 和 config 中的 layer 表达的虽然都是镜像的 layer ，但二者代表的意义不太一样，稍后会讲到。manifest 文件是存放在 registry 中，当我们拉取镜像的时候，会根据该文件拉取相应的 layer 。根据 OCI image-spec 规范中 [OCI Image Manifest Specification](https://github.com/opencontainers/image-spec/blob/master/manifest.md) 的定义可以得知，镜像的 manifest 文件主要有以下三个目标：（英语不好就不翻译了😥

> There are three main goals of the Image Manifest Specification.
>
> - The first goal is content-addressable images, by supporting an image model where the image's configuration can be hashed to generate a unique ID for the image and its components.
> - The second goal is to allow multi-architecture images, through a "fat manifest" which references image manifests for platform-specific versions of an image. In OCI, this is codified in an [image index](https://github.com/opencontainers/image-spec/blob/master/image-index.md).
> - The third goal is to be [translatable](https://github.com/opencontainers/image-spec/blob/master/conversion.md) to the [OCI Runtime Specification](https://github.com/opencontainers/runtime-spec).

另外 manifest 也分好几个版本，目前主流的版本是  `Manifest Version 2, Schema 2` ，可以参考 docker 的官方文档 [Image Manifest Version 2, Schema 2](https://github.com/docker/distribution/blob/master/docs/spec/manifest-v2-2.md) 。registry 中会有个 `Manifest List ` 文件，该文件是为不同处理器体系架构而设计的，通过该文件指向与该处理器体系架构相对应的 Image Manifest ，这一点不要搞混。

- Example Manifest List

```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
  "manifests": [
    {
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "size": 7143,
      "digest": "sha256:e692418e4cbaf90ca69d05a66403747baa33ee08806650b51fab815ad7fc331f",
      "platform": {
        "architecture": "ppc64le",
        "os": "linux",
      }
    },
    {
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "size": 7682,
      "digest": "sha256:5b0bcabd1ed22e9fb1310cf6c2dec7cdef19f0ad69efa1f392e94a4333501270",
      "platform": {
        "architecture": "amd64",
        "os": "linux",
        "features": [
          "sse4"
        ]
      }
    }
  ]
}
```

- Image Manifest

```shell
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
  "config": {
    "mediaType": "application/vnd.docker.container.image.v1+json",
    "size": 1509,
    "digest": "sha256:a24bb4013296f61e89ba57005a7b3e52274d8edd3ae2077d04395f806b63d83e"
  },
  "layers": [
    {
      "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
      "size": 5844992,
      "digest": "sha256:50644c29ef5a27c9a40c393a73ece2479de78325cae7d762ef3cdc19bf42dd0a"
    }
  ]
}
```

最后再补充一段高策大佬的 [解释](http://gaocegege.com/Blog/ormb) ：

> Manifest 是一个 JSON 文件，其定义包括两个部分，分别是 [Config](https://github.com/opencontainers/image-spec/blob/master/config.md) 和 [Layers](https://github.com/opencontainers/image-spec/blob/master/layer.md)。Config 是一个 JSON 对象，Layers 是一个由 JSON 对象组成的数组。可以看到，Config 与 Layers 中的每一个对象的结构相同，都包括三个字段，分别是 digest、mediaType 和 size。其中 digest 可以理解为是这一对象的 ID。mediaType 表明了这一内容的类型。size 是这一内容的大小。
>
> 容器镜像的 Config 有着固定的 mediaType `application/vnd.oci.image.config.v1+json`。一个 Config 的示例配置如下，它记录了关于容器镜像的配置，可以理解为是镜像的元数据。通常它会被镜像仓库用来在 UI 中展示信息，以及区分不同操作系统的构建等。
>
> 而容器镜像的 Layers 是由多层 mediaType 为 `application/vnd.oci.image.layer.v1.*`（其中最常见的是 `application/vnd.oci.image.layer.v1.tar+gzip`) 的内容组成的。众所周知，容器镜像是分层构建的，每一层就对应着 Layers 中的一个对象。
>
> 容器镜像的 Config，和 Layers 中的每一层，都是以 Blob 的方式存储在镜像仓库中的，它们的 digest 作为 Key 存在。因此，在请求到镜像的 Manifest 后，Docker 会利用 digest 并行下载所有的 Blobs，其中就包括 Config 和所有的 Layers。

#### image manifest index

[index 文件](https://github.com/opencontainers/image-spec/blob/master/image-index.md) ：其实就是我们上面提到的 Manifest List 啦。在 docker 的 [distribution](https://github.com/docker/distribution) 中称之为 `Manifest List` 在 OCI 中就叫 [OCI Image Index Specification](https://github.com/opencontainers/image-spec/blob/master/image-index.md) 。其实两者是指的同一个文件，甚至两者 GitHub 上文档给的 example 都一一模样🤣，应该是 OCI 复制粘贴 Docker 的文档😂。index 文件是个可选的文件，包含着一个列表为同一个镜像不同的处理器 arch 指向不同平台的 manifest 文件，这个文件能保证一个镜像可以跨平台使用，每个处理器 arch 平台拥有不同的 manifest 文件，使用 index 作为索引。当我们使用 arm 架构的处理器时要额外注意，在拉取镜像的时候要拉取 arm 架构的镜像，一般处理器的架构都接在镜像的 tag 后面，默认 latest tag 的镜像是 x86 的，在 arm 处理器的机器这些镜像上是跑不起来的。

### 各种 id 分不清？

看完  [image-spec](http://www.github.com/opencontainers/image-spec) 里面提到的各种 id 相信你又很多疑惑，在此总结一下这些 id 的作用：

|   image-id   | image config 的 sha256 哈希值，在本地镜像存储中由它唯一标识一个镜像 |
| :----------: | ------------------------------------------------------------ |
| image digest | 在 registry 中的 image manifest 的 sha256 哈希值，在 registry 中由它唯一标识一个镜像 |
|   diff_ids   | 镜像每一层的 id ，是对 layer 的未压缩的 tar 包的 sha256 哈希值 |
| layer digest | 镜像在 registry 存储中的 id ，是对 layer压缩后的 tar 包的 sha256 哈希值 |

镜像的 image config 中的 `rootfs` 字段记录了每一层 layer 的 id，而镜像的 layer id 则是 layer tar 包的 sha256 值，如果镜像的 layer 改变，则这个 layer id 会改变，而记录它的 image config 内容也会改变，image config 内容变了，image config 文件的 sha256 值也就会改变，这样就可以由 image id 和 image digest 唯一标识一个镜像，达到防治篡改的安全目的。

```json
"rootfs": {
    "type": "layers",
    "diff_ids": [
      "sha256:d1b85e6186f67d9925c622a7a6e66faa447e767f90f65ae47cdc817c629fa956"
    ]
  }
```

### Dockerfile

众所周知 docker 镜像需要一个 Dockerfile 来构建而成，当我们对 OCI 镜像规范有了个大致的了解之后，我们接下来就拿着 Dockerfile 这个 ”图纸“ 去一步步构建镜像。本文不再细讲 Dockerfile 的详细书写和技巧，网上也有很多众所周知的关于写好 Dockerfile 的技巧，比如我之前水过的一篇 [Dockerfile 搓镜像的小技巧](https://blog.k8s.li/dockerfile-tips.html) 。

下面就是 [webp server go](https://webp.sh) Dockerfile 的例子：

```dockerfile
FROM golang:alpine as builder
ARG IMG_PATH=/opt/pics
ARG EXHAUST_PATH=/opt/exhaust
RUN apk update ;\
    apk add alpine-sdk ;\
    git clone https://github.com/webp-sh/webp_server_go /build ;\
    cd /build ;\
    sed -i "s|.\/pics|${IMG_PATH}|g" config.json ;\
    sed -i "s|\"\"|\"${EXHAUST_PATH}\"|g" config.json ;\
    sed -i 's/127.0.0.1/0.0.0.0/g' config.json
WORKDIR /build
RUN go build -o webp-server .

FROM alpine
COPY --from=builder /build/webp-server  /usr/bin/webp-server
COPY --from=builder /build/config.json /etc/config.json
WORKDIR /opt
VOLUME /opt/exhaust
CMD ["/usr/bin/webp-server", "--config", "/etc/config.json"]
```

需要注意的是，在 RUN 指令的每行结尾我使用的是 `;\` 来接下一行 shell ，另一种写法是 `&&` 。二者有本质的区别，比如 COMMAND 1;COMMAND 2 ，当 COMMAND 1 运行失败时会继续运行 COMMAND2 ，并不会退出。而 COMMAND 1&& COMMAND 2，时 COMMAND 1 运行成功时才接着运行 COMMAND 2 ，COMMAND 1 运行失败会退出。如果没有十足的把握保证每一行 shell 都能每次运行成功建议用 `&&` ，这样失败了就退出构建镜像，不然构建出来的镜像会有问题。如果是老司机🚗 的话建议用 `;` ，逛了一圈 docker hub 官方镜像中用 `;` 较多一些，因为 `;` 比 `&&` 要美观一些（大雾😂。

- 风格一：比如 [nginx](https://github.com/nginxinc/docker-nginx/blob/master/stable/buster/Dockerfile) 官方镜像是用的 `&&`，貌似也混入了 `;`🤣

```shell
RUN set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup --system --gid 101 nginx \
    && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid 101 nginx \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 ca-certificates \
    && \
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
    found=''; \
    for server in \
        ha.pool.sks-keyservers.net \
        hkp://keyserver.ubuntu.com:80 \
        hkp://p80.pool.sks-keyservers.net:80 \
        pgp.mit.edu \
    ; do \
```

- 风格二：比如 [redis](https://github.com/docker-library/redis/blob/23af5b6adb271bcebbcebc93308884438512a4af/6.0/Dockerfile) 官方镜像就清一色使用的 `;`

```shell
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates dirmngr gnupg wget; \
	rm -rf /var/lib/apt/lists/*; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true
```

汝喜欢哪种风格呢？快在评论区留言吧😋

#### 镜像工厂🛠

> Docker 是一个典型的 C/S 架构的应用，分为 Docker 客户端（即平时敲的 docker 命令） Docker 服务端（dockerd 守护进程）。
>
> Docker 客户端通过 REST API 和服务端进行交互，docker 客户端每发送一条指令，底层都会转化成 REST API 调用的形式发送给服务端，服务端处理客户端发送的请求并给出响应。
>
> Docker 镜像的构建、容器创建、容器运行等工作都是 Docker 服务端来完成的，Docker 客户端只是承担发送指令的角色。
>
> Docker 客户端和服务端可以在同一个宿主机，也可以在不同的宿主机，如果在同一个宿主机的话，Docker 客户端默认通过 UNIX 套接字(`/var/run/docker.sock`)和服务端通信。

类比于钢铁是怎样炼成的，如果说炼制镜像也需要个工厂的话，那么我们的 dockerd 这个守护进程就是个生产镜像的工厂。能生产镜像的不止 docker 一家，红帽子家的 [buildah](https://buildah.io/) 也能生产镜像，不过用的人并不多。二者的最大区别在于 buildah 可以不用 root 权限来构建镜像，而使用 docker 构建镜像时需要用到 root 权限，没有 root 权限的用户构建镜像会当场翻车。

```shell
Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock:
```

不过 buildah 构建出来的镜像有一堆堆的兼容性问题，所以我们还是使用 docker 来构建镜像吧。当我们使用 docker build 命令构建一个镜像的时候第一行日志就是 `Sending build context to Docker daemon xx MB`。这一步是 docker cli 这个命令行客户端将我们当前目录（即构建上下文） `build context` 打包发送 `Docker daemon` 守护进程 （即 dockerd）的过程。

![](https://p.k8s.li/docker-architecture.png)

docker build 构建镜像的流程大概就是：

- 执行 `docker build -t <imageName:Tag> .`，可以使用 `-f`参数来指定 Dockerfile 文件；
- docker 客户端会将构建命令后面指定的路径(`.`)下的所有文件打包成一个 tar 包，发送给 Docker 服务端;
- docker 服务端收到客户端发送的 tar 包，然后解压，接下来根据 Dockerfile 里面的指令进行镜像的分层构建；
- docker 下载 FROM 语句中指定的基础镜像，然后将基础镜像的 layer 联合挂载为一层，并在上面创建一个空目录；
- 接着启动一个临时的容器并在 chroot 中启动一个 bash，运行 `RUN` 语句中的命令：`RUN: chroot . /bin/bash -c "apt get update……"`；
- 一条 `RUN` 命令结束后，会把上层目录压缩，形成新镜像中的新的一层；
- 如果 Dockerfile 中包含其它命令，就以之前构建的层次为基础，从第二步开始重复创建新层，直到完成所有语句后退出；
- 构建完成之后为该镜像打上 tag；

以上就是构建镜像的大致流程，我们也可以通过 `docker history <imageName:Tag>` 命令来逆向推算出 docker build 的过程。

```shell
╭─root@sg-02 ~/buster/slim
╰─# docker history webpsh/webps
IMAGE               CREATED             CREATED BY          SIZE                COMMENT
30d9679b0b1c        2 weeks ago         /bin/sh -c #(nop)  CMD ["/usr/bin/webp-serve…   0B
<missing>           2 weeks ago         /bin/sh -c #(nop)  VOLUME [/opt/exhaust]        0B
<missing>           2 weeks ago         /bin/sh -c #(nop) WORKDIR /opt                  0B
<missing>           2 weeks ago         /bin/sh -c #(nop) COPY file:1497d882aeef5f77…   168B
<missing>           2 weeks ago         /bin/sh -c #(nop) COPY file:327020918e4dc998…   14.9MB
<missing>           6 weeks ago         /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>           6 weeks ago         /bin/sh -c #(nop) ADD file:b91adb67b670d3a6f…   5.61MB

╭─root@sg-02 ~/buster/slim
╰─# docker history debian:v2
IMAGE               CREATED             CREATED BY           SIZE                COMMENT
e6e782a57a51        38 hours ago        /bin/sh -c #(nop)  CMD ["bash"]                 0B
ba8f577813c7        38 hours ago        /bin/sh -c #(nop) ADD file:a82014afc29e7b364…   69.2MB
```

#### base image

当我们在写 Dockerfile 的时候都需要用 `FROM` 语句来指定一个基础镜像，这些基础镜像并不是无中生有，也需要一个 Dockerfile 来构建成镜像。下面我们拿来 [debian:buster](https://hub.docker.com/_/debian) 这个基础镜像的 [Dockerfile](https://github.com/debuerreotype/docker-debian-artifacts/blob/18cb4d0418be1c80fb19141b69ac2e0600b2d601/buster/Dockerfile) 来看一下基础镜像是如何炼成的。

```dockerfile
FROM scratch
ADD rootfs.tar.xz /
CMD ["bash"]
```

一个基础镜像的 Dockerfile 一般仅有三行。第一行 `FROM scratch` 中的`scratch` 这个镜像并不真实的存在。当你使用 `docker pull scratch` 命令来拉取这个镜像的时候会翻车哦，提示 `Error response from daemon: 'scratch' is a reserved name`。这是因为自从 docker 1.5 版本开始，在 Dockerfile 中 `FROM scratch` 指令并不进行任何操作，也就是不会创建一个镜像层；接着第二行的 `ADD rootfs.tar.xz /` 会自动把 `rootfs.tar.xz`  解压到 `/` 目录下，由此产生的一层镜像就是最终构建的镜像真实的 layer 内容；第三行 `CMD ["bash"]` 指定这镜像在启动容器的时候执行的应用程序，一般基础镜像的 CMD 默认为 bash 或者 sh 。

> As of Docker 1.5.0 (specifically, [`docker/docker#8827`](https://github.com/docker/docker/pull/8827)), `FROM scratch` is a no-op in the Dockerfile , and will not create an extra layer in your image (so a previously 2-layer image will be a 1-layer image instead).

`ADD rootfs.tar.xz /` 中，这个 `rootfs.tar.xz` 就是我们经过一系列骚操作（一般是发行版源码编译）搓出来的根文件系统，这个操作比较复杂，木子太菜了🥬就不在这里瞎掰掰了🙃，如果汝对源码构建 `rootfs.tar.xz` 这个过程感兴趣可以去看一下构建 debian 基础镜像的 Jenkins 流水线任务 [debuerreotype](https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/)，上面有构建这个 `rootfs.tar.xz` 完整过程，或者参考 Debian 官方的 [docker-debian-artifacts](https://github.com/debuerreotype/docker-debian-artifacts) 这个 repo 里的 shell 脚本。

需要额外注意一点，在这里往镜像里添加 `rootfs.tar.xz` 时使用的是 `ADD` 而不是 `COPY` ，因为在 Dockerfile 中的 ADD 指令 src 文件如果是个 tar 包，在构建的时候 docker 会帮我们把 tar 包解开到指定目录，使用 copy 指令则不会解开 tar 包。另外一点区别就是 ADD 指令是添加一个文件，这个文件可以是构建上下文环境中的文件，也可以是个 URL，而 COPY 则只能添加构建上下文中的文件，所谓的构建上下文就是我们构建镜像的时候最后一个参数啦。

> PS：面试的时候经常被问 ADD 与 COPY 的区别；CMD 与 ENTRYPOINT 的区别😂。

搓这个 `rootfs.tar.xz` 不同的发行版方法可能不太一样，Debian 发行版的 `rootfs.tar.xz` 可以在 [docker-debian-artifacts](https://github.com/debuerreotype/docker-debian-artifacts) 这个 repo 上找到，根据不同处理器 arch 选择相应的 branch ，然后这个 branch 下的目录就对应着该发行版的不同的版本的代号。意外发现 Debian 官方是将所有 arch 和所有版本的 `rootfs.tar.xz` 都放在这个 repo 里的，以至于这个 repo 的大小接近 2.88 GiB 😨，当网盘来用的嘛🤣（：手动滑稽

```shell
╭─root@sg-02 ~
╰─# git clone https://github.com/debuerreotype/docker-debian-artifacts
Cloning into 'docker-debian-artifacts'...
remote: Enumerating objects: 278, done.
remote: Counting objects: 100% (278/278), done.
Receiving objects:  67% (443/660), 1.60 GiB | 16.96 MiB/s
remote: Total 660 (delta 130), reused 244 (delta 97), pack-reused 382
Receiving objects: 100% (660/660), 2.88 GiB | 16.63 MiB/s, done.
Resolving deltas: 100% (267/267), done.
```

我们把这个 `rootfs.tar.xz` 解开就可以看到，这就是一个 Linux 的根文件系统，不同于我们使用 ISO 安装系统的那个根文件系统，这个根文件系统是经过一系列的裁剪，去掉了一些在容器运行中不必要的文件，使之更加轻量适用于容器运行的场景，整个根文件系统的大小为 125M，如果使用 slim 的`rootfs.tar.xz` 会更小一些，仅仅 76M。当然相比于仅仅几 M 的 `alpine` ，这算是够大的了。

```shell
╭─root@sg-02 ~/docker-debian-artifacts/buster ‹dist-amd64*›
╰─# git checkout dist-amd64
╭─root@sg-02 ~/docker-debian-artifacts/buster ‹dist-amd64*›
╰─# cd buster
╭─root@sg-02 ~/docker-debian-artifacts/buster ‹dist-amd64*›
╰─# mkdir rootfs
╭─root@sg-02 ~/docker-debian-artifacts/buster ‹dist-amd64*›
╰─# tar -xvf rootfs.tar.xz -C !$
╭─root@sg-02 ~/docker-debian-artifacts/buster ‹dist-amd64*›
╰─# ls rootfs/
bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
╭─root@sg-02 ~/docker-debian-artifacts/buster ‹dist-amd64*›
╰─# du -sh rootfs
125M    rootfs
╭─root@sg-02 ~/docker-debian-artifacts/buster ‹dist-amd64*›
╰─# du -sh slim/rootfs
76M     slim/rootfs
```

想要自己构建一个 `debian:buster` 基础镜像其实很简单，就像下面这样一把梭操作下来就行😂：

```shell
git clone https://github.com/debuerreotype/docker-debian-artifacts debian
cd !$
git checkout dist-amd64
cd buster
docker build -t debian:buster .
```

下面就是构建 Debian 基础镜像的过程，正如 Dockerfile 中的那样，最终只产生了一层镜像。

```shell
docker build -t debian:buster .
Sending build context to Docker daemon  30.12MB
Step 1/3 : FROM scratch
 --->
Step 2/3 : ADD rootfs.tar.xz /
 ---> 1756d6a585ae
Step 3/3 : CMD ["bash"]
 ---> Running in c86a8b6deb3d
Removing intermediate container c86a8b6deb3d
 ---> 04948daa3c2e
Successfully built 04948daa3c2e
Successfully tagged debian:buster
```

## 镜像是怎样存放的 （一）本地存储 🙄

当我们构建完一个镜像之后，镜像就存储在了我们 docker 本地存储目录，默认情况下为 `/var/lib/docker` ，下面就探寻一下镜像是以什么样的目录结构存放的。在开始 hack 之前我们先统一一下环境信息，我使用的机器是 Ubuntu 1804，`docker info` 信息如下：

```yaml
╭─root@sg-02 /var/lib/docker
╰─# docker info
Client:
 Debug Mode: false
 Plugins:
  buildx: Build with BuildKit (Docker Inc., v0.3.1-tp-docker)
  app: Docker Application (Docker Inc., v0.8.0)
Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 2
 Server Version: 19.03.5
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
 containerd version: b34a5c8af56e510852c35414db4c1f4fa6172339
 runc version: 3e425f80a8c931f88e6d94a8c831b9d5aa481657
 init version: fec3683
 Security Options:
  apparmor
  seccomp
   Profile: default
 Kernel Version: 4.15.0-1052-aws
 Operating System: Ubuntu 18.04.1 LTS
 OSType: linux
 Architecture: x86_64
 CPUs: 1
 Total Memory: 983.9MiB
 Name: sg-02
 ID: B7J5:Y7ZM:Y477:7AS6:WMYI:6NLV:YOMA:W32Y:H4NZ:UQVD:XHDX:Y5EF
 Docker Root Dir: /opt/docker
 Debug Mode: false
 Username: webpsh
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Registry Mirrors:
  https://registry.k8s.li/
 Live Restore Enabled: false
```

为了方便分析，我将其他的 docker image 全部清空掉，只保留 `debian:v1` 和 `debian:v2` 这两个镜像，这两个镜像足够帮助我们理解容器镜像是如何存放的，镜像多了多话分析下面存储目录的时候可能不太方便（＞﹏＜），这两个镜像是我们之前使用 Debian 的 `rootfs.tar.xz` 构建出来的基础镜像。

```shell
╭─root@sg-02 /var/lib/docker
╰─# docker images
REPOSITORY       TAG         IMAGE ID            CREATED             SIZE
debian           v2          e6e782a57a51        22 hours ago        69.2MB
debian           v1          cfba37fd24f8        22 hours ago        69.2MB
```

### docker (/var/lib/docker)

```shell
╭─root@sg-02 /var/lib/docker
╰─# tree -d -L 1
.
├── builder
├── buildkit
├── containers
├── image
├── network
├── overlay2
├── plugins
├── runtimes
├── swarm
├── tmp
├── trust
└── volumes

12 directories
```

根据目录的名字我们可以大致推断出关于容器镜像的存储，我们只关心 image 和 overlay2 这两个文件夹即可，容器的元数据存放在 image 目录下，容器的 layer 数据则存放在 overlay2 目录下。

### /var/lib/docker/image

overlay2 代表着本地 docker 存储使用的是 overlay2 该存储驱动，目前最新版本的 docker 默认优先采用 **overlay2** 作为存储驱动，对于已支持该驱动的 Linux 发行版，不需要任何进行任何额外的配置，可使用 lsmod 命令查看当前系统内核是否支持 overlay2 。

另外值得一提的是`devicemapper` 存储驱动已经在 docker 18.09 版本中被废弃，docker 官方推荐使用 `overlay2` 替代`devicemapper`。（之前我老东家用的 docker 1.13 版本，`devicemapper`的存储驱动在生产环境翻过车😂。所以呢，都 2020 年了，当你使用 baidu 这种垃圾搜素引擎去搜索 “CentOS 安装 docker” 时它会给你一堆垃圾的教程，叫你去安装 `device-mapper-persistent-data lvm2`，对于这种抄来抄去的博客平台，离得越远越好。

```shell
image
└── overlay2
    ├── distribution
    │   ├── diffid-by-digest
    │   │   └── sha256
    │   │       ├── 039b991354af4dcbc534338f687e27643c717bb57e11b87c2e81d50bdd0b2376
    │   │       ├── 09a4142c5c9dde2fbf35e7a6e6475eba75a8c28540c375c80be7eade4b7cb438
    │   └── v2metadata-by-diffid
    │       └── sha256
    │           ├── 0683de2821778aa9546bf3d3e6944df779daba1582631b7ea3517bb36f9e4007
    │           ├── 0f7493e3a35bab1679e587b41b353b041dca1e7043be230670969703f28a1d83
    ├── imagedb
    │   ├── content
    │   │   └── sha256
    │   │       ├── 708bc6af7e5e539bdb59707bbf1053cc2166622f5e1b17666f0ba5829ca6aaea
    │   │       └── f70734b6a266dcb5f44c383274821207885b549b75c8e119404917a61335981a
    │   └── metadata
    │       └── sha256
    ├── layerdb
    │   ├── mounts
    │   ├── sha256
    │   │   ├── b9835d6a62886d4e85b65abb120c0ea44ff1b3d116d7a707620785d4664d8c1a
    │   │   │   ├── cache-id
    │   │   │   ├── diff
    │   │   │   ├── parent
    │   │   │   ├── size
    │   │   │   └── tar-split.json.gz
    │   │   └── d9b567b77bcdb9d8944d3654ea9bb5f6f4f7c4d07a264b2e40b1bb09af171dd3
    │   │       ├── cache-id
    │   │       ├── diff
    │   │       ├── parent
    │   │       ├── size
    │   │       └── tar-split.json.gz
    │   └── tmp
    └── repositories.json
21 directories, 119 files
```

- `repositories.json`

repositories.json 就是存储镜像元数据信息，主要是 image name 和 image id 的对应，digest 和 image id 的对应。当 pull 完一个镜像的时候 docker 会更新这个文件。当我们 docker run 一个容器的时候也用到这个文件去索引本地是否存在该镜像，没有镜像的话就自动去 pull 这个镜像。

```json
╭─root@sg-02 /var/lib/docker/image/overlay2
╰─# jq "." repositories.json
{
  "Repositories": {
    "debian": {
      "debian:v1": "sha256:cfba37fd24f80f59e5d7c1f7735cae7a383e887d8cff7e2762fdd78c0d73568d",
      "debian:v2": "sha256:e6e782a57a51d01168907938beb5cd5af24fcb7ebed8f0b32c203137ace6d3df"
    },
    "localhost:5000/library/debian": {
      "localhost:5000/library/debian:v1": "sha256:cfba37fd24f80f59e5d7c1f7735cae7a383e887d8cff7e2762fdd78c0d73568d",
      "localhost:5000/library/debian:v2": "sha256:e6e782a57a51d01168907938beb5cd5af24fcb7ebed8f0b32c203137ace6d3df",
      "localhost:5000/library/debian@sha256:b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239": "sha256:cfba37fd24f80f59e5d7c1f7735cae7a383e887d8cff7e2762fdd78c0d73568d",
      "localhost:5000/library/debian@sha256:c805f078bb47c575e9602b09af7568eb27fd1c92073199acba68c187bc5bcf11": "sha256:e6e782a57a51d01168907938beb5cd5af24fcb7ebed8f0b32c203137ace6d3df"
    },
    "registry": {
      "registry:latest": "sha256:708bc6af7e5e539bdb59707bbf1053cc2166622f5e1b17666f0ba5829ca6aaea",
      "registry@sha256:7d081088e4bfd632a88e3f3bcd9e007ef44a796fddfe3261407a3f9f04abe1e7": "sha256:708bc6af7e5e539bdb59707bbf1053cc2166622f5e1b17666f0ba5829ca6aaea"
    }
  }
}
```

-   distribution 目录下

存放着 layer 的 diff_id 和 digest 的对应关系

diffid-by-digest :存放 `digest` 到 `diffid` 的对应关系

v2metadata-by-diffid : 存放 `diffid` 到 `digest` 的对应关系

```
    ├── distribution
    │   ├── diffid-by-digest
    │   │   └── sha256
    │   │       ├── 039b991354af4dcbc534338f687e27643c717bb57e11b87c2e81d50bdd0b2376
    │   │       ├── 09a4142c5c9dde2fbf35e7a6e6475eba75a8c28540c375c80be7eade4b7cb438
    │   └── v2metadata-by-diffid
    │       └── sha256
    │           ├── 0683de2821778aa9546bf3d3e6944df779daba1582631b7ea3517bb36f9e4007
    │           ├── 0f7493e3a35bab1679e587b41b353b041dca1e7043be230670969703f28a1d83
```

-   imagedb

```shell
    ├── imagedb
    │   ├── content
    │   │   └── sha256
    │   │       ├── 708bc6af7e5e539bdb59707bbf1053cc2166622f5e1b17666f0ba5829ca6aaea
    │   │       └── f70734b6a266dcb5f44c383274821207885b549b75c8e119404917a61335981a
    │   └── metadata
    │       └── sha256
```

-   layerdb

```shell
    ├── layerdb
    │   ├── mounts
    │   ├── sha256
    │   │   ├── b9835d6a62886d4e85b65abb120c0ea44ff1b3d116d7a707620785d4664d8c1a
    │   │   │   ├── cache-id  # docker 下载镜像时随机生成的 id
    │   │   │   ├── diff # 存放 layer 的 diffid
    │   │   │   ├── parent # 放当前 layer 的父 layer 的 diffid，最底层的 layer 没有这个文件
    │   │   │   ├── size # 该 layer 的大小
    │   │   │   └── tar-split.json.gz
```

需要注意的是：tar-split.json.gz 文件是 layer tar 包的 split 文件，记录了 layer 解压后的文件在 tar 包中的位置（偏移量），通过这个文件可以还原 layer 的 tar 包，在 docker save 导出 image 的时候会用到，由根据它可以开倒车把解压的 layer 还原回 tar 包。详情可参考 [tar-split]( https://github.com/vbatts/tar-split)

### /var/lib/docker/overlay2

```shell
overlay2
├── 259cf6934509a674b1158f0a6c90c60c133fd11189f98945c7c3a524784509ff
│   └── diff
│       ├── bin
│       ├── dev
│       ├── etc
│       ├── home
│       ├── lib
│       ├── media
│       ├── mnt
│       ├── opt
│       ├── proc
│       ├── root
│       ├── run
│       ├── sbin
│       ├── srv
│       ├── sys
│       ├── tmp
│       ├── usr
│       └── var
├── 27f9e9b74a88a269121b4e77330a665d6cca4719cb9a58bfc96a2b88a07af805
│   ├── diff
│   └── work
├── a0df3cc902cfbdee180e8bfa399d946f9022529d12dba3bc0b13fb7534120015
│   ├── diff
│   │   └── bin
│   └── work
├── b2fbebb39522cb6f1f5ecbc22b7bec5e9bc6ecc25ac942d9e26f8f94a028baec
│   ├── diff
│   │   ├── etc
│   │   ├── lib
│   │   ├── usr
│   │   └── var
│   └── work
├── be8c12f63bebacb3d7d78a09990dce2a5837d86643f674a8fd80e187d8877db9
│   ├── diff
│   │   └── etc
│   └── work
├── e8f6e78aa1afeb96039c56f652bb6cd4bbd3daad172324c2172bad9b6c0a968d
│   └── diff
│       ├── bin
│       ├── dev
│       ├── etc
│       ├── home
│       ├── lib
│       ├── media
│       ├── mnt
│       ├── proc
│       ├── root
│       ├── run
│       ├── sbin
│       ├── srv
│       ├── sys
│       ├── tmp
│       ├── usr
│       └── var
└── l
    ├── 526XCHXRJMZXRIHN4YWJH2QLPY -> ../b2fbebb39522cb6f1f5ecbc22b7bec5e9bc6ecc25ac942d9e26f8f94a028baec/diff
    ├── 5RZOXYR35NSGAWTI36CVUIRW7U -> ../be8c12f63bebacb3d7d78a09990dce2a5837d86643f674a8fd80e187d8877db9/diff
    ├── LBWRL4ZXGBWOTN5JDCDZVNOY7H -> ../a0df3cc902cfbdee180e8bfa399d946f9022529d12dba3bc0b13fb7534120015/diff
    ├── MYRYBGZRI4I76MJWQHN7VLZXLW -> ../27f9e9b74a88a269121b4e77330a665d6cca4719cb9a58bfc96a2b88a07af805/diff
    ├── PCIS4FYUJP4X2D4RWB7ETFL6K2 -> ../259cf6934509a674b1158f0a6c90c60c133fd11189f98945c7c3a524784509ff/diff
    └── XK5IA4BWQ2CIS667J3SXPXGQK5 -> ../e8f6e78aa1afeb96039c56f652bb6cd4bbd3daad172324c2172bad9b6c0a968d/diff
```

在 `/var/lib/docker/overlay2` 目录下，我们可以看到，镜像 layer 的内容都存放在一个 `diff` 的文件夹下，diff 的上级目录就是以镜像 layer 的 digest 为名的目录。其中还有个 `l` 文件夹，下面有一坨坨的硬链接文件指向上级目录的 layer 目录。这个 l 其实就是 link 的缩写，l 下的文件都是一些比 digest 文件夹名短一些的，方面不至于 mount 的参数过长。

## 镜像是怎么搬运的🤣

当我们在本地构建完成一个镜像之后，如何传递给他人呢？这就涉及到镜像是怎么搬运的一些知识，搬运镜像就像我们在 GitHub 上搬运代码一样，docker 也有类似于 git clone 和 git push 的搬运方式。docker push 就和我们使用 git push 一样，将本地的镜像推送到一个称之为 registry 的镜像仓库，这个 registry 镜像仓库就像 GitHub 用来存放公共/私有的镜像，一个中心化的镜像仓库方便大家来进行交流和搬运镜像。docker pull 就像我们使用 git pull 一样，将远程的镜像拉拉取本地。

### docker pull

理解 docker pull 一个镜像的流程最好的办法是查看 OCI registry 规范中的这段文档 [pulling-an-image](https://github.com/opencontainers/distribution-spec/blob/master/spec.md#pulling-an-image) ，在这里我结合大佬的博客简单梳理一下 pull 一个镜像的大致流程。下面这张图是从 [浅谈docker中镜像和容器在本地的存储)](https://github.com/helios741/myblog/blob/new/learn_go/src/2019/20191206_docker_disk_storage/README.md) 借来的😂

![](https://user-images.githubusercontent.com/12036324/70367494-646d2380-18db-11ea-992a-d2bca4cbfeb0.png)

docker pull 就和我们使用 git clone 一样效果，将远程的镜像仓库拉取到本地来给容器运行时使用，结合上图大致的流程如下：

-   第一步应该是使用`~/.docker/config.json` 中的 auth 认证信息在 registry 那里进行鉴权授权，拿到一个 token，后面的所有的 HTTP 请求中都要包含着该 token 才能有权限进行操作。

```json
╭─root@sg-02 /home/ubuntu
╰─# cat ~/.docker/config.json
{
        "auths": {
                "https://registry.k8s.li/v2/": {
                        "auth": "d2VicH855828WM7bSVsslJFpmQE43Sw=="
                }
        },
        "HttpHeaders": {
                "User-Agent": "Docker-Client/19.03.5 (linux)"
        },
        "experimental": "enabled"
}
```

-   dockerd 守护进程解析 docker 客户端参数，由镜像名 + tag 向 registry 请求 Manifest 文件，HTTP 请求为`GET /v2/<name>/manifests/<reference>`。registry 中一个镜像有多个 tag 或者多个处理器体系架构的镜像，则根据这个 tag 来返回给客户端与之对应的  manifest 文件；

```json
GET /v2/<name>/manifests/<reference>
{
   "annotations": {
      "com.example.key1": "value1",
      "com.example.key2": "value2"
   },
   "config": {
      "digest": "sha256:6f4e69a5ff18d92e7315e3ee31c62165ebf25bfa05cad05c0d09d8f412dae401",
      "mediaType": "application/vnd.oci.image.config.v1+json",
      "size": 452
   },
   "layers": [
      {
         "digest": "sha256:6f4e69a5ff18d92e7315e3ee31c62165ebf25bfa05cad05c0d09d8f412dae401",
         "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
         "size": 78343
      }
   ],
   "schemaVersion": 2
}
```

-   dockerd 得到 `manifest` 后，读取里面 image config 文件的 `digest`，这个 sha256 值就是 image 的 `ID`
-   根据 `ID` 在本地的 `repositories.json`中查找找有没有存在同样 `ID` 的 image，有的话就不用下载了
-   如果没有，那么会给 registry 服务器发请求拿到  image config 文件
-   根据 image config 文件中的 `diff_ids`在本地找对应的 layer 是否存在
-   如果 layer 不存在，则根据 `manifest` 里面 layer 的 `sha256` 和 `media type` 去服务器拿相应的 layer（相当去拿压缩格式的包）
-   dockerd 守护进程并行下载各 layer ，HTTP 请求为`GET /v2/<name>/blobs/<digest>`。 
-   拿到后进行解压，并检查解压(gzip -d)后 tar 包的 sha256 是否和 image config 中的 `diff_id` 相同，不相同就翻车了
-   等所有的 layer 都下载完成后，整个 image 的 layer 就下载完成，接着开始进行解压(tar -xf) layer 的 tar 包。
-   dockerd 起一个单独的进程 `docker-untar` 来 gzip 解压缩已经下载完成的 layer 文件；对于有些比较大的镜像（比如几十 GB 的镜像），往往镜像的 layer 已经下载完成了，但还没有解压完😂。

```shell
docker-untar /var/lib/docker/overlay2/a076db6567c7306f3cdab6040cd7d083ef6a39d125171353eedbb8bde7f203b4/diff
```

-   验证 image config 中的 RootFS.DiffIDs 是否与下载（解压后）hash 相同；


### docker push

push 推送一个镜像到远程的 registry 流程恰好和 pull 拉取镜像到本地的流程相反。我们 pull 一个镜像的时候往往需要先获取包含着镜像 layer 信息的 Manifest 文件，然后根据这个文件中的 layer 信息取 pull 相应的 layer。push 一个镜像，需要先将镜像的各个 layer 推送到 registry ，当所有的镜像 layer 上传完毕之后最后再 push Image Manifest 到 registry。大体的流程如下：

>   All layer uploads use two steps to manage the upload process. The first step starts the upload in the registry service, returning a url to carry out the second step. The second step uses the upload url to transfer the actual data. Uploads are started with a POST request which returns a url that can be used to push data and check upload status.

-   第一步和 pull 一个镜像一样也是进行鉴权授权，拿到一个 token；

-   向 registry 发送 `POST /v2/<name>/blobs/uploads/`请求，registry 返回一个上传镜像 layer 时要应到的 URL；

-   客户端通过 `HEAD /v2/<name>/blobs/<digest>` 请求检查 registry 中是否已经存在镜像的 layer。

-   客户端通过URL 使用 POST 方法来实时上传 layer 数据，上传镜像 layer 分为 `Monolithic Upload` （整体上传）和`Chunked Upload`（分块上传）两种方式。

    -   Monolithic Upload 

    ```http
    PUT /v2/<name>/blobs/uploads/<session_id>?digest=<digest>
    Content-Length: <size of layer>
    Content-Type: application/octet-stream
    
    <Layer Binary Data>
    ```

    -   Chunked Upload

    ```http
    PATCH /v2/<name>/blobs/uploads/<session_id>
    Content-Length: <size of chunk>
    Content-Range: <start of range>-<end of range>
    Content-Type: application/octet-stream
    
    <Layer Chunk Binary Data>
    ```

-   镜像的 layer 上传完成之后，客户端需要向 registry 发送一个 PUT HTTP 请求告知该 layer 已经上传完毕。

```http
PUT /v2/<name>/blobs/uploads/<session_id>?digest=<digest>
Content-Length: <size of chunk>
Content-Range: <start of range>-<end of range>
Content-Type: application/octet-stream

<Last Layer Chunk Binary Data>
```

-   最后当所有的 layer 上传完之后，客户端再将 manifest 推送上去就完事儿了。

```json
PUT /v2/<name>/manifests/<reference>
Content-Type: <manifest media type>

{
   "annotations": {
      "com.example.key1": "value1",
      "com.example.key2": "value2"
   },
   "config": {
      "digest": "sha256:6f4e69a5ff18d92e7315e3ee31c62165ebf25bfa05cad05c0d09d8f412dae401",
      "mediaType": "application/vnd.oci.image.config.v1+json",
      "size": 452
   },
   "layers": [
      {
         "digest": "sha256:6f4e69a5ff18d92e7315e3ee31c62165ebf25bfa05cad05c0d09d8f412dae401",
         "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
         "size": 78343
      }
   ],
   "schemaVersion": 2
}
```

### Python [docker-drag](https://github.com/NotGlop/docker-drag)

这是一个很简单粗暴的 Python 脚本，使用 request 库请求 registry API 来从镜像仓库中拉取镜像，并保存为一个 tar 包，拉完之后使用 docker load 加载一下就能食用啦。该 python 脚本简单到去掉空行和注释不到 200 行，如果把这个脚本源码读一遍的话就能大概知道 docker pull 和 skopeo copy 的一些原理，他们都是去调用 registry 的 API ，所以还是推荐去读一下这个它的源码。

食用起来也很简单直接 `python3 docker_pull.py [image name]`，貌似只能拉取 docker.io 上的镜像。

```shell
╭─root@sg-02 /home/ubuntu
╰─# wget https://raw.githubusercontent.com/NotGlop/docker-drag/master/docker_pull.py
╭─root@sg-02 /home/ubuntu
╰─# python3 docker_pull.py nginx
Creating image structure in: tmp_nginx_latest
afb6ec6fdc1c: Pull complete [27098756]
dd3ac8106a0b: Pull complete [26210578]                                       ]
8de28bdda69b: Pull complete [538]
a2c431ac2669: Pull complete [900]
e070d03fd1b5: Pull complete [669]
Docker image pulled: library_nginx.tar
╭─root@sg-02 /home/ubuntu
╰─# docker load -i library_nginx.tar
ffc9b21953f4: Loading layer [==================================================>]  72.49MB/72.49MB
d9c0b16c8d5b: Loading layer [==================================================>]  63.81MB/63.81MB
8c7fd6263c1f: Loading layer [==================================================>]  3.072kB/3.072kB
077ae58ac205: Loading layer [==================================================>]  4.096kB/4.096kB
787328500ad5: Loading layer [==================================================>]  3.584kB/3.584kB
Loaded image: nginx:latest
```

### skopeo

这个工具是红帽子家的，是 Podman、Skopeo 和 Buildah （简称 PSB ）下一代容器新架构中的一员，不过木子觉着 Podman 想要取代 docker 和 containerd 容器运行时还有很长的路要走，虽然它符合 OCI 规范，但对于企业来讲，替换的成本并不值得他们去换到 PSB 上去。

其中的 skopeo 这个镜像搬运工具简直是个神器，尤其是在 CI/CD 流水线中搬运两个镜像仓库里的镜像简直爽的不得了。我入职新公司后做的一个工作就是优化我们的 Jenkins 流水线中同步两个镜像仓库的过程，使用 了skopeo 替代 docker 来同步两个镜像仓库中的镜像，将原来需要 2h 小时缩短到了 25min 😀。

关于这个工具的详细使用推荐大家去读一下我之前写的一篇博客 [镜像搬运工 skopeo 初体验](https://blog.k8s.li/skopeo.html) 。在这里只讲两个木子最常用的功能。

#### skopeo copy

使用 skopeo copy 两个 registry 中的镜像时，skopeo 请求两个 registry API 直接 copy `original blob` 到另一个 registry ，这样免去了像 docker pull –> docker tag –> docker push 那样 pull 镜像对镜像进行解压缩，push 镜像进行压缩。尤其是在搬运一些较大的镜像（几GB 或者几十 GB的镜像，比如 `nvidia/cuda` ），使用 skopeo copy 的加速效果十分明显。

```shell
DEBU[0000] Detected compression format gzip
DEBU[0000] Using original blob without modification

Getting image source signatures
Copying blob 09a9f6a07669 done
Copying blob f8cdeb3c6c18 done
Copying blob 22c4d5853f25 done
Copying blob 76abc3f50d9b done
Copying blob 3386b7c9ccd4 done
Copying blob b9207193f1af [==============================>-------] 224.2MiB / 271.2MiB
Copying blob 2f32d819e6ce done
Copying blob 5dbc3047e646 done
Copying blob f8dfcc3265c3 [==================>-------------------] 437.1MiB / 864.3MiB
Copying blob 13d3556105d1 done
Copying blob f9b7fa6a027e [=========================>------------] 84.0MiB / 124.3MiB
Copying blob a1a0f6abe73b [====================>-----------------] 417.9MiB / 749.1MiB
Copying blob bcc9947fc8a4 done
Copying blob 9563b2824fef done
Copying blob a1b8faa0044b [===>----------------------------------] 88.0MiB / 830.1MiB
Copying blob 9917e218edfd [===============>----------------------] 348.6MiB / 803.6MiB
Copying blob 776b9ff2f788 done
Copying config d0c3cfd730 done
Writing manifest to image destination
Storing signatures
```

#### skopeo inspect

用 skopeo inspect 命令可以很方方便地通过 registry 的 API 来查看镜像的 manifest 文件，以前我都是用 curl 命令的，要 token 还要加一堆参数，所以比较麻烦，所以后来就用上了  skopeo inspect😀。

```json
root@deploy:/root # skopeo inspect docker://index.docker.io/webpsh/webps:latest --raw
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
   "config": {
      "mediaType": "application/vnd.docker.container.image.v1+json",
      "size": 2534,
      "digest": "sha256:30d9679b0b1ca7e56096eca0cdb7a6eedc29b63968f25156ef60dec27bc7d206"
   },
   "layers": [
      {
         "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
         "size": 2813316,
         "digest": "sha256:cbdbe7a5bc2a134ca8ec91be58565ec07d037386d1f1d8385412d224deafca08"
      },
      {
         "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
         "size": 8088920,
         "digest": "sha256:54335262c2ed2d4155e62b45b187a1394fbb6f39e0a4a171ab8ce0c93789e6b0"
      },
      {
         "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
         "size": 262,
         "digest": "sha256:31555b34852eddc7c01f26fa9c0e5e577e36b4e7ccf1b10bec977eb4593a376b"
      }
   ]
}
```

## 镜像是怎么存放的 (二) registry 存储🙄

文章的开头我们提到过 OCI 规范中的镜像仓库规范 [distribution-spec](https://github.com/opencontainers/distribution-spec)，该规范就定义着容器镜像如何存储在远端（即 registry）上。我们可以把 registry 看作镜像的仓库，使用该规范可以帮助我们把这些镜像按照约定俗成的格式来存放，目前实现该规范的 registry 就 docker 家的 registry 使用的多一些。其他的 registry 比如 harbor ，quay.io 使用的也比较多。

### registry (/registry/docker/v2)

想要分析一下镜像是如何存放在 registry 上的，我们在本地使用 docker run 来起 registry 的容器即可，我们仅仅是来分析 registry 中镜像时如何存储的，这种场景下不太适合用 harbor 这种重量级的 registry 。

```shell
╭─root@sg-02 /home/ubuntu
╰─# docker run -d --name registry -p 5000:5000 -v /var/lib/registry:/var/lib/registry registry
335ea763a2fa4508ebf3ec6f8b11f3b620a11bdcaa0ab43176b781427e0beee6
```

启动完 registry 容器之后我们给之前已经构建好的镜像重新打上改 registry 的 tag 方便后续 push 到 registry 上。

```shell
╭─root@sg-02 ~/buster/slim
╰─# docker tag debian:v1  localhost:5000/library/debian:v1
╭─root@sg-02 ~/buster/slim
╰─# ^v1^v2
╭─root@sg-02 ~/buster/slim
╰─# docker tag debian:v2  localhost:5000/library/debian:v2
╭─root@sg-02 ~/buster/slim
╰─# docker images
REPOSITORY                      TAG                 IMAGE ID            CREATED             SIZE
debian                          v2                  e6e782a57a51        5 minutes ago       69.2MB
localhost:5000/library/debian   v2                  e6e782a57a51        5 minutes ago       69.2MB
debian                          v1                  cfba37fd24f8        9 minutes ago       69.2MB
localhost:5000/library/debian   v1                  cfba37fd24f8        9 minutes ago       69.2MB
╭─root@sg-02 ~/buster/slim
╰─# docker push localhost:5000/library/debian:v1
The push refers to repository [localhost:5000/library/debian]
d1b85e6186f6: Pushed
v1: digest: sha256:b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239 size: 529
╭─root@sg-02 ~/buster/slim
╰─# docker push localhost:5000/library/debian:v2
The push refers to repository [localhost:5000/library/debian]
d1b85e6186f6: Layer already exists
v2: digest: sha256:c805f078bb47c575e9602b09af7568eb27fd1c92073199acba68c187bc5bcf11 size: 529
```

当我们在本地启动一个 registry 容器之后，容器内默认的存储位置为 `/var/lib/registry` ，所以我们在启动的时候加了参数 `-v /var/lib/registry:/var/lib/registry` 将本机的路径挂载到容器内。进入这里路径我们使用 tree 命令查看一下这个目录的存储结构。

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# tree -h
.
├── [4.0K]  blobs
│   └── [4.0K]  sha256
│       ├── [4.0K]  aa
│       │   └── [4.0K]  aaae33815489895f602207ac5a583422b8a8755b3f67fc6286ca9484ba685bdb
│       │       └── [ 26M]  data
│       ├── [4.0K]  b9
│       │   └── [4.0K]  b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239
│       │       └── [ 529]  data
│       ├── [4.0K]  c8
│       │   └── [4.0K]  c805f078bb47c575e9602b09af7568eb27fd1c92073199acba68c187bc5bcf11
│       │       └── [ 529]  data
│       ├── [4.0K]  cf
│       │   └── [4.0K]  cfba37fd24f80f59e5d7c1f7735cae7a383e887d8cff7e2762fdd78c0d73568d
│       │       └── [1.4K]  data
│       └── [4.0K]  e6
│           └── [4.0K]  e6e782a57a51d01168907938beb5cd5af24fcb7ebed8f0b32c203137ace6d3df
│               └── [1.4K]  data
└── [4.0K]  repositories
    └── [4.0K]  library
        └── [4.0K]  debian
            ├── [4.0K]  _layers
            │   └── [4.0K]  sha256
            │       ├── [4.0K]  aaae33815489895f602207ac5a583422b8a8755b3f67fc6286ca9484ba685bdb
            │       │   └── [  71]  link
            │       ├── [4.0K]  cfba37fd24f80f59e5d7c1f7735cae7a383e887d8cff7e2762fdd78c0d73568d
            │       │   └── [  71]  link
            │       └── [4.0K]  e6e782a57a51d01168907938beb5cd5af24fcb7ebed8f0b32c203137ace6d3df
            │           └── [  71]  link
            ├── [4.0K]  _manifests
            │   ├── [4.0K]  revisions
            │   │   └── [4.0K]  sha256
            │   │       ├── [4.0K]  b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239
            │   │       │   └── [  71]  link
            │   │       └── [4.0K]  c805f078bb47c575e9602b09af7568eb27fd1c92073199acba68c187bc5bcf11
            │   │           └── [  71]  link
            │   └── [4.0K]  tags
            │       ├── [4.0K]  v1
            │       │   ├── [4.0K]  current
            │       │   │   └── [  71]  link
            │       │   └── [4.0K]  index
            │       │       └── [4.0K]  sha256
            │       │           └── [4.0K]  b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239
            │       │               └── [  71]  link
            │       └── [4.0K]  v2
            │           ├── [4.0K]  current
            │           │   └── [  71]  link
            │           └── [4.0K]  index
            │               └── [4.0K]  sha256
            │                   └── [4.0K]  c805f078bb47c575e9602b09af7568eb27fd1c92073199acba68c187bc5bcf11
            │                       └── [  71]  link
            └── [4.0K]  _uploads

37 directories, 14 files
```

树形的结构看着不太直观，木子就画了一张层级结构的图：

![](https://p.k8s.li/registry-storage.jpeg)

### blobs 目录

之前我们向 registry 种推送了两个镜像，这两个镜像的 layer 相同但不是用一个镜像，在我们之前 push image 的时候也看到了 `d1b85e6186f6: Layer already exists`。也就可以证明了，虽然两个镜像不同，但它们的 layer 在 registry 中存储的时候可能是相同的。

在 `blobs/sha256` 目录下一共有 5 个名为 data 的文件，我们可以推测一下最大的那个 `[ 26M]` 应该是镜像的 layer ，最小的 `[ 529]` 那个应该是 manifest，剩下的那个 `[1.4K]` 应该就是 image config 文件。

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2/blobs/sha256
╰─# tree -h
.
├── [4.0K]  aa
│   └── [4.0K]  aaae33815489895f602207ac5a583422b8a8755b3f67fc6286ca9484ba685bdb
│       └── [ 26M]  data
├── [4.0K]  b9
│   └── [4.0K]  b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239
│       └── [ 529]  data
├── [4.0K]  c8
│   └── [4.0K]  c805f078bb47c575e9602b09af7568eb27fd1c92073199acba68c187bc5bcf11
│       └── [ 529]  data
├── [4.0K]  cf
│   └── [4.0K]  cfba37fd24f80f59e5d7c1f7735cae7a383e887d8cff7e2762fdd78c0d73568d
│       └── [1.4K]  data
└── [4.0K]  e6
    └── [4.0K]  e6e782a57a51d01168907938beb5cd5af24fcb7ebed8f0b32c203137ace6d3df
        └── [1.4K]  data
```

在 `registry` 的存储目录下，`blobs` 目录用来存放镜像的三种文件： layer 的真实数据，镜像的 manifest 文件，镜像的 image config 文件。这些文件都是以 `data` 为名的文件存放在于该文件 `sha256` 相对应的目录下。 使用以内容寻址的 `sha256` 散列存储方便索引文件，在 `blob digest` 目录下有一个名为 `data`的文件，对于 layer 来讲，这是个 `data` 文件的格式是 `vnd.docker.image.rootfs.diff.tar.gzip` ，我们可以使用 `tar -xvf` 命令将这个 layer 解开。当我们使用 docker pull 命令拉取镜像的时候，也是去下载这个 `data`文件，下载完成之后会有一个 `docker-untar`的进程将这个 `data`文件解开存放在`/var/lib/docker/overlay2/${digest}/diff` 目录下。

```shell
├── [4.0K]  blobs
│   └── [4.0K]  sha256
│       ├── [4.0K]  aa
│       │   └── [4.0K]  aaae33815489895f602207ac5a583422b8a8755b3f67fc6286ca9484ba685bdb
│       │       └── [ 26M]  data
```

#### manifest 文件

就是一个普通的 json 文件啦，记录了一个镜像所包含的 layer 信息，当我们 pull 镜像的时候会使用到这个文件。

```json
╭─root@sg-02 /var/lib/registry/docker/registry/v2/blobs/sha256/b9/b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239
╰─# cat data
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
   "config": {
      "mediaType": "application/vnd.docker.container.image.v1+json",
      "size": 1462,
      "digest": "sha256:cfba37fd24f80f59e5d7c1f7735cae7a383e887d8cff7e2762fdd78c0d73568d"
   },
   "layers": [
      {
         "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
         "size": 27097859,
         "digest": "sha256:aaae33815489895f602207ac5a583422b8a8755b3f67fc6286ca9484ba685bdb"
      }
   ]
}#
```

#### image config 文件

image config 文件里并没有包含镜像的 tag 信息。

```json
╭─root@sg-02 /var/lib/registry/docker/registry/v2/blobs/sha256/e6/e6e782a57a51d01168907938beb5cd5af24fcb7ebed8f0b32c203137ace6d3df
╰─# cat data | jq "."
{
  "architecture": "amd64",
  "config": {
    "Hostname": "",
    "Domainname": "",
    "User": "",
    "AttachStdin": false,
    "AttachStdout": false,
    "AttachStderr": false,
    "Tty": false,
    "OpenStdin": false,
    "StdinOnce": false,
    "Env": [
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    ],
    "Cmd": [
      "bash"
    ],
    "Image": "sha256:ba8f577813c7bdf6b737f638dffbc688aa1df2ff28a826a6c46bae722977b549",
    "Volumes": null,
    "WorkingDir": "",
    "Entrypoint": null,
    "OnBuild": null,
    "Labels": null
  },
  "container": "38501d5aa48c080884f4dc6fd4b1b6590ff1607d9e7a12e1cef1d86a3fdc32df",
  "container_config": {
    "Hostname": "38501d5aa48c",
    "Domainname": "",
    "User": "",
    "AttachStdin": false,
    "AttachStdout": false,
    "AttachStderr": false,
    "Tty": false,
    "OpenStdin": false,
    "StdinOnce": false,
    "Env": [
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    ],
    "Cmd": [
      "/bin/sh",
      "-c",
      "#(nop) ",
      "CMD [\"bash\"]"
    ],
    "Image": "sha256:ba8f577813c7bdf6b737f638dffbc688aa1df2ff28a826a6c46bae722977b549",
    "Volumes": null,
    "WorkingDir": "",
    "Entrypoint": null,
    "OnBuild": null,
    "Labels": {}
  },
  "created": "2020-06-07T01:59:47.348924716Z",
  "docker_version": "19.03.5",
  "history": [
    {
      "created": "2020-06-07T01:59:46.877600299Z",
      "created_by": "/bin/sh -c #(nop) ADD file:a82014afc29e7b364ac95223b22ebafad46cc9318951a85027a49f9ce1a99461 in / "
    },
    {
      "created": "2020-06-07T01:59:47.348924716Z",
      "created_by": "/bin/sh -c #(nop)  CMD [\"bash\"]",
      "empty_layer": true
    }
  ],
  "os": "linux",
  "rootfs": {
    "type": "layers",
    "diff_ids": [
      "sha256:d1b85e6186f67d9925c622a7a6e66faa447e767f90f65ae47cdc817c629fa956"
    ]
  }
}
```

#### _uploads 文件夹

_uploads 文件夹是个临时的文件夹，主要用来存放 push 镜像过程中的文件数据，当镜像 `layer` 上传完成之后会清空该文件夹。其中的 `data` 文件上传完毕后会移动到 `blobs` 目录下，根据该文件的 `sha256` 值来进行散列存储到相应的目录下。

上传过程中的目录结构：

```shell
_uploads
├── [  53]  0d6c996e-638f-4436-b2b6-54fa7ad430d2
│   ├── [198M]  data
│   ├── [  20]  hashstates
│   │   └── [  15]  sha256
│   │       └── [ 108]  0
│   └── [  20]  startedat
└── [  53]  ba31818e-4217-47ef-ae46-2784c9222614
    ├── [571M]  data
    ├── [  20]  hashstates
    │   └── [  15]  sha256
    │       └── [ 108]  0
    └── [  20]  startedat

6 directories, 6 files
```

- 上传完镜像之后，`_uploads` 文件夹就会被清空，正常情况下这个文件夹是空的。但也有异常的时候😂，比如网络抖动导致上传意外中断，该文件夹就可能不为空。

```shell
_uploads

0 directories, 0 files
```

#### _manifests 文件夹

`_manifests` 文件夹是镜像上传完成之后由 registry 来生成的，并且该目录下的文件都是一个名为 `link`的文本文件，它的值指向 blobs 目录下与之对应的目录。

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2/repositories/library
╰─# find . -type f
./debian/_layers/sha256/aaae33815489895f602207ac5a583422b8a8755b3f67fc6286ca9484ba685bdb/link
./debian/_layers/sha256/e6e782a57a51d01168907938beb5cd5af24fcb7ebed8f0b32c203137ace6d3df/link
./debian/_layers/sha256/cfba37fd24f80f59e5d7c1f7735cae7a383e887d8cff7e2762fdd78c0d73568d/link
./debian/_manifests/tags/v2/current/link
./debian/_manifests/tags/v2/index/sha256/c805f078bb47c575e9602b09af7568eb27fd1c92073199acba68c187bc5bcf11/link
./debian/_manifests/tags/v1/current/link
./debian/_manifests/tags/v1/index/sha256/b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239/link
./debian/_manifests/revisions/sha256/b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239/link
./debian/_manifests/revisions/sha256/c805f078bb47c575e9602b09af7568eb27fd1c92073199acba68c187bc5bcf11/link
```

`_manifests` 文件夹下包含着镜像的 `tags` 和 `revisions` 信息，每一个镜像的每一个 tag 对应着于 tag 名相同的目录。镜像的 tag 并不存储在 image config 中，而是以目录的形式来形成镜像的 tag，这一点比较奇妙，这和我们 Dockerfile 中并不包含镜像名和 tag 一个道理？

```shell
.
├── [4.0K]  _layers
│   └── [4.0K]  sha256
│       ├── [4.0K]  aaae33815489895f602207ac5a583422b8a8755b3f67fc6286ca9484ba685bdb
│       │   └── [  71]  link
│       ├── [4.0K]  cfba37fd24f80f59e5d7c1f7735cae7a383e887d8cff7e2762fdd78c0d73568d
│       │   └── [  71]  link
│       └── [4.0K]  e6e782a57a51d01168907938beb5cd5af24fcb7ebed8f0b32c203137ace6d3df
│           └── [  71]  link
├── [4.0K]  _manifests
│   ├── [4.0K]  revisions
│   │   └── [4.0K]  sha256
│   │       ├── [4.0K]  b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239
│   │       │   └── [  71]  link
│   │       └── [4.0K]  c805f078bb47c575e9602b09af7568eb27fd1c92073199acba68c187bc5bcf11
│   │           └── [  71]  link
│   └── [4.0K]  tags
│       ├── [4.0K]  v1
│       │   ├── [4.0K]  current
│       │   │   └── [  71]  link
│       │   └── [4.0K]  index
│       │       └── [4.0K]  sha256
│       │           └── [4.0K]  b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239
│       │               └── [  71]  link
│       └── [4.0K]  v2
│           ├── [4.0K]  current
│           │   └── [  71]  link
│           └── [4.0K]  index
│               └── [4.0K]  sha256
│                   └── [4.0K]  c805f078bb47c575e9602b09af7568eb27fd1c92073199acba68c187bc5bcf11
│                       └── [  71]  link
└── [4.0K]  _uploads

22 directories, 9 files
```

#### 镜像的 tag

 每个 `tag`名目录下面有 `current` 目录和 `index` 目录， `current` 目录下的 link 文件保存了该 tag 目前的 manifest 文件的 sha256 编码，对应在 `blobs` 中的 `sha256` 目录下的 `data` 文件，而 `index` 目录则列出了该 `tag` 历史上传的所有版本的 `sha256` 编码信息。`_revisions` 目录里存放了该 `repository` 历史上上传版本的所有 sha256 编码信息。

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2/repositories/library/debian/_manifests/tags/v1
╰─# cat current/link
sha256:b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239
╭─root@sg-02 /var/lib/registry/docker/registry/v2/blobs/sha256
╰─# tree -h
.
├── [4.0K]  aa
│   └── [4.0K]  aaae33815489895f602207ac5a583422b8a8755b3f67fc6286ca9484ba685bdb
│       └── [ 26M]  data
├── [4.0K]  b9
│   └── [4.0K]  b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239
│       └── [ 529]  data
```

当我们 `pull` 镜像的时候如果不指定镜像的 `tag`名，默认就是 latest，registry 会从 HTTP 请求中解析到这个 tag 名，然后根据 tag 名目录下的 link 文件找到该镜像的 manifest 的位置返回给客户端，客户端接着去请求这个 manifest 文件，客户端根据这个 manifest 文件来 pull 相应的镜像 layer 。

```json
╭─root@sg-02 /var/lib/registry/docker/registry/v2/repositories/library/debian/_manifests/tags/v1
╰─# cat  /var/lib/registry/docker/registry/v2/blobs/sha256/b9/b9caca385021f231e15aee34929eac332c49402372a79808d07ee66866792239/data
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
   "config": {
      "mediaType": "application/vnd.docker.container.image.v1+json",
      "size": 1462,
      "digest": "sha256:cfba37fd24f80f59e5d7c1f7735cae7a383e887d8cff7e2762fdd78c0d73568d"
   },
   "layers": [
      {
         "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
         "size": 27097859,
         "digest": "sha256:aaae33815489895f602207ac5a583422b8a8755b3f67fc6286ca9484ba685bdb"
      }
   ]
}
```

最后再补充一点就是，同一个镜像在 registry 中存储的位置是相同的，具体的分析可以参考 [镜像仓库中镜像存储的原理解析](https://supereagle.github.io/2018/04/24/docker-registry/) 这篇博客。

> - 通过 Registry API 获得的两个镜像仓库中相同镜像的 manifest 信息完全相同。
> - 两个镜像仓库中相同镜像的 manifest 信息的存储路径和内容完全相同。
> - 两个镜像仓库中相同镜像的 blob 信息的存储路径和内容完全相同。

从上面这三个结论中我们可以推断出 registry 存储目录里并不会存储与该 registry 相关的信息，比我们 push 镜像的时候需要给镜像加上 `localhost:5000` 这个前缀，这个前缀并不会存储在 registry 存储中。加入我要迁移一个很大的 registry 镜像仓库，镜像的数量在 5k 以上。最便捷的办法就是打包这个 registry 存储目录，将这个 tar 包 rsync 到另一台机器即可。需要强调一点，打包 registry 存储目录的时候不需要进行压缩，直接 `tar -cvf` 即可。因为 registry 存储的镜像 layer 已经是个 `tar.gzip` 格式的文件，再进行压缩的话效果甚微而且还浪费 CPU 时间得不偿失。

### docker-archive

本来我想着 docker save 出来的并不是一个镜像，而是一个 `.tar` 文件，但我想了又想，还是觉着它是一个镜像，只不过存在的方式不同而已。于在 docker 和 registry 中存放的方式不同，使用 docker save 出来的镜像是一个孤立的存在。就像是从蛋糕店里拿出来的蛋糕，外面肯定要有个精美的包装是吧，你总没见过。放在哪里都可以，使用的时候我们使用 docker load 拆开外包装(`.tar`)就可。比如我们离线部署 harbor 的时候就是使用官方的镜像 tar 包来进行加载镜像启动容器的。

## 镜像是怎么食用的😋

当我们拿到一个镜像之后，如果用它来启动一个容器呢？这里就涉及到了 OCI 规范中的另一个规范即运行时规范 [runtime-spec](https://github.com/opencontainers/runtime-spec) 。容器运行时通过一个叫 [ OCI runtime filesytem bundle](https://github.com/opencontainers/runtime-spec/blob/master/bundle.md) 的标准格式将 OCI 镜像通过工具转换为 bundle ，然后 OCI 容器引擎能够识别这个 bundle 来运行容器。

> filesystem bundle 是个目录，用于给 runtime 提供启动容器必备的配置文件和文件系统。标准的容器 bundle 包含以下内容：
>
> - config.json: 该文件包含了容器运行的配置信息，该文件必须存在 bundle 的根目录，且名字必须为 config.json
> - 容器的根目录，可以由 config.json 中的 root.path 指定

![](https://p.k8s.li/20200609_oci-04.jpg)

### docker run

当我们启动一个容器之后我们使用 tree 命令来分析一下 overlay2 就会发现，较之前的目录，容器启动之后 overlay2 目录下多了一个 `merged` 的文件夹，该文件夹就是容器内看到的。docker 通过 overlayfs 联合挂载的技术将镜像的多层 layer 挂载为一层，这层的内容就是容器里所看到的，也就是 merged 文件夹。

```shell
╭─root@sg-02 /var/lib/docker
╰─# tree overlay2 -d -L 3
overlay2
├── 259cf6934509a674b1158f0a6c90c60c133fd11189f98945c7c3a524784509ff
│   └── diff
│       ├── bin
|
│       └── var
├── 27f9e9b74a88a269121b4e77330a665d6cca4719cb9a58bfc96a2b88a07af805
│   ├── diff
│   └── work
├── 5f85c914c55220ec2635bce0080d2ad677f739dcfac4fd266b773625e3051844
│   ├── diff
│   │   └── var
│   ├── merged
│   │   ├── bin
│   │   ├── dev
│   │   ├── etc
│   │   ├── home
│   │   ├── lib
│   │   ├── media
│   │   ├── mnt
│   │   ├── proc
│   │   ├── root
│   │   ├── run
│   │   ├── sbin
│   │   ├── srv
│   │   ├── sys
│   │   ├── tmp
│   │   ├── usr
│   │   └── var
│   └── work
│       └── work
├── 5f85c914c55220ec2635bce0080d2ad677f739dcfac4fd266b773625e3051844-init
│   ├── diff
│   │   ├── dev
│   │   └── etc
│   └── work
│       └── work
```

```shell
overlay on / type overlay (rw,relatime,lowerdir=/opt/docker/overlay2/l/4EPD2X5VF62FH5PZOZHZDKAKGL:/opt/docker/overlay2/l/MYRYBGZRI4I76MJWQHN7VLZXLW:/opt/docker/overlay2/l/5RZOXYR35NSGAWTI36CVUIRW7U:/opt/docker/overlay2/l/LBWRL4ZXGBWOTN5JDCDZVNOY7H:/opt/docker/overlay2/l/526XCHXRJMZXRIHN4YWJH2QLPY:/opt/docker/overlay2/l/XK5IA4BWQ2CIS667J3SXPXGQK5,upperdir=/opt/docker/overlay2/f913d81219134e23eb0827a1c27668494dfaea2f1b5d1d0c70382366eabed629/diff,workdir=/opt/docker/overlay2/f913d81219134e23eb0827a1c27668494dfaea2f1b5d1d0c70382366eabed629/work)
```

从 docker 官方文档 [Use the OverlayFS storage driver](https://docs.docker.com/storage/storagedriver/overlayfs-driver/) 里偷来的一张图片

![](https://p.k8s.li/overlay_constructs.jpg)

关于上图中这些 Dir 的作用，下面是一段从 [StackOverflow](https://stackoverflow.com/questions/56550890/docker-image-merged-diff-work-lowerdir-components-of-graphdriver) 上搬运过来的解释。

> **LowerDir**: these are the read-only layers of an overlay filesystem. For docker, these are the image layers assembled in order.
>
> **UpperDir**: this is the read-write layer of an overlay filesystem. For docker, that is the equivalent of the container specific layer that contains changes made by that container.
>
> **WorkDir**: this is a required directory for overlay, it needs an empty directory for internal use.
>
> **MergedDir**: this is the result of the overlay filesystem. Docker effectively chroot's into this directory when running the container.

如果想对 overlayfs 文件系统有详细的了解，可以参考 Linux 内核官网上的这篇文档 [overlayfs.txt](https://www.kernel.org/doc/Documentation/filesystems/overlayfs.txt) 。

## 参考

### 官方文档

- [Create a base image](https://docs.docker.com/develop/develop-images/baseimages/)
- [FROM scratch](https://hub.docker.com/_/scratch)
- [Docker Registry](https://docs.docker.com/registry/)
- [Image Manifest Version 2, Schema 2](https://github.com/docker/distribution/blob/master/docs/spec/manifest-v2-2.md)
- [Docker Registry HTTP API V2](https://docs.docker.com/registry/spec/api/)
- [image](https://github.com/containers/image)
- [OCI Image Manifest Specification](https://github.com/opencontainers/image-spec)
- [distribution-spec](https://github.com/opencontainers/distribution-spec)
- [debuerreotype/](https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/)
- [overlayfs.txt](https://www.kernel.org/doc/Documentation/filesystems/overlayfs.txt)

### 源码

- [oi-janky-groovy](https://github.com/docker-library/oi-janky-groovy)
- [docker-debian-artifacts](https://github.com/debuerreotype/docker-debian-artifacts)
- [docker-drag](https://github.com/NotGlop/docker-drag)
- [oras](https://github.com/deislabs/oras)
- [skopeo](https://github.com/containers/skopeo)
- [tar-split](https://github.com/vbatts/tar-split)

### 博客

- [镜像仓库中镜像存储的原理解析](https://supereagle.github.io/2018/04/24/docker-registry/)
- [docker 在本地如何管理 image（镜像）?](https://fuckcloudnative.io/posts/how-manage-image/)
- [ormb：像管理 Docker 容器镜像一样管理机器学习模型](http://gaocegege.com/Blog/ormb)
- [镜像是怎样炼成的](https://blog.fleeto.us/post/how-are-docker-images-built/)
- [docker pull分析](https://duyanghao.github.io/docker-registry-pull-manifest-v2/)
- [浅谈docker中镜像和容器在本地的存储](https://github.com/helios741/myblog/blob/new/learn_go/src/2019/20191206_docker_disk_storage/README.md)
- [容器OCI规范 镜像规范](https://www.qedev.com/cloud/103860.html)
- [开放容器标准(OCI) 内部分享](https://xuanwo.io/2019/08/06/oci-intro/)
- [容器开放接口规范（CRI OCI）](https://wilhelmguo.cn/blog/post/william/%E5%AE%B9%E5%99%A8%E5%BC%80%E6%94%BE%E6%8E%A5%E5%8F%A3%E8%A7%84%E8%8C%83%EF%BC%88CRI-OCI%EF%BC%89-2)
- [Docker镜像的存储机制](https://segmentfault.com/a/1190000014284289)
- [Docker源码分析（十）：Docker镜像下载](http://open.daocloud.io/docker-source-code-analysis-part10/)
- [Docker源码分析（九）：Docker镜像](http://open.daocloud.io/docker-source-code-analysis-part9/)
- [docker push 過程 distribution源碼 分析](https://www.twblogs.net/a/5b8aab392b71775d1ce86eca)
- [Allen 谈 Docker](http://open.daocloud.io/tag/allen-tan-docker/)
- [深入理解 Docker 镜像 json 文件](http://open.daocloud.io/shen-ru-li-jie-dockerjing-xiang-jsonwen-jian-2/)
- [Docker 镜像内有啥，存哪？](http://open.daocloud.io/docker-jing-xiang-nei-you-sha-cun-na-ntitled/)
- [理解 Docker 镜像大小](http://open.daocloud.io/allen-tan-docker-xi-lie-zhi-shen-ke-li-jie-docker-jing-xiang-da-xiao/)
- [看尽 docker 容器文件系统](http://open.daocloud.io/allen-tan-docker-xi-lie-zhi-tu-kan-jin-docker-rong-qi-wen-jian-xi-tong/)
- [深入理解 Docker 构建上下文](https://qhh.me/2019/02/17/%E6%B7%B1%E5%85%A5%E7%90%86%E8%A7%A3-Docker-%E6%9E%84%E5%BB%BA%E4%B8%8A%E4%B8%8B%E6%96%87/)
- [OCI 和 runc：容器标准化和 docker](https://cizixs.com/2017/11/05/oci-and-runc/)
