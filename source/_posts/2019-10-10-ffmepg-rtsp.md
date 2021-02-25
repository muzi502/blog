---
title: 使用 FFmpeg 远程读取 rtsp 监控视频流
date: 2019-09-10
categories: 技术
slug:  ffmpeg-rtsp-monitor
tag:
  - ffmpeg
  - rtsp
copyright: true
comment: true
---

## 背景

由于自己住的是价格及其便宜的民宿，四人间的合租房间。房东家住的大概有二十号人吧，人多眼杂，上月舍友丢失了一台笔记本。自己的台式机幸免遇难未被盗走。所以决定装个 IP 摄像头，防患于未然😂

## 选购摄像头

在闲鱼和某宝上挑了很久很久，一直没有找到合适的。有那种 WiFi 摄像头，比如小米、海康威视、大华，还有其他的。价格也相对来讲便宜些，一般都在 100 元左右。不过这种摄像头坑爹的是，远程存储需要购买他们的云服务，最便宜的也要 60元/30G/年，真他奶奶的割韭菜。而且还不能单独使用 NAS 之类的存储。因为我需要的是将监控视频远程保存到服务器上，保存到自己的服务器上，我不喜欢把数据交给国内的毒瘤厂商。

摄像头根据传输介质大概分为模拟传输、网络传输。模拟传输就是采用的模拟信号，把监控视频流采集到专门的录像机上，一般录像机的价格要比一个摄像头的价格贵很多。另外还要给监控录像机供电也是一笔开销，遂不考虑使用模拟摄像头。

