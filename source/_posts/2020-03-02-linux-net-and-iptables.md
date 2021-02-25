---
title: Linux 网络和 iptables 运行原理
date: 2020-03-02
updated: 2020-03-02
slug:
categories: 技术
tag:
  - Linux 网络
  - 防火墙
copyright: true
comment: true
---

最近参加了一场视频会议面试，虽然结果可能不太理想，但还是发现自己对技术细节钻研的不够深，一些很基础性的知识点并没有形成一个系统性的知识架构。比如 TCP 和 UDP 的区别，这是再简单不过的问题。虽然平时都知道 TCP 应用于哪些场景，UDP 应用与哪些场景，但二者之间的细节，还是没能仔细地深入研究。所以从现在开始从新学习一下一些基础性的东西，补足一下欠下的知识😥。不过这次面试也让我意识到，我是该离开这个安逸的环境了，再过几年就要三十而立了，而这几年也正是技术积累沉淀的黄金时代，希望珍惜这段时光踏踏实实研究技术。

## Linux 协议栈

在讲解 iptables 之前要回顾一下 Linux 接收数据包和发送数据包的流程，才能理解 iptables 在 Linux 网络协议栈中的位置和作用。去年的时候听了 Go 夜读的  [【Go 夜读】 网络知识十全大补丸](https://github.com/developer-learning/night-reading-go/issues/506) ，推荐去看一下[YouTube【Go 夜读】#68 网络知识十全大补丸](https://www.youtube.com/watch?v=30wCahZEjNg)。

> 后端工程师在工作中经常会遇到计算机网络方面的问题，网络对多数人来说还是一个黑盒子，本次技术分享从常见的网络硬件、企业和数据中心的网络拓扑、Linux协议栈和防火墙等基础网络知识开始介绍，一直讲到TCP和HTTP这些年的技术演进路线和未来趋势。

### 收包流程

#### 1. 数据包到达网卡 NIC(Network Interface Card)

#### 2. NIC 检验 MAC 网卡(网卡非混杂模式)和帧的校验字段 FCS

NIC 会校验收到数据包的目的 MAC 地址是不是自己的 MAC 地址，在网卡非混杂模式下，MAC 地址不是自己的数据包通常就会丢弃。在开启混杂模式之后所有数据包都会是接收处理。

使用非混杂模式的场景：

- 抓包
- 虚拟机
- 抓包程序会把网卡设置为非混杂模式，因此抓包程序需要  root 权限，没有 root 权限无法修改硬件设备的配置。

校验完 MAC 地址之后 NIC 还会校验帧的校验字段 FCS，一次来确保接收到的数据包是正确的，如果校验失败就直接丢弃数据包

#### 3. NIC 通过 DMA 将数据包放入提前映射好的内存区域

DMA：英文拼写是 “Direct Memory Access” ，翻译成中文就是直接内存访问。DMA 允许网络设备将数据包数据直接移动到系统内存中, 从而降低 CPU 利用率。

正常情况下，一个网络数据包从网卡到应用程序需要经过如下的过程：数据从网卡通过 DMA 等方式传到内核开辟的缓冲区，然后从内核空间拷贝到用户态空间，在 Linux 内核协议栈中，这个耗时操作甚至占到了数据包整个处理流程的 57.1%。

#### 4. NIC 将数据包的引用放入接收的 ring buffer （环形缓冲区）队列 rx 中

#### 5. NIC 等待 rx-usecs 的超时时间或者 rx 队列长度达到 rx-frames 后触发硬件中断 IRQ，表示数据包收到了

- rx-usecs: 系统内核参数设置的若干微妙的超时时间。

- rx-frames: 对应的 rx 队列长度。

调整二者参数大一点，中断不频繁，吞吐量会高一些，但实时性会差一些。二者参数调小一些，NIC 中断频繁一些，实时性会高一些，但吞吐量会小一些。

#### 6. CPU 执行硬件中断和网卡的驱动程序

CPU 接收硬件中断信号后就停止手里的活，保存上下文，接着去执行网卡的中断程序，网卡的中断程序是网卡的驱动程序提前注册好的，所以接下来会调用网卡的驱动程序。

#### 7. 驱动程序清理硬中断并触发软中断 NET_RX_SOFTIRQ

在此硬件中断就处理完了。在此梳理一些整个中断处理的过程：NIC 引起硬件中断 --> 硬件中断的 handler 将引起软件中断 --> 驱动将处理这个中断，它将报文从环形缓冲区溢出，在内存中分配一个 skb --> 调用 netif_rx(skb) --> 此 skb 将放入 cpu 处理报文的队列中。如果队列满了此包将丢掉。到这为止中断就处理结束。

- **linux kernel 在报文处理上的不足**

> 1.**中断处理：**当网络中大量数据包到来时，会产生频繁的硬件中断请求，这些硬件中断可以打断之前较低优先级的软中断或者系统调用的执行过程，如果这种打断频繁的话，将会产生较高的性能开销。
> 2.**内存拷贝**：正常情况下，一个网络数据包从网卡到应用程序需要经过如下的过程：数据从网卡通过 DMA 等方式传到内核开辟的缓冲区，然后从内核空间拷贝到用户态空间，在 Linux 内核协议栈中，这个耗时操作甚至占到了数据包整个处理流程的 57.1%。
> 3.**上下文切换：**频繁到达的硬件中断和软中断都可能随时抢占系统调用的运行，这会产生大量的上下文切换开销。另外，在基于多线程的服务器设计框架中，线程间的调度也会产生频繁的上下文切换开销，同样，锁竞争的耗能也是一个非常严重的问题。
> 4.**局部性失效：**如今主流的处理器都是多个核心的，这意味着一个数据包的处理可能跨多个 CPU 核心，比如一个数据包可能中断在 cpu0，内核态处理在 cpu1，用户态处理在 cpu2，这样跨多个核心，容易造成 CPU 缓存失效，造成局部性失效。如果是 NUMA 架构，更会造成跨 NUMA 访问内存，性能受到很大影响。
> 5.**内存管理：**传统服务器内存页为 4K，为了提高内存的访问速度，避免 cache miss，可以增加 cache 中映射表的条目，但这又会影响 CPU 的检索效率。

`此处引用` [1](https://github.com/OSH-2019/x-xdp-on-android/blob/master/docs/research.md)

#### 8. 软中断对网卡进行轮训收包

- **补充**

因为硬件中断不能被嵌套即不能被打断，所以 NIC 会将硬中断信号清理掉去触发一个软中断，而软中断只需要指令即可触发。

- 硬中断：硬件信号触发的，比如键盘按键。

- 软中断：CPU 自身指令触发的中断，可以被硬件中断打断。比如系统调用。

中断数量太多的时候，CPU 不断地上下文切换，整个系统的性能将会有所损耗。

半中断半轮询模式：在软中断里轮询收包。

#### 9. 数据包被放入 qdisc 队列

以前每一个 NIC 一个队列，所有的中断都被一个 CPU 处理，直到后来改进设计出网卡多队列的模型。

网卡多队列：一个网卡对应多个接收队列，在收到数据包后会对源地址和目的地址做一个 HASH 分配到对各个队列当中去，每一个队列都会有个子中断号，这个子中断号可以分配到不同的 CPU 中去处理。这样可以让 NIC 收到的数据包让多个 CPU 来处理。

CPU 绑定：一个 NIC 产生多个中断，让多个 CPU 去分担中断的负载。

#### 10. 将数据包送入协议栈，调用 ip_recv

在此数据包就进入了协议栈，调用 ip_recv 进入三层协议栈。

ip_recv函数 [linux TCP/IP协议栈-IP层](http://abcdxyzk.github.io/blog/2015/03/04/kernel-net-ip/)

```c
/* 主要功能：对IP头部合法性进行严格检查，然后把具体功能交给ip_rcv_finish。*/
int ip_rcv(struct sk_buff *skb, struct net_device *dev, struct packet_type *pt, struct net_device *orig_dev)
{
	struct iphdr *iph;
	u32 len;
	/* 网络名字空间，忽略 */
	if (dev->nd_net != &init_net)
		goto drop;
	/*
	 *当网卡处于混杂模式时，收到不是发往该主机的数据包，由net_rx_action()设置。
	 *在调用ip_rcv之前，内核会将该数据包交给嗅探器，所以该函数仅丢弃该包。
	 */
	if (skb->pkt_type == PACKET_OTHERHOST)
		goto drop;
	/* SNMP所需要的统计数据，忽略 */
	IP_INC_STATS_BH(IPSTATS_MIB_INRECEIVES);

	/*
	 *ip_rcv是由netif_receive_skb函数调用，如果嗅探器或者其他的用户对数据包需要进
	 *进行处理，则在调用ip_rcv之前，netif_receive_skb会增加skb的引用计数，既该引
	 *用计数会大于1。若如此次，则skb_share_check会创建sk_buff的一份拷贝。
	 */
	if ((skb = skb_share_check(skb, GFP_ATOMIC)) == NULL) {
		IP_INC_STATS_BH(IPSTATS_MIB_INDISCARDS);
		goto out;
	}
	/*
	 *pskb_may_pull确保skb->data指向的内存包含的数据至少为IP头部大小，由于每个
	 *IP数据包包括IP分片必须包含一个完整的IP头部。如果小于IP头部大小，则缺失
	 *的部分将从数据分片中拷贝。这些分片保存在skb_shinfo(skb)->frags[]中。
	 */
	if (!pskb_may_pull(skb, sizeof(struct iphdr)))
		goto inhdr_error;
	/* pskb_may_pull可能会调整skb中的指针，所以需要重新定义IP头部*/
	iph = ip_hdr(skb);

	/*
	 *    RFC1122: 3.1.2.2 MUST silently discard any IP frame that fails the checksum.
	 *
	 *    Is the datagram acceptable?
	 *
	 *    1.    Length at least the size of an ip header
	 *    2.    Version of 4
	 *    3.    Checksums correctly. [Speed optimisation for later, skip loopback checksums]
	 *    4.    Doesn't have a bogus length
	 */
	/* 上面说的很清楚了 */
	if (iph->ihl < 5 || iph->version != 4)
		goto inhdr_error;
	/* 确保IP完整的头部包括选项在内存中 */
	if (!pskb_may_pull(skb, iph->ihl*4))
		goto inhdr_error;
	
	iph = ip_hdr(skb);
	/* 验证IP头部的校验和 */
	if (unlikely(ip_fast_csum((u8 *)iph, iph->ihl)))
		goto inhdr_error;
	/* IP头部中指示的IP数据包总长度 */
	len = ntohs(iph->tot_len);
	/*
	 *确保skb的数据长度大于等于IP头部中指示的IP数据包总长度及数据包总长度必须
	 *大于等于IP头部长度。
	 */
	if (skb->len < len) {
		IP_INC_STATS_BH(IPSTATS_MIB_INTRUNCATEDPKTS);
		goto drop;
	} else if (len < (iph->ihl*4))
		goto inhdr_error;

	/* Our transport medium may have padded the buffer out. Now we know it
	 * is IP we can trim to the true length of the frame.
	 * Note this now means skb->len holds ntohs(iph->tot_len).
	 */
	/* 注释说明的很清楚，该函数成功执行完之后，skb->len = ntohs(iph->tot_len). */
	if (pskb_trim_rcsum(skb, len)) {
		IP_INC_STATS_BH(IPSTATS_MIB_INDISCARDS);
		goto drop;
	}

	/* Remove any debris in the socket control block */
	memset(IPCB(skb), 0, sizeof(struct inet_skb_parm));
	/* 忽略与netfilter子系统的交互，调用为ip_rcv_finish(skb) */
	return NF_HOOK(PF_INET, NF_IP_PRE_ROUTING, skb, dev, NULL,
		 ip_rcv_finish);

inhdr_error:
	IP_INC_STATS_BH(IPSTATS_MIB_INHDRERRORS);
drop:
	kfree_skb(skb);
out:
	return NET_RX_DROP;
}
```

#### 11. 调用 netfilter 的 PREROUTING 链

> netfilter： 是 Linux 内核中进行数据包过滤，连接跟踪（Connect Track），网络地址转换（NAT）等功能的主要实现框架；该框架在网络协议栈处理数据包的关键流程中定义了一系列钩子点（Hook 点），并在这些钩子点中注册一系列函数对数据包进行处理。这些注册在钩子点的函数即为设置在网络协议栈内的数据包通行策略，也就意味着，这些函数可以决定内核是接受还是丢弃某个数据包，换句话说，这些函数的处理结果决定了这些网络数据包的“命运”。

在这里就到了内核防火墙*ip_rcv*函数为网络层向下层开放的入口，数据包通过该函数进入网络层进行处理，该函数主要对上传到网络层的数据包进行前期合法性检查，通过后交由 Netfilter 的钩子节点（IP_PRE_ROUTING）； IP_PRE_ROUTING 会根据预设的规则对数据包进行判决并根据判决结果做相关的处理，比如执行 NAT 转换；

#### 12. 查找路由表，进行转发或者投递到 local

IP_PRE_ROUTING 节点处理完成后，数据包将交由 `ip_rcv_finish` 处理，该函数根据路由判决结果，决定数据包是交由本机上层应用处理，还是需要进行转发；如果是交由本机处理，则会交由 `p_local_deliver` 本地上交流程；如果需要转发，则交由 `ip_forward` 函数走转发流程，IP_FORWARD 节点会对转发数据包进行检查过滤；

#### 13. 对投递到 local 的数据包调用 netfilter 的 LOCAL_IN 链

#### 14. 调用四层协议栈，如 tcp_v4_rcv

#### 15. 查找到对应的 socket，运行 TCP 的状态机

内核中的五元组：`| 协议类型 | 源地址 | 源端口 | 目标地址 | 目的端口 |`

将五元组进行 HASH ，根据哈希值找到对应的 socket --> 去运行该 socket 的 TCP 状态机。

#### 16. 将数据放入 TCP 的接收缓冲区中

#### 17. 通过 epoll 或者其他轮训方式通知应用程序

epoll：通过 epoll 监听可读事件，数据包丢到接收缓冲区的时候就有一个可读的事件，epoll 就会挂一个钩子，可读事件就会调用 epoll 这个钩子，然后将可读事件放入到可读队列中，接着通知到应用程序。

select：

#### 18. 应用程序读取程序

通过 read()函数读取数据？

### 发包流程

#### 1. 应用数据发送程序

调用 send() 函数，将数据从应用层拷贝到内核中。

#### 2. TCP 为发送的数据申请 skb

在 Linux 内核中，系统使用 `sk_buff` 数据结构对数据包进行存储和管理。在数据包接收过程中，该数据结构从网卡驱动收包开始，一直贯穿到内核网络协议栈的顶层，直到用户态程序从内核获取数据。

#### 3. 构建 TCP 头部，如 src 和 dst 的 port，checksum

#### 4. 调用第三层协议，构建 IP 头部，调用 netfilter 的 LOCAL_OUT 链

此处防火墙，从本机出去的包都要跑一下 LOCAL_OUT 链，网络层通过注册到上层的 `ip_local_out` 函数接收数据处理，处理 OK 进一步交由 `IP_LOCAL_OUT` 节点检测。

#### 5. 查找路由表，确定下一跳

#### 6. 调用 netfilter 的 POST_ROUTING 链

对于即将发往下层的数据包，需要经过 `IP_POST_ROUTING` 节点处理；网络层处理结束，通过 `dev_queue_xmit` 函数将数据包交由 Linux 内核中虚拟网络设备做进一步处理，从这里数据包即离开网络层进入到下一层。

#### 7. 对超时 MTU 的报文进行分片(fragment)

#### 8. 调用二成的发包函数 dev_queue_xmit

#### 9. 将待发数据包放入输出的 QDisc 队列

#### 10. 调用网卡驱动程序，将数据包放入循环缓冲队列 tx

#### 11. 驱动程序在 tx-usecs 的超时时间后，或者积累 tx-frames 个待发数据包后触发软中断

- tx-usecs

- tx-frames

#### 12. 驱动程序启用网卡的硬件中断

#### 13. 驱动程序将数据包映射到 DMA 内存

#### 14. 网卡从 DMA 中取数据并发送

#### 15. 网卡发送完毕后触发硬件中断

#### 16. 硬中断清理中断信号后触发软中断

#### 17. 软中断释放已经发送完的数据包的内存

## 防火墙

提到防火墙，想必各位都知道大名鼎鼎的方教授哈😂，不过咱今天不谈这，感兴趣的可以去读一哈 [Shadowsocks是如何被检测和封锁的](https://gfw.report/blog/gfw_shadowsocks/zh.html) 和 [G.F.W的原理](http://www.oneyearago.me/2019/06/14/learn_gwf/)

讲完了 Linux 发包和收包的整个流程我们就清楚了防火墙在网络中所工作的地方，下面就将一下 Linux 上的防火墙 iptables。

### iptales

自从 Linux 内核 2.4 之后 iptables 就集成进主线内核，不过 iptables 只是一个命令行工具，用于配置管理数据包的过滤规则，而真正起到信息包过滤作用的是 netfilter 框架。准确来讲 iptables 是一个通过控制 Linux 内核的 netfilter 模块来**管理网络数据包的流动与转送**的应用软件，其功能包括不仅仅包括防火墙的控制出入流量，还有端口转发等等。

### netfilter

netfilter 是内核的一个子系统，其工作在内核空间，核心是一个报文过滤架构，它包含了一组分布在报文处理各个阶段的钩子函数，报文经过网络协议栈时进入 netfilter 处理架构，会调用其他模块在各个阶段注册的钩子函数，并返回处理结果，netfilter 根据返回结果进行不同的处理。

#### 表/链/规则

iptables 内部有表 tables、链 chains、规则 rules 这三种概念。其中每一个 `表` 都和不同的数据包处理有关，而决定数据包是否可以穿越的是 `链`、而链上的一条条 `规则` 决定了是否送往下一条链（或其它的动作）。 netfilter/iptables 可以理解成是 `表` 的容器；表则是 `链` 的容器，即所有的`链`都属于其对应的`表`；`链`是 `规则` 的容器，其集合从属关系可以表述为（表（链（规则）））。

广为流传的说法是 iptables 有四表五链，其中四表（ raw、filter, nat, mangle,）五链（INPUT、OUTPUT、FORWARD、 PREROUTING、 POSTROUTING），不过也有说法为五表（ raw、filter、nat、mangle、security）五链，不过 security 表大多数情况下不会用到，常用的是  filter 和 nat 表，mangle 表次之。

#### 五表

- raw 表： 优先级最高，通常与`NOTRACK`一起使用，用于跳过`连接跟踪（conntrack）`和 nat 表的处理用于配置数据包，raw 中的数据包不会被系统跟踪。设置 raw 时一般是为了不再让 iptables 做数据包的链接跟踪处理，提高性能。

- filter 表： 为 iptables 默认的表，用于过滤数据包，比如 ACCEPT（允许），DROP（丢弃）、REJECT（拒绝）、LOG（记录日志）；在操作时如果没有指定使用哪个表，iptables 默认使用 filter 表来执行所有的命令。filter 表根据预定义的一组规则过滤符合条件的数据包。在 filter 表中只允许对数据包进行接收、丢弃的操作，而无法对数据包进行更改。

- nat 表： 即 Network Address Translation，主要是用于网络地址转换（例如：端口转发），该表可以实现一对一、一对多、多对多等 NAT 工作，如 SNAT（修改源地址）、DNAT（修改目的地址）、REDIRECT 重定向等；。

- mangle 表： 修改包头部的某些特殊条目，主要用于对指定包的传输特性进行修改。某些特殊应用可能需要改写数据包的一些传输特性，如 TOS、TTL、打上特殊标记 MARK 等，以影响后面的路由决策。

- security 表： 用于强制访问控制网络规则（例如： SELinux）。

表的处理优先级: raw > mangle > nat > filter。

> raw 表除了 `-j NOTRACK` 外，还有一个常用的动作，那就是 `-j TRACE`，用于跟踪数据包，进行规则的调试，使用 dmesg 查看。
>
> `连接跟踪`，顾名思义，就是跟踪并记录网络连接的状态（你可能认为只有 TCP 才有“连接”这个概念，但是在 netfilter 中，TCP、UDP、ICMP 一视同仁）。netfilter 会为每个经过网络堆栈的连接生成一个**连接记录项（Connection Entry）**；此后所有属于此连接的数据包都被唯一地分配给这个连接并标识连接的状态；由所有连接记录项组成的表其实就是所谓的**连接跟踪表**。
>
> 为什么需要连接跟踪？因为它是**状态防火墙和 NAT 的实现基础**！
>
> - `状态防火墙`：iptables 的 conntrack/state 模块允许我们根据连接的状态进行规则配置，如果没有连接跟踪，那是做不到的。
> - `NAT`，NAT 其实就是修改数据包的源地址/端口、目的地址/端口，如果没有连接跟踪，那么也不可能再找回修改前的地址信息。

#### 五链

链(chains)是数据包传输的路径，对应着报文处理的五个不同阶段：

- INPUT： 处理入站数据包，当接收到访问本机地址的数据包(入站)时，应用此链中的规则。
- OUTPUT： 处理出站数据包，当本机向外发送数据包(出站)时，应用此链中的规则。
- FORWARD： 处理转发数据包，当接收到需要通过本机发送给其他地址的数据包(转发)时，应用此链中的规则。（ip_forward 和路由器会用到）
- PREROUTING： 在对数据包作路由选择之前，应用此链中的规则。
- POSTROUTING： 在对数据包作路由选择之后，应用此链中的规则。

其中 INPUT 和 OUTPUT 链主要应用在本机的网络控制中，而 FORWARD、PREROUTING、 POSTROUTING 链更多地应用在对外的网络控制中，特别是机器作为网关使用时的情况。

#### 规则

数据包的过滤基于 **规则**，而规则是由匹配条件和处理动作组成。规则分别指定了源地址、目的地址、传输协议（如TCP、UDP、ICMP）和服务类型（如HTTP、FTP和SMTP）等。当数据包与规则匹配时，iptables 就根据规则所定义的方法来处理这些数据包，如放行（accept）、拒绝（reject）和丢弃（drop）等。配置防火墙的主要工作就是添加、修改和删除这些规则。

**常见的处理动作：**

- ACCEPT： 允许数据包通过。
- DROP： 直接丢弃数据包，不给任何回应信息。
- QUEUE： 将数据包移交到用户空间。
- RETURN： 停止执行当前链中的后续规则，并返回到调用链(The Calling Chain)中。
- REJECT： 拒绝数据包通过，必要时会给数据发送端一个响应的信息。
- DNAT： 目标地址转换（docker 网络会用到）。
- SNAT： 源地址转换，解决内网用户用同一个公网地址上网的问题 （docker 网络会用到）。
- MASQUERADE： 是 SNAT 的一种特殊形式，适用于动态的、临时会变的 ip 上。
- REDIRECT： 在本机做端口映射（透明代理的时候会用到）。
- LOG： 记录日志信息，除记录外不对数据包做任何其他操作，仍然匹配下一条规则。

**总体顺序如下：**

1.当一个数据包进入某个链时，首先按照表的优先级依次处理；
2.每个表中的规则都有序号（从 1 开始），数据包会根据规则序号依次进行匹配；
3.如果命中一条规则，则执行相应的动作；如果所有表的规则都未命中，则执行默认策略。

### 关系

链是规则的容器，一条链中可能包含着众多的规则，当一个数据包到达一个链时，iptables 就会从链中第一条规则开始匹配，如果满足该规则的条件，系统就会根据该条规则所定义的方法处理该数据包，否则将继续匹配下一条规则，如果该数据包不符合链中任一条规则，iptables 就会根据该链预先定义的默认策略来处理数据包。可以看到 iptables 遍历链中的规则算法复杂度为 O(n)，即随着链中的规则数量增大而增大。而且，链的匹配是有顺序的，这一点非常重要，在添加规则的时候也要主要顺序，搞错了就可能导致系统所有流量都无法进入。

#### Filter 表

Filter 表是 iptables 的默认表，因此如果没有指定表，那么默认操作的是 filter 表，其包含以下三种内建链：

- INPUT 链：处理来自外部的数据
- OUTPUT 链：处理向外发送的数据
- FORWARD 链：将数据转发到本机的其他网卡设备上

#### NAT 表

- PREROUTING 链：处理刚到达本机并在路由转发前的数据包。它会转换数据包中的目标 IP 地址（destination ip address），通常用于 DNAT(destination NAT)

- POSTROUTING 链：处理即将离开本机的数据包。它会转换数据包中的源 IP 地址（source ip address），通常用于 SNAT（source NAT）

- OUTPUT 链：处理本机发出的数据包

#### Mangle 表

Mangle 表包含五种内建链：PREROUTING、OUTPUT、FORWARD、INPUT、POSTROUTING。

#### Raw 表

含两个内建链：PREROUTING, OUTPUT.

### 数据包流程

![img](https://blog.k8s.li/img/iptables.png)

在 Linux 下，从任何网络端口进来的每一个 IP 数据包都要从上到下的穿过这张图，iptabales 对从任何端口进入的数据包都会采取相同的处理方式。

此图摘自 [Archlinux 文档](https://wiki.archlinux.org/index.php/Iptables)

```txt
                               XXXXXXXXXXXXXXXXXX
                             XXX     Network    XXX
                               XXXXXXXXXXXXXXXXXX
                                       +
                                       |
                                       v
 +-------------+              +------------------+
 |table: filter| <---+        | table: nat       |
 |chain: INPUT |     |        | chain: PREROUTING|
 +-----+-------+     |        +--------+---------+
       |             |                 |
       v             |                 v
 [local process]     |           ****************          +--------------+
       |             +---------+ Routing decision +------> |table: filter |
       v                         ****************          |chain: FORWARD|
****************                                           +------+-------+
Routing decision                                                  |
****************                                                  |
       |                                                          |
       v                        ****************                  |
+-------------+       +------>  Routing decision  <---------------+
|table: nat   |       |         ****************
|chain: OUTPUT|       |               +
+-----+-------+       |               |
      |               |               v
      v               |      +-------------------+
+--------------+      |      | table: nat        |
|table: filter | +----+      | chain: POSTROUTING|
|chain: OUTPUT |             +--------+----------+
+--------------+                      |
                                      v
                               XXXXXXXXXXXXXXXXXX
                             XXX    Network     XXX
                               XXXXXXXXXXXXXXXXXX
```

### 遍历链流程图

该流程图描述链了在任何接口上收到的网络数据包是按照怎样的顺序穿过表的交通管制链。

![tables_traverse](https://www.frozentux.net/iptables-tutorial/chunkyhtml/images/tables_traverse.jpg)

- 第一个路由策略包括决定数据包的目的地是本地主机（这种情况下，数据包穿过 INPUT 链），还是其他主机（数据包穿过 FORWARD 链）；

- 中间的路由策略包括决定给传出的数据包使用那个源地址、分配哪个接口；

- 最后一个路由策略存在是因为先前的 mangle 与 nat 链可能会改变数据包的路由信息。

数据包通过路径上的每一条链时，链中的每一条规则按顺序匹配；无论何时匹配了一条规则，相应的 target/jump 动作将会执行。最常用的3个 target 是 ACCEPT, DROP ,或者 jump 到用户自定义的链。内置的链有默认的策略，但是用户自定义的链没有默认的策略。在 jump 到的链中，若每一条规则都不能提供完全匹配，那么数据包像这张图片描述的一样返回到调用链。在任何时候，若 DROP target 的规则实现完全匹配，那么被匹配的数据包会被丢弃，不会进行进一步处理。如果一个数据包在链中被 ACCEPT，那么它也会被所有的父链 ACCEPT，并且不再遍历其他父链。然而，要注意的是，数据包还会以正常的方式继续遍历其他表中的其他链。

#### 本机发出的包

本机进程 -> OUTPUT 链 -> 路由选择 -> POSTROUTING 链 -> 出口网卡

#### 本机收到的包

入口网卡 -> PREROUTING 链 -> 路由选择 -> 此时有两种可能的情况：

- 目的地址为本机：INPUT 链 -> 本机进程
- 目的地址不为本机：FORWARD 链 -> POSTROUTING 链 -> 网卡出口（内核允许网卡转发的情况下）

## iptables 实战

iptables [-t 表] 命令选项 [链] [匹配选项] [操作选项]

### 命令选项

| 选项名            | 功能及特点                                                   |
| :---------------- | :----------------------------------------------------------- |
| -A --append       | 在指定链的末尾添加一条新的规则                               |
| -D --delete       | 删除指定链中的某一条规则，按规则序号或内容确定要删除的规则   |
| -I --insert       | 在指定链中插入一条新的规则，默认在链的开头插入               |
| -R --replace      | 修改、替换指定链中的一条规则，按规则序号或内容确定           |
| -F --flush        | 清空指定链中的所有规则，默认清空表中所有链的内容             |
| -N --new          | 新建一条用户自己定义的规则链                                 |
| -X --delete-chain | 删除指定表中用户自定义的规则链                               |
| -P --policy       | 设置指定链的默认策略                                         |
| -F, --flush       | 清空指定链上面的所有规则，如果没有指定链，清空表上所有链的所有规则 |
| -Z, --zero        | 把指定链或表中的所有链上的所有计数器清零                     |
| -L --list         | 列出指定链中的所有的规则进行查看，默认列出表中所有链的内容   |
| -S --list-rules   | 以原始格式列出链中所有规则                                   |
| -v --verbose      | 查看规则列表时显示详细的信息                                 |
| -n --numeric      | 用数字形式显示输出结果，如显示主机的 IP 地址而不是主机名     |
| --line-number     | 查看规则列表时，同时显示规则在链中的顺序号                   |

### 匹配选项

| 选项名             | 功能及特点                          |
| :----------------- | :---------------------------------- |
| -i --in-interface  | 匹配输入接口，如 eth0，eth1         |
| -o --out-interface | 匹配输出接口                        |
| -p --proto         | 匹配协议类型，如 TCP、UDP 和 ICMP等 |
| -s --source        | 匹配的源地址                        |
| --sport            | 匹配的源端口号                      |
| -d --destination   | 匹配的目的地址                      |
| --dport            | 匹配的目的端口号                    |
| -m --match         | 匹配规则所使用的过滤模块            |

### 操作选项

 一般为 `-j 处理动作` 的形式，处理动作包括 ACCEPT、DROP、RETURN、REJECT、DNAT、SNAT 等。不同的处理动作可能还有额外的选项参数，如指定 DNAT、SNAT 动作则还需指定 `--to` 参数用以说明要装换的地址，指定 REDIRECT 动作则需指定 --to-ports 参数用于说明要跳转的端口。

| 操作名     | 功能                                                         |
| ---------- | ------------------------------------------------------------ |
| ACCEPT     | 允许数据包通过                                               |
| DROP       | 直接丢弃数据包，不给任何回应信息                             |
| QUEUE      | 将数据包移交到用户空间                                       |
| RETURN     | 停止执行当前链中的后续规则，并返回到调用链(The Calling Chain)中 |
| REJECT     | 拒绝数据包通过，必要时会给数据发送端一个响应的信息           |
| DNAT       | 进行目标地址转换                                             |
| SNAT       | 源地址转换，解决内网用户用同一个公网地址上网的问题           |
| MASQUERADE | 是 SNAT 的一种特殊形式，适用于动态的、临时会变的 ip 上       |
| REDIRECT   | 在本机做端口映射                                             |
| LOG        | 记录日志信息，除记录外不对数据包做任何其他操作，仍然匹配下一条规则 |

### 命令详解

```bash
### 命令用法 (man 文档)
iptables [-t table] {-A|-C|-D} chain rule-specification         # (ipv4) 追加|检查|删除 规则
ip6tables [-t table] {-A|-C|-D} chain rule-specification        # (ipv6) 追加|检查|删除 规则
iptables [-t table] -I chain [rulenum] rule-specification       # 在 rulenum 处插入规则 (默认为 1)
iptables [-t table] -R chain rulenum rule-specification         # 替换第 rulenum 条规则
iptables [-t table] -D chain rulenum                            # 删除第 rulenum 条规则
iptables [-t table] -S [chain [rulenum]]                        # 打印指定 table 的规则
iptables [-t table] {-F|-L|-Z} [chain [rulenum]] [options...]   # 清空|列出|置零 链/规则
iptables [-t table] -P chain target                             # 设置默认策略
iptables [-t table] -N chain                                    # 新建自定义链
iptables [-t table] -X [chain]                                  # 删除自定义链
iptables [-t table] -E old-chain-name new-chain-name            # 重命名自定义链

### 一般形式
iptables [-t 表名] {-A|I|D|R} 链名 [规则号] 匹配规则 -j 动作

### 查看帮助
iptables --help             # 查看 iptables 的帮助
iptables -m 模块名 --help   # 查看指定模块的可用参数
iptables -j 动作名 --help   # 查看指定动作的可用参数

### 持久化规则
# 在 RHEL/CentOS 中，默认规则文件为 /etc/sysconfig/iptables
# 在 iptables 服务启动时，默认会加载该配置文件中定义的规则
# 如果想要设置的规则在重启后有效，就需要保存规则到这个文件
# 使用这两个工具：iptables-save、iptables-restore 重定向即可
## 保存当前规则
iptables-save >/etc/sysconfig/iptables
iptables-save >/etc/sysconfig/iptables.20171125
## 恢复当前规则
iptables-restore </etc/sysconfig/iptables
iptables-restore </etc/sysconfig/iptables.20171125

### 命令和选项
-t              # 指定要操作的表，如果省略则默认为 filter 表
-A              # "追加" 一条规则，只能追加到末尾
-I              # "插入" 一条规则，如果省略序号则默认为 1
-R              # "替换" 一条规则，必须指定序号
-D              # "删除" 一条规则，必须指定序号
-C              # "检查" 规则是否存在，如果存在则返回 0
-P              # 设置链的 "默认策略"，nat 表不允许修改默认策略
-S              # "查看" 规则（原始格式）
-L              # "打印" 规则（友好格式）
-F              # 清空表中的规则并将包计数器、字节计数器置零
-Z              # 将某个链或某条规则的包计数器、字节计数器置零
-N              # 新建自定义链
-X              # 删除自定义链
-E              # 重命名自定义链
-n              # 以数字形式显示地址和端口
-v              # 在打印规则时显示详细信息
--line-numbers  # 在打印规则时显示规则序号

### 反向匹配
# 只需在选项前面使用 ! 即可，如: ! -s 192.168.0.0/16 表示除 192.168/16 外的源 IP

### 通用匹配
-s addr[/mask][...] # 源 IP，可以有多个，使用逗号隔开，有多少个地址就有多少条规则
-d addr[/mask][...] # 目的 IP，可以有多个，使用逗号隔开，有多少个地址就有多少条规则
-i input-nic[+]     # 数据包来自哪个网卡，+ 表示通配符
-o output-nic[+]    # 数据包送往哪个网卡，+ 表示通配符
-p {tcp|udp|udplite|icmp|icmpv6|esp|ah|sctp|mh|all}
                    # 指定匹配的协议，all 表示所有

### 隐式扩展匹配 (tcp/udp/icmp)
## tcp 扩展
--sport port[:port]     # 源端口号，100:200 表示端口范围
--dport port[:port]     # 目的端口号，100:200 表示端口范围
--tcp-flags mask comp   # TCP 标志位，flags={SYN|ACK|FIN|RST|URG|PSH|ALL|NONE}
--syn                   # SYN 标志位，等同于 --tcp-flags SYN,RST,ACK,FIN SYN
--tcp-option number     # TCP 选项

## udp 扩展
--sport port[:port]     # 源端口号
--dport port[:port]     # 目的端口号

## icmp 扩展
--icmp-type name[/code] # icmp 类型，常用的两个: ping、pong，请求和应答

### 显式扩展匹配 (-m module-name)
## multiport 多端口
--sports port[,port:port,port...]   # 匹配多个源端口[范围]
--dports port[,port:port,port...]   # 匹配多个目的端口[范围]
--ports port[,port:port,port...]    # 匹配多个源和目的端口[范围]

## owner 所属用户(组)
--uid-owner userid[-userid]     # 匹配 UID[范围]/username
--gid-owner groupid[-groupid]   # 匹配 GID[范围]/groupname
--socket-exists                 # 匹配与套接字相关联的数据包

## state 连接状态(基本)
--state [INVALID|ESTABLISHED|NEW|RELATED|UNTRACKED][,...]
# NEW           新连接
# ESTABLISHED   已建立的连接
# RELATED       关联的连接，如 ftp
# INVALID       无效/非法的连接
# UNTRACKED     未启用连接跟踪的连接

## conntrack 连接状态
--ctstate {INVALID|ESTABLISHED|NEW|RELATED|UNTRACKED|SNAT|DNAT}[,...]

## iprange IP范围
--src-range ip[-ip]     # 匹配指定的源 IP 范围
--dst-range ip[-ip]     # 匹配指定的目的 IP 范围

## mac 源MAC地址
--mac-source XX:XX:XX:XX:XX:XX  # 匹配源 MAC 地址

## addrtype 地址类型
--src-type type[,...]   # 匹配 source ip 地址的类型
--dst-type type[,...]   # 匹配 destination ip 地址的类型
# UNSPEC       未指定的地址，如 0.0.0.0
# UNICAST      单播地址
# LOCAL        本机地址
# BROADCAST    广播地址
# ANYCAST      任播地址
# MULTICAST    多播地址
# BLACKHOLE    黑洞地址
# UNREACHABLE  不可达地址
# PROHIBIT     禁止访问的地址

## time 时间
--datestart time     # 起始日期 YYYY[-MM[-DD[Thh[:mm[:ss]]]]]
--datestop time      # 结束日期 YYYY[-MM[-DD[Thh[:mm[:ss]]]]]
--timestart time     # 起始时间 hh:mm[:ss]
--timestop time      # 结束时间 hh:mm[:ss]
--monthdays value    # 几号，1 至 31，默认为 all
--weekdays value     # 星期几，1 至 7，默认为 all
--kerneltz           # 使用内核时区而非 UTC

## string 关键字匹配
--from offset       # 设置起始偏移量
--to offset         # 设置结束偏移量
--algo {bm|kmp}     # 指定使用的算法
--icase             # 忽略大小写匹配
--string string     # 要匹配的字符串
--hex-string string # 要匹配的字符串，十六进制

## length 数据包大小
--length length[:length]    # 匹配数据包大小[范围]

## mark 防火墙标记
--mark value[/mask]     # 匹配有指定防火墙标记的数据包

## connmark "连接"标记
--mark value[/mask]     # 如果当前数据包所属的"连接"打了给定的标记，则匹配成功

## limit 速率限制
--limit avg             # 平均速率限制，如 3/hour，单位: sec|minute|hour|day
--limit-burst number    # 封顶速率限制，默认为 5

## connlimit 并发连接数
--connlimit-upto n      # 0..n
--connlimit-above n     # > n

### -j target 动作
## 无参数系列
ACCEPT      # 接收数据包
DROP        # 丢弃数据包
CUST-CHAIN  # 进入自定义链
RETURN      # 退出当前链，分两种情况：
            # 如果当前链是自定义链，则返回调用链，继续匹配调用点的下一条规则
            # 如果当前链不是自定义链，则执行当前链的默认策略，如 ACCEPT、DROP

## 带参数系列
# REJECT 拒绝（带原因）
--reject-with type              # 丢弃数据包，并回复源主机，可用的 type 如下：
    icmp-net-unreachable        # ICMP 网络不可达
    net-unreach                 # 同上，别名
    icmp-host-unreachable       # ICMP 主机不可达
    host-unreach                # 同上，别名
    icmp-proto-unreachable      # ICMP 协议不可达
    proto-unreach               # 同上，别名
    icmp-port-unreachable       # ICMP 端口不可达（默认）
    port-unreach                # 同上，别名
    icmp-net-prohibited         # ICMP 网络限制
    net-prohib                  # 同上，别名
    icmp-host-prohibited        # ICMP 主机限制
    host-prohib                 # 同上，别名
    icmp-admin-prohibited       # ICMP 管理员限制
    admin-prohib                # 同上，别名
    tcp-reset                   # TCP RST 连接重置
    tcp-rst                     # 同上，别名

# MARK 打防火墙标记
--set-mark value[/mask]   # 设置标记，mask OR value（推荐）
--set-xmark value[/mask]  # 设置标记，mask XOR value
--and-mark bits           # 设置二进制标记，AND
--or-mark bits            # 设置二进制标记，OR
--xor-mask bits           # 设置二进制标记，XOR

# CONNMARK 打"连接"标记
--set-mark value[/mask]       # 设置当前数据包所属连接的连接标记
--save-mark [--mask mask]     # 将当前数据包的标记作为其所属连接的标记
--restore-mark [--mask mask]  # 将当前数据包所属连接的标记作为该数据包的标记

# LOG 防火墙日志，dmesg 可查看
--log-level level       # 日志级别（syslog.conf）
--log-prefix prefix     # 日志前缀字符串
--log-tcp-sequence      # 记录 TCP seq 序列号
--log-tcp-options       # 记录 TCP options 选项
--log-ip-options        # 记录 IP options 选项
--log-uid               # 记录套接字相关联的 UID
--log-macdecode         # 解析 MAC 地址和协议

# ULOG 防火墙日志，kernel 2.4+
--ulog-nlgroup nlgroup  # 记录的 NETLINK 组
--ulog-cprange size     # 要复制的字节数
--ulog-qthreshold       # 内核队列的消息阈值
--ulog-prefix prefix    # 日志前缀字符串

# NFLOG 防火墙日志，kernel 2.6+
--nflog-group NUM       # 记录的 NETLINK 组
--nflog-size NUM        # 要复制的字节数
--nflog-threshold NUM   # 内核队列的消息阈值
--nflog-prefix STRING   # 日志前缀字符串

# SNAT 源地址转换，用在 POSTROUTING、INPUT 链
--to-source [<ipaddr>[-<ipaddr>]][:port[-port]]
--random        # 映射到随机端口号
--random-fully  # 映射到随机端口号（PRNG 完全随机化）
--persistent    # 映射到固定地址

# DNAT 目的地址转换，用在 PREROUTING、OUTPUT 链
--to-destination [<ipaddr>[-<ipaddr>]][:port[-port]]
--random        # 映射到随机端口号
--persistent    # 映射到固定地址

# MASQUERADE 源地址转换（适用于 DHCP 动态 IP），用在 POSTROUTING 链
--to-ports <port>[-<port>]  # 映射到指定端口号[范围]
--random                    # 映射到随机端口号

# REDIRECT 目的地址转换（重定向至 localhost:端口号），用在 PREROUTING、OUTPUT 链
--to-ports <port>[-<port>]  # 重定向到指定端口号[范围]
--random                    # 重定向到随机端口号
```

### 常用命令

#### 查看帮助

```bash
iptables --help             # 查看 iptables 的帮助
iptables -m 模块名 --help    # 查看指定模块的可用参数
iptables -j 动作名 --help    # 查看指定动作的可用参数
```

#### 查看规则

```bash
iptables -nvL
iptables -t nat -nvL

# 显示规则序号
iptables -nvL INPUT --line-numbers
iptables -t nat -nvL --line-numbers
iptables -t nat -nvL PREROUTING --line-numbers

# 查看规则的原始格式
iptables -t filter -S
iptables -t nat -S
iptables -t mangle -S
iptables -t raw -S
```

#### 设置默认规则

```bash
iptables -P INPUT DROP     # 配置默认丢弃访问的数据表
iptables -P FORWARD DROP   # 配置默认禁止转发
iptables -P OUTPUT ACCEPT  # 配置默认允许向外的请求
```

#### 清除所有规则

注意，在使用的时候

```bash
iptables -F  # 清空表中所有的规则
iptables -X  # 删除表中用户自定义的链
iptables -Z  # 清空计数

iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -t raw -F
iptables -t raw -X
iptables -t security -F
iptables -t security -X
```

#### 增加规则

```bash
# 增加一条规则到最后
iptables -A INPUT -i eth0 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT

# 注：以下几条操作都需要使用规则的序号，需要使用 -L --line-numbers 参数先查看规则的顺序号

# 添加一条规则到指定位置
iptables -I INPUT 2 -i eth0 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
```

#### 删除规则

```bash
# 将所有 iptables 以序号标记显示
iptables -L -n --line-numbers

# 根据规则的序号来删除
iptabels -D INPUT ${line-numbers}
```

#### 修改规则

```bash
iptables -R INPUT 3 -i eth0 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
```

#### 开放指定端口

```bash
# 允许本地回环接口(即运行本机访问本机)
iptables -A INPUT -i lo -j ACCEPT

# 允许已建立的或相关连接的通行
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 允许所有本机向外的访问
iptables -A OUTPUT -j ACCEPT

# 允许 22,80,443 端口的访问
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dports 80,443 -j ACCEPT

# 允许 ping
iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT

# 禁止 ping
iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j DROP

# 禁止其他未允许的规则访问
iptables -A INPUT -j REJECT
iptables -A FORWARD -j REJECT
```

#### 设置白名单

```bash
# 允许机房内网机器可以访问
iptables -A INPUT -p all -s 10.10.10.0/24 -j ACCEPT
# 允许 10.10.10.22 访问本机的 22 端口
iptables -A INPUT -p tcp -s 10.10.10.22 --dport 22 -j ACCEPT
```

#### 屏蔽某 IP

```bash
 # 屏蔽恶意主机（比如，114.114.114.114)
iptables -A INPUT -p tcp -m tcp -s 114.114.114.114 -j DROP

# 屏蔽单个IP的命令
iptables -I INPUT -s 123.45.6.7 -j DROP

#封整个段即从 10.10.10.1 到 10.10.10.254的命令
iptables -I INPUT -s 10.10.10.0/24 -j DROP    
```

#### 指定数据包出去的网络接口

```bash
# 只对 OUTPUT，FORWARD，POSTROUTING 三个链起作用
iptables -A FORWARD -o eth0
```

#### 防止SYN洪水攻击

```bash
iptables -A INPUT -p tcp --syn -m limit --limit 5/second -j ACCEPT
```

#### 端口映射

```bash
# 本机的 2222 端口映射到内网虚拟机的22 端口
iptables -t nat -A PREROUTING -d 223.6.6.6 -p tcp --dport 2222  -j DNAT --to-dest 10.10.10.22:22
```

#### 持久化规则：

**RHEL/CentOS**

```bash
# 运维千万条，备份第一条，操作不规范，数据全完蛋(大雾
cp /etc/sysconfig/iptables{，.bak}

# 保存当前规则
iptables-save > /etc/sysconfig/iptables
cat /etc/sysconfig/iptables

# 恢复备份规则
iptables-restore < iptables
```

**Debian/Ubuntu**

```bash
# 备份当前规则
cp /etc/iptables/rules.v4{,.bak}

# 持久化当前规则
iptables-save > /etc/iptables/rules.v4
```

#### 切记

在操作 iptables 规则时一定要主要先后顺序，因为链上的规则是一条条规则遍历下来的，所以顺序出错的话，iptables 作用的效果也有可能不一样的哦。

## 参考

- [Linux协议栈--连接跟踪源码分析](http://cxd2014.github.io/2017/08/15/connection-tracking-system/)
- [x-xdp-on-android](https://github.com/OSH-2019/x-xdp-on-android/blob/master/docs/research.md)
- [linux TCP/IP协议栈-IP层](http://abcdxyzk.github.io/blog/2015/03/04/kernel-net-ip/)
- [CPU体系架构 DMA](https://nieyong.github.io/wiki_cpu/CPU%E4%BD%93%E7%B3%BB%E6%9E%B6%E6%9E%84-DMA.html)
- [iptables 使用方式整理](http://blog.konghy.cn/2019/07/21/iptables/)
- [Archlinux：Iptables](https://wiki.archlinux.org/index.php/Iptables_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87))
- [iptables 防火墙基本配置和使用](https://windard.com/opinion/2016/10/15/About-Iptables)
- [Linux的 iptables 常用配置范例（1）](http://www.ha97.com/3928.html)
- [开启 ufw 导致断网不能 ping? ufw 和 iptables 的那些坑](https://www.bennythink.com/ufw-iptables.html)
- [Linux 网络层收发包流程及 Netfilter 框架浅析](https://zhuanlan.zhihu.com/p/93630586)
- [Linux防火墙与iptables介绍](http://www.mikewootc.com/wiki/linux/usage/linux_firewall_iptables_intro.html)
- [iptables 详解](https://www.zfl9.com/iptables.html)
