---
title: 搓一个 Debian 透明代理/旁路网关 虚拟机
date: 2019-06-30
categories: 技术
slug:
tag:
  - Linux
  - Debian
  - proxy
  - 科学上网
copyright: true
comment: true
---

## ESXi 透明代理虚拟机

弃坑了，太鸡儿难用了😡，还是使用了 [LEDE软路由](https://blog.k8s.li/esxi-lede)

## 0. 项目背景

由于工作的环境是 ESXi ，上面运行着一堆虚拟机，用来做部署方案测试使用。因为要经常访问 GitHub 以及要去 gcr.k8s.io  上拉去镜像；而且在写 Dockerfile build 镜像的时候，也需要去 GitHub 下载 release 包；使用helm初始化时需要的docker 镜像无法pull那个速度比百度网盘还慢啊啊啊啊，气死人。我觉着 GFW 的存在严重第影响了我的工作效率，遂决定搓一个虚拟机来当代理网关，或者叫旁路网关。被需要代理的机器仅仅需要修改网关和 DNS 为透明代理服务器 IP 即可。

题外话：其实用软路由 LEDE/OpenWrt 实现最合适，而且占用资源也极低，但因为使用软路由发生了一次事故，所以就不再用软路由了。那时候刚入职实习，在 ESXi 上装了个 LEDE 软路由，然后办公室的网络就瘫痪了。。

## 1.实现功能

1. 透明代理，客户端仅仅需要修改默认网关为上游透明网关即可，无需安装其他代理软件
2. 国外/国内域名分开解析，解决运营商DNS域名污染问题
3. 加快客户端访问GitHub、Google等网站速度，clone速度峰值 15MB/S
4. Docker pull 镜像速度 15MB/S，clone [torvalds/linux](https://github.com/torvalds/linux)
5. 需要代理的内网机器仅仅需要修改网关和 DNS 即可实现透明代理

## 2. 实现效果

### 1. wget 下载 GitHub release 上的文件，以 Linux为例

`163M Aug 23 21:35 v5.3-rc5.tar.gz` 163M 的文件用时不到 30s

![](https://p.k8s.li/1566567341680.png)

### 2. kubeadm config image pull

使用 kubeadm 命令加上 `--kubernetes-version=` 参数指定镜像的版本号，速度还是可以的😂

![](https://p.k8s.li/1566566813113.png)

### 3. 使用 nload 命令查看网关流量情况

![](https://p.k8s.li/1566566775553.png)

### 4. git clone GitHub 上的 repo

在此还是以 linux 项目为例，clone 过程速度飘忽不定，但一般都会在 10MiB/S 以上，按照这个速度，还和我物理机器的网卡有关，虽然号称是千兆网卡，但实际测试峰值就达不到 500Mbps，欲哭无泪🤦‍♂️

![](https://p.k8s.li/1566567116544.png)

### 5. 要代理的虚拟机

![](https://p.k8s.li/1566565577328.png)

### 5. 网关占用资源

![](https://p.k8s.li/1566565631398.png)

总的来说，这个速度还是可以接受的，比那几十几百 KB/S 的龟速满意得多了，而且对于要代理的机器来说配置起来也及其的方便，仅仅修改默认网关和 DNS 就行。

## 3. 实现过程

### 0. project

主要使用到 [ss-tproxy](https://github.com/zfl9/ss-tproxy) 这个项目，按照项目上的 README 部署部署起来就 ojbk

大佬的博客[ss/ssr/v2ray/socks5 透明代理](https://www.zfl9.com/ss-redir.html) ,很详细，建议认真读完

### 1. OS

首先虚拟机的系统我是使用的 Debian 10，使用 [netinst](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-10.0.0-amd64-netinst.iso) 镜像安装好的，当然你也可以使用 Ubuntu ，选择 Debian 是因为 Debian 可以再精简一些，安装后的占用不到 700MB 。至于 Alpine 可能要费点功夫，因为编译需要的包比较麻烦。

### 2. 安装编译环境和依赖

Debian 和 Ubuntu 的话就一把梭子就行哈

```bash
apt update
apt install -y git
apt install -y --no-install-recommends --no-install-suggests  \
    gettext build-essential autoconf libtool  libsodium-dev libmbedtls-dev \
    libpcre3-dev asciidoc xmlto libev-dev libc-ares-dev automake curl wget \
    dnsmasq iproute2 ipset perl haveged gawk
```

### 3. 安装爱国软件

这里根据你的代理软件安装配置好就行，我就剽窃一下 shadowsocks-libev 官方的 wiki

```bash
# Installation of libsodium
export LIBSODIUM_VER=1.0.16
wget https://download.libsodium.org/libsodium/releases/libsodium-$LIBSODIUM_VER.tar.gz
tar xvf libsodium-$LIBSODIUM_VER.tar.gz
pushd libsodium-$LIBSODIUM_VER
./configure --prefix=/usr && make
make install
popd
ldconfig

# Installation of MbedTLS
export MBEDTLS_VER=2.6.0
wget https://tls.mbed.org/download/mbedtls-$MBEDTLS_VER-gpl.tgz
tar xvf mbedtls-$MBEDTLS_VER-gpl.tgz
pushd mbedtls-$MBEDTLS_VER
make SHARED=1 CFLAGS="-O2 -fPIC"
make DESTDIR=/usr install
popd
ldconfig

# Installation of shadowsocks-libev
git clone https://github.com/shadowsocks/shadowsocks-libev.git --depth=1
cd shadowsocks-libev
git submodule update --init --recursive
./autogen.sh && ./configure && make
make install
```

### 4. 安装 Chinadns

安装 Chinadns 实现域名分流，国内的域名交给国内的 DNS (119.29.29.29 或 223.6.6.6) 来解析，国外的域名交给 国外的 DNS (8.8.8.8 或 1.1.1.1)来解析

```bash
# Installation of chinadns-ng
git clone https://github.com/zfl9/chinadns-ng --depth=1
cd chinadns-ng
make && make install
```

### 5. 安装 ss-tproxy

```bash
# Installation of ss-tproxy
git clone https://github.com/zfl9/ss-tproxy --depth=1
cd ss-tproxy
chmod +x ss-tproxy
cp -af ss-tproxy /usr/local/bin
mkdir -p /etc/ss-tproxy
cp -af ss-tproxy.conf gfwlist* chnroute* /etc/ss-tproxy
cp -af ss-tproxy.service /etc/systemd/system
```

### 6. 配置 ss-redir

```bash
cat >> /etc/ss.json << EOF
{
    "server":"",
    "mode":"tcp_and_udp",
    "server_port":,
    "local_port":,
    "local_address":"0.0.0.0",
    "reuse_port": true,
    "no_delay": true,
    "password":"",
    "timeout":60,
    "method":"chacha20"
}
EOF

```

```ini
"server":"", 代理服务器的 IP
"mode":"tcp_and_udp", 代理协议
"server_port":, 代理服务器端口
"local_port":, 本地端口，要和
"local_address":"0.0.0.0",一定要填，不然只能本机代理，其他及其用不了,坑我一次
"reuse_port": true,
"no_delay": true,
"password":"", 密码
"timeout":60,
"method":"" 加密协议
```

### 7. 配置 ss-tproxy

剽窃一下官方的配置文件 `/etc/ss-tproxy/ss-tproxy.conf`

```ini
## mode
#mode='gfwlist' # gfwlist 分流 (黑名单)
mode='chnroute' # chnroute 分流 (白名单)

## ipv4/6
ipv4='true'     # true:启用ipv4透明代理; false:关闭ipv4透明代理
ipv6='false'    # true:启用ipv6透明代理; false:关闭ipv6透明代理

## tproxy
tproxy='false'  # true:TPROXY+TPROXY; false:REDIRECT+TPROXY

## proxy
proxy_svraddr4=()      # 服务器的 IPv4 地址或域名，允许填写多个服务器地址，空格隔开
proxy_svraddr6=()      # 服务器的 IPv6 地址或域名，允许填写多个服务器地址，空格隔开
proxy_svrport='8080'   # 服务器的外网监听端口，格式同 ipts_proxy_dst_port，不可留空
proxy_tcpport='1080'   # ss/ssr/v2ray 等本机进程的 TCP 监听端口，该端口支持透明代理
proxy_udpport='1080'   # ss/ssr/v2ray 等本机进程的 UDP 监听端口，该端口支持透明代理
proxy_startcmd='cmd1'  # 用于启动本机代理进程的 shell 命令，该命令应该能立即执行完毕
# shadowsocks-libev 的启动命令是 ss-redir -c /etc/ss.json -u </dev/null &>>/var/log/ss-redir.log  ss.json 是你 shadowsocks 的配置文件
proxy_stopcmd='cmd2'   # 用于关闭本机代理进程的 shell 命令，该命令应该能立即执行完毕

## dnsmasq
dnsmasq_bind_port='53'                  # dnsmasq 服务器监听端口，见 README
dnsmasq_cache_size='4096'               # DNS 缓存条目，不建议过大，4096 足够
dnsmasq_cache_time='3600'               # DNS 缓存时间，单位是秒，最大 3600 秒
dnsmasq_log_enable='false'              # 记录详细日志，除非进行调试，否则不建议启用
dnsmasq_log_file='/var/log/dnsmasq.log' # 日志文件，如果不想保存日志可以改为 /dev/null
dnsmasq_conf_dir=()                     # `--conf-dir` 选项的参数，可以填多个，空格隔开
dnsmasq_conf_file=()                    # `--conf-file` 选项的参数，可以填多个，空格隔开

## chinadns
chinadns_bind_port='65353'               # chinadns-ng 服务器监听端口，通常不用改动
chinadns_verbose='false'                 # 记录详细日志，除非进行调试，否则不建议启用
chinadns_logfile='/var/log/chinadns.log' # 日志文件，如果不想保存日志可以改为 /dev/null

## dns
dns_direct='119.29.29.29'          # 本地 IPv4 DNS，不能指定端口，也可以填组织、公司内部 DNS
dns_direct6='240C::6666'              # 本地 IPv6 DNS，不能指定端口，也可以填组织、公司内部 DNS
dns_remote='8.8.8.8#53'               # 远程 IPv4 DNS，必须指定端口，提示：访问远程 DNS 会走代理
dns_remote6='2001:4860:4860::8888#53' # 远程 IPv6 DNS，必须指定端口，提示：访问远程 DNS 会走代理

## ipts
ipts_rt_tab='233'               # iproute2 路由表名或表 ID，除非产生冲突，否则不建议改动该选项
ipts_rt_mark='0x2333'           # iproute2 策略路由的防火墙标记，除非产生冲突，否则不建议改动该选项
ipts_set_snat='false'           # 设置 iptables 的 MASQUERADE 规则，布尔值，`true/false`，详见 README
ipts_set_snat6='true'           # 设置 ip6tables 的 MASQUERADE 规则，布尔值，`true/false`，详见 README
ipts_intranet=(10.20.172.0/24)  # 要代理的 IPv4 内网网段，可填多个，空格隔开，该选项的具体说明请看 README
ipts_intranet6=(fd00::/8)       # 要代理的 IPv6 内网网段，可填多个，空格隔开，该选项的具体说明请看 README
ipts_reddns_onstop='true'       # ss-tproxy stop 后，是否将其它主机发至本机的 DNS 请求重定向至本地直连 DNS，详见 README
ipts_proxy_dst_port='1:65535'   # 目标 IP 的哪些端口走代理，目标 IP 就是黑名单 IP，多个用逗号隔开，冒号为端口范围(含边界)

## opts
opts_ss_netstat='auto'                  # auto/ss/netstat，用哪个端口检测命令，见 README
opts_overwrite_resolv='false'           # true/false，定义如何修改 resolv.conf，见 README
opts_ip_for_check_net='114.114.114.114' # 用来检测外网是否可访问的 IP，该 IP 需要允许 ping

## file
file_gfwlist_txt='/etc/ss-tproxy/gfwlist.txt'      # gfwlist 黑名单文件 (默认规则)
file_gfwlist_ext='/etc/ss-tproxy/gfwlist.ext'      # gfwlist 黑名单文件 (扩展规则)
file_chnroute_set='/etc/ss-tproxy/chnroute.set'    # chnroute 地址段文件 (iptables)
file_chnroute6_set='/etc/ss-tproxy/chnroute6.set'  # chnroute6 地址段文件 (ip6tables)
file_dnsserver_pid='/etc/ss-tproxy/.dnsserver.pid' # dnsmasq 和 chinadns-ng 的 pid 文件
```

### 8. 启动

启动亲需要先关闭本机的 dnsmasq 进程，不然会提示 53 端口已占用

```bash
systemctl stop dnsmasq
systemctl disable dnsmasq
systemctl enable haveged # 启动 haveged 用来产生足够多的熵，供加密算法用
ss-tproxy start
```

## 4. 结语

完成以上该能跑起来了，需要注意的是，透明网关要和需要代理的机器在同一网段，不可跨网段，只能在一个 LAN 局域网里。最后祝 GFW 早点倒吧😡

完整脚本，在 Debian 10 下测试通过

```bash
#!/bin/bash
apt update
set -xue
apt install -y git
apt install -y --no-install-recommends --no-install-suggests  \
    gettext build-essential autoconf libtool  libsodium-dev libmbedtls-dev \
    libpcre3-dev asciidoc xmlto libev-dev libc-ares-dev automake curl wget \
    dnsmasq iproute2 ipset perl haveged gawk

mkdir -p ~/gateway
cd ~/gateway
# Installation of chinadns-ng
git clone https://github.com/zfl9/chinadns-ng --depth=1
cd chinadns-ng
make && make install
cd ../

# Installation of libsodium
export LIBSODIUM_VER=1.0.16
wget https://download.libsodium.org/libsodium/releases/libsodium-$LIBSODIUM_VER.tar.gz
tar xvf libsodium-$LIBSODIUM_VER.tar.gz
pushd libsodium-$LIBSODIUM_VER
./configure --prefix=/usr && make
make install
popd
ldconfig

# Installation of MbedTLS
export MBEDTLS_VER=2.6.0
wget https://tls.mbed.org/download/mbedtls-$MBEDTLS_VER-gpl.tgz
tar xvf mbedtls-$MBEDTLS_VER-gpl.tgz
pushd mbedtls-$MBEDTLS_VER
make SHARED=1 CFLAGS="-O2 -fPIC"
make DESTDIR=/usr install
popd
ldconfig

# Installation of shadowsocks-libev
git clone https://github.com/shadowsocks/shadowsocks-libev.git --depth=1
cd shadowsocks-libev
git submodule update --init --recursive
./autogen.sh && ./configure && make
make install
cd ../

# Installation of ss-tproxy
git clone https://github.com/zfl9/ss-tproxy --depth=1
cd ss-tproxy
chmod +x ss-tproxy
cp -af ss-tproxy /usr/local/bin
mkdir -p /etc/ss-tproxy
cp -af ss-tproxy.conf gfwlist* chnroute* /etc/ss-tproxy
cp -af ss-tproxy.service /etc/systemd/system

cat >> /etc/ss.json << EOF
{
    "server":"",
    "mode":"tcp_and_udp",
    "server_port":8080,
    "local_port":1080,
    "local_address":"0.0.0.0",
    "reuse_port": true,
    "no_delay": true,
    "password":"",
    "timeout":60,
    "method":"chacha20"
}
EOF

systemctl enable haveged
systemctl start haveged
systemctl disable dnsmasq
```