![](https://p.k8s.li/1561802376885.jpg)

网络摄像头分为 WiFi 无线网络摄像头和网线摄像头。 WiFi 摄像头就是和小米那样的，另外房东家也是用的 WiFi 摄像头。网线摄像头分为独立供电、POE 供电两种。独立供电需要单独的 12V DC 给摄像头供电，而 POE 供电是将网线和电源绑在一起，通过 POE 交换机供电。这种 POE 供电的摄像头价格也比较贵，还需要单独购买 POE 交换机。遂也不决定购买 POE 供电的摄像头。

![](https://p.k8s.li/1561802376888.jpg)

![](https://p.k8s.li/1561802376886.jpg.jpg)

找了半天最终还是找到了一个摄像头，价格也比较便宜😂。特意问了卖家能不能通过浏览器访问、能不能不需要专用的摄像机来访问摄像头。卖家说是可以的。

![](https://p.k8s.li/1570702505815.png)

![](https://p.k8s.li/1570702514509.png)

## 安装摄像头

把路由器的电源适配器输出接口给剪了，又接了一个 DC 2.5mm 的插头，这样一个电源适配器同时供路由器和摄像头使用了😂。不用担心功率，一个摄像头和路由器总功耗还不到 8W。

![](https://p.k8s.li/1570704495847.png)

![](https://p.k8s.li/1570702447664.png)

![](https://p.k8s.li/1570702472108.png)

穹妹哦😂，骨科？

![](https://p.k8s.li/1570702482302.png)

![](https://p.k8s.li/1570702739896.png)

## 配置摄像头

询问卖家怎么配置摄像头，卖家说搜索雄迈，然后下载相应的工具。[配套软件下载 ](https://www.xiongmaitech.com/service/down_detail1/83/176) 下载安装就行。

![](https://p.k8s.li/1570704765775.png)

![](https://p.k8s.li/1570704813188.png)

![](https://p.k8s.li/1570704875787.png)

![](https://p.k8s.li/1570704956430.png)

![](https://p.k8s.li/1570704990621.png)

![](https://p.k8s.li/1570705020709.png)

## 路由器 FRP 穿透

接下来就开始配置 frp ，将摄像头 rtsp 协议的端口 554 内网穿透到服务器上

local_ip 设置为摄像头的 IP ，端口号就是 rtsp 协议监听的端口号，这样就能从服务器断读取 rtsp 的视频流了。

```ini
root@OpenWrt:~# cat /etc/frpc.ini
[common]
server_addr =
server_port =
token =

[monweb]
type = tcp
local_ip = 192.168.0.241
local_port = 80
remote_port = 2418

[monrtsp]
type = tcp
local_ip = 192.168.0.241
local_port = 554
remote_port = 554
```

## RTSP 视频流

访问 RTSP 视频流，可以使用 PotPlayer 或 VLC 等播放器，使用 FFmpeg 也是可以读取视频流。服务器端使用 FFmpeg 读取视频流，命令行操作比较方便，设置定时任务读取分割摄像头的 RTSP 视频流即可

如何访问摄像头的 RTSP 视频流？，一般摄像头的固件供应商那里会有帮助手册，总算在官方网站找到了。

> **使用VLC按RTSP协议连接我司的设备网络串流的格式**
>
> ——使用第3方的播放器通过RTSP连接我司设备的URL格式如下：
>
> ``rtsp://$(IP):$(PORT)/user=$(USER)&password=$(PWD)&channel=$(Channel)&stream=$(Stream).sdp?real_stream``
>
> ——类似 ``rtsp://10.6.10.25:554/user=admin&password=&channel=1&stream=0.sdp?real_stream``如果是通过公网需要将RTSP端口开放（ 默认是554），这个端口在网络服务->RTSP中可以设置

按照官方规定的 URL ，我的摄像头 RTSP 视频流访问 URL 就是如下：

```bash
rtsp="rtsp://192.168.0.241:554/user=user&password=password&channel=Channel&stream=Stream.sdp?real_stream"
```

![](https://p.k8s.li/1570705646007.png)

![](https://p.k8s.li/1570705720287.png)

然后服务器端安装好 FFmpeg ，使用 FFmpeg读取 rtsp 视频流即可

```bash
apt install FFmpeg -y

RTSP="rtsp://127.0.0.1:554/user=user&password=password&channel=Channel&stream=Stream.sdp?real_stream"

ffmpeg  -rtsp_transport tcp  -i $RTSP -vcodec  copy -r 1 -t 60  -y $(TZ=UTC-8 date +\%m\%d\%H\%M).mp4
```

其中 -r 参数是指定帧率，-t 参数是指定时间。关于 FFmpeg 的详细使用参数可以去参考一下官方手册，在此就不赘述了😂

```bash
╭─root@sg-02 ~/log
╰─# ffmpeg  -rtsp_transport tcp  -i $RTSP -vcodec  copy -r 1 -t 60  -y $(TZ=UTC-8 date +\%m\%d\%H\%M).mp4     130 ↵
FFmpeg version 3.4.6-0ubuntu0.18.04.1 Copyright (c) 2000-2019 the FFmpeg developers
  built with gcc 7 (Ubuntu 7.3.0-16ubuntu3)
  configuration: --prefix=/usr --extra-version=0ubuntu0.18.04.1 --toolchain=hardened --libdir=/usr/lib/x86_64-linux-gnu --incdir=/usr/include/x86_64-linux-gnu --enable-gpl --disable-stripping --enable-avresample --enable-avisynth --enable-gnutls --enable-ladspa --enable-libass --enable-libbluray --enable-libbs2b --enable-libcaca --enable-libcdio --enable-libflite --enable-libfontconfig --enable-libfreetype --enable-libfribidi --enable-libgme --enable-libgsm --enable-libmp3lame --enable-libmysofa --enable-libopenjpeg --enable-libopenmpt --enable-libopus --enable-libpulse --enable-librubberband --enable-librsvg --enable-libshine --enable-libsnappy --enable-libsoxr --enable-libspeex --enable-libssh --enable-libtheora --enable-libtwolame --enable-libvorbis --enable-libvpx --enable-libwavpack --enable-libwebp --enable-libx265 --enable-libxml2 --enable-libxvid --enable-libzmq --enable-libzvbi --enable-omx --enable-openal --enable-opengl --enable-sdl2 --enable-libdc1394 --enable-libdrm --enable-libiec61883 --enable-chromaprint --enable-frei0r --enable-libopencv --enable-libx264 --enable-shared
  libavutil      55. 78.100 / 55. 78.100
  libavcodec     57.107.100 / 57.107.100
  libavformat    57. 83.100 / 57. 83.100
  libavdevice    57. 10.100 / 57. 10.100
  libavfilter     6.107.100 /  6.107.100
  libavresample   3.  7.  0 /  3.  7.  0
  libswscale      4.  8.100 /  4.  8.100
  libswresample   2.  9.100 /  2.  9.100
  libpostproc    54.  7.100 / 54.  7.100
Input #0, rtsp, from 'rtsp://127.0.0.1:554/user=user&password=password&channel=Channel&stream=Stream.sdp?real_stream':
  Metadata:
    title           : RTSP Session
  Duration: N/A, start: 0.600000, bitrate: N/A
    Stream #0:0: Video: h264 (Main), yuvj420p(pc, bt709, progressive), 1280x720, 10 fps, 10 tbr, 90k tbn, 20 tbc
Output #0, mp4, to '10101946.mp4':
  Metadata:
    title           : RTSP Session
    encoder         : Lavf57.83.100
    Stream #0:0: Video: h264 (Main) (avc1 / 0x31637661), yuvj420p(pc, bt709, progressive), 1280x720, q=2-31, 10 fps, 10 tbr, 16384 tbn, 1 tbc
Stream mapping:
  Stream #0:0 -> #0:0 (copy)
Press [q] to stop, [?] for help
[mp4 @ 0x563c634747a0] Non-monotonous DTS in output stream 0:0; previous: 0, current: -8192; changing to 1. This may result in incorrect timestamps in the output file.
[mp4 @ 0x563c634747a0] Non-monotonous DTS in output stream 0:0; previous: 1, current: -6554; changing to 2. This may result in incorrect timestamps in the output file.
[mp4 @ 0x563c634747a0] Non-monotonous DTS in output stream 0:0; previous: 2, current: -4915; changing to 3. This may result in incorrect timestamps in the output file.
[mp4 @ 0x563c634747a0] Non-monotonous DTS in output stream 0:0; previous: 3, current: -3277; changing to 4. This may result in incorrect timestamps in the output file.
[mp4 @ 0x563c634747a0] Non-monotonous DTS in output stream 0:0; previous: 4, current: -1638; changing to 5. This may result in incorrect timestamps in the output file.
[mp4 @ 0x563c634747a0] Non-monotonous DTS in output stream 0:0; previous: 5, current: 0; changing to 6. This may result in incorrect timestamps in the output file.
frame=  387 fps= 11 q=-1.0 size=    4352kB time=00:00:38.00 bitrate= 938.2kbits/s speed=1.06x
video:6838kB audio:0kB subtitle:0kB other streams:0kB global headers:0kB muxing overhead: 0.106432%
```

## 设置定时录制任务

```bash
 */1 * * * * /root/shell/monitor.sh
```

选择每一分钟录制一分钟的是视频，没有找到其他合适的录制方法，每次录制录制都要重新建立 RTSP 链接，后面可能会写一个简单的 C 服务端直接建立 RTSP 的视频流，然后再切割视频文件。

不得不说 FFmpeg 真是强大的，偶尔了解了 FFmpeg 作者，巨牛逼的天才啊。

> - 1997年他发现了最快速的计算圆周率的算法，是Bailey-Borwein-Plouffe 公式的变体。
> - 2000年他化名Gérard Lantau，创建了 FFmpeg 项目。2004年他编写了一个只有138KB的启动加载程序TCCBOOT，可以在15秒内从源代码编译并启动Linux系统。
> - 2003年开发了Emacs克隆QEmacs。2005年用普通PC和VGA卡设计了一个数字电视系统。
> - 2009年12月31日，他声称打破了圆周率计算的世界纪录，算出小数点后2.7万亿位，仅用一台普通PC机。
> - 2011年，他单用JavaScript写了一个PC虚拟机Jslinux 。这个虚拟机仿真了一个32位的x86兼容处理器，一个8259可编程中断控制器，一个8254可编程中断计时器，和一个16450 UART。
> - Fabrice Bellard，法国著名程序员，QEMU、TinyCC、FFmpeg等作者。

不得不再提一嘴 FFmpeg 这个项目 [从FFmpeg耻辱榜看开源软件的“潜规则”](http://history.programmer.com.cn/3877/)

> FFmpeg是一个开源免费跨平台的视频和音频流方案，属于自由软件，采用LGPL或GPL许可证。2009年，韩国名软KMPlayer被FFmpeg开源项目发现使用了它们的代码和二进制文件，但没有按照规定/惯例开放相应说明/源码。被人举报后，KMPlayer进入了FFmpeg官网上的耻辱黑名单。最近，国内也有同样的产品被列入黑名单比如暴风影音、QQ影音等。
> [FFmpeg](http://ffmpeg.org/index.html)是一个跨平台的视频和音频流方案，属于自由软件，采用LGPL或GPL许可证（依据你选择的组件）。*今年2月韩国播放软件KMPlayer被加入到FFmpeg耻辱名单中，随后网友yegle向FFmpeg举报，指出暴风影音使用了大量开源代码，侵犯了FFmpeg的许可证。5月10日，另一位用户cehoyos下载了暴风软件，用7z解压之后发现其安装程序内包含了大量的开源和私有解码器的dll：avcodec，avformat，avutil，x264，xvid，bass，wmvdmod等等。杀毒软件AntiVir报告lib_VoiceEngine_dll.dll是木马程序“TR\Spy.Legmir.SS.2”。之后暴风影音被正式加入到FFmpeg耻辱名单之列。*
