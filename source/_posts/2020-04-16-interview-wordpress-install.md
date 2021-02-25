---
title: 一次有趣的面试：WordPress 部署
date: 2020-04-16
updated: 2020-04-28
slug:
categories: 技术
tag:
  - WordPress
  - nginx
  - MySQL
  - PHP
  - Webp
copyright: true
comment: true
---

今天收到一份面试题，内容看似很简单：

>   1. CentOS7，nginx 最新版，php 7.x，mysql 不做要求 + wordpress
>   2. 以文件的方式创建并挂载2G的swap分区
>
>   请把学习记录以 URL，截图等方式保留。最终。我在手机上可以看到wordpress站点就好。时间1小时以内，方法方式不限

虽然看起来和简单，比如用 `docker-compose` 一键就能完成部署完成，不过为了把部署过程中遇到的一些问题详细地记录下来，以及参考的一些文档等，通过一篇正式的博客展现出来，这样效果会好一些。同时咱作为完美主义者，希望给再做一些额外的优化，比如 HTTPS ，以及不久前和咱给博客加的 Webp Server 😂。[让图片飞起来 oh-my-webp.sh ！](https://blog.k8s.li/oh-my-webpsh.html) 咱来推销 [Webp Server Go](https://github.com/webp-sh/webp_server_go) 啦 （小声。

另外提一点的是，如果你深入理解 LNMP 技术栈的话，还是推荐使用传统的方式比如 yum 安装或源码编译安装，那样会能理解这些服务之间的工作流程，会对整个系统有深入的了解。而 `docker-compose` 简单粗暴的方式为我们屏蔽了这些细节，会让我们放弃去思考这些底层的细节，对于我们学习这门技术栈来讲，还是弊大于利。不过今天为了快速部署起来，还是选用 docker-compose 吧😂

## WordPress

> Get WordPress Use the software that powers over 35% of the web.

WordPress 想必大家都很熟悉啦，毕竟收是全球内容管理系统里的老大哥，常年占据在第一的位置（占有率 35%）。官网 [wordpress.org](https://wordpress.org)

## 任务2 以文件的方式创建并挂载2G的swap分区

这个任务与 WordPress 不太相关，所以就先完成这个。拿到机器后 ssh 登录到系统，先使用常用的命令看一下服务器的信息，另外在自己的域名上添加了 A  记录`wordpress.k8s.li` 到这台服务器  IP ，并开启 HTTPS ，防止被 DDOS 攻击，毕竟有 CloudFlare 的 Anycast CDN 给我们在前头扛一把😂还是不错滴。

```shell
[root@interview ~]# uname -a
Linux interview 3.10.0-1062.12.1.el7.x86_64 #1 SMP Tue Feb 4 23:02:59 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux
[root@interview ~]# cat /proc/cpuinfo
processor       : 0
vendor_id       : GenuineIntel
cpu family      : 6
model           : 45
model name      : Intel(R) Xeon(R) CPU E5-2670 0 @ 2.60GHz
stepping        : 7
microcode       : 0x710
cpu MHz         : 2594.123
cache size      : 20480 KB
physical id     : 0
siblings        : 1
core id         : 0
cpu cores       : 1
apicid          : 0
initial apicid  : 0
fpu             : yes
fpu_exception   : yes
cpuid level     : 13
wp              : yes
flags           : fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat clflush mmx fxsr sse sse2 syscall nx rdtscp lm constant_tsc rep_good nopl eagerfpu pni pclmulqdq ssse3 cx16 sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes hypervisor lahf_lm
bogomips        : 5187.68
clflush size    : 64
cache_alignment : 64
address sizes   : 46 bits physical, 48 bits virtual
power management:

[root@interview ~]# free -h
              total        used        free      shared  buff/cache   available
Mem:           985M        150M        451M         12M        382M        680M
Swap:            0B          0B          0B
```

-   `unanme -a` 查看一下系统的内核版本 ，`3.10.0-1062` 的内核看样子是 CentOS7.7
-   `cat /proc/cpuinfo` 查看一下 CPU 的信息，E5-2670 的 CPU ，属于 Intel 第六代 CPU 系列。
-   `free` 查看一下内存的情况，1GB 的小内存😂

> Q2 以文件的方式创建并挂载2G的swap分区

这个问题比较简单，之前自己的 GCE 小鸡 512M 内存上也是使用文件的方式创建 2GB 的交换分区😂。所以对这个步骤早就熟记于心，并不需要搜索就能搞定😋。使用 dd 命令即可生成一个 2GB 大小的文件。

```txt
[root@interview ~]# dd if=/dev/zero of=/swapfile bs=4M count=500
500+0 records in
500+0 records out
2097152000 bytes (2.1 GB) copied, 11.0648 s, 190 MB/s
```

`2097152000 bytes (2.1 GB) copied, 11.0648 s, 190 MB/s` 怎么会是 2.1 GB 呢？，多出来 0.1GB ，强迫症受不了。想起来了，可能是 `bs=4M` 参数的问题。于是我在我的 debian 机器上测试了一下

顺带 man 一下 dd 看看 bs 参数是怎么定义的

>   bs=BYTES read and write up to BYTES bytes at a time (default: 512); overrides ibs and obs

```shell
╭─debian@debian ~
╰─$ dd if=/dev/zero of=./test bs=4MB count=4
4+0 records in
4+0 records out
16000000 bytes (16 MB, 15 MiB) copied, 0.0147078 s, 1.1 GB/s
```

原因是文件大小单位不同，一个是 `MB` 另一个是 `MiB` ，在 Google 上搜索了一下 。看到上的一个回答 [What is the difference between 1 MiB and 1 MB and why should we care?](https://www.quora.com/What-is-the-difference-between-1-MiB-and-1-MB-and-why-should-we-care) 。也想起了前两天看到 [面向信仰编程](https://draveness.me/) 大佬的一个推文：

{% raw %}

<blockquote class="twitter-tweet"><p lang="zh" dir="ltr">最近才发现 MB 和 MiB 是不一样的：<br><br>+ MiB 是 1024 的倍数<br>+ MB 是 1000 的倍数<br><br>Git 下载时的单位是 MiB，但是 macOS 里显示的确实 MB，部分服务会把两者用混，比如 DigitalOcean 里的 S3 服务，下载文件的时候我还以为只下载了一部分😂 <a href="https://twitter.com/hashtag/%E5%86%B7%E7%9F%A5%E8%AF%86?src=hash&amp;ref_src=twsrc%5Etfw">#冷知识</a> <a href="https://t.co/U1IoRlgjXJ">pic.twitter.com/U1IoRlgjXJ</a></p>&mdash; Draveness (@draven0xff) <a href="https://twitter.com/draven0xff/status/1249290829161590786?ref_src=twsrc%5Etfw">April 12, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

{% endraw %}

接下来使用 `mkswap` 命令将刚刚创建好的 `/swapfile` 文件格式化为交换分区所需要的格式，并修改一下文件权限为 600 ，即只能由 root 用户读，不然默认的 755 会被其他用户看到，而里面的内容是内存里的信息，所以安全起见还是修改一下权限。

```shell
[root@interview ~]# mkswap /swapfile
Setting up swapspace version 1, size = 2047996 KiB
no label, UUID=a4eab465-75d1-4830-b870-c222c7e2e87b
[root@interview ~]#
[root@interview ~]# chmod 600 /swapfile
[root@interview ~]# swapon !$
swapon /swapfile
[root@interview ~]# free -h
              total        used        free      shared  buff/cache   available
Mem:           985M        212M        140M         12M        633M        612M
Swap:          2.0G          0B        2.0G
```

至此任务二完成了，接下来就是题目的核心安装 WordPress 啦

## install

刚开始打算使用常规的方法来部署 WordPress 的，使用 Google 搜索关键字 `CentOS install WordPress` ，排名第二的是 `DigitalOcean` 官方博客里的 [How To Install WordPress on CentOS 7](https://www.digitalocean.com/community/tutorials/how-to-install-wordpress-on-centos-7)。官方博客里提到：

> Additionally, you’ll need to have a LAMP (Linux, Apache, MySQL, and PHP) stack installed on your CentOS 7 server. If you don’t have these components already installed or configured, you can use this guide to learn how to install LAMP on CentOS 7.

虽然 WordPress 官方没有给出详细的搭建步骤，但可以参考 DigitalOcean 官方的内容，毕竟公有云服务提供商的技术专家写的博客更可靠一些。由于要求的是 nginx 最新版本，yum 安装的 nginx 版本可能会旧一些。

```shell
[root@interview wordpress]# yum list nginx
Loaded plugins: fastestmirror, langpacks
Loading mirror speeds from cached hostfile
 * base: centos-distro.1gservers.com
 * epel: d2lzkl7pfhq30w.cloudfront.net
 * extras: mirror.dal.nexril.net
 * updates: mirror.dal10.us.leaseweb.net
Available Packages
nginx.x86_64       1:1.16.1-1.el7            epel
```

`yum list nginx` 里的信息显示 nginx 版本为 1.16.1 并不是 [官网](https://nginx.org/en/download.html) 上的最新版 `1.17.10` ，源码编译的时间可能会有点长，因为前天看到一个推文说他使用 GCP 的小鸡编译 nginx 大概花了 3 个小时😂。而我面试规定的时间是要求 1 个小时内解决。我去，想要最新版 nginx ，而且最省时间的办法看来只用 docker 的方式安装 nginx 了 ，使用 nginx 官方的镜像 nginx:latest 即为 nginx 最新的版本。Google 搜索 `docker hub nginx` 来到 docker 官方的  nginx 镜像仓库 [nginx](https://hub.docker.com/_/nginx) 。我哭了，虽然是 1.17 版本，但是 1.17.9 版本而不是 1.17.10 ，就差了一点点啊！掀桌儿（。将就着用吧，虽然差了那么一点点。

{% raw %}

<blockquote class="twitter-tweet"><p lang="zh" dir="ltr">小折腾了一把：在闲置的手机上跑了个Ruby on Rails网站，它还带有HTTPS证书且公网可以访问。望着屏幕上滚动的Nginx日志感觉还挺不可思议的。<br><br>系统是Android上跑的Debian。<br><br>另外用这几年前的手机编译Nginx居然只花了大概3小时，比GCP最低档的VPS还快。 <a href="https://t.co/5PGy96al5D">pic.twitter.com/5PGy96al5D</a></p>&mdash; 丁宇 | DING Yu (@felixding) <a href="https://twitter.com/felixding/status/1249675123218497536?ref_src=twsrc%5Etfw">April 13, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

{% endraw %}

事实证明我推断错了，第二天我在我的另一台机器上编译 nginx 花了不到 1 分钟，被大佬坑惨了啊😂。在 GCE 小鸡上编译 nginx 根本不可能需要 3 小时吧，3 分钟才对的吧。当初看到后就感觉编译 nginx 需要 3个小时就有点问题，但并没有亲自去验证。唉，还是自己不够细致啊，**一知半解真是很危险的事儿！**

### install docker

安装 docker 的方式再熟悉不过了，使用一个 curl 命令就能搞定 `curl -fsSL https://get.docker.com | bash -s docker` 如果在国内环境的话，后面加上  `--mirror Aliyun`  参数就能使用阿里云的镜像站，这样会更快一些。即 `curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun` 。

不过我还是从第一次接触的角度来安装 docker ，Google 搜索 `centos install docker` 点进入第一个搜索结果即为官网 [Install Docker Engine on CentOS](https://docs.docker.com/engine/install/centos/) ，为了节省时间就没有按照官网的步骤来，而是使用官方的一键脚本来安装。

```shell
[root@interview ~]# curl -fsSL https://get.docker.com -o get-docker.sh
[root@interview ~]# ls
get-docker.sh
[root@interview ~]# chmod +x get-docker.sh
[root@interview ~]# ./get-docker.sh
```

安装完成之后使用 `docker info` 来查看一下 docker 信息。需要注意的是：目前最新版本的 docker 默认优先采用 **overlay2** 的存储驱动，对于已支持该驱动的 Linux 发行版，不需要任何进行任何额外的配置。另外需要注意的是`devicemapper` 存储驱动已经在 docker 18.09 版本中被废弃，docker 官方推荐使用 `overlay2` 替代`devicemapper`，在我司生产环境曾经因为 `devicemapper` 遇到过存储挂不起的坑😑。

```yaml
[root@interview ~]# docker info
Client:
 Debug Mode: false
Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 19.03.8
 Storage Driver: overlay2
  Backing Filesystem: <unknown>
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
 containerd version: 7ad184331fa3e55e52b890ea95e65ba581ae3429
 runc version: dc9208a3303feef5b3839f4323d9beb36df0a9dd
 init version: fec3683
 Security Options:
  seccomp
   Profile: default
 Kernel Version: 3.10.0-1062.12.1.el7.x86_64
 Operating System: CentOS Linux 7 (Core)
 OSType: linux
 Architecture: x86_64
 CPUs: 1
 Total Memory: 985.3MiB
 Name: interview
 ID: YSZO:TT5U:GDLH:3FYT:LFGP:NLOS:L4YI:5LFU:3EAV:KHP2:F746:I5P3
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false
```

### install docker-compose

安装完 docker 之后，接下来安装 docker-compose ，使用 Google 搜索 `centos install docker-compose` 点进入第一个搜索结果即为官网的 [Install Docker Compose](https://docs.docker.com/compose/install/)

```shell
[root@interview ~] sudo curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
[root@interview ~]# docker-compose version
bash: /usr/local/bin/docker-compose: Permission denied
[root@interview ~]# chmod +x /usr/local/bin/docker-compose
[root@interview ~]# docker-compose version
docker-compose version 1.25.4, build 8d51620a
docker-py version: 4.1.0
CPython version: 3.7.5
OpenSSL version: OpenSSL 1.1.0l  10 Sep 2019
```

遇到了 `Permission denied` 问题，原来是忘记加权限了 `chmod +x /usr/local/bin/docker-compose` 一下即可。

### WordPress

官方 [Quickstart: Compose and WordPress](https://docs.docker.com/compose/wordpress/) 的 `docker-compose.yaml` 中的 web 服务器是使用的 apache 而不是 nginx ，因此要使用第三方的 docker-compose.yaml，前段时间在折腾 Webp Server Go 的时候遇到过这种需求。于是在 GitHub 上搜索 `wordpress nginx docker-compose` 找到了合适的 repo 即 [wordpress-nginx-docker](https://github.com/mjstealey/wordpress-nginx-docker) 。看一下 docker-compose.yaml 文件

```yaml
version: '3.6'
services:

  wordpress:
    image: wordpress:${WORDPRESS_VERSION:-php7.3-fpm}
    container_name: wordpress
    volumes:
      - ./config/php.conf.ini:/usr/local/etc/php/conf.d/conf.ini
      - ./wordpress:/var/www/html
    environment:
      - WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME:-wordpress}
      - WORDPRESS_TABLE_PREFIX=${WORDPRESS_TABLE_PREFIX:-wp_}
      - WORDPRESS_DB_HOST=${WORDPRESS_DB_HOST:-mysql}
      - WORDPRESS_DB_USER=${WORDPRESS_DB_USER:-root}
      - WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD:-password}
    depends_on:
      - mysql
    restart: always

  mysql:
    image: mariadb:${MARIADB_VERSION:-latest}
    container_name: mysql
    volumes:
      - ./mysql:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-password}
      - MYSQL_USER=${MYSQL_USER:-root}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD:-password}
      - MYSQL_DATABASE=${MYSQL_DATABASE:-wordpress}
    restart: always

  nginx:
    image: nginx:${NGINX_VERSION:-latest}
    container_name: nginx
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ${NGINX_CONF_DIR:-./nginx}:/etc/nginx/conf.d
      - ${NGINX_LOG_DIR:-./logs/nginx}:/var/log/nginx
      - ${WORDPRESS_DATA_DIR:-./wordpress}:/var/www/html
      - ${SSL_CERTS_DIR:-./certs}:/etc/letsencrypt
      - ${SSL_CERTS_DATA_DIR:-./certs-data}:/data/letsencrypt
    depends_on:
      - wordpress
    restart: always

  adminer:
    image: adminer
    restart: always
    links:
      - mysql
    ports:
      - 8080:8080
```

共有 4 个容器： wordpress、mysql、nginx、adminer，默认不需要修改既可以部署起来。adminer 是个 web 端管理 MySQL 数据库的，可以删掉不需要。

由于默认的系统不带 git ，所以需要安装一下 git `yum install git`，然后把 repo clone 下来。

```shell
git clone https://github.com/mjstealey/wordpress-nginx-docker
cd wordpress-nginx-docker
docker-compose up
```

这样使用 `docker-compose up` 命令就能启动一个 WordPress 站点了。通过访问域名 [ wordpress.k8s.li](https://wordpress.k8s.li/) 即可访问刚刚创建好的网站了。

### Webp Server

为了优化一下博客图片静态资源的加载速度，可以为 WordPress 加上一个 Webp Server 服务，将原图片压缩为 webp 格式。需要修改一下 nginx 的配置文件，添加内容如下：

```nginx
location ^~ /wp-content/uploads/ {
    proxy_pass http://webp-server:3333;
}
```

在 docker-compose.yaml 文件中加入 webp server 的容器

```yaml
version: '3.6'
services:

  wordpress:
    image: wordpress:${WORDPRESS_VERSION:-php7.3-fpm}
    container_name: wordpress
    volumes:
      - ./config/php.conf.ini:/usr/local/etc/php/conf.d/conf.ini
      - ./wordpress:/var/www/html
    environment:
      - WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME:-wordpress}
      - WORDPRESS_TABLE_PREFIX=${WORDPRESS_TABLE_PREFIX:-wp_}
      - WORDPRESS_DB_HOST=${WORDPRESS_DB_HOST:-mysql}
      - WORDPRESS_DB_USER=${WORDPRESS_DB_USER:-root}
      - WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD:-password}
    depends_on:
      - mysql
    restart: always

  mysql:
    image: mariadb:${MARIADB_VERSION:-latest}
    container_name: mysql
    volumes:
      - ./mysql:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-password}
      - MYSQL_USER=${MYSQL_USER:-root}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD:-password}
      - MYSQL_DATABASE=${MYSQL_DATABASE:-wordpress}
    restart: always

  nginx:
    image: nginx:${NGINX_VERSION:-latest}
    container_name: nginx
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ${NGINX_CONF_DIR:-./nginx}:/etc/nginx/conf.d
      - ${NGINX_LOG_DIR:-./logs/nginx}:/var/log/nginx
      - ${WORDPRESS_DATA_DIR:-./wordpress}:/var/www/html
      - ${SSL_CERTS_DIR:-./certs}:/etc/letsencrypt
      - ${SSL_CERTS_DATA_DIR:-./certs-data}:/data/letsencrypt
    depends_on:
      - wordpress
    restart: always

  webp-server:
    image: webpsh/webps:latest
    restart: always
    container_name: webp-server
    volumes:
      - ./webp-server/config.json:/etc/config.json
      - ./wordpress:/var/www/html
    ports:
      - 3333:3333
```

修改好 docker-compose.yaml 文件之后，我们还需要为  webp-server 准备一个 config.json 文件，存放在 `./webp-server/config.json`  下，内容如下：

```json
{
  "HOST": "0.0.0.0",
  "PORT": "3333",
  "QUALITY": "80",
  "IMG_PATH": "/var/www/html",
  "EXHAUST_PATH": "",
  "ALLOWED_TYPES": ["jpg","png","jpeg","bmp","gif"]
}             
```

接下来我们使用 `docker-compose restart` 命令重启一下容器，之后再 WordPress 端上传一张图片测试一下。上传完成之后，拿到图片的 url ，然后使用 wget 命令测试一下，显示 `Length: 102288 (100K)  [image/webp]` 就说明我们的 webp server 已经成功运行啦😂。完整的 repo 在我的 GitHub 上 [Wwordpress](https://github.com/muzi502/Wwordpress) ，欢迎来食用呀😋

```shell
╭─root@sg-02 /opt/wordpress-nginx-docker ‹master›
╰─# wget  http://dl.amd64.xyz/wp-content/uploads/2020/04/74898710_p21.jpg
--2020-04-17 01:06:29--  http://dl.amd64.xyz/wp-content/uploads/2020/04/74898710_p21.jpg
Resolving dl.amd64.xyz (dl.amd64.xyz)... 3.1.38.108
Connecting to dl.amd64.xyz (dl.amd64.xyz)|3.1.38.108|:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 102288 (100K) [image/webp]
Saving to: ‘74898710_p21.jpg’

74898710_p21.jpg             100%[=======>]  99.89K  --.-KB/s    in 0.001s

2020-04-17 01:06:29 (130 MB/s) - ‘74898710_p21.jpg’ saved [102288/102288]
```

## 参考

- [wordpress.org](https://wordpress.org/)

- [dockerhub WordPress](https://hub.docker.com/_/wordpress/)

- [nginx.com](https://www.nginx.com/)

- [wordpress-nginx-docker](https://github.com/mjstealey/wordpress-nginx-docker)

- [Wwordpress](https://github.com/muzi502/Wwordpress)

- [How To Install WordPress on CentOS 7](https://www.digitalocean.com/community/tutorials/how-to-install-wordpress-on-centos-7)

- [How To Install Linux, Apache, MySQL, PHP (LAMP) stack On CentOS 7](https://www.digitalocean.com/community/tutorials/how-to-install-linux-apache-mysql-php-lamp-stack-on-centos-7)

- [Quickstart: Compose and WordPress](https://docs.docker.com/compose/wordpress/)

- [How To Install WordPress With Docker Compose](https://www.digitalocean.com/community/tutorials/how-to-install-wordpress-with-docker-compose)

- [Install Docker Engine on CentOS](https://docs.docker.com/engine/install/centos/)

- [Install Docker Compose](https://docs.docker.com/compose/install/)

- [How to Build NGINX from source on Ubuntu 18.04 LTS](https://www.howtoforge.com/tutorial/how-to-build-nginx-from-source-on-ubuntu-1804-lts/)

- [让图片飞起来 oh-my-webp.sh ！](https://blog.k8s.li/oh-my-webpsh.html)

## end

至此部署一个 WordPress 的流程就结束啦，为了追求速度就放弃了对一些细节的深究，得不偿失啊。

有些内容看似简单，但想把这个过程中遇到的问题以及想法落笔成字，形成一篇博客，还是需要语言组织能力，看来自己这方面还是有些欠缺。

