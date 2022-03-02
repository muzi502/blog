---
title: 使用 overlay2 或 bind 重新构建 ISO 镜像
date: 2022-01-25
updated: 2022-01-26
slug:
categories: 技术
tag:
  - overlay2
  - ISO
copyright: true
comment: true
---

笔者之前在字节跳动的时候是负责 PaaS 容器云平台的私有化部署相关的工作，所以经常会和一些容器镜像打交道，对容器镜像也有一些研究，之前还写过不少博客文章。比如 [深入浅出容器镜像的一生 🤔](https://blog.k8s.li/Exploring-container-image.html)、[overlay2 在打包发布流水线中的应用](https://blog.k8s.li/overlay2-on-package-pipline.html) 等等。

自从换了新工作之后，则开始负责 [超融合产品](https://www.smartx.com/smartx-hci/) 集群部署相关工作，因此也会接触很多 `镜像`，不过这个镜像是操作系统的 ISO 镜像而不是容器镜像 😂。虽然两者都统称为镜像，但两者有着本质的区别。

首先两者构建的方式有本质的很大的区别，ISO 镜像一般使用 `mkisofs` 或者 `genisoimage` 等命令将一个包含操作系统安装所有文件目录构建为一个 ISO 镜像；而容器镜像构建则是根据 `Dockerfile` 文件使用相应的容器镜像构建工具来一层一层构建；

另外 ISO 镜像挂载后是只读的，这就意味着如果想要修改 ISO 镜像中的一个文件（比如 kickstart 文件），则需要先将 ISO 镜像中的所有内容负责到一个可以读写的目录中，在这个读写的目录中进行修改和重新构建 ISO 操作。

```bash
╭─root@esxi-debian-devbox ~/build
╰─# mount -o loop CentOS-7-x86_64-Minimal-2009.iso /mnt/iso
mount: /mnt/iso: WARNING: device write-protected, mounted read-only.
╭─root@esxi-debian-devbox ~/build
╰─# touch /mnt/iso/kickstart.cfg
touch: cannot touch '/mnt/iso/kickstart.cfg': Read-only file system
```

在日常工作中经常会对一些已有的 ISO 镜像进行重新构建，重新构建 ISO 的效率根据不同的方式也会有所不同，本文就整理了三种不同重新构建 ISO 镜像的方案供大家参考。

## 常规方式

以下是按照 RedHat 官方文档 [ WORKING WITH ISO IMAGES](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/anaconda_customization_guide/sect-iso-images) 中的操作步骤进行 ISO 重新构建。

- 首先我们下载一个 ISO 文件，这里以 [CentOS-7-x86_64-Minimal-2009.iso](https://mirrors.tuna.tsinghua.edu.cn/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-Minimal-2009.iso) 为例，下载好之后将它挂载到本地 `/mn/iso` 目录下；

```bash
╭─root@esxi-debian-devbox ~/build
╰─# mount -o loop CentOS-7-x86_64-Minimal-2009.iso /mnt/iso
mount: /mnt/iso: WARNING: device write-protected, mounted read-only.
```

- 将 ISO 里的所有文件复制到另一个目录

```bash
╭─root@esxi-debian-devbox ~/build
╰─# rsync -avrut --force /mnt/iso/ /mnt/build/
```

- 进入到该目录下修改或新增文件，然后重新构建 ISO 镜像

```bash
# 使用 genisoimage 命令构建 ISO 镜像，在 CentOS 上可以使用 mkisofs 命令，参数上会有一些差异
╭─root@esxi-debian-devbox ~/build
╰─# genisoimage -U -r -v -T -J -joliet-long -V "CentOS 7 x86_64" -volset "CentOS 7 x86_64" -A "CentOS 7 x86_64" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -no-emul-boot -o /mnt/CentOS-7-x86_64-Minimal-2009-dev.iso .
Total translation table size: 124658
Total rockridge attributes bytes: 55187
Total directory bytes: 100352
Path table size(bytes): 140
Done with: The File(s)                             Block(s)    527985
Writing:   Ending Padblock                         Start Block 528101
Done with: Ending Padblock                         Block(s)    150
Max brk space used a4000
528251 extents written (1031 MB)
# 给 ISO 镜像生成 md5 校验
╭─root@esxi-debian-devbox ~/build
╰─# implantisomd5 /mnt/CentOS-7-x86_64-Minimal-2009-dev.iso
Inserting md5sum into iso image...
md5 = 9ddf5277bcb1d8679c367dfa93f9b162
Inserting fragment md5sums into iso image...
fragmd5 = f39e2822ec1ae832a69ae399ea4bd3e891eeb31e9deb9c536f529c15bbeb
frags = 20
Setting supported flag to 0
```

对于 ISO 镜像比较小或者该操作不是很频繁的情况下按照这种方式是最省事儿的，但如果是 ISO 镜像比较大，或者是在 CI/CD 流水线中频繁地重新构建镜像，每次都要 cp 复制原 ISO 镜像的内容确实比较浪费时间。那有没有一个更加高效的方法呢 🤔️

经过一番摸索，折腾出来两种可以避免使用 cp 复制这种占用大量 IO 操作的构建方案，可以根据不同的场景进行选择。

## overlay2

熟悉 docker 镜像的应该都知道镜像是只读的，使用镜像的时候则是通过联合挂载的方式将镜像的每一层 layer 挂载为只读层，将容器实际运行的目录挂载为读写层，而容器运行期间在读写层的所有操作不会影响到镜像原有的内容。容器镜像挂载的方式使用最多的是 overlay2 技术，在 [overlay2 在打包发布流水线中的应用](https://blog.k8s.li/overlay2-on-package-pipline.html) 和 [深入浅出容器镜像的一生 🤔](https://blog.k8s.li/Exploring-container-image.html) 中咱曾对它进行过比较深入的研究和使用，对 overlay2 技术感兴趣的可以翻看一下这两篇博客，本文就不再详解其中的技术原理了，只对使用 overlay2 技术重新构建 ISO 镜像的可行性进行一下分析。

- 首先是创建 overlay2 挂载所需要的几个目录

```bash
╭─root@esxi-debian-devbox ~
╰─# mkdir -p /mnt/overlay2/{lower,upper,work,merged}
╭─root@esxi-debian-devbox ~
╰─# cd /mnt/overlay2
```

- 接着将 ISO 镜像挂载到 overlay2 的只读层 `lower` 目录

```bash
╭─root@esxi-debian-devbox /mnt/overlay2
╰─# mount -o loop  /root/build/CentOS-7-x86_64-Minimal-2009.iso lower
mount: /mnt/overlay2/lower: WARNING: device write-protected, mounted read-only.
```

- 使用 mount 命令挂载 overlay2 文件系统，挂载点为 `merged` 目录

```bash
╭─root@esxi-debian-devbox /mnt/overlay2
╰─# mount -t overlay overlay -o lowerdir=lower,upperdir=upper,workdir=work merged
╭─root@esxi-debian-devbox /mnt/overlay2
╰─# cd merged
```

- 新增一个 kickstart.cfg 文件，然后重新构建 ISO 镜像

```bash
╭─root@esxi-debian-devbox /mnt/overlay2/merged
╰─# echo '# this is a kickstart config file' > kickstart.cfg
╭─root@esxi-debian-devbox /mnt/overlay2/merged
╰─# genisoimage -U -r -v -T -J -joliet-long -V "CentOS 7 x86_64" -volset "CentOS 7 x86_64" -A "CentOS 7 x86_64" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -no-emul-boot -o /mnt/CentOS-7-x86_64-Minimal-2009-dev.iso .
Total translation table size: 124658
Total rockridge attributes bytes: 55187
Total directory bytes: 100352
Path table size(bytes): 140
Done with: The File(s)                             Block(s)    527985
Writing:   Ending Padblock                         Start Block 528101
Done with: Ending Padblock                         Block(s)    150
Max brk space used a4000
528251 extents written (1031 MB)
```

- 挂载新的 ISO 镜像验证后发现确实可行

```bash
╭─root@esxi-debian-devbox /mnt/overlay2/merged
╰─# mount -o loop /mnt/CentOS-7-x86_64-Minimal-2009-dev.iso /mnt/newiso
mount: /mnt/newiso: WARNING: device write-protected, mounted read-only.
╭─root@esxi-debian-devbox /mnt/overlay2/merged
╰─# cat /mnt/newiso/kickstart.cfg
# this is a kickstart config file
```

## mount --bind

前面讲到了使用 overlay2 的方式避免复制原镜像内容进行重新构建镜像的方案，但是 overlay2 对于不是很熟悉的人来讲还是比较复杂，光 lowerdir、upperdir、workdir、mergeddir 这四个文件夹的作用和原理就把人直接给整不会了。那么还有没有更为简单一点的方式呢？

别说还真有，只不过这种方式的用途比较局限。如果仅仅是用于修改 ISO 中的一个文件或者目录，可以将该文件或目录以 `bind` 挂载的方式将它挂载到 ISO 目录目录对应的文件上。

原理就是虽然 ISO 目录本身是只读的，但它里面的文件和目录是可以作为一个挂载点的。也就是说我把文件 A 挂载到文件 B，并不是在修改文件 B，这就是 Unix/Linux 文件系统十分奇妙的地方。同样运用 bind 挂载的还有 docker 的 volume 以及 pod 的 volume 也是运用同样的原理，以 bind 的方式将宿主机上的目录或文件挂载到容器运行对应的目录上。对于修改只读 ISO 里的文件/目录我们当然也可以这样做。废话不多说来实践验证一下：

- 首先依旧是将 ISO 镜像挂载到 `/mn/iso` 目录

```bash
╭─root@esxi-debian-devbox ~/build
╰─# mount -o loop CentOS-7-x86_64-Minimal-2009.iso /mnt/iso
mount: /mnt/iso: WARNING: device write-protected, mounted read-only.
```

- 接着创建一个 `/mnt/files/ks.cfg` 文件，并写入我们需要的内容

```bash
╭─root@esxi-debian-devbox ~/build
╰─# mkdir -p /mnt/files
╭─root@esxi-debian-devbox ~/build
╰─# echo '# this is a kickstart config file' > /mnt/files/ks.cfg
```

- 接着以 mount --bind 的方式挂载新建的文件到 ISO 的 EULA 文件

```bash
╭─root@esxi-debian-devbox /mnt/build
╰─# mount --bind /mnt/files/ks.cfg /mnt/iso/EULA
╭─root@esxi-debian-devbox /mnt/build
╰─# cat /mnt/iso/EULA
# this is a kickstart config file
```

- 可以看到原来 ISO 文件中的 EULA 文件已经被成功替换成了我们修改的文件，然后再重新构建一下该 ISO 镜像

```bash
╭─root@esxi-debian-devbox /mnt/iso
╰─# genisoimage -U -r -v -T -J -joliet-long -V "CentOS 7 x86_64" -volset "CentOS 7 x86_64" -A "CentOS 7 x86_64" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -no-emul-boot -o /mnt/CentOS-7-x86_64-Minimal-2009-dev.iso .
```

- 然后我们再重新挂载新的 ISO 文件验证一下是否可以

```bash
╭─root@esxi-debian-devbox /mnt/iso
╰─# mkdir /mnt/newiso
╭─root@esxi-debian-devbox /mnt/iso
╰─# mount -o loop /mnt/CentOS-7-x86_64-Minimal-2009-dev.iso /mnt/newiso
mount: /mnt/newiso: WARNING: device write-protected, mounted read-only.
╭─root@esxi-debian-devbox /mnt/iso
╰─# cat /mnt/newiso/EULA
# this is a kickstart config file
```

验证通过，确实可以！不过这种方式很局限，比较适用于修改单个文件如 `kickstart.cfg`，如果是要新增文件那还是使用上文提到的 overlay2 的方式更为方便一些。

## 收获

虽然 ISO 镜像和容器镜像二者有着本质的差别，但对于只读和联合挂载的这些特性二者可以相互借鉴滴。

不止如此 overlay2 这种联合挂载的特性，还可以用在其他地方。比如我有一个公共的 NFS 共享服务器，共享着一些目录，所有人都可以以 root 用户并以读写的权限进行 NFS 挂载。这种情况下很难保障一些重要的文件和数据被误删。这时候就可以使用 overlay2 的方式将一些重要的文件数据挂载为 overlay2 的 lowerdir 只读层，保证这些数据就如容器镜像一样，每次挂载使用的时候都作为一个只读层。所有的读写操作都在 overlay2 的 merged 那一层，不会真正影响到只读层的内容。

草草地水了一篇博客，是不是没有用的知识又增加了 😂

## 推荐阅读

- [overlayfs.txt](https://www.kernel.org/doc/Documentation/filesystems/overlayfs.txt)
- [Docker 存储驱动—Overlay/Overlay2「译」](https://arkingc.github.io/2017/05/05/2017-05-05-docker-filesystem-overlay/)
- [深入浅出容器镜像的一生 🤔](https://blog.k8s.li/Exploring-container-image.html)
- [聊一聊 ISO 9660](https://zdyxry.github.io/2019/01/12/%E8%81%8A%E4%B8%80%E8%81%8A-ISO-9660/)
- [WORKING WITH ISO IMAGES](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/anaconda_customization_guide/sect-iso-images)
- [overlay2 在打包发布流水线中的应用](https://blog.k8s.li/overlay2-on-package-pipline.html)
- [mount 命令之 --bind 挂载参数](https://blog.k8s.li/mount-bind.html)
