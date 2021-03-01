---
title: registry + overlay2 在打包发布流水线中的应用
date: 2021-03-05
updated: 2021-03-03
slug:
categories: 技术
tag:
  - registry
  - images
  - OCI
copyright: true
comment: true
---

## 背景

自从去年五月份入职后一直在负责公司 PaaS toB 产品的打包发布及部署运维工作，工作性质上有点类似于 Kubernetes 社区的 [SIG Release  团队](https://github.com/kubernetes/sig-release)。试用期的主要工作就是优化我们先有的打包发布流程。在这期间对打包发布流水线优化了很多，其中最突出的是镜像同步的优化，将镜像同步的速度提升了 5 到 15 倍。大大缩短了整个产品的发布耗时，也得到了同事们的一致好评。于是今天就想着把这项优化和背后的原理分享出来。

我们的产品打包时会有一个镜像列表，并根据这个镜像列表在 CI/CD 的流水线镜像仓库里将镜像同步到一个发布归档的镜像仓库和一个打包的镜像仓库。最终会将打包的镜像仓库的 registry 存储目录打包一个未经 gzip 压缩的 tar 包。最终在客户环境部署的时候将这个 tar 包解压到部署的镜像仓库存储目录中，供集群部署和组件部署使用。至于部署的时候为什么可以这样做，其中的原理可以参考我之前写过的文章 [docker registry 迁移至 harbor](https://blog.k8s.li/docker-registry-to-harbor.html)。

![](https://p.k8s.li/2021-03-01-001.jpeg)

在打包的过程中镜像同步会进行两次，每次都会根据一个 images.list 列表将镜像同步到不同的镜像仓库中，同步的方式使用的是  `docker pull –> docker tag –> docker push`。第一次是从CI/CD 流水线镜像仓库（cicd.registry.local）中拉取镜像并 push 到发布归档的镜像仓库(archive.registry.local)中，其目的是归档并备份我们已经发布的镜像。

第二次将镜像从发布归档的镜像仓库 (archive.registry.local) 同步镜像到打包镜像仓库（package.registry.local）中。不同于第一次的镜像同步，这次同步镜像的时候会对镜像仓库做清理的操作，首先清理打包镜像仓库的存储目录，然后容器 registry 容器让 registry 重新提取镜像的元数据信息到内存中。其目的是清理旧数据，防止历史的镜像带入本次发布版本的安装包中。镜像同步完成之后会将整个打包镜像仓库的存储目录打包成一个 tar 包，并放到产品安装包中。

## 问题

我刚入职的时候，我们的产品发布耗时最久的就是镜像同步阶段， 最长的时候耗时 `2h30min`。耗时这么久的主要原因如下：

### docker 性能问题

因为在做镜像同步的时候使用的是  `docker pull –> docker tag –> docker push` 的方式。而在 docker pull 和 docker push 的过程中 docker 守护进程都会对镜像的 layer 做解压缩的操作。这是及其耗时和浪费 CPU 资源的。又因为我们的内网机器性能十分地烂，有时甚至连 USB 2.0 的速度都不如！那慢的程度可想而知。

### 无法复用旧数据

在第二次镜像同步时会对打包镜像仓库做清理的操作，导致无法复用历史的镜像。其实每次发布的时候，变更和新增的镜像很少，平均为原来的 1/10 左右，增量同步的镜像也就那么一丢丢而已。因为要保证这次打包发布的镜像仓库中只能包好这个需要的镜像，不能包含与本次无关的镜像，因此每次都需要清理打包镜像仓库，这无法避免。

## 优化

根据上面提到的两个问题，经过反复的研究和测试终于都完美地解决了。

### skopeo 替代 docker

针对  `docker pull –> docker tag –> docker push`  的性能问题，当时第一个方案想到的就是使用 skopeo 来替代它。使用 `skopeo copy` 直接将镜像从一个 registry 复制到另一个 registry 中。关于 skopeo 的使用和其背后的原理可以参考我之前的博客 [镜像搬运工 skopeo 初体验](https://blog.k8s.li/skopeo.html) 。使用 skopeo 之后镜像同步比之前快了很多，平均快了 5 倍左右。

###  overlay2 复用旧数据

解决了 docker 的性能问题，剩下的就是无法复用旧数据的问题了。在如何保留历史镜像的问题上可煞费苦心。当时也不知道就想到了 overlay2 的特性：`写时复制`。就好比如 docker run 启动一个容器，在容器内进行修改和删除文件的操作，这些操作并不会影响到镜像本身，因为 docker 使用 overlay2 联合挂载的方式将镜像的每一层挂载为一个 merged 的层。在容器内看到的就是这个 merged 的层，在容器内对 merged 层文件的修改和删除操作是通过 overlay2 的 upper 层完成的，并不会影响到镜像本身。

从 docker 官方文档 [Use the OverlayFS storage driver](https://docs.docker.com/storage/storagedriver/overlayfs-driver/) 里偷来的一张图片https://p.k8s.li

![img](https://p.k8s.li/overlay_constructs.jpg)

关于上图中这些 Dir 的作用，下面是一段从 [StackOverflow](https://stackoverflow.com/questions/56550890/docker-image-merged-diff-work-lowerdir-components-of-graphdriver) 上搬运过来的解释。如果想对 overlayfs 文件系统有详细的了解，可以参考 Linux 内核官网上的这篇文档 [overlayfs.txt](https://www.kernel.org/doc/Documentation/filesystems/overlayfs.txt) 。

>   **LowerDir**: these are the read-only layers of an overlay filesystem. For docker, these are the image layers assembled in order.
>
>   **UpperDir**: this is the read-write layer of an overlay filesystem. For docker, that is the equivalent of the container specific layer that contains changes made by that container.
>
>   **WorkDir**: this is a required directory for overlay, it needs an empty directory for internal use.
>
>   **MergedDir**: this is the result of the overlay filesystem. Docker effectively chroot’s into this directory when running the container.

总之 overlay2 大法好！根据 overlay2 的特性，我们可以将历史的数据当作 overlay2 里的 lowerdir 来使用。而 upperdir 则是本次镜像同步的增量数据，merged 则是最终实际需要的数据。

## overlay2

虽然在上文中提到了使用 overlay2 的方案，但到目前为止还是没有一个成熟的解决方案。需要解决的问题如下：

1.  如何清理旧数据

2.  如何复用历史的镜像？

3.  如何区分出历史的镜像和本次的镜像？

4.  如何保障本次镜像同步的结果只包含本次需要的镜像？

### registry 存储结构

既然要使用历史的镜像仓库数据来作为 overlay2 的 lowerdir。那么如何解决之前提到的清理旧数据，以及如何使用历史的镜像呢？那么还是需要再次回顾一下 registry 存储目录结构。

![](https://p.k8s.li/registry-storage.jpeg)

根据 registry 的存储结构可以得知，在 blobs 目录下保存的是镜像的 blob 的文件。blob 文件大体上有三种：镜像的 manifests；镜像的 image config 文件；以及镜像的 layer 层文件。其中 manifests 和 images config 文件都是 json 格式的文本文件，镜像的 layer 层文件则是经过压缩的 tar 包文件(一般为 gzip)。如果要复用历史的镜像，很大程度上复用的是镜像的 layer 层文件，因为这些文件是镜像当中最大的，在 docker pull 和 docker push 的时候就是对镜像的 layer 层文件进行解压缩的。

而且对于同一个镜像仓库来讲，blobs 下的文件都是由 repositories 下的 link 文件指向对应的 data 文件的。这就意味着，多个镜像可以使用相同的 layer。比如假如多个镜像的 base 镜像使用的都是  `debian:buster`，那么对于整个 registry 镜像仓库而言，只需要存一份 `debian:buster` 镜像即可。

同理，在使用历史的镜像时，我们是否可以只使用它的 layer 呢？这一点可能比较难理解 😂。我们使用下面这个例子来简单说明下。

```
k8s.gcr.io/kube-apiserver:v1.18.3
k8s.gcr.io/kube-controller-manager:v1.18.3
k8s.gcr.io/kube-scheduler:v1.18.3
k8s.gcr.io/kube-proxy:v1.v1.18.3
```

当我们使用  skopeo copy 将这些镜像从 `k8s.gcr.io` 复制到本地的一个镜像仓库时，复制完第一个镜像后，在 copy 后面的镜像时都会提示 `Copying blob 83b4483280e5 skipped: already exists` 的日志信息。这是因为这些镜像使用的是同一个 base 镜像，这个 base 镜像只包含了一个 layer，也就是 `83b4483280e5` 这一个 blob 文件。虽然本地的镜像仓库中没有这些镜像的 base 镜像，但是有 base 镜像的 layer， skopeo 也就不会再 copy 这个相同的 blob。

```bash
╭─root@sg-02 /home/ubuntu
╰─# skopeo copy docker://k8s.gcr.io/kube-apiserver:v1.18.3 docker://localhost/kube-apiserver:v1.18.3 --dest-tls-verify=false                                                     
Getting image source signatures
Copying blob 83b4483280e5 done
Copying blob 2bfb66b13a96 done
Copying config 7e28efa976 done
Writing manifest to image destination
Storing signatures
╭─root@sg-02 /home/ubuntu
╰─# skopeo copy docker://k8s.gcr.io/kube-controller-manager:v1.18.3 docker://localhost/kube-controller-manager:v1.18.3 --dest-tls-verify=false
Getting image source signatures
Copying blob 83b4483280e5 skipped: already exists
Copying blob 7a73c2c3b85e done
Copying config da26705ccb done
Writing manifest to image destination
Storing signatures
╭─root@sg-02 /home/ubuntu
╰─# skopeo copy docker://k8s.gcr.io/kube-scheduler:v1.18.3 docker://localhost/kube-scheduler:v1.18.3 --dest-tls-verify=false
Getting image source signatures
Copying blob 83b4483280e5 skipped: already exists
Copying blob 133c4d2f432a done
Copying config 76216c34ed done
Writing manifest to image destination
Storing signatures
╭─root@sg-02 /home/ubuntu
╰─# skopeo copy docker://k8s.gcr.io/kube-proxy:v1.18.3 docker://localhost/kube-proxy:v1.18.3 --dest-tls-verify=false
Getting image source signatures
Copying blob 83b4483280e5 skipped: already exists
Copying blob ffa39a529ef3 done
Copying config 3439b7546f done
Writing manifest to image destination
Storing signatures
```

从上面的实验我们可以得知，只要 registry 中存在相同的 blob，skopeo 就不会 copy 这个相同的 blob。那么如何让 skopeo 和 registry 知道存在这些 layer 了呢？

这时需要再次回顾以下 registry 存储结。在 repositories 下，每个镜像的文件夹中都会有 `_layers` 这个目录，而这个目录下的内容正是指向镜像 layer 和 image config 的 link 文件。也就是说：只要某个镜像的 `_layers` 下有指向 blob 的 link 文件，并且该 link 文件指向的 blobs 下的 data 文件确实存在，那么在 push 镜像的时候 registry 就会向客户端返回该 blob 已经存在，而 skopeo 就会略过处理已经存在的 blob 。以此，我们就可以达到复用历史数据的目的。

![](https://p.k8s.li/registry-storage.jpeg)

那么在历史镜像仓库数据中：blobs 目录是全部都要的，而  repositories 目录下只需要每个镜像的 `_layers ` 目录即可。`_manifests` 目录下是镜像的 tag 我们并不需要他们，而 `_uploads` 目录则是 push 镜像时的临时目录也不需要。那么我们最终需要的历史镜像仓库数据就如下：

![](https://p.k8s.li/2021-03-01_09-18-19.jpg)

到此为止已经解决掉了如何清理旧数据和如何如何复用历史的镜像的问题了。接下来要做的如何使用 overlay2  去构建这个文件系统了。

### 套娃：镜像里塞镜像？

提到 overlay2 第一个想到的方案就是容器镜像：使用套娃的方式，将历史的镜像仓库存储目录复制到一个 registry 的镜像里，然后用这个镜像来启动打包镜像仓库的 registry 容器。这个镜像仓库的 `Dockerfile` 如下：

```dockerfile
FROM registry:latest

# 将历史镜像仓库的目录打包成 tar 包，放到 registry 的镜像中， ADD 指令会自动解开这个 tar 包
ADD docker.tar /var/lib/registry/

# 删除掉所有镜像的 _manifests 目录，让 registry 认为里面没有镜像只有 blobs 数据
RUN find /var/lib/registry/docker/registry/v2/repositories -type d -name "_manifests" -exec rm -rf {} \;
```

-   然后使用这个 `Dockerfile` 构建一个镜像，并命名为 `registry:v0.1.0-base` ，使用这个镜像来 docker run 一个容器。

```bash
docker run -d --name registry -p 127.0.0.1:443:5000 registry:v0.1.0-base
```

-   接着同步镜像

```bash
cat images.list | xargs -L1 -I {} skopeo copy  docker://cidi.registry.local/{} docker://package.registry.local/{}
```

-   同步完成镜像之后，需要删除掉 repositories 下没有生成 _manifests 目录的镜像，因为如果本次同步镜像有该镜像的话，会在 repositories 目录下重新生成 _manifests 目录，如果没有生成的话就说明本次同步的列表中不包含该镜像。以此可以解决如何区分出历史的镜像和本次的镜像和如何保障本次镜像同步的结果只包含本次需要的镜像。

```bash
for project in $(ls repositories/); do
  for image in $(ls repositories/${project}); do
    if [[ ! -d "repositories/${project}/${image}/_manifests" ]]; then
    rm -rf repositories/${project}/${image}
  fi
done
```

-   最后还需要使用 registry GC 来删除掉 blobs 目录下没有被引用的文件。

```bash
docker exec -it registry registry garbage-collect /etc/docker/registry/config.yml 
```

-   再使用 docker cp 的方式将镜像从容器里复制出来并打包成一个 tar 包

```bash
docker cp registry:/var/lib/registry/docker docker
tar -cf docker.tar docker
```

使用这种办法做了一下简单的测试，因为使用 skopeo copy 镜像的时候会提示很多 blobs 已经存在了，所以实际上复制的镜像只是一小部分，性能上的确比之前快了很多。但是这种方案也存在很多的弊端：一是这个 registry 的镜像需要手动维护和构建；二是使用 docker cp 的方式将容器内的 registry 存储目录复制到容器宿主机，性能上有点差；三是不同的产品需要不同的 base 镜像，维护起来比较麻烦。综上，我们还需要更为简单一点使用 overlay2 技术。

### 容器挂载 overlay2 merged 目录

仔细想一下，将历史的镜像数据放到 registry 镜像中，用它来启动一个 registry 容器。同步镜像和进行 registry gc 这两部实际上是对 overlay2 的 merged 层进行读写删除操作。那我们为何 不直接在宿主机上创建好 overlay2 需要的目录，然后再使用 overlay2 联合挂载的方式将这些目录挂载为一个 merged 目录。在启动 registry 容器的时候通过 `docker run -v` 参数将这个 merged 目录以 bind 的方式挂载到 registry 容器内呢？

-   首先创建 overlay2 需要的目录

```bash
cd /var/lib/registry
mkdir -p lower upper work merged
```

-   将历史镜像仓库数据放到 lower 目录内

```bash
tar -cf docker.tar -C /var/lib/registry/lower
```

-   删除 所有镜像的 _manifests 目录，让 registry 认为里面没有镜像只有 blobs 数据

```
find /var/lib/registry/lower/docker/registry/v2/repositories -type d -name "_manifests" -exec rm -rf {} \;
```

-   模拟容器的启动，使用 overlay2 联合挂载为一层 merged 层

```bash
mount -t overlay overlay -o lowerdir=lower,upperdir=upper,workdir=work merged
```

-   docker run 启动一个 registry ，并将 merged 挂载到容器内的 `/var/lib/registry/docker` 目录

```bash
docker run -d -name registry -p 127.0.0.1:443:5000 \
-v /var/lib/registry/merged/docker:/var/lib/registry/docker
```

-   同步镜像，将本次发布需要的镜像同步到 registry 中

```bash
cat images.list | xargs -L1 -I {} skopeo copy --insecure-policy --src-tls-verify=false --dest-tls-verify=false docker://cidi.registry.local/{} docker://package.registry.local/{}
```

-   同步完成镜像后，进行 registry gc ，删除无用的 blob 数据

```bash
docker exec -it registry registry garbage-collect /etc/docker/registry/config.yml 
```

-   最后打包 merged 目录，就是本次最终的结果

```bash
cd /var/lib/registry/merged
tar -cf docker.tar docker
```

### registry gc 问题 ？

在使用的过程中遇到过 registry GC 清理不干净的问题：在进行 GC 之后，一些镜像 layer 和 config 文件已经在 blobs 存储目录下删除了，但指向它的 layers/link 文件依旧保存在 repositories 目录下🙄。GitHub 上有个 PR [Remove the layer’s link by garbage-collect #2288](https://github.com/docker/distribution/issues/2288) 就是专门来清理这些无用的 layer link 文件的，最早的一个是三年前的，但是还没有合并😂。

解决办法就是使用我在 [docker registry GC 原理分析](https://blog.k8s.li/registry-gc.html) 文章中提到的方案：手写 registry GC 脚本🙃。

```bash
#!/bin/bash
v2=$1
v2=${v2:="/var/lib/registry/docker/registry/v2"}
cd ${v2}
all_blobs=/tmp/all_blobs.list
: > ${all_blobs}
# delete unlink blob's link file in _layers
for link in $(find repositories -type f -name "link" | grep -E "_layers\/sha256\/.*"); do
    link_sha256=$(echo ${link} | grep -Eo "_layers\/sha256\/.*" | sed 's/_layers\/sha256\///g;s/\/link//g')
    link_short=${link:0:2}
    link_dir=$(echo ${link} | sed 's/\/link//')
    data_file=blobs/sha256/${link_short}/${link}
    if [[ ! -d ${data_file} ]]; then rm -rf ${link_dir}; fi
done
#marking all the blob by all images manifest
for tag in $(find repositories -name "link" | grep current); do
    link=$(cat ${tag} | cut -c8-71)
    mfs=blobs/sha256/${link:0:2}/${link}/data
    echo ${link} >> ${all_blobs}
    grep -Eo "\b[a-f0-9]{64}\b" ${mfs} | sort -n | uniq | cut -c1-12 >> ${all_blobs}
done
#delete blob if the blob doesn't exist in all_blobs.list
for blob in $(find blobs -name "data" | cut -d "/" -f4); do
    if ! grep ${blob} ${all_blobs}; then
        rm -rf blobs/sha256/${blob:0:2}/${blob}
    fi
done
```

##  流程

好了，至此最终的优化方案已经定下来了，虽然比之前的流程复杂了很多很多，但优化的结果是十分明显滴。

![](https://p.k8s.li/2021-03-01-002.jpeg)

## 最佳实践？

可能到此为止你会觉得一头雾水，不知道这篇文章究竟在讲什么。什么镜像同步、历史数据、镜像 blob、layer、overlay2、联合挂载、写时复制等等，被这一堆复杂的背景和概念搞混了😂。本文确实不太好理解，因为背景可能较特殊和复杂，很少人会遇到这样的场景。

为了很好地理解本文所讲到的内容和背后的原理，过段时间我会单独写一篇博客。

## 结果

