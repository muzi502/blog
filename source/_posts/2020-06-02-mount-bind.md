---
title: mount 命令之 --bind 挂载参数
date: 2020-06-02
updated:
slug:
categories: 技术
tag: 
  - linux
  - overlay2
  - docker
copyright: true
comment: true
---

## 翻车（：

由于我的 VPS 不是大盘鸡(就是大容量磁盘机器啦😂)， docker 存储目录 `/var/lib/docker` 所在的分区严重不足，于是就想着在不改变 docker 配置的下将 `/opt` 目录下的分区分配给 `/var/lib/docker` 目录。首先想到的是把 `/var/lib/docker` 复制到 `/opt/docker`，然后再将 `/opt/docker` 软链接到 `/var/lib/docker` 。

于是我就一顿操作猛如虎，`mv /var/lib/docker /opt/docker && ln -s /opt/docker /var/lib/docker` 一把梭，然后我启动一个容器的时候当场就翻车了🤣。

原来有些程序是不支持软链接目录的，还有一点就是软链接的路径也有点坑。比如我将 `/opt/docker -> /var/lib/docker/` ，在 `/var/lib/docker` 目录下执行 `ls ../` 即它的上一级目录是 `/opt` 而不是 `/var/lib` ，对于一些依赖相对路径的应用（尤其是 shell 脚本）来讲这样使用软链接的方式也容易翻车😂。

那么有没有一种更好的办法将两个目录进行“硬链接”呢，注意我在此用的是双引号，并非是真正的”硬链接“，搜了一圈发现 mount --bind 这种骚操作。无论我们对文件使用软链接/硬链接/bind，还是对目录使用软链接，其实都是希望操作的 `src` 和 `dest` 他们二者都能保持一致。通过 bind 挂载的方式具有着挂载点的一些特性，这是链接是不具有的，对一些不支持链接的应用来讲，bind 的方式要友好一些。

## bind

