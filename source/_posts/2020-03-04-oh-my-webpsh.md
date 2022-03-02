---
title: 让图片飞起来 oh-my-webp.sh ！
date: 2020-03-05
updated: 2020-03-06
slug:
categories: 技术
tag:
  - 博客
copyright: true
comment: true
---

> 咱来推销 webp server go 啦 （x 小声

## 劝退三连 😂

- 需要配置 nginx 反向代理（＞﹏＜）
- 图片必须放在自己的服务器上，图床不得行 (ﾉ*･ω･)ﾉ
- 需要独立的服务器，GitHub page 之类的不得行（╯︿╰）

不过，对于已经会自由访问互联网的人来说这都不难 (●ˇ∀ˇ●) ，食用过程中有什么疑问的话也可以联系咱，咱会尽自己所能提供一些帮助 😘，一起来完善这个开源项目。

## WebP

> WebP 的有损压缩算法是基于 VP8 视频格式的帧内编码[17]，并以 RIFF 作为容器格式。[2] 因此，它是一个具有八位色彩深度和以 1:2 的比例进行色度子采样的亮度-色度模型（YCbCr 4:2:0）的基于块的转换方案。[18] 不含内容的情况下，RIFF 容器要求只需 20 字节的开销，依然能保存额外的 元数据(metadata)。[2] WebP 图像的边长限制为 16383 像素。

WebP 是一种衍生自 Google VP8 的图像格式，同时支持有损和无损编码。当使用有损模式，它在相同体积提供比 JPG 图像更好的质量；当使用无损模式，它提供比最佳压缩的 PNG 图像更小的体积。简单来说，WebP 图片格式的存在，让我们在 WebP 上展示的图片体积可以有较大幅度的缩小。网站上的图片资源如果使用 WebP，那么自然也会减少这些图片文件的加载时间，也就带来了网站加载性能的提升。关于 webp 图像格式的具体实现细节可以去维基百科或者文末我提到的推荐阅读看一下，总之 webp 很香就是啦 (●'◡'●)

### 支持情况

