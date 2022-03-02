---
title: 同步 docker hub library 镜像到本地 registry
date: 2021-02-10
updated: 2021-02-16
slug:
categories: 技术
tag:
  - registry
  - images
copyright: true
comment: true
---

## 恰烂钱？

自从去年 11 月份开始，docker 公司为了恰点烂钱就对 docker hub 上 pull 镜像的策略进行限制：

- **未登录用户，每 6 小时只允许 pull 100 次**
- **已登录用户，每 6 小时只允许 pull 200 次**

而且，限制的手段也非常地粗暴，通过判断请求镜像的 manifest 文件的次数，请求一个镜像的 manifest 文件就算作一次 pull 镜像。即便你 pull 失败了，也会算作一次。

随后也有很多大佬分享绕过 docker hub 限制的办法，比如搭建私有的镜像仓库，然后再给客户端配置上 `registry-mirrors` 参数，就可以通过本地的镜像仓库来拉取镜像。

- [突破 DockerHub 限制，全镜像加速服务](https://moelove.info/2020/09/20/%E7%AA%81%E7%A0%B4-DockerHub-%E9%99%90%E5%88%B6%E5%85%A8%E9%95%9C%E5%83%8F%E5%8A%A0%E9%80%9F%E6%9C%8D%E5%8A%A1/)
- [绕过从 Docker Hub pull 镜像时的 429 toomanyrequests](https://nova.moe/bypass-docker-hub-429/)
- [如何绕过 DockerHub 拉取镜像限制](https://www.chenshaowen.com/blog/how-to-cross-the-limit-of-dockerhub.html)

但是呢，以上方法都比较局限：首先镜像需要挨个手动 push 到本地镜像仓库；其次本地镜像仓库中的镜像无法和官方镜像保持同步更新，如果要使用新的 tag 好的镜像仍然需要手动将镜像从 docker hub 上 pull 下来，然后再 push 到本地镜像仓库；还有手动 push 镜像是比较混乱的，如果使用的镜像比较多，比如公有云容器服务，这时候再手动 push 的话管理起来是及其不方便的。

因此经过一番折腾终于摸索出了一个方案：将 docker hub 上 library repo 的镜像同步到本地镜像仓库，最终要做到上游如果更新了镜像 tag 也能自动地将镜像同步到本地镜像仓库。

## 获取镜像 tag

对于 docker hub 上的镜像，我们使用到最多的就是 library 这个 repo 即 [Official Images on Docker Hub](https://docs.docker.com/docker-hub/official_images/)，里面包含着大部分开源软件和 Linux 发行版的基础镜像。

> - Provide essential base OS repositories (for example, [ubuntu](https://hub.docker.com/_/ubuntu/), [centos](https://hub.docker.com/_/centos/)) that serve as the starting point for the majority of users.
> - Provide drop-in solutions for popular programming language runtimes, data stores, and other services, similar to what a Platform as a Service (PAAS) would offer.
> - Exemplify [`Dockerfile` best practices](https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/) and provide clear documentation to serve as a reference for other `Dockerfile` authors.
> - Ensure that security updates are applied in a timely manner. This is particularly important as Official Images are some of the most popular on Docker Hub.

library 的镜像常见的特点就是当我们使用 docker 客户端去 pull 一个镜像时，无需指定该镜像的 repo ，比如 `ubuntu:latest`，其他非 library 的镜像需要指定镜像所属的 repo ，比如 `jenkins/slave:latest`。这部分代码是硬编码在 docker 的源码当中的。

> 我们虽然日常访问的是 `https://hub.docker.com` ，但是我们在 [https://github.com/docker/distribution/blob/master/reference/normalize.go#L13](https://github.com/docker/distribution/blob/master/reference/normalize.go#L13) 中可以看到实际 `docker` 使用的地址是一个硬编码的 `docker.io`
>
> ```golang
> var (
> 	legacyDefaultDomain = "index.docker.io"
> 	defaultDomain       = "docker.io"
> 	officialRepoName    = "library"
> 	defaultTag          = "latest"
> )
> ```

我们可以通过如下几种办法来获取 docker hub 上 library repo 的镜像列表。

### 通过 docker registry 命令行

在 docker 官方文档中 [docker registry](https://docs.docker.com/engine/reference/commandline/registry/) 有提到可以列出某个 registry 中的镜像，但这个功能仅限于 [Docker Enterprise Edition.](https://docs.docker.com/ee/supported-platforms/) 版本，而社区的版本中未有该命令。遂放弃……

> This command is only available on Docker Enterprise Edition.
>
> Learn more about [Docker Enterprise products](https://docs.docker.com/ee/supported-platforms/).

```bash
docker registry ls # List registry images
```

### 通过 registry v2 API

- `get-images.list`

```bash
#!/bin/bash
set -eo pipefail

DOCKER_HUB_URL="https://hub.docker.com/v2/repositories/library"

get_images_list() {
    ALL_IMAGES=""
    URL="${DOCKER_HUB_URL}/?page_size=100"
    while true ; do
        ALL_IMAGES="$(curl -sSL ${URL} | jq -r '.results[].name' | tr '\n' ' ') ${ALL_IMAGES}"
        URL="$(curl -sSL ${URL} | jq -r '.next')"
        if [ "${URL}" = "null" ]; then break; fi
    done
    : > all_library_images.list
    for image in ${ALL_IMAGES};do
        if skopeo list-tags docker://${image} &> /dev/null; then
            skopeo list-tags docker://${image} | jq ".Tags" | tr -d '[],\" ' | tr -s '\n' | sed "s|^|${image}:|g" >> all_library_images.list
        fi
    done
}
get_images_list
```

通过 docker hub 的  API 获取到的镜像 tag 实在是太多了，截至今日 docker hub 上整个 [library repo](https://hub.docker.com/u/library) 的项目一共有 162 个，而这 162 个项目中的镜像 tag 数量多达**五万两千**多个。总的镜像仓库存储占用空间的大小预计至少 5TB 。其中的镜像我们真正需要用到的估计也不到 **0.1%**，因此需要想个办法减少这个镜像列表的数量，获得的镜像列表更精确一些，通用一些。

```bash
╭─root@sg-02 /opt/official-images ‹sync*›
╰─# cat all_library_images.list|cut -d ':' -f1 | sort -u | wc
    162     162    1353
╭─root@sg-02 /opt/official-images ‹sync*›
╰─# cat all_library_images.list | wc
  52094   52094 1193973
```

### 通过 official-images repo

以 [debian](https://hub.docker.com/_/debian) 为例，在 docker hub 上镜像的 tag 基本上都是这样子的：

> **Supported tags and respective `Dockerfile` links**
>
> - [`bullseye`, `bullseye-20210208`](https://github.com/debuerreotype/docker-debian-artifacts/blob/b05117a87fbd32f977b4909e399fe368c75767ad/bullseye/Dockerfile)
> - [`bullseye-backports`](https://github.com/debuerreotype/docker-debian-artifacts/blob/b05117a87fbd32f977b4909e399fe368c75767ad/bullseye/backports/Dockerfile)
> - [`bullseye-slim`, `bullseye-20210208-slim`](https://github.com/debuerreotype/docker-debian-artifacts/blob/b05117a87fbd32f977b4909e399fe368c75767ad/bullseye/slim/Dockerfile)
> - [`buster`, `buster-20210208`, `10.8`, `10`, `latest`](https://github.com/debuerreotype/docker-debian-artifacts/blob/b05117a87fbd32f977b4909e399fe368c75767ad/buster/Dockerfile)
> - [`buster-backports`](https://github.com/debuerreotype/docker-debian-artifacts/blob/b05117a87fbd32f977b4909e399fe368c75767ad/buster/backports/Dockerfile)
> - [`buster-slim`, `buster-20210208-slim`, `10.8-slim`, `10-slim`](https://github.com/debuerreotype/docker-debian-artifacts/blob/b05117a87fbd32f977b4909e399fe368c75767ad/buster/slim/Dockerfile)
> - [`experimental`, `experimental-20210208`](https://github.com/debuerreotype/docker-debian-artifacts/blob/b05117a87fbd32f977b4909e399fe368c75767ad/experimental/Dockerfile)
> - [`jessie`, `jessie-20210208`, `8.11`, `8`](https://github.com/debuerreotype/docker-debian-artifacts/blob/b05117a87fbd32f977b4909e399fe368c75767ad/jessie/Dockerfile)
> - [`jessie-slim`, `jessie-20210208-slim`, `8.11-slim`, `8-slim`](https://github.com/debuerreotype/docker-debian-artifacts/blob/b05117a87fbd32f977b4909e399fe368c75767ad/jessie/slim/Dockerfile)

每一行都代表着同一个镜像，如： [`buster`, `buster-20210208`, `10.8`, `10`, `latest`](https://github.com/debuerreotype/docker-debian-artifacts/blob/b05117a87fbd32f977b4909e399fe368c75767ad/buster/Dockerfile) 。一行中镜像虽然有多个 tag，但这些 tag 指向的 manifest 其实都是一致的。镜像 tag 的关系有点类似于 C 语言里的指针变量，是引用的关系。

但这么多的信息是如何高效地管理的呢？于是顺藤摸瓜发现了：由于 library repo 里的镜像构建信息都是由 [official-images](https://github.com/docker-library/official-images) 这个 repo 来管理的。

```bash
# buster -- Debian 10.8 Released 06 February 2021
Tags: buster, buster-20210208, 10.8, 10, latest
Architectures: amd64, arm32v5, arm32v7, arm64v8, i386, mips64le, ppc64le, s390x
Directory: buster

Tags: buster-backports
Architectures: amd64, arm32v5, arm32v7, arm64v8, i386, mips64le, ppc64le, s390x
Directory: buster/backports

Tags: buster-slim, buster-20210208-slim, 10.8-slim, 10-slim
Architectures: amd64, arm32v5, arm32v7, arm64v8, i386, mips64le, ppc64le, s390x
Directory: buster/slim
```

在这个 [official-images](https://github.com/docker-library/official-images)  repo 里  library 目录下有以镜像 name 命名的文件，而文件的内容正是记录着与 docker hub 相对应的 tag 信息。由此我们可以根据这个 repo 获取 library repo 镜像的 tag。好处在于虽然这样得到的镜像列表并不是全面的，但这个 repo 里记录的镜像 tag 都是官方还在维护的，并不会包含一些旧的或者 CI 测试的镜像。这样获得的镜像列表更通用一些。

拿出 Linux 文本处理三剑客，一顿操作搓出了个脚本来生成镜像以及镜像的数量。惊奇的发现，通过这种方式获取到的镜像数量为 docker hub 的 registry API 获取到的镜像数量的十分之一左右。根据如下数据可以得出，docker hub 真实需要的镜像数量为 1517 个，而 5590 个镜像中包含了多个 tag 指向同一个镜像的情况，因此，我们只需要将这些相同镜像的 tag pull 一次即可，其余的镜像通过 retag 的方式打上 tag 即可。

```bash
# 获取镜像列表
$ grep -Er "^Tags:|^SharedTags:" library | sed 's|library/||g;s|:Tags||g;s|:SharedTags||g;s| ||g'

# 获取镜像数量，也就是 manifests 的数量
$ grep -Er "^Tags:|^SharedTags:" library | sed 's|library/||g;s|:Tags||g;s|:SharedTags||g;s| ||g' | wc
   1518    1518   95999
# 获取所有镜像 tag 数量，包含了所有的 tag
$ grep -Er "^Tags:|^SharedTags:" library | sed 's|library/||g;s|:Tags||g;s|:SharedTags||g;s| ||g' | tr ',' '\n' | wc
   5590    5590   95999
```

## 本地同步镜像

获取到镜像列表之后，我们就可用使用 [skopeo copy](https://github.com/containers/skopeo/blob/master/docs/skopeo-copy.1.md) 直接将镜像 copy 到本地的镜像仓库中啦。结合上述步骤，使用不到 20 行的脚本就能完成：

```bash
ALL_IMAGES=$(grep -Er "^Tags:|^SharedTags:" library \
| sed 's|library/||g;s|:Tags||g;s|:SharedTags||g;s| ||g')
IFS=$'\n'
for image in ${ALL_IMAGES}; do
    name="$(echo ${image} | cut -d ':' -f1)"
    tags="$(echo ${image} | cut -d ':' -f2 | cut -d ',' -f1)"
    if skopeo copy docker://${name}:${tags} docker://registry.local/library/${name}:${tags}; then
    for tag in $(echo ${image} | cut -d ':' -f2 | tr ',' '\n'); do
        skopeo copy docker://${name}:${tag} docker://registry.local/library/${name}:${tags};
     done
     fi
done
```

但，没我想象中的那么简单，在自己的机器上 pull 了不到 150 个镜像的时候就报错退出了，提示 `toomanyrequests: You have reached your pull rate limit.` 错误。心里 mmp，docker inc 啊，干啥啥不行（如今 Docker Machine，Docker Swarm，docker-compose 三驾马车哪儿去了？），**恰烂钱可还行** 😡。

> ime="2021-02-12T07:08:51Z" level=fatal msg="Error parsing image name \"docker://ubuntu:latest\":
>
> Error reading manifest latest in docker.io/library/ubuntu: toomanyrequests: You have reached your pull rate limit. You may increase the limit by authenticating and upgrading: [https://www.docker.com/increase-rate-limit](https://www.docker.com/increase-rate-limit)"

## Dockerfile 里同步镜像？

既然在本地有 pull 次数的限制，那什么地方不会有这种限制呢？首先想到的是 docker hub 上 build 镜像肯定不会限制吧。应该是的……。不如在 Dockerfile 里塞一个脚本，用它来同步镜像如何？于是一顿操作猛如虎，不一会儿就搓出来个 Dockerfile。

```dockerfile
FROM debian:unstable-slim
RUN set -xue ;\
    apt update -y ;\
    apt install ca-certificates skopeo git curl jq -y --no-install-recommends ;\
    rm -rf /var/lib/apt/lists/* ;\
    git clone -b sync https://github.com/muzi502/official-images /build
RUN set -xue ;\
    skopeo login hub.k8s.li -u admin -p Harbor123456 ;\
    bash /build/sync-images.sh
```

然……事实证明是我太天真了，在同步了不到 100 多个镜像后，同样也出现了 429 toomanyrequests 的限制。掀桌儿！在 docker hub 上构建镜像，也会被限制？自己限制自己？？这什么鸡儿玩意。

~~假如有一个多阶段构建的 Dockerfile，就有可能因为拉不到镜像而导致镜像构建失败。那么这种智障的设计没想到过？~~

想到一种可能是 docker hub 内部是通过 token 来进行验证的，而不是根据客户端访问源 IP 。build 镜像的宿主机上会有 docker login 的 token 文件，但 build 镜像的容器里是没有这个 token 文件的，所以在 dockerfile 里 pull 镜像同样会被限制。看来 dockerfile 里同步镜像的方案也就不行了 🙃，只能另寻他路啦。

## GitHub Action 来同步镜像

### ssh 连接 runner

在刚开始写这篇博客的时候也没有想到使用 GitHub Action，在刷 GitHub 动态的时候无意间发现了它。于是又一顿操作看看 GitHub Action 是否能用来同步镜像。

首先参考 [SSH 连接到 GitHub Actions 虚拟服务器](https://p3terx.com/archives/ssh-to-the-github-actions-virtual-server-environment.html) 连接到 runner 的机器上:

- `.github/workflows/ssh.yaml`

```yaml
name: Ubuntu
on: push
jobs:
  build:
    runs-on: ubuntu-20.04
    steps:
    - uses: actions/checkout@v1
    - name: Setup tmate session
      uses: mxschmitt/action-tmate@v1
```

使用 ssh 连接到 action runner 的机器里意外发现，在 `~/.docker/config.json ` 文件里竟然已经有了个 login 的 docker hub 账户。`哦豁.jpg`。由于 docker login 的配置文件只是简单的 base64 加密，解码后拿到真实的 user 和 token。

```shell
runner@fv-az60-303:~$ cat .docker/config.json
{
        "auths": {
                "https://index.docker.io/v1/": {
                        "auth": "Z2l0aHViYWN0aW9uczozZDY0NzJiOS0zZDQ5LTRkMTctOWZjOS05MGQyNDI1ODA0M2I="
                }
        }
}runner@fv-az60-303:~$ echo "Z2l0aHViYWN0aW9uczozZDY0NzJiOS0zZDQ5LTRkMTctOWZjOS05MGQyNDI1ODA0M2I=" | base64 -d
githubactions:3d6472b9-3d49-4d17-9fc9-90d24258043b
```

![](https://p.k8s.li/image-20210216173039196.png)

于是想着可以验证一下这个账户是否有限制：

```bash
curl --user 'githubactions:3d6472b9-3d49-4d17-9fc9-90d24258043' "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull"
```

但失败了，提示 `{"details":"incorrect username or password"}` ，估计这个账户是个 bot 账户，只能用于 pull 镜像，其他的 api 请求都没权限使用。至于这个账户有没有限制，还需要做下测试。

另外意外地发现 runner 的机器里集成了很多工具，其中  skopeo 也包含在内，实在是太方便了。GitHub 牛皮，微软爸爸我爱你 😘！那就方便了，我们就使用 skopeo inspect 去请求镜像的 manifests 文件。看看最多能请求多少会被限制。于是花了点时间搓了个脚本用于去获取 docker hub 上 library repo 中的所有镜像的 manifests 文件。

- `get-manifests.sh`

```bash
#!/bin/bash
set -eo pipefail

DOCKER_HUB_URL="https://hub.docker.com/v2/repositories/library"
IMAGES_LIST="images.list"

get_images_list() {
    ALL_IMAGES=""
    URL="${DOCKER_HUB_URL}/?page_size=100"
    while true ; do
        ALL_IMAGES="$(curl -sSL ${URL} | jq -r '.results[].name' | tr '\n' ' ') ${ALL_IMAGES}"
        URL="$(curl -sSL ${URL} | jq -r '.next')"
        if [ "${URL}" = "null" ]; then break; fi
    done
    : > ${IMAGES_LIST}
    for image in ${ALL_IMAGES};do
        if skopeo list-tags docker://${image} &> /dev/null; then
            skopeo list-tags docker://${image} | jq -c ".Tags" | tr -d '[]\"' \
            | tr ',' '\n' | sed "s|^|${image}:|g" >> ${IMAGES_LIST}
        fi
    done
}

get_manifests() {
    mkdir -p manifests
    IFS=$'\n'
    for image in $(cat ${IMAGES_LIST}); do
        if skopeo inspect --raw docker://${image} | jq  -r '.manifests[].digest' &> /dev/null ; then
            skopeo inspect --raw docker://${image} | jq  -r '.manifests[].digest' \
            |  xargs -L1 -P8 -I % sh -c "skopeo inspect --raw docker://${image/:*/}@% > manifests/${image}@%.json"
        else
            skopeo inspect --raw docker://${image} > manifests/${image}.json
        fi
    done
}

get_images_list
get_manifests
```

经过一番长时间的刺测试，在获取了 20058   个镜像的 manifest 文件之后依旧没有被限制，于是大胆猜测，runner 里内置的 docker hub 账户 pull library 镜像是没有限制的。估计是 GitHub 和 docker inc 达成了  py 交易，用这个账户去 pull 公共镜像没有限制。

![](https://p.k8s.li/image-20210216173003436.png)

```shell
runner@fv-az212-267:~/work/runner-test/runner-test$ ls manifests/ | wc
  20058   20058 1875861
```

### 定时同步镜像

从上述步骤一可知在 GitHub Action runner 机器里自带的 docker login 账户是没有限制，那我们最终就选定使用它来同步镜像到本地 registry 吧。参照 GitHub Action 照葫芦画瓢搓了个 action 的配置文件：

```yaml
name: sync-images

on:
  push:
    branches:
      - sync
  # 设置定时任务，每 6 小时运行一次
  schedule:
    - cron: "* */6 * * *"

jobs:
  sync-images:
    runs-on: ubuntu-20.04
    steps:
      - name: Clone repository
        uses: actions/checkout@v2
      - run: |
          git config user.name github-actions
          git config user.email github-actions@github.com

      - name: Sync images
        shell: bash
        env:
          REGISTRY_DOMAIN: ${{ secrets.REGISTRY_DOMAIN }}
          REGISTRY_USER: ${{ secrets.REGISTRY_USER }}
          REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
        run: |
          sudo skopeo login ${REGISTRY_DOMAIN}  -u ${REGISTRY_USER} -p ${REGISTRY_PASSWORD}
          sudo bash sync-images.sh ${REGISTRY_DOMAIN}

```

既然 GitHub runner 的机器里有 docker login 的配置文件，不如把它**偷**过来，复制粘贴到自家的机器上使用 😜？不过我认为这种行为有点不厚道 😂，还是别干了。在这里只提供一个思路，实际上可行性还待验证。

### 增量同步

默认设置的为 6 小时同步一次上游最新的代码，由于定时更新是使用的增量同步，即通过 git diff 的方式将当前分支最新的 commit 和上游 docker hub 官方的 repo 最新 commit 进行比较，找出变化的镜像。因此如果是首次同步，需要全量同步，在同步完成之后会给 repo 打上一个时间戳的 tag ，下次同步的时候就用这个 tag 和上游 repo 最新 commit 做差异比较。

```shell
IMAGES=$(git diff --name-only --ignore-space-at-eol --ignore-space-change \
    --diff-filter=AM ${LAST_TAG} ${CURRENT_COMMIT} library | xargs -L1 -I {} sed "s|^|{}:|g" {} \
    | sed -n "s| ||g;s|library/||g;s|:Tags:|:|p;s|:SharedTags:|:|p" | sort -u | sed "/${SKIPE_IMAGES}/d")
```

## 如何食用？

如果你也想将 docker hub 上 library repo 的镜像搞到本地镜像仓库，可以参考如下方法：

### 劝退三连 😂

- 首先要本地部署好镜像仓库并配置好 SSL 证书。镜像仓库建议使用 docker registry 或者 harbor，具体的部署方法可以在互联网上找到。
- 需要个大盘鸡（大硬盘机器），当前 docker hub 上还在维护的 tag 镜像总大小为 128 GB 左右。
- 如果是长期使用，本地镜像仓库的存储空间至少 1TB 以上。
- 由于是使用 GitHub action 的机器将镜像 push 到本地镜像仓库，因此本地镜像仓库需要有个公网 IP 以及域名 + SSL 证书

### 增加配置

首先 fork 官方的 repo [docker-library/official-images](https://github.com/docker-library/official-images)  到自己的 GitHub 账户下；

然后 fork 这个 repo [muzi502/sync-library-images](https://github.com/muzi502/sync-library-images) 到自己的 GitHub 账户下；

最后在自己的 sync-library-images 这个 repo 的 `Settings >  Secrets` 中配置好如下三个变量：

- REGISTRY_DOMAIN 设置为本地镜像仓库的域名
- REGISTRY_USER 本地镜像仓库的用户名
- REGISTRY_PASSWORD 设置为本地镜像仓库的密码

![](https://p.k8s.li/image-20210216163441719.png)

## 参考

- [Official Images on Docker Hub](https://docs.docker.com/docker-hub/official_images/)
- [How do I authenticate with the V2 API?](https://hub.docker.com/support/doc/how-do-i-authenticate-with-the-v2-api)
- [Download rate limit](https://docs.docker.com/docker-hub/download-rate-limit/)
- [突破 DockerHub 限制，全镜像加速服务](https://moelove.info/2020/09/20/%E7%AA%81%E7%A0%B4-DockerHub-%E9%99%90%E5%88%B6%E5%85%A8%E9%95%9C%E5%83%8F%E5%8A%A0%E9%80%9F%E6%9C%8D%E5%8A%A1/)
- [绕过从 Docker Hub pull 镜像时的 429 toomanyrequests](https://nova.moe/bypass-docker-hub-429/)
- [如何绕过 DockerHub 拉取镜像限制](https://www.chenshaowen.com/blog/how-to-cross-the-limit-of-dockerhub.html)
- [SSH 连接到 GitHub Actions 虚拟服务器](https://p3terx.com/archives/ssh-to-the-github-actions-virtual-server-environment.html)
