---
title: every linux networking tool i know
mathjax: false
copyright: true
comment: true
tags:
    - linux
    - network
    - network tools
categories: 技术
slug:
date: 2019-04-05
---

不久前在 twitter 上看到一张描述 45 个 Linux 网络工具的 [图片](https://wizardzines.com/networking-tools-poster/)，于是想整理一下它们常用功能

----

1.`ping` "are these computers even connected"

2.`curl` make any http request  you want

3.`httpie` like curl but easier (http get)

4.`wget` download files

5.`tc` one a linux router:slow down you brother's internet(and more more)

6.`dig/nsloopup` what's the ip for the domain (DNS requery)

7.`whois` is the domain registered

8.`ssh` secure shell

9.`scp` copy file over a SSH connection

10.`rsync` copy only changed files (works over SSH)

11.`ngrep` grep your network

12.`tcpdump` show me all packets on port 80

13.`wireshark` look at those packets in a GUI

14.`tshark` command line super poweroful packets analysis

15.`tcpflow` capture & assemble TCP streams

16.`ifconfig` what's my ip address

17.`route` view and change route and more

18.`ip` replace ifconfig .route and more

19.`arp` see your arp table

20.`mitmproxy`spy on SSL connetcions your programs are making

21.`nmap` in network scanning port

22.`zenmap` GUI for nmap

23.`pof` identify OS of hosts connetcing to you

24.`ftp/sftp` copy files .sftp does if over SSH

25.`netstat/ss/fuser` "what port are server using?"

26.`iptables` setup firewall and NAT !

27.`nfables` new versiob of iptables

28.`telnet` like ssh but insecure

29.`openvpn` a VPN

30.`wireguard` a newer VPN

31.`nc` netcat ! make TCP connections manually

32.`socat` proxy a tcp socket a unix domain socket + lost more

33.`hping3` contect ang TCP packet that server

34.`traceroute/mtr` what server are on the way to what server?

35.`tcptraceroute` use tcp packets instad of icmp to traceroute

36.`ethtool` manage physical Ethernet connections + network cards

37.`iw/iwconfig` manage wireless network settings (see speed / frquery)

38.`sysctl` configure linux kernel network stack

39.`openssl` do literally anything with ssl cerficates

40.`stunel` make a ssl proxy for an insecure server

41.`iptraf/nethogsl/iftop/ntop` see what's is useing bandwidth

42.`ab/nload/iperf` benchmarking tools

43.`python3 -m http.server` server file from a directory

44.`ipcalc` easily see what

45.`nsenter`enter a container process's network namespace
