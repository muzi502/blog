---
title: 国内镜像源伪评测
date: 2019-09-18
categories: 技术
slug:
tag:
  - Linux
copyright: true
comment: true
---

根据自己的网络，如何选择一个适合自己的镜像源呢？可能大家使用的发行版不同，还好有了 docker 这个玩具，能使用不同的发行版镜像启动容器来测试。那么就选定国内知名的镜像源来个测试，供大家参考选择一个合适的发行版。如果是公有云服务器的话，肯定是选择厂商的镜像源啦，内网传输速度超快，所以这次的测试对公有云服务器毫无意义，仅仅针对于办公或家用网络哈。

## 国内知名镜像源

|  所属  |                 官网                  |   评价    |
| :----: | :-----------------------------------: | :-------: |
|  清华  | https://mirrors.tuna.tsinghua.edu.cn/ | 速度 NO.1 |
| 中科大 |     https://mirrors.ustc.edu.cn/      | 速度最差  |
|  163   |       https://mirrors.163.com/        | 速度 NO.3 |
| 阿里云 |      https://mirrors.aliyun.com/      | 速度 NO.2 |
|  华为  |   https://mirrors.huaweicloud.com/    | 速度最快  |

## 测试系统

选用 debian 10 ，安装的软件包有 ``xfce4 gnome libreoffice  vlc`` ，这三个包总大小 1014MB

```bash
apt install xfce4 gnome libreoffice  vlc -d -y
0 upgraded, 1574 newly installed, 0 to remove and 0 not upgraded.
Need to get 1014 MB of archives.
After this operation, 3471 MB of additional disk space will be used.
```

## 测试过程

### 测试环境

公司办公网络是千兆内网，外网访问速度最快能达到 `50MB/s`

测试方法很简单，使用 sed 替换掉原来的镜像域名就行，都使用 http 的方式下载 加上 -d 参数只下载即可

```bash
#!/bin/bash
set -xue
sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list
sed -i 's|security.debian.org/debian-security|mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list
time apt update
time apt install xfce4 gnome libreoffice  vlc -d -y
```

### 清华

```bash
sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list
sed -i 's|security.debian.org/debian-security|mirrors.tuna.tsinghua.edu.cn/debian-security|g' /etc/apt/sources.list
apt update
root@6586bff7e2bf:/# time apt update
Get:1 http://mirrors.tuna.tsinghua.edu.cn/debian buster InRelease [122 kB]
Get:2 http://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates InRelease [39.1 kB]
Get:3 http://mirrors.tuna.tsinghua.edu.cn/debian buster-updates InRelease [49.3 kB]
Get:4 http://mirrors.tuna.tsinghua.edu.cn/debian buster/main amd64 Packages [7899 kB]
Get:5 http://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates/main amd64 Packages [85.3 kB]
Get:6 http://mirrors.tuna.tsinghua.edu.cn/debian buster-updates/main amd64 Packages [884 B]
Fetched 8195 kB in 2s (3821 kB/s)
Reading package lists... Done
Building dependency tree
Reading state information... Done
All packages are up to date.

apt install xfce4 gnome libreoffice  vlc -d -y
0 upgraded, 1574 newly installed, 0 to remove and 0 not upgraded.
Need to get 1014 MB of archives.
After this operation, 3471 MB of additional disk space will be used.
Fetched 1014 MB in 2min 3s (8246 kB/s)
Download complete and in download only mode
```

测试结果 `Fetched 1014 MB in 2min 3s (8246 kB/s)`

### 中科大

