---
title: docker registry GC 原理分析
date: 2020-07-11
updated:
slug:
categories: 技术
tag:
  - docker
  - registry
  - 镜像
copyright: true
comment: true
---

> 好久没更新博客了，在家摸鱼赶紧来水一篇😂

## registry GC 原理🤔

在咱上个月写的[《深入浅出容器镜像的一生》](https://blog.k8s.li/Exploring-container-image.html)中简单提到了容器镜像的一些知识，也简单介绍了镜像在 registry 中存储的目录结构。今天还是从文件系统层面分析一下 registry GC 的原理，比从源码来分析更直观一些。

### 部署 registry 容器

首先我们需要在本地部署一个 registry 容器，同时为了操作的方便还需要使用到 skopeo 这个工具来替代 docker 命令行客户端进行 copy 镜像和 delete 镜像。关于 skopeo 这个工具的安装和使用可以参考咱之前写过的[《镜像搬运工 skopeo 》](https://blog.k8s.li/skopeo.html)。

#### 自签 SSL 证书

这一步为了方便在使用 skopeo 的时候不用加一堆额外的参数😂

```SHELL
#!/bin/sh
set -e
set -o nounset
cat >ca.conf <<EOF
[ req ]
default_bits  = 2048
distinguished_name = req_distinguished_name
prompt   = no
encrypt_key  = no
x509_extensions  = v3_ca
[ req_distinguished_name ]
CN         = localhost
[ CA_default ]
copy_extensions = copy
[ alternate_names ]
DNS.2=localhost
[ v3_ca ]
subjectAltName=@alternate_names
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer:always
basicConstraints = critical,CA:true
keyUsage=keyCertSign,cRLSign,digitalSignature,keyEncipherment,nonRepudiation
EOF
mkdir -p certs
openssl req -days 365 -x509 -config ca.conf \
    -new -keyout certs/domain.key -out certs/domain.crt
```

- 信任证书，根据不同的发行版选择相应的路径和命令行即可。

```shell
# CentOS
update-ca-trust force-enable
cp certs/domain.crt /etc/pki/ca-trust/source/anchors/localhost.crt
update-ca-trust

# Ubuntu
cp certs/domain.crt /usr/local/share/ca-certificates/localhost.crt
$ update-ca-certificates

# Debian
cp certs/domain.crt /usr/share/ca-certificates/localhost.crt
echo localhost.crt >> /etc/ca-certificates.conf
update-ca-certificates
```

#### 创建密码 auth 认证  auth.htpasswd 文件

由于 PUSH 镜像和 DELETE 镜像是通过 HTTP 请求 registry 的 API 完成的，每个请求都需要一个 token 才能完成操作，这个 token 需要使用这个 AUTH 文件来进行鉴权，使用 `htpasswd` 来生成一个明文的用户/密码即可。

```shell
htpasswd -cB -b auth.htpasswd root 123456
```

#### 启动 registry 容器，docker run 走起！

- `-v /var/lib/registry:/var/lib/registry` ，将本地的存储目录挂载到容器内的 registry 存储目录下。
- `-v pwd/certs:/certs`，将生成的 SSL 证书挂载到容器内。
- `-e REGISTRY_STORAGE_DELETE_ENABLED=true`，添加该参数才能进行 DELETE 镜像操作，不然的话会提示 [Error in deleting repository in a private registry V2 #1573](https://github.com/docker/distribution/issues/1573) 这种错误（＞﹏＜）。

```shell
docker run -d -p 127.0.0.1:443:5000 --name registry \
    -v /var/lib/registry:/var/lib/registry \
    -v `pwd`/certs:/certs \
    -v $(pwd)/auth.htpasswd:/etc/docker/registry/auth.htpasswd \
    -e REGISTRY_AUTH="{htpasswd: {realm: localhost, path: /etc/docker/registry/auth.htpasswd}}" \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
    -e REGISTRY_STORAGE_DELETE_ENABLED=true \
    registry
```

#### docker login

这一步是为了在 `~/.docker/.config.json` ，中添加上 auth 认证，后面使用 skopeo 的时候会用到。

```shell
╭─root@sg-02 ~/registry
╰─# docker login localhost -u root -p 123456
]WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
╭─root@sg-02 ~/registry
╰─# cat ~/.docker/config.json
{
        "auths": {
                "https://registry.k8s.li/v2": {
                        "auth": "VlJFpmQE43Sw=="
                },
                "localhost": {
                        "auth": "cm9vdDoxMjM0NTY="
                }
        },
        "HttpHeaders": {
                "User-Agent": "Docker-Client/19.03.5 (linux)"
        },
        "experimental": "enabled"
}#
```

### COPY 镜像到 registry

```shell
╭─root@sg-02 ~/registry
╰─# skopeo copy docker://alpine:3.10 docker://localhost/library/alpine:3.10
Getting image source signatures
Copying blob 21c83c524219 done
Copying config be4e4bea2c done
Writing manifest to image destination
Storing signatures
```

### registry 存储目录长什么样🤔

![](https://p.k8s.li/registry-storage.jpeg)

registry 容器内的`/var/lib/registry/docker/registry/v2` 存储目录，结合上面这张图，通过 tree 目录我们可以清晰地看到：registry 存储目录下只有两种文件名的文件，一个是 `data` 文件，一个是 `link` 文件。其中 link 文件是普通的文本文件，存放在 `repositories` 目录下，其内容是指向 data 文件的 sha256 digest 值。link 文件是不是有点像 C 语言中的指针😂（大雾。

data 文件存放在 `blobs` 目录下文件又分为了三种文件，一个是镜像每一层的 `layer` 文件和镜像的 `config` 文件，以及镜像的 `manifest` 文件。

在 `repositories` 目录下每个镜像的 `_layers/sha256` 目录下的文件夹名是镜像的 layer 和 config 文件的 digest ，该目录下的 link 文件就是指向对应 blobs 目录下的 data 文件。当我们 pull 一个镜像的 layer 时，是通过 link 文件找到 layer 在 registry 中实际的存储位置的。

在 `_manifests` 文件夹下的 tags 和 revisions 目录下的 link 文件则指向该镜像的 manifest 文件，保存在所有历史镜像 tag 的 manifest 文件 的 link。当删除一个镜像时，只会删除该镜像最新的 tag 的 link 文件。

tags 目录下的文件夹名例如 3.10 ，就是该镜像的 tag ，在它的子目录下的 current/link 文件则记录了当前 tag 指向的 manifest 文件的位置。比如我们的 alpine:latest 镜像，每次 push 新的 latest 镜像时，current/link 都会更新成指向最新镜像的 manifest 文件。

我们后面观察一下当删除一个镜像时，这些文件是怎么变化的，就可以得知通过 registry API 进行 DELETE 操作可以转换成文件系统层面上对 link 文件的删除操作。

```shell
╭─root@sg-02 ~/registry
╰─# cd /var/lib/registry/docker/registry/v2
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# tree
.
├── blobs
│   └── sha256
│       ├── 21
│       │   └── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
│       │       └── data
│       ├── a1
│       │   └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
│       │       └── data
│       └── be
│           └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
│               └── data
└── repositories
    └── library
        └── alpine
            ├── _layers
            │   └── sha256
            │       ├── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
            │       │   └── link
            │       └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
            │           └── link
            ├── _manifests
            │   ├── revisions
            │   │   └── sha256
            │   │       └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
            │   │           └── link
            │   └── tags
            │       └── 3.10
            │           ├── current
            │           │   └── link
            │           └── index
            │               └── sha256
            │                   └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
            │                       └── link
            └── _uploads

26 directories, 8 files
```

- `blobs` 存储目录，存放了镜像的三个必须文件，`layer`，`manifest`，`config`。通过文件大小我们可以大致地推算出最大的 2.7M 是镜像的 layer 。

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# find . -name "data" -exec ls -sh {} \;
2.7M ./blobs/sha256/21/21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d/data
4.0K ./blobs/sha256/a1/a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590/data
4.0K ./blobs/sha256/be/be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c/data
```

- `image layer` 文件，是 gzip 格式的 tar 包，是镜像层真实内容的 `tar.gzip` 格式存储形式。

```ini
./blobs/sha256/21/21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d/data: gzip compressed data
```

- `image manifest` 文件，json 文件格式的，存放该镜像 `layer` 和  `image config` 文件的索引。

```json
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# cat ./blobs/sha256/a1/a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590/data
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
   "config": {
      "mediaType": "application/vnd.docker.container.image.v1+json",
      "size": 1509,
      "digest": "sha256:be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c"
   },
   "layers": [
      {
         "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
         "size": 2795580,
         "digest": "sha256:21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d"
      }
   ]
}#
```

- `image config` 文件，json 格式的。是构建时生成的，根据 `Dockerfile` 和宿主机的一些信息，以及一些构建过程中的容器可以生成 digest 唯一的 `image config` 文件。仔细看这个 image config 文件是不是有点疑惑，无论是 manifest 还是 config 文件里面的内容压根就没有镜像的名称和 tag 。其实，镜像就好比一个文件，文件的内容和文件名毫无关系。在 registry 中，是通过路径名的方式来对一个镜像进行命名的。当我们往 registry 中 PUSH 一个镜像时，以`localhost/library/alpine:3.10`为例，`localhost`，就是该 registry 的域名或者 URL ，`library`就是 project ，`alpine:3.10`就是镜像名和镜像的 tag。registry 会根据 `localhost/library/alpine:3.10` 在`repositories` 目录下依次创建相应的目录。

```json
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# cat ./blobs/sha256/be/be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c/data | jq "."
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
      "/bin/sh"
    ],
    "ArgsEscaped": true,
    "Image": "sha256:d928e20e1fbe5142bb5cdf594862271673133c5354950d6a8f74afed24df4c23",
    "Volumes": null,
    "WorkingDir": "",
    "Entrypoint": null,
    "OnBuild": null,
    "Labels": null
  },
  "container": "37e3972c75360676982c8f6591b66a9097719e5ad4cecd5fa63ad4f06472825f",
  "container_config": {
    "Hostname": "37e3972c7536",
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
      "CMD [\"/bin/sh\"]"
    ],
    "ArgsEscaped": true,
    "Image": "sha256:d928e20e1fbe5142bb5cdf594862271673133c5354950d6a8f74afed24df4c23",
    "Volumes": null,
    "WorkingDir": "",
    "Entrypoint": null,
    "OnBuild": null,
    "Labels": {}
  },
  "created": "2020-04-24T01:05:21.571691552Z",
  "docker_version": "18.09.7",
  "history": [
    {
      "created": "2020-04-24T01:05:21.178437685Z",
      "created_by": "/bin/sh -c #(nop) ADD file:66a440394c2442570f1f060e25c86613cb2d88a8af0c71c5a4154b3570e9a805 in / "
    },
    {
      "created": "2020-04-24T01:05:21.571691552Z",
      "created_by": "/bin/sh -c #(nop)  CMD [\"/bin/sh\"]",
      "empty_layer": true
    }
  ],
  "os": "linux",
  "rootfs": {
    "type": "layers",
    "diff_ids": [
      "sha256:1b3ee35aacca9866b01dd96e870136266bde18006ac2f0d6eb706c798d1fa3c3"
    ]
  }
}
```

-   我们再往 registry 中 COPY 一个镜像，方便后面的分析过程。

```shell
skopeo copy docker://debian:buster-slim docker://localhost/library/debian:buster-slim
```

-   这是 registry 中就只有 `alpine:3.10` 和 `debian:buster-slim`这两个基础镜像，此时的 registry 存储目录的结构如下：

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# tree
.
├── blobs
│   └── sha256
│       ├── 21
│       │   └── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
│       │       └── data
│       ├── 43
│       │   └── 43e3995ee54ac008271bfcf2d8ac7278c33f4c5e83d2f02bfcddd350034e3357
│       │       └── data
│       ├── 7c
│       │   └── 7c459309b9a5ec1683ef3b137f39ce5888f5ad0384e488ad73c94e0243bc77d4
│       │       └── data
│       ├── 85
│       │   └── 8559a31e96f442f2c7b6da49d6c84705f98a39d8be10b3f5f14821d0ee8417df
│       │       └── data
│       ├── a1
│       │   └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
│       │       └── data
│       └── be
│           └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
│               └── data
└── repositories
    └── library
        ├── alpine
        │   ├── _layers
        │   │   └── sha256
        │   │       ├── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
        │   │       │   └── link
        │   │       └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
        │   │           └── link
        │   ├── _manifests
        │   │   ├── revisions
        │   │   │   └── sha256
        │   │   │       └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
        │   │   │           └── link
        │   │   └── tags
        │   │       └── 3.10
        │   │           ├── current
        │   │           │   └── link
        │   │           └── index
        │   │               └── sha256
        │   │                   └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
        │   │                       └── link
        │   └── _uploads
        └── debian
            ├── _layers
            │   └── sha256
            │       ├── 43e3995ee54ac008271bfcf2d8ac7278c33f4c5e83d2f02bfcddd350034e3357
            │       │   └── link
            │       └── 8559a31e96f442f2c7b6da49d6c84705f98a39d8be10b3f5f14821d0ee8417df
            │           └── link
            ├── _manifests
            │   ├── revisions
            │   │   └── sha256
            │   │       └── 7c459309b9a5ec1683ef3b137f39ce5888f5ad0384e488ad73c94e0243bc77d4
            │   │           └── link
            │   └── tags
            │       └── buster-slim
            │           ├── current
            │           │   └── link
            │           └── index
            │               └── sha256
            │                   └── 7c459309b9a5ec1683ef3b137f39ce5888f5ad0384e488ad73c94e0243bc77d4
            │                       └── link
            └── _uploads

48 directories, 16 files
```

