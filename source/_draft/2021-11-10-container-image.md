```yaml
title: 内部技术分享：深入浅出容器镜像的一生
date: 2021-11-10
updated: 2021-11-10
slug:
categories: 生活
tag:
copyright: true
comment: true
```

## OCI

这两个协议通过OCI Runtime filesystem bundle的标准格式连接在一起，OCI 镜像可以通过工具转换成bundle，然后OCI容器引擎通过识别这个bundle来运行容器。

### image-spec

```bash
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

#### layer

[文件系统](https://github.com/opencontainers/image-spec/blob/master/layer.md)：以 layer （镜像层）保存的文件系统，每个 layer 保存了和上层之间变化的部分，layer 应该保存哪些文件，怎么表示增加、修改和删除的文件等。

#### image config

[image config 文件](https://github.com/opencontainers/image-spec/blob/master/config.md)：保存了文件系统的层级信息（每个层级的 hash 值、历史信息）；容器运行时需要的一些信息（比如环境变量、工作目录、命令参数、mount 列表）；指定了镜像在某个特定平台和系统的配置。

比较接近我们使用 `docker inspect <image_id>` 看到的内容。

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

[manifest 文件](https://github.com/opencontainers/image-spec/blob/master/manifest.md) ：镜像的 config 文件索引，有哪些 layer，额外的 annotation 信息；manifest 文件中保存了很多和当前平台有关的信息。另外 manifest 中的 layer 和 config 中的 layer 表达的虽然都是镜像的 layer ，但二者代表的意义不太一样。manifest 文件是存放在 registry 中，当我们拉取镜像的时候，会根据该文件拉取相应的 layer 。

另外 manifest 也分好几个版本，目前主流的版本是  `Manifest Version 2, Schema 2` ，可以参考 docker 的官方文档 [Image Manifest Version 2, Schema 2](https://github.com/docker/distribution/blob/master/docs/spec/manifest-v2-2.md) 。registry 中会有个 `Manifest List ` 文件，该文件是为不同处理器体系架构而设计的，通过该文件指向与该处理器体系架构相对应的 Image Manifest ，这一点不要搞混。

- manifests index

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

[index 文件](https://github.com/opencontainers/image-spec/blob/master/image-index.md) ：其实就是我们上面提到的 Manifest List 啦。在 docker 的 [distribution](https://github.com/docker/distribution) 中称之为 `Manifest List` 在 OCI 中就叫 [OCI Image Index Specification](https://github.com/opencontainers/image-spec/blob/master/image-index.md) 。其实两者是指的同一个文件，甚至两者 GitHub 上文档给的 example 都一一模样🤣，应该是 OCI 复制粘贴 Docker 的文档😂。

index 文件是个可选的文件，包含着一个列表为同一个镜像不同的处理器 arch 指向不同平台的 manifest 文件，这个文件能保证一个镜像可以跨平台使用，每个处理器 arch 平台拥有不同的 manifest 文件，使用 index 作为索引。当我们使用 arm 架构的处理器时要额外注意，在拉取镜像的时候要拉取 arm 架构的镜像，一般处理器的架构都接在镜像的 tag 后面，默认 latest tag 的镜像是 x86 的，在 arm 处理器的机器这些镜像上是跑不起来的。

### 各种 id 分不清？

```bash
╭─root@esxi-debian-devbox ~
╰─# docker pull alpine
Using default tag: latest
latest: Pulling from library/alpine
a0d0a0d46f8b: Pull complete
Digest: sha256:e1c082e3d3c45cccac829840a25941e679c25d438cc8412c2fa221cf1a824e6a
Status: Downloaded newer image for alpine:latest
docker.io/library/alpine:latest
```

看完 [image-spec](http://www.github.com/opencontainers/image-spec) 里面提到的各种 id 相信你又很多疑惑，在此总结一下这些 id 的作用：

|      ID      | 用途                                                         |
| :----------: | ------------------------------------------------------------ |
|   image-id   | image config 的 sha256 哈希值，在本地镜像存储中由它唯一标识一个镜像 |
| image digest | 在 registry 中的 image manifest 的 sha256 摘要，在 registry 中由它唯一标识一个镜像 |
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

### distribution-spec

#### manifests

#### manifest index

### runtime-spec

## Build

 ### Dockerfile

### Build tools

#### BuildKit

#### Buildah

#### Kaniko

### Base image

- Dockerfile

```dockerfile
FROM scratch
ADD rootfs.tar.xz /
CMD ["bash"]
```

- rootfs

### Image type

- docker-archive
- docker
- registry

## Ship

### image registry

#### docker registry

#### harbor

### Ship tools

#### docker

#### skopeo

## Run

### runtime

#### podman

#### docker

#### containerd

### storage