其实 bind 这个挂载选项我们在使用 docker 或者 kubernetes 多少都会用到的，尤其是当使用 kubernetes  时 kubelet 在启动容器挂载存储的时候底层是将 node 节点本机的 `/var/lib/kubelet/pods/<Pod的ID>/volumes/kubernetes.io~<Volume类型>/<Volume名字>` 目录通过 bind 的方式挂载到容器中的，详细的分析可以参考之前我写的一篇博客 [kubelet 挂载 volume 原理分析](https://blog.k8s.li/kubelet-mount-volumes-analysis.html) 。

>   -   **Volumes** are stored in a part of the host filesystem which is *managed by Docker* (`/var/lib/docker/volumes/` on Linux). Non-Docker processes should not modify this part of the filesystem. Volumes are the best way to persist data in Docker.
>   -   **Bind mounts** may be stored *anywhere* on the host system. They may even be important system files or directories. Non-Docker processes on the Docker host or a Docker container can modify them at any time.
>   -   **`tmpfs` mounts** are stored in the host system’s memory only, and are never written to the host system’s filesystem.

不过那时候并没有详细地去了解 bind 的原理，直到最近翻了一次车才想起来 bind ，于是接下来就详细地分析以下 mount --bind 挂载参数。

```shell
# 使用软链接链接目录
# ls -i 显示文件/目录的 inode 号
╭─root@sg-02 /var/lib
╰─# ln -s /opt/docker /var/lib/docker
╭─root@sg-02 /var/lib
╰─# ls -i /opt | grep docker
2304916 docker
╭─root@sg-02 /var/lib
╰─# ls -i /var/lib | grep docker
    211 docker

# 使用硬链接链接两个文件
╭─root@sg-02 /var/lib
╰─# ln /usr/local/bin/docker-compose /usr/bin/docker-compose
╭─root@sg-02 /var/lib
╰─# ls -i /usr/bin/docker-compose
112 /usr/bin/docker-compose
╭─root@sg-02 /var/lib
╰─# ls -i /usr/bin/docker-compose
112 /usr/bin/docker-compose

# 使用 --bind 挂载目录
╭─root@sg-02 /var/lib
╰─# mount --bind /opt/docker /var/lib/docker
╭─root@sg-02 /var/lib
╰─# ls -i /var/lib | grep docker
2304916 docker
╭─root@sg-02 /var/lib
╰─# ls -i /opt | grep docker
2304916 docker
```

我们可以看到当使用使用硬链接或 bind 挂载目录时，两个文件 inode 号是相同的，使用软链接的两个文件的 inode 号是不同的。但目录又不能使用硬链接，而且硬链接不支持跨分区。我们是否可以将 bind 的效果和
“硬链接目录“ 样来使用呢？其实可以这样用，但这样类比并不严谨。

当我们使用 bind 的时候，是将一个目录 A  挂载到另一个目录 B ，目录 B 原有的内容就被屏”蔽掉“了，目录 B 里面的内容就是目录 A 里面的内容。这和我们挂在其他分区到挂载点目录一样，目录 B 的内容还是存在的，只不过是被”屏蔽“掉了，当我们 umount B 后，原内容就会复现。

当我们使用 `docker run -v PATH:PATH` 启动一个容器的时候，实质上也是会用到 `bind`，docker 会将主机的目录通过 `bind` 的方式挂载到容器目录。下面我们启动一个 alpine 容器来实验一下。

```shell
docker run --name alpine -v /opt/bind/:/var --privileged --rm -it alpine sh
docker inspect alpine
```

```json
"Mounts": [
    {
        "Type": "bind",
        "Source": "/opt/bind",
        "Destination": "/var",
        "Mode": "",
        "RW": true,
        "Propagation": "rprivate"
    }
]
```

在容器内使用 umount 命令卸载掉 `/var` ，umount 操作需要 root 权限，这也是为什么要在容器启动的时候加上 `--privileged` 参数来启动一个特权容器的原因。

```shell
/ # ls /var/
74898710_p21.jpg    MJSTEALEY.md        docker-compose.yml  letsencrypt         resolv.conf
CONSOLE.md          README.md           hostname            logs                stop-and-remove.sh
LICENSE             config              hosts               nginx               webp-server
/ # umount /var/
# umount 之后容器内原来的 /var 目录内容"恢复"了
/ # ls /var/
cache  empty  lib    local  lock   log    mail   opt    run    spool  tmp
```

## 其他用处🤔

### 无缝更新 Webp Server Go

在 [小土豆]()、[Nona]() 大佬讨论 [Webp Server Go]() 无缝更新的时候我们提出了一个思路：

>   -   在更新之前先对 nginx 配置文件进行修改，去掉 webp server 的 location 字段：
>
>   ```nginx
>           location ~* \.(png|jpg|jpeg)$ {
>               proxy_pass http://127.0.0.1:3333;
>               proxy_set_header HOST $http_host;
>               add_header Cache-Control 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0';
>           }
>   ```
>
>   -   然后再 nginx -s reload 不中断 reload 一
>   -   接着停掉 webp server 服务 `systemctl stop webps`
>   -   mv webp-server{.bak,}
>   -   mv ./upload/webp-server-linux-amd64 webp-server
>   -   接着启动 webp server 服务 `systemctl start webps`
>   -   然后开倒车把 nginx 配置文件再改回去🍞

在此需要提几点，我们希望**无缝更新**，即在更新的过程中不会导致用户请求图片资源失败，那怕 `+1s`都不行，所以我们需要暂时性地在 nginx 配置文件里去掉 webp server ，使它去请求原图片，等更新完 webp server 之后再添加上去。

对于木子这种经常删库跑路的手残菜鸟来讲，对一个配置文件改来改去不是好方法，万一 nginx 配置文件改来改去没改好， nginx -s reload 一下 nginx 服务就炸了😂。那么使用 cp 和 mv 怎么样。

```shell
cp blog.conf{,.bak}
vim blog.conf
nginx -s reload
- update webp server
mv blog.conf{,.bak2}
mv blog.conf{.bak,}
nginx -s reload
```

使用 bind 呢？好像少了一步，下次更新 webp server 的时候只需要 umount 一下，更新完之后再 mount 一下就可以啦。

```shell
cp blog.conf{,.bak}
vim blog.conf
nginx -s reload
- update webp server
mount --bind blog.conf.bak blohg.conf
nginx -s reload
```

### VPS 搬家助手

其实还有很多用途啦，这里就不罗列了