### DELETE 镜像

- 通过 `skopeo delete` 删除镜像，注意，通过 registry 的 API 删除镜像每次只能删除一个 tag 的镜像。

```http
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# skopeo delete docker://localhost/library/alpine:3.10 --debug
DEBU[0000] Returning credentials from /run/containers/0/auth.json
DEBU[0000] Using registries.d directory /etc/containers/registries.d for sigstore configuration
DEBU[0000]  No signature storage configuration found for localhost/library/alpine:3.10
DEBU[0000] Looking for TLS certificates and private keys in /etc/docker/certs.d/localhost
DEBU[0000] Loading registries configuration "/etc/containers/registries.conf"
DEBU[0000] GET https://localhost/v2/
DEBU[0000] Ping https://localhost/v2/ status 401
DEBU[0000] GET https://localhost/v2/library/alpine/manifests/3.10
DEBU[0000] DELETE https://localhost/v2/library/alpine/manifests/sha256:a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
```

- 再看一下删除后的 registry 存储目录下的 alpine 目录里都少了哪些东东？

```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# tree
.
├── blobs
│   └── sha256
│       ├── 21
│       │   └── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
│       │       └── data
│       ├── 43
│       │   └── 43e3995ee54ac008271bfcf2d8ac7278c33f4c5e83d2f02bfcddd350034e3357
│       │       └── data
│       ├── 7c
│       │   └── 7c459309b9a5ec1683ef3b137f39ce5888f5ad0384e488ad73c94e0243bc77d4
│       │       └── data
│       ├── 85
│       │   └── 8559a31e96f442f2c7b6da49d6c84705f98a39d8be10b3f5f14821d0ee8417df
│       │       └── data
│       ├── a1
│       │   └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
│       │       └── data
│       └── be
│           └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
│               └── data
└── repositories
    └── library
        ├── alpine
        │   ├── _layers
        │   │   └── sha256
        │   │       ├── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
        │   │       │   └── link
        │   │       └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
        │   │           └── link
        │   ├── _manifests
        │   │   ├── revisions
        │   │   │   └── sha256
        │   │   │       └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
        │   │   └── tags
        │   └── _uploads
```