根据 [caniuse](https://caniuse.com/#search=webp) 的统计情况，主流浏览器（接近 80%）都支持 webp 了，如果遇到 Safari 这样的奇葩，咱直接返回原图。IE 浏览器？？

![](https://p.k8s.li/20200306094307271.png)

## webp-sh

- 官网 [webp.sh](https://webp.sh)
- GitHub [webp-sh](https://github.com/webp-sh)

webp server 顾名思义就是 webp 服务器啦，用于将网站里的图片（jpg、png、jpeg 等）转换成 webp 图像编码格式，而且无须修改博客站点内图片的 url ，因此对于访问图片资源的客户端来讲是透明的。主流的 CDN 也支持这样类似的功能，比如 Cloudflare 的 [Polish]() ，可以参考 [Using Cloudflare Polish to compress images](https://support.cloudflare.com/hc/en-us/articles/360000607372-Using-Cloudflare-Polish-to-compress-images) 。但是天下没有免费的午餐，图片转码与编码这都是要算力的，都是要计算资源的，都是要 CPU 的，都是要花钱的 😂。说到底还是穷啊（咱 webp server 是开源免费的。

> 最重要的一点是——我们访问的 URL 可以完全不用改变，访客访问的依然是 `https://image.nova.moe/tsuki/tsuki.jpg` ，但是得到的图片格式为：`image/webp`，而且体积减少了不少。

其实 webp server 有多种语言都实现了，并且这些仓库还都放在了 [webp-sh](https://github.com/webp-sh) 该 Organizations 下。不过咱比较喜欢 golang 所以就推荐 webp server go 啦 😂，隔壁的 webp server rust 别打我啊（逃

> 这个工具就是由 [Nova 童鞋](https://nova.moe/)、 [Benny](https://www.bennythink.com) 、[cocoa](https://blog.0xbbc.com/) 以及 [muzi](https://blog.k8s.li/) 小盆友一起鼓捣的 webp_server_go 啦！

- [webp_server_go](https://github.com/webp-sh/webp_server_go)
- [webp_server_rs](https://github.com/webp-sh/webp_server_rs)
- [webp_server_node](https://github.com/webp-sh/webp_server_node)
- [webp_server_java](https://github.com/webp-sh/webp_server_java)
- [webp_server_python](https://github.com/webp-sh/webp_server_python)

## 食用指南

### 1. 下载

首先到 [release](https://github.com/webp-sh/webp_server_go/releases) 页面下载已经编译好的二进制文件或者根据自己的发行版选择下载 rpm 或 deb 包，在此要注意选择下载符合自己的 arch 和 OS。

至于安装路径，我个人更倾向于放在 `/opt/` 目录下，因为这个目录下的东西都是自己安装的，而且也不依赖于特定的发行版，方便博客迁移（搬家），搬家的时候直接打包 `/opt` 目录，然后 scp 一下就卷铺盖走人，多方便呀 😂。

### 2. 配置

食用 webp-server-go 之前选准备好一个 ``config.json`` 配置文件，如下：

```json
{
  "HOST": "127.0.0.1",
  "PORT": "3333",
  "QUALITY": "80",
  "IMG_PATH": "/var/www/hexo",
  "EXHAUST_PATH": "./dist",
  "ALLOWED_TYPES": ["jpg","png","jpeg","bmp","gif"]
}
```

- HOST：对于 webp server 服务来讲只需要监听 127.0.0.1 这个本机地址就可以了，稍后使用 nginx 反向代理一下。
- PORT：就是 webp server 服务监听的的端口号，根据自己需求修改
- QUALITY：编码的质量，一般推荐 75 ，不过使用 80 也是不错的。
- IMG_PATH：网站的根目录，根目录，根目录，一定要配置你图片 url 的根目录。
- EXHAUST_PATH：转换后的 webp 图片文件存放位置，提前创建好。
- ALLOWED_TYPES：允许转码的图片格式，目前支持这几种。

接下来再配置以下 nginx ，下面以我的 hexo 博客为例，hugo 也同样如此。再添加一块 localtion 字段即可，如果你修改了默认端口号的话不要忘记修改为你改之后的端口号。

```nginx
        location ~* \.(png|jpg|jpeg)$ {
            proxy_pass http://127.0.0.1:3333;
        }
```

``/etc/nginx/conf.d/blog.conf``

```nginx
server {
        listen 80;
        listen [::]:80;
        server_name  blog.k8s.li;
        set $base /var/www/hexo/public;
        root $base/;
        location / {
            index  index.html;
        }
        location ~* \.(png|jpg|jpeg)$ {
            proxy_pass http://127.0.0.1:3333;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_hide_header X-Powered-By;
            proxy_set_header HOST $http_host;
            add_header Cache-Control 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0';
        }
}
```

不过在此需要注意，nginx 的 location 字段的路径一定要和 webp server `config.json` 里的 `IMG_PATH` 相对应，不然会导致请求资源的 uri 与 webp server 转换后的文件路径不一致而导致资源 404 。还有一点就是 location 那里不能仅仅添加 `proxy_pass http://127.0.0.1:3333;` ，这样浏览器的 UA 会被 nginx 给吃掉 😄，nginx 将请求 proxy 给 webp server 后无法从 headers 那里获取到 UA ，而导致 `Safari` 浏览器无法正常输出原图。所以以下几行添加在 `proxy_pass` 下面是必须的：

```nginx
            proxy_set_header HOST $http_host;
            add_header Cache-Control 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0';
```

此外感谢好心读者的提醒才发现这个 bug 😘

![](https://p.k8s.li/20200307102856702.png)

### 3.启动

手动运行起来很简单，`./webp-server -config /path/to/config.json` ，如果该服务挂掉了资源就 gg 了，所以还是选用一种稳定持久化的运行方式。咱推荐使用 systemd 来启动，这样 webp server 服务挂掉了也会自动拉起重启一下。首先要创建或修改一下 `webps.service` 配置文件。

```bash
[Unit]
Description=WebP Server
Documentation=https://github.com/webp-sh/webp_server_go
After=nginx.target

[Service]
Type=simple
StandardError=journal
AmbientCapabilities=CAP_NET_BIND_SERVICE
WorkingDirectory=/opt/webps
ExecStart=/opt/webps/webp-server --config /opt/webps/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
```

修改一下 `ExecStart=/opt/webps/webp-server --config /opt/webps/config.json` 和 `WorkingDirectory=/opt/webps` 对应的路径。

```bash
cp webps.service /lib/systemd/system/
systemctl daemon-reload
systemctl enable webps.service
systemctl start webps.service
```

### 4.预加载

webp-server-go 有个预加载的功能，就是提前将全部的图片资源进行一次转换，这样再次访问图片资源的时候就不必再进行转换，而直接使用已经转换后的 webp 文件即可。这相当于一次 “缓存” 。

使用 `./webp-server -jobs 1 -config config.json -prefetch` 来进行一次预加载，其中 jobs 后面的数字为你 CPU 的核心数，也可以不用加默认使用全部核心。

## benchmark

说到性能，咱必须得进行一次压测才能放心大胆地推荐各位食用 webp server go 啦，下面得就是咱的测试数据样例。图片的测试样本是咱使用 [pxder](https://github.com/Tsuk1ko/pxder) 爬下来的，总共 10600 张图片，总大小 11.1 GB。如果你也需要这些测试样本的话可以私聊咱发给你。下面就是真实的测试数据。测试环境是 8 core ×3.4G Hz，测试版本为 [v0.1.0](https://github.com/webp-sh/webp_server_go/releases/tag/0.1.0) ，使用的是默认参数配置。

```json
{
  "HOST": "127.0.0.1",
  "PORT": "3333",
  "QUALITY": "80",
  "IMG_PATH": "./src",
  "EXHAUST_PATH": "./dist",
  "ALLOWED_TYPES": ["jpg","png","jpeg","bmp","gif"]
}
```

![](https://p.k8s.li/20200304191400500.png)

### 测试结果

| file_size_range | file_num | src_size | dist_size |  total  |   user   | system | cpu | core |
| :-------------: | :------: | :------: | :-------: | :-----: | :------: | :----: | :--: | :--: |
|  (10KB,500KB)  |   4600   |   1.3G   |   310M   | 1:44.49 | 905.41s | 9.55s | 875% |  8  |
|   (500KB,1MB)   |   3500   |   2.4G   |   361M   | 2:04.81 | 1092.50s | 7.98s | 881% |  8  |
|    (1MB,4MB)    |   2000   |   3.8G   |   342M   | 2:32.64 | 1345.73s | 10.84s | 888% |  8  |
|   (4MB,32MB)   |   500   |   3.6G   |   246M   | 1:44.53 | 916.91s | 12.03s | 888% |  8  |

#### 不同核心 total 对比

| file_size_range | file_num | src_size | dist_size |    8    |    4    |    2    |    1    |
| :-------------: | :------: | :------: | :-------: | :-----: | :-----: | :-----: | :-----: |
|  (10KB,500KB)  |   4600   |   1.3G   |   310M   | 1:44.49 | 2:18.49 | 3:36.05 | 5:20.88 |
|   (500KB,1MB)   |   3500   |   2.4G   |   361M   | 2:04.81 | 2:49.46 | 4:16.41 | 6:28.97 |
|    (1MB,4MB)    |   2000   |   3.8G   |   342M   | 2:32.64 | 3:26.18 | 5:22.15 | 7:53.45 |
|   (4MB,32MB)   |   500   |   3.6G   |   246M   | 1:44.53 | 2:21.22 | 3:39.16 | 5:28.65 |

```bash
### 10KB-500KB
./webp-server -jobs 1 -config config.json -prefetch  632.77s user 11.23s system 200% cpu 5:20.88 total
./webp-server -jobs 2 -config config.json -prefetch  639.31s user 8.77s system 299% cpu 3:36.05 total
./webp-server -jobs 4 -config config.json -prefetch  676.17s user 8.12s system 494% cpu 2:18.49 total
./webp-server -jobs 8 -config config.json -prefetch  905.41s user 9.55s system 875% cpu 1:44.49 total

### 500KB-1MB

./webp-server -jobs 1 -config config.json -prefetch  767.45s user 10.14s system 199% cpu 6:28.97 total
./webp-server -jobs 2 -config config.json -prefetch  778.00s user 8.62s system 295% cpu 4:16.41 total
./webp-server -jobs 4 -config config.json -prefetch  831.38s user 7.62s system 495% cpu 2:49.46 total
./webp-server -jobs 8 -config config.json -prefetch  1092.50s user 7.98s system 881% cpu 2:04.81 total

### 1MB-4MB

./webp-server -jobs 1 -config config.json -prefetch  934.22s user 12.45s system 199% cpu 7:53.45 total
./webp-server -jobs 2 -config config.json -prefetch  958.41s user 9.41s system 300% cpu 5:22.15 total
./webp-server -jobs 4 -config config.json -prefetch  1010.56s user 8.05s system 494% cpu 3:26.18 total
./webp-server -jobs 8 -config config.json -prefetch  1345.73s user 10.84s system 888% cpu 2:32.64 total

### 4MB-32MB

./webp-server -jobs 1 -config config.json -prefetch  641.78s user 10.77s system 187% cpu 5:28.65 total
./webp-server -jobs 2 -config config.json -prefetch  643.19s user 9.73s system 297% cpu 3:39.16 total
./webp-server -jobs 4 -config config.json -prefetch  688.05s user 9.91s system 494% cpu 2:21.22 total
./webp-server -jobs 8 -config config.json -prefetch  916.91s user 12.03s system 888% cpu 1:44.53 total
```

### 转换前后大小对比

以下咱就截取一小部分的测试结果，完整的日志放在了我的 gist 上 **[webp-server-go_test.log](https://gist.github.com/muzi502/4f7c4128895ac3f438e7a183df219661)** 。图片都是真是的数据，根据文件名的 ID 可以在 pixiv.net 上找到源文件，相信老司机们都懂得 😂。

#### (10KB,500KB)

```bash
./webp-server -jobs 8 -config config.json -prefetch
905.41s user 9.55s system 875% cpu 1:44.49 total

src		    	dist		num
1.3G			310M		4600
63304866.png	495K		40K
40881097.jpg	495K		118K
21045662.jpg	495K		94K
67888534.png	495K		73K
50136421.jpg	495K		62K
72636668.png	495K		113K
55156014.jpg	495K		78K
76671894.png	495K		59K
64709121.png	495K		67K
78336881.jpg	495K		77K
57090512.png	494K		35K
72153105.jpg	494K		64K
62457185.png	494K		39K
44892218.png	494K		96K
39599640.jpg	494K		39K
21428544.jpg	493K		76K
65293876.jpg	493K		68K
76098632.png	493K		80K
65418239.jpg	493K		119K
17900553.jpg	493K		51K
61511853.jpg	493K		123K
77984504.png	493K		56K
54667116.jpg	493K		56K
75357235.jpg	493K		67K
21085426.jpg	492K		55K
```

#### (500KB,1MB)

```bash
./webp-server -jobs 8 -config config.json -prefetch
1092.50s user 7.98s system 881% cpu 2:04.81 total

src				dist		num
2.4G			361M		3500

44937735.png	974K		74K
56343106.png	974K		49K
51320479.png	974K		73K
68346957.jpg	974K		112K
74882964.png	974K		150K
76640395.jpg	974K		75K
62034004.jpg	974K		110K
59897148.jpg	974K		147K
46287856.jpg	973K		68K
54674488.jpg	973K		111K
42265521.png	973K		51K
40261146.jpg	973K		135K
76815098.png	973K		77K
57095484.png	973K		99K
65354070.jpg	973K		206K
24130390.jpg	973K		121K
73753170.jpg	972K		106K
64066680.jpg	972K		92K
72175991.png	972K		49K
53402985.png	972K		114K
70710923.png	971K		63K
76242996.png	971K		63K
65736419.jpg	971K		728K
70095856.png	971K		91K
64284761.png	971K		53K
73907152.jpg	971K		101K
62120962.png	970K		85K
22003560.png	970K		76K
77293789.jpg	970K		116K
68647243.png	970K		46K
54618347.png	970K		59K
79602155.jpg	969K		120K
55491641.jpg	968K		119K
53473372.png	968K		45K
77569729.jpg	968K		69K
57420240.png	968K		61K
69798500.png	968K		74K
63487148.png	968K		47K
79687107.jpg	967K		164K
70081772.jpg	966K		129K
79623240.jpg	966K		133K
72535236.jpg	966K		160K
47680545.png	966K		162K
```

#### (1MB,4MB)

```bash
./webp-server -jobs 8 -config config.json -prefetch
1345.73s user 10.84s system 888% cpu 2:32.64 total

src		  		dist		num
3.8G			342M		2000

73839511.png	4.1M		293K
73839511.png	4.1M		293K
66504933.png	4.1M		107K
78316050.png	4.1M		319K
74264931.png	4.1M		330K
74412671.png	4.1M		186K
77414892.png	4.1M		227K
76442741.png	4.0M		191K
71330750.png	4.0M		199K
78361206.png	4.0M		153K
68763693.png	4.0M		233K
67222487.png	4.0M		368K
68560466.png	4.0M		186K
72437850.png	4.0M		282K
67767752.png	4.0M		203K
73597995.png	4.0M		432K
71506633.png	4.0M		88K
77601042.png	4.0M		726K
77033762.png	4.0M		261K
73436647.jpg	4.0M		514K
78099751.png	4.0M		283K
73165937.png	4.0M		202K
74379006.png	4.0M		300K
79274246.png	4.0M		191K
69701132.png	4.0M		129K
67455430.jpg	3.9M		397K
73651880.png	3.9M		183K
79152655.png	3.9M		298K
73117385.png	3.9M		258K
70281950.png	3.9M		314K
68501346.png	3.9M		203K
78895125.png	3.9M		310K
70159814.png	3.9M		156K
70764048.jpg	3.9M		437K
```

#### (4MB,32MB)

```bash
./webp-server -jobs 8 -config config.json -prefetch
916.91s user 12.03s system 888% cpu 1:44.53 total

src				dist		num
3.8G			3.8G		500

78467499.png	32M		2.8M
79620324.png	32M
74975502.png	32M		3.0M
74902740.png	31M		2.6M
77032574.png	31M		2.5M
77673519.png	30M		2.3M
77298781.png	29M		1.4M
77959551.png	27M		1.5M
69987155.png	26M		649K
74432253.png	25M		1.6M
78994948.png	25M		923K
77218195.png	24M		1.6M
72379562.png	22M		251K
77559996.png	22M		1.9M
71522636.png	22M		1.3M
78236671.png	21M		1.7M
78033540.jpg	20M		2.7M
70906047.png	19M		677K
72498744.png	19M		882K
73977640.png	19M		523K
78757823.png	18M		1.5M
71588979.png	18M		1.2M
75747535.png	17M		1.2M
71504158.png	17M		1.2M
76969768.png	17M		1.4M
77995994.png	17M		568K
75340699.png	17M		1.4M
69821163.png	16M		1.1M
70050613.png	16M		1.1M
76559411.png	15M		1.7M
76576885.png	15M		853K
75640746.png	15M		1.4M
78188732.png	15M		1.4M
73355141.png	15M		589K
75977096.png	15M		1.4M
72840608.jpg	15M		1.8M
75665779.png	14M		1.5M
77898275.png	14M		1.2M
79663534.png	13M		1.2M
76539246.png	13M		1.2M
70598104.png	13M		840K
78348611.jpg	13M		2.7M
```

## 实际效果

为了做个对比，咱使用  `hexo.k8s.li` 这个域名为对照组，即输出源文件，使用 `blog.k8s.li` 这个域名为实验组加上 webp server 来测试，各位读者也可以分别访问这两个域名来实际体验之间的差别，肉眼可见 😂。

### no webps

优化建议能节省 138s ，之前也有读者普遍反映图片打开极慢

![](https://p.k8s.li/no-webp.png)

### webps yes!

优化建议能节省 19s ，比不适用 webp 整整减少了将近 2 min😂，看来效果及其明显呀。

![](https://p.k8s.li/with-webp.png)

选择两篇图片比较多的博客，测试链接为 ：

- `https://blog.k8s.li/2020-Lunar-New-Year.html`
- `https://blog.k8s.li/wd-hc310-dc-hdd.html`
- `https://hexo.k8s.li/2020-Lunar-New-Year.html`
- `https://hexo.k8s.li/wd-hc310-dc-hdd.html`

## 推荐阅读

- [让站点图片加载速度更快——引入 WebP Server 无缝转换图片为 WebP](https://nova.moe/re-introduce-webp-server/)
- [记 Golang 下遇到的一回「毫无由头」的内存更改](https://await.moe/2020/02/note-about-encountered-memory-changes-for-no-reason-in-golang/)
- [WebP Server in Rust](https://await.moe/2020/02/webp-server-in-rust/)
- [个人网站无缝切换图片到 webp](https://www.bennythink.com/flying-webp.html)
- [优雅的让 Halo 支持 webp 图片输出](https://halo.run/archives/halo-and-webp)
- [前端性能优化——使用 webp 来优化你的图片 xx](https://vince.xin/2018/09/12/%E5%89%8D%E7%AB%AF%E6%80%A7%E8%83%BD%E4%BC%98%E5%8C%96%E2%80%94%E2%80%94%E4%BD%BF%E7%94%A8webp%E6%9D%A5%E4%BC%98%E5%8C%96%E4%BD%A0%E7%9A%84%E5%9B%BE%E7%89%87/)
- [探究 WebP 一些事儿](https://aotu.io/notes/2016/06/23/explore-something-of-webp/index.html)
- [A new image format for the Web](https://developers.google.com/speed/webp)