```shell
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
sed -i 's|security.debian.org/debian-security|mirrors.ustc.edu.cn/debian-security|g' /etc/apt/sources.list
apt update
root@1242bc5d5e5a:/# time apt update
Get:1 http://mirrors.ustc.edu.cn/debian buster InRelease [122 kB]
Get:2 http://mirrors.ustc.edu.cn/debian-security buster/updates InRelease [39.1 kB]
Get:3 http://mirrors.ustc.edu.cn/debian buster-updates InRelease [49.3 kB]
Get:4 http://mirrors.ustc.edu.cn/debian buster/main amd64 Packages [7899 kB]
Get:5 http://mirrors.ustc.edu.cn/debian-security buster/updates/main amd64 Packages [85.3 kB]
Get:6 http://mirrors.ustc.edu.cn/debian buster-updates/main amd64 Packages [884 B]
Fetched 8195 kB in 4s (1896 kB/s)
Reading package lists... Done
Building dependency tree
Reading state information... Done
All packages are up to date.

apt install xfce4 gnome libreoffice  vlc -d -y
0 upgraded, 1574 newly installed, 0 to remove and 0 not upgraded.
Need to get 1014 MB of archives.
Fetched 1005 MB in 37min 31s (446 kB/s)
E: Failed to fetch http://mirrors.ustc.edu.cn/debian/pool/main/t/totem/totem-common_3.30.0-4_all.deb  Connection failed [IP: 202.141.176.110 80]
E: Failed to fetch http://mirrors.ustc.edu.cn/debian/pool/main/s/shotwell/shotwell_0.30.1-1_amd64.deb  Connection failed [IP: 202.141.176.110 80]
E: Failed to fetch http://mirrors.ustc.edu.cn/debian/pool/main/d/dom4j/libdom4j-java_2.1.1-2_all.deb  Connection failed [IP: 202.141.176.110 80]
E: Failed to fetch http://mirrors.ustc.edu.cn/debian/pool/main/x/xfonts-scalable/xfonts-scalable_1.0.3-1.1_all.deb  Connection failed [IP: 202.141.176.110 80]
E: Some files failed to download
```

测试结果 `Fetched 1005 MB in 37min 31s (446 kB/s)` ，1000MB 的包下载用时将近 40 分钟

测试过程中多次出现 `[Waiting for headers]`  速度有几分钟都在`17.6 kB/s 13h 58min 9s`、 `159 kB/s 1h 38min 9s` 🤦‍♂️ ，其中还出现了 `2850 PB/s 0s` 😂

### 163

```shell
sed -i 's/deb.debian.org/mirrors.163.com/g' /etc/apt/sources.list
sed -i 's|security.debian.org/debian-security|mirrors.163.com/debian-security|g' /etc/apt/sources.list
apt update
root@66e0d532818e:/# apt update
Get:1 http://mirrors.163.com/debian buster InRelease [122 kB]
Get:2 http://mirrors.163.com/debian-security buster/updates InRelease [39.1 kB]
Get:3 http://mirrors.163.com/debian buster-updates InRelease [49.3 kB]
Get:4 http://mirrors.163.com/debian buster/main amd64 Packages [7899 kB]
Get:5 http://mirrors.163.com/debian-security buster/updates/main amd64 Packages [85.3 kB]
Get:6 http://mirrors.163.com/debian buster-updates/main amd64 Packages [884 B]
Fetched 8195 kB in 3s (2939 kB/s)

apt install xfce4 gnome libreoffice  vlc -d -y
0 upgraded, 1574 newly installed, 0 to remove and 0 not upgraded.
Need to get 1014 MB of archives.

Fetched 1012 MB in 7min 21s (2295 kB/s)
Download complete and in download only mode
```

测试结果 `Fetched 1012 MB in 7min 21s (2295 kB/s)`

### 阿里云

```bash
sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list
sed -i 's|security.debian.org/debian-security|mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list
root@e4b82e40b6c6:/# apt update
Get:1 http://mirrors.aliyun.com/debian buster InRelease [122 kB]
Get:2 http://mirrors.aliyun.com/debian-security buster/updates InRelease [39.1 kB]
Get:3 http://mirrors.aliyun.com/debian buster-updates InRelease [49.3 kB]
Get:4 http://mirrors.aliyun.com/debian buster/main amd64 Packages [7899 kB]
Get:5 http://mirrors.aliyun.com/debian-security buster/updates/main amd64 Packages [85.3 kB]
Get:6 http://mirrors.aliyun.com/debian buster-updates/main amd64 Packages [884 B]
Fetched 8195 kB in 1s (6489 kB/s)
Reading package lists... Done
Building dependency tree
Reading state information... Done
All packages are up to date.

apt install xfce4 gnome libreoffice  vlc -d -y
0 upgraded, 1574 newly installed, 0 to remove and 0 not upgraded.
Need to get 1014 MB of archives.
After this operation, 3471 MB of additional disk space will be used.
Fetched 1014 MB in 2min 54s (5815 kB/s)
Download complete and in download only mode
```

测试结果 `Fetched 1014 MB in 2min 54s (5815 kB/s)`

### 华为

```bash
sed -i 's/deb.debian.org/mirrors.huaweicloud.com/g' /etc/apt/sources.list
sed -i 's|security.debian.org/debian-security|mirrors.huaweicloud.com/debian-security|g' /etc/apt/sources.list
apt update

root@659549fb7f12:/# apt update
Get:1 http://mirrors.huaweicloud.com/debian buster InRelease [122 kB]
Get:2 http://mirrors.huaweicloud.com/debian-security buster/updates InRelease [39.1 kB]
Get:3 http://mirrors.huaweicloud.com/debian buster-updates InRelease [49.3 kB]
Get:4 http://mirrors.huaweicloud.com/debian buster/main amd64 Packages [7899 kB]
Get:5 http://mirrors.huaweicloud.com/debian-security buster/updates/main amd64 Packages [85.0 kB]
Get:6 http://mirrors.huaweicloud.com/debian buster-updates/main amd64 Packages [884 B]
Fetched 8194 kB in 2s (4766 kB/s)
Reading package lists... Done
Building dependency tree
Reading state information... Done
All packages are up to date.

apt install xfce4 gnome libreoffice  vlc -d -y
0 upgraded, 1574 newly installed, 0 to remove and 0 not upgraded.
Need to get 1014 MB of archives.
After this operation, 3471 MB of additional disk space will be used.
Fetched 1014 MB in 1min 25s (12.0 MB/s)
Download complete and in download only mode
```

测试结果 `Fetched 1014 MB in 1min 25s (12.0 MB/s)`

不得不说华为云镜像站真香啊。进度条上基本上都是 10MB/s 以上，从没出现低于 10MB/s 的，甚至峰值能达到 20MB/s

## 附录---测试数据表格

`xfce4 、gnome 、libreoffice 、 vlc`  1574 个包，总大小 `1014 MB` 测试时间为白天工作时间

| 序号 |   清华    |  中科大  |    163    |  阿里云   |  华为云   |
| :--: | :-------: | :------: | :-------: | :-------: | :-------: |
|  1   | 8246 kB/s | 446 kB/s | 2295 kB/s | 5815 kB/s | 12.0 MB/s |
|  2   | 462 kB/s  | 980 kB/s | 5498 kB/s | 2642 kB/s | 15.8 MB/s |
|  3   | 1144 kB/s | 657 kB/s | 1333 kB/s | 5938 kB/s | 13.1 MB/s |

## 建议

根据一轮的测试速度来看，华为胜出😂

1. 华为
2. 阿里云
3. 163
4. 清华
5. 中国科大

就这四个选择吧，也和本地的网络有关系，我的是电信网络。之前我的测试环境的服务器一直在使用中科大的镜像站，每次都很慢，今天一测才知道，中科大的镜像站这么慢啊，以后还是选择华为云吧。

撇开偏见，今天评论华为开源镜像站，前端 UI 无疑是国内镜像站里边做的最好的（虽然我不喜欢卡片式设计），下载速度是所有镜像站里面最快的（1574 个包，总大小 1014MB，平均都在 12MB/s 以上，峰值能达到 20MB/s）。其他的镜像站基本上都没能达到 10MB/s 以上。如果注册会员是不是下载速度翻倍，都能跑到 20MB/s 以上？