我们可以看到，通过 skopeo delete 一个镜像的时候，只对 `_manifests` 下的 link 文件进行了操作，删除的都是对该 tag 镜像 manifest 文件夹下的 link 文件，实际上 manifest 文件并没有从 blobs 目录下删除，只是删除了该镜像的 manifest 文件的引用。删除一个镜像后，tags 目录下的 tag 名目录就被删除了，_manifests/revisions 目录下的 link 文件也被删除了。实际上两者删除的是同一个内容，即对该镜像 manifest 文件的 link 文件。

```ini
DEBU[0000] DELETE https://localhost/v2/library/alpine/manifests/sha256:a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
```

从上面文件的变化可以得出，通过 registry API 来 DELETE 一个镜像实质上是删除 repositories 元数据文件夹下的 tag 名文件夹和该 tag 的 revisions 下的 link 文件。

##  registry GC 原理

上面巴拉巴拉扯了一通也许你现在一头雾水，这和今天的主题 registry GC 原理毛关系？😂，其实想要从文件系统层面来理解 registry GC ，上面的知识是必备的（*^____^*）。

### GC 是弄啥咧？🤔

GC 嘛，就是垃圾回收的意思，从 docker 官方文档 [Garbage collection](https://docs.docker.com/registry/garbage-collection/) 偷来的 example 😂来解释一下吧。

-   假如镜像 A 和镜像 B ，他俩分别引用了layer a，b和 a，c。

```
A -----> a <----- B
    \--> b     |
         c <--/
```

-   通过 registry API 删除镜像 B 之后，layer c 并没有删掉，只是删掉了对它的引用，所以 c 是多余的。

```shell
A -----> a     B
    \--> b
         c
```

-   GC 之后，layer c 就被删掉了，现在就没有无用的 layer 了。

```shell
A -----> a
    \--> b
```

### GC 的过程

翻一下 registry  GC 的源码 [garbagecollect.go](https://github.com/docker/distribution/blob/master/registry/storage/garbagecollect.go)，可以看到 GC 的主要分两个阶段，marking 和 sweep。

#### marking

marking 阶段是扫描所有的 manifest 文件，根据上文我们提到的 link 文件，通过扫描所有镜像 tags 目录下的 link 文件就可以得到这些镜像的 manifest，在 manifest 中保存在该镜像所有的 layer 和 config 文件的 digest 值，把这些值标记为**不能清除**。

```go
	// mark
	markSet := make(map[digest.Digest]struct{})
	manifestArr := make([]ManifestDel, 0)
	err := repositoryEnumerator.Enumerate(ctx, func(repoName string) error {
		emit(repoName)

		var err error
		named, err := reference.WithName(repoName)
		if err != nil {
			return fmt.Errorf("failed to parse repo name %s: %v", repoName, err)
		}
		repository, err := registry.Repository(ctx, named)
		if err != nil {
			return fmt.Errorf("failed to construct repository: %v", err)
		}

		manifestService, err := repository.Manifests(ctx)
		if err != nil {
			return fmt.Errorf("failed to construct manifest service: %v", err)
		}

		manifestEnumerator, ok := manifestService.(distribution.ManifestEnumerator)
		if !ok {
			return fmt.Errorf("unable to convert ManifestService into ManifestEnumerator")
		}
```

这一阶段用 shell 脚本来实现的话大致可以这样来搞，使用 shell 去遍历这些 manifest ，然后再 grep 出所有的 sha256 值就能得到这个镜像所有的 blobs 目录下的 data 文件。

```shell
#!/bin/bash
set -x
v2=${v2:="/var/lib/registry/docker/registry/v2"}
cd ${v2}
all_blobs=/tmp/all_blobs.list
echo "" > ${all_blobs}
# marking all the blob by all images manifest
for tag in $(find repositories -name "link" | grep current)
do
    link=$(cat ${tag} | cut -c8-71)
    mfs=blobs/sha256/${link:0:2}/${link}/data
    echo ${link} >> ${all_blobs}
    grep sha256 ${mfs} |cut -d "\"" -f4 | cut -c8-71 >> ${all_blobs}
done
```

#### sweep

第二阶段就是删除操作啦，marking 完之后，没有标记 blob（ layer 和 config 文件）就会被清除掉。

```go
	// sweep
	vacuum := NewVacuum(ctx, storageDriver)
	if !opts.DryRun {
		for _, obj := range manifestArr {
			err = vacuum.RemoveManifest(obj.Name, obj.Digest, obj.Tags)
			if err != nil {
				return fmt.Errorf("failed to delete manifest %s: %v", obj.Digest, err)
			}
		}
	}
	blobService := registry.Blobs()
	deleteSet := make(map[digest.Digest]struct{})
	err = blobService.Enumerate(ctx, func(dgst digest.Digest) error {
		// check if digest is in markSet. If not, delete it!
		if _, ok := markSet[dgst]; !ok {
			deleteSet[dgst] = struct{}{}
		}
		return nil
	})
```

![](https://p.k8s.li/registry-gc.png)

### GC 都干了啥？

接下来我们就进行实际的 GC 操作，进入到 registry 容器中，使用 registry garbage-collect 这个子命令进行操作。

#### marking

```verilog
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# docker exec -it registry sh
/ # registry garbage-collect -m --delete-untagged=true /etc/docker/registry/config.yml
library/alpine
library/debian
library/debian: marking manifest sha256:7c459309b9a5ec1683ef3b137f39ce5888f5ad0384e488ad73c94e0243bc77d4
library/debian: marking blob sha256:43e3995ee54ac008271bfcf2d8ac7278c33f4c5e83d2f02bfcddd350034e3357
library/debian: marking blob sha256:8559a31e96f442f2c7b6da49d6c84705f98a39d8be10b3f5f14821d0ee8417df

3 blobs marked, 3 blobs and 0 manifests eligible for deletion
```

#### sweep

```
blob eligible for deletion: sha256:a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
INFO[0000] Deleting blob: /docker/registry/v2/blobs/sha256/a1/a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590  go.version=go1.11.2 instance.id=3ad15352-7cb7-46ca-a5ae-e5e16c6485a5 service=registry
blob eligible for deletion: sha256:be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
INFO[0000] Deleting blob: /docker/registry/v2/blobs/sha256/be/be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c  go.version=go1.11.2 instance.id=3ad15352-7cb7-46ca-a5ae-e5e16c6485a5 service=registry
blob eligible for deletion: sha256:21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
INFO[0000] Deleting blob: /docker/registry/v2/blobs/sha256/21/21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d  go.version=go1.11.2 instance.id=3ad15352-7cb7-46ca-a5ae-e5e16c6485a5 service=registry
```

#### GC 之后的 registry 存储目录长什么样？



```shell
╭─root@sg-02 /var/lib/registry/docker/registry/v2
╰─# tree                                                                                     
.
├── blobs
│   └── sha256
│       ├── 21
│       ├── 43
│       │   └── 43e3995ee54ac008271bfcf2d8ac7278c33f4c5e83d2f02bfcddd350034e3357
│       │       └── data
│       ├── 7c
│       │   └── 7c459309b9a5ec1683ef3b137f39ce5888f5ad0384e488ad73c94e0243bc77d4
│       │       └── data
│       ├── 85
│       │   └── 8559a31e96f442f2c7b6da49d6c84705f98a39d8be10b3f5f14821d0ee8417df
│       │       └── data
│       ├── a1
│       └── be
└── repositories
    └── library
        ├── alpine
        │   ├── _layers
        │   │   └── sha256
        │   │       ├── 21c83c5242199776c232920ddb58cfa2a46b17e42ed831ca9001c8dbc532d22d
        │   │       │   └── link
        │   │       └── be4e4bea2c2e15b403bb321562e78ea84b501fb41497472e91ecb41504e8a27c
        │   │           └── link
        │   ├── _manifests
        │   │   ├── revisions
        │   │   │   └── sha256
        │   │   │       └── a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
        │   │   └── tags
        │   └── _uploads
        └── debian
            ├── _layers
            │   └── sha256
            │       ├── 43e3995ee54ac008271bfcf2d8ac7278c33f4c5e83d2f02bfcddd350034e3357
            │       │   └── link
            │       └── 8559a31e96f442f2c7b6da49d6c84705f98a39d8be10b3f5f14821d0ee8417df
            │           └── link
            ├── _manifests
            │   ├── revisions
            │   │   └── sha256
            │   │       └── 7c459309b9a5ec1683ef3b137f39ce5888f5ad0384e488ad73c94e0243bc77d4
            │   │           └── link
            │   └── tags
            │       └── buster-slim
            │           ├── current
            │           │   └── link
            │           └── index
            │               └── sha256
            │                   └── 7c459309b9a5ec1683ef3b137f39ce5888f5ad0384e488ad73c94e0243bc77d4
            │                       └── link
            └── _uploads

40 directories, 10 files
```

根据 GC 后的 registry 存储目录我们可以看到，原本 blobs 目录下有 6 个 data 文件，现在已经变成了 3 个，alpine:3.10 这个镜像相关的 layer、config、manifest 这三个文件都已经被 GC 掉了。但是在 repositories 目录下，该镜像的 _layers 下的 link 文件依旧存在🤔。

### 总结

总结以上，用下面这三张图片就能直观地理解这些过程啦。

#### delete 镜像之前的 registry 存储目录结构

![](https://p.k8s.li/registry-gc-1.jpeg)

#### delete 镜像之后的 registry 存储目录结构

![](https://p.k8s.li/registry-gc-2.jpeg)

#### GC 之后的 registry 存储目录结构

![](https://p.k8s.li/registry-gc-3.jpeg)

### shell 大法好！

根据上面的 GC 原理和过程，实际上我们可以使用不到 25 行的 shell 脚本来实现一个粗暴的  GC 😂

```SHELL
#!/bin/bash
set -x
v2=$1
v2=${v2:="/var/lib/registry/docker/registry/v2"}
cd ${v2}
all_blobs=/tmp/all_blobs.list
: > ${all_blobs}
# marking all the blob by all images manifest
for tag in $(find repositories -name "link" | grep current)
do
    link=$(cat ${tag} | cut -c8-71)
    mfs=blobs/sha256/${link:0:2}/${link}/data
    echo ${link} >> ${all_blobs}
    grep sha256 ${mfs} |cut -d "\"" -f4 | cut -c8-71 >> ${all_blobs}
done
# delete blob if the blob doesn't exist in all_blobs.list
for blob in $(find blobs -name "data" | cut -d "/" -f4)
do
    grep ${blob} ${all_blobs}
    if [[ $? != 0 ]]; then
    rm -rf blobs/sha256/${blob:0:2}/${blob}
    fi
done
```

1.  遍历所有镜像的 tag 下最新的 link 文件指向的 manifest

2.  根据 manifest 文件 grep 出 sha256 值的 image config 和 layer 文件，保存到 `all_blobs.list` 文件中。
3.  使用 `find` 和 `for` 循环遍历所有 blobs 下的的 data 文件，判断它是否在 `all_blobs.list` 中，不再的话直接 `rm -rf` 干掉它！
4.  最后重启一下 registry 容器。

就是这么简单粗暴！哈哈，`rm -rf` 用起来真爽（手动滑稽 。如果还想把这个脚本再优化一下的话，可以将 所有的 blob 的 sha256 值截取前 12 位保存在一个变量中。通过 `=~` 来判断包含关系来替代 grep。

## 踩坑！

### The operation is unsupported.(405 Method Not Allowed)

```http
╭─root@sg-02 ~/registry
╰─# skopeo delete docker://localhost/library/alpine:3.10 --debug
DEBU[0000] Returning credentials from /run/containers/0/auth.json
DEBU[0000] Using registries.d directory /etc/containers/registries.d for sigstore configuration
DEBU[0000]  No signature storage configuration found for localhost/library/alpine:3.10
DEBU[0000] Looking for TLS certificates and private keys in /etc/docker/certs.d/localhost
DEBU[0000] Loading registries configuration "/etc/containers/registries.conf"
DEBU[0000] GET https://localhost/v2/
DEBU[0000] Ping https://localhost/v2/ status 401
DEBU[0000] GET https://localhost/v2/library/alpine/manifests/3.10
DEBU[0000] DELETE https://localhost/v2/library/alpine/manifests/sha256:a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590
FATA[0000] Failed to delete /v2/library/alpine/manifests/sha256:a143f3ba578f79e2c7b3022c488e6e12a35836cd4a6eb9e363d7f3a07d848590: {"errors":[{"code":"UNSUPPORTED","message":"The operation is unsupported."}]}
 (405 Method Not Allowed)
```

在 registry 容器启动的时候添加变量开启 `REGISTRY_STORAGE_DELETE_ENABLED=true` 即可，或者修改容器内的配置文件 `/etc/docker/registry/config.yml`，在 `storage:` 下添加上 下面的参数。

```yaml
storage:
  delete:
    enabled: false
```

### GC 不彻底，残留 link 文件

从上面我们可以得知，registry 无论是删除一个镜像还是进行 GC 操作，都不会删除 repositories 目录下的 `_layers/sha256/digest/link` 文件，在进行 GC 之后，一些镜像 layer 和 config 文件已经在 blobs 存储目录下删除了，但指向它的 layers/link 文件依旧保存在 repositories 目录下🙄。GitHub 上有个 PR [Remove the layer's link by garbage-collect #2288](https://github.com/docker/distribution/issues/2288) 就是专门来清理这些无用的 layer link 文件的，最早的一个是三年前的，但是还没有合并😂。

留着已经被 GC 掉 blob 的 layer link 也没啥用，使用下面这个脚本就能删掉无用的 layer link 文件。根据 layer link 的值去 blobs 目录下看看该文件是否存在，不存在的话就 rm -rf 掉，存在的话就留着。这样就能清理干净啦😁。

```shell
#!/bin/bash
cd /var/lib/registry/docker/registry/v2
for link in $(find repositories -name "link" | grep -E "_layers")
do
    link_sha256=$(echo ${link} | awk -F "/" '{print $6}')
    link_short=$(echo ${link} | awk -F "/" '{print $6}' | cut -c1-2)
    data_file=blobs/sha256/${link_short}/${link_sha256}
    dir_link=$(echo ${link} | sed s'/link//g')
    if [[ ! -d "${data_file}" ]]; then
    rm -rf ${dir_link}
    fi
done
```

### GC 后要重启！

GC 之后一定要重启，因为 registry 容器缓存了镜像 layer 的信息，当删除掉一个镜像 A ，后边 GC 掉该镜像的 layer 之后，如果不重启 registry 容器，当重新 PUSH 镜像 A 的时候就会提示镜像 layer 已经存在，不会重新上传 layer ，但实际上已经被 GC 掉了，最终会导致镜像 A 不完整，无法 pull 到该镜像。

### GC 不是事务性操作

GC 的时候最好暂停 PUSH 镜像，以免把正在上传的镜像 layer 给 GC 掉。