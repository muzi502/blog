---
title: 【翻译】给 VMware vSphere 用户的 Kubernetes 简介
date: 2019-12-10
updated:
categories: 技术
slug:
tag:
  - kubernetes
  - 翻译
copyright: true
comment: true

---

## 更新日志

- 2019-12-10 初步开始翻译
- 2019-12-11 补充完整
- 2019-12-20 校稿

## README

本文翻译自 [Kubernetes Introduction for VMware Users – Part 1: The Theory]( https://blogs.vmware.com/cloudnative/2017/10/25/kubernetes-introduction-vmware-users/ )

By Hany Michaels, Senior Staff Solutions Architect NSBU, VMware

October 25, 2017

四六级未过的工地英语翻译、希望各位读者雅正翻译不当的部分😁

## Kubernetes Introduction for VMware Users – Part 1: The Theory

## 给 VMware 用户的 Kubernetes 简介——第一部分：理论

>This is the second part of my “Kubernetes in the Enterprise” blog series. As I mentioned in my [last article](http://www.hanymichaels.com/2017/10/04/kubernetes-in-the-enterprise-a-vmware-guide-on-how-to-design-deploy-and-operate-k8saas-with-nsx-t-and-vra/), it is important to get everyone to the same level of understanding about Kubernetes ([K8s](https://kubernetes.io/)) before we can proceed to the design and implementation guides.

这是我的“ kubernetes 在企业中应用” 博客系列的第二篇文章。正如我在上一篇文章提到的，在我们继续设计与实现指南之前，重要的是让每个人对 kubernetes 的理解都是相同水平的。

> I am not going to take the traditional approach here to explain the Kubernetes architecture and technologies. I will explain everything through comparisons with the [vSphere platform](https://www.vmware.com/products/vsphere.html) that you, as a VMware user, are already familiar with. You can say that this was the approach I would have liked someone to use to introduce K8s to me. The latter could be very confusing and overwhelming to understand at the beginning. I’d like to add also that I used this approach internally at VMware to introduce Kubernetes to some audiences from different practices, and it has proven to work great and get people up to speed with the core concepts.

在这里，我不打算采用传统的方法来讲解 Kubernetes 的架构和技术。我将通过与 [vSphere 平台](https://www.vmware.com/products/vsphere.html) 的比较来为你解释所有的概念，对你来讲 VMware 已经相当熟悉了。你可以说，这就是我希望别人向我介绍 k8s 的方法。后者在一开始可能会让人感到非常困惑和难以理解。我还想补充一点，我在 VMware 内部也是使用这种方法向来自不同实践的听众们介绍 Kubernetes。

> An important note before we kick this off: I am not using this comparison for the sake of it, or to prove any similarities or differences between vSphere and Kubernetes. Both are distributed systems at heart, and they must have similarities like any other similar system out there. What I am trying to achieve here at the end of the day is to introduce an incredible technology like Kubernetes to the broader VMware community.

在此之前有一个重要提示：我不是为了介绍 Kubernetes 而使用这个比较，也不是为了证明 vSphere 和 Kubernetes 之间存在的任何异同之处。两者的核心都是分布式系统，它们肯定有着其他分布式系统的相似之处。最后，我想在这里实现的目标是向更广泛的 VMware 社区介绍像 Kubernetes 这样不可思议的技术。

![](https://p.k8s.li/kubernetes-architecture-1024x512.png)

> Figure: The Kubernetes overall architecture compared to vSphere

图片：Kubernetes 和 vSphere 整体架构对比

## A little bit of history

## 插曲

> You should already be familiar with containers before reading this post. I am not going to go through those basics as I am sure there are so many resources out there that talk about this. What I see very often though when I speak with my customers is that they cannot make much sense of why containers have taken our industry by storm and become very popular in record time. To answer this question, and in fact set the context for what is coming, I may have to tell you a little bit about my history as a practical example of how I personally made sense of all the shift that is happening in our industry.

在阅读这篇文章之前，你应该已经熟悉容器技术了。在此我就不再赘述这些基础知识了，因为我敢肯定网上有很多教程在讲解这些。不过，当我与客户交谈时，我经常注意到，他们无法理解为什么容器技术席有史以来席卷了我们的行业并变得非常流行。为了回答这个问题，并为接下来的内容做铺垫，我可能需要向你介绍一下我的历史，以此作为一个实际的例子，来阐述我个人如何理解行业中正在发生的转变。

> I used to be a web developer back in 2003 before I got introduced to the telecom world, and it was my second paying job after being a network engineer/admin. (I know, I was a jack-of-all-trades back then). I used to code in PHP, and I’ve done all sorts of applications from small internal apps used by my employer, to professional voting apps for TV programs, to telco apps interfacing with VSAT hubs and interacting with satellite systems. Life was great, except for one major hurdle that I am sure every developer can relate to: the dependencies.

早在 2003 年进入电信行业之前，我刚成为一名 web 开发者，这是我在成为网络工程师/管理员之后的第二份有薪工作。（我知道，那时的我是个万事通）。我过去使用 PHP 编写代码，我开发过各种各样的应用，从我的雇主使用的小型内部应用，到电视节目的专业投票应用，再到与 VSAT 集线器接口和卫星系统交互的电信应用程序。生活是美好的，除了一个主要的障碍，我相信每个开发人员涉及到：依赖。

> I first code my app on my laptop using something like the LAMP stack, and when it works well, I upload the source code to the servers, be it hosted out on the internet (anyone remember RackShack?) or on private servers for our end-customers. As you can imagine, as soon as I do that, my app is broken and it just won’t work on those servers. The reason, of course, is that the dependencies I use (like Apache, PHP, MySQL, etc.) have different releases than what I used on my laptop. So I have to figure out a way to either upgrade those releases on the remote servers (bad idea) or just re-code what I did on my laptop to match the remote stacks (worse idea). It was a nightmare, and sometimes I hated myself and questioned why I’m doing this for a living.

首先我在我的笔记本电脑上用 LAMP 技术栈编写我的应用程序。当就绪时，我上传源代码到托管在互联网的服务器上（谁还记得 RackShack？）或者我们终端客户的私有服务器上。可以想象，只要我这样做，我的应用程序是不完整的，它就无法在这些服务器上运行。原因当然是我在这些服务器上所使用的依赖环境（如 Apache、PHP、MySQL 等）的版本与我在笔记本电脑上使用的版本不同。因此，我必须想办法升级远程服务器上的这些版本（馊主意），或者只是重新编写我在笔记本电脑上所做的代码，以匹配远程技术栈（更糟糕的办法）。那是一场噩梦，有时我恨自己并质疑我为什么要这么做。

> Fast forward 10 years, and along came a company called Docker. I was a VMware consultant in professional services (2013) when I heard about Docker, and let me tell you that I couldn’t make any sense of that technology back in those days. I kept saying things like: “Why would I run containers when I can do that with VMs?” “Why would I give up important features like vSphere HA, DRS or vMotion for those weird benefits of booting up a container instantly or skipping the “hypervisor” layer?” In short, I was looking at this from a pure infrastructure perspective.

快进10年，随之而来的是一家名为 Docker 的公司。当我听说 Docker 时，我是一名 VMware 专业服务顾问（2013 年）。你有所不知，那时的我对这种技术一无所知。我总是这样说："为什么当我能够使用 VM 时非要运行容器呢？“，"我为什么要放弃重要特性，如 vSphere HA、DRS 或 vMotion，为了快速启动容器或跳过 `虚拟机管理程序`层所带来的好处？”。简而言之，我是从纯粹的基础架构角度来看待这个问题的。

> But then I started looking closer until it just hit me. Everything Docker is all about relates to developers. Only when I started thinking like one did it click. What if I had this technology back in 2003 and packaged my dependencies? My web apps would work no matter what server they run on. Better yet, I don’t have to keep uploading source code or setting up anything special. I can just “package” my app in an image and tell my customer to download that image and run it. That’s a web developer’s dream!

但后来我开始基础容器技术，直到它刚刚冲击到我。Docker 的所有内容都与开发者有关。只有当我开始像一个人一样思考时，它才击中要害。如果我在 2003 年拥有此技术并打包了依赖关系，该怎么办？无论在什么服务器上运行，我的 Web 应用都会工作。更好的是，我不需要继续上传源代码或设置任何特别的东西。我可以在镜像中"打包"我的应用程序，并告诉我的客户下载该镜像并运行它。这是一个 web 开发者的梦想！

> Docker solved a huge issue for interop and packaging, but now what? As an enterprise customer, how can I operate this app at scale? I still want my HA, my DRS, my vMotion and my DR. It solved my developer problems and it created a whole bunch of new ones for my DevOps team. They need a platform to run those containers the same way they used to run VMs.

Docker 解决了交互和打包的一个大问题，但现在怎么办？作为企业客户，我如何大规模操作此应用程序？我仍然想要我的 HA、我的 DRS、我的 vMotion 和我的 DR。它解决了我的开发人员的问题，并为我的 DevOps 团队创建了一大堆新的问题。他们需要一个平台来运行这些容器，就像他们用来运行 VM 一样。

> But then along came Google to tell the world that it has been actually running containers for years (and in fact invented them – Google: cgroups), and that the proper way to do that is through a platform they called Kubernetes. They then open sourced it, gave it as gift to the community, and that changed everything again.

但是后来 Google 告诉世界，他们实际上运行容器很多年了（其实是他们发明的 - Google: cgroups），而这样做的正确方法是通过一个称为 Kubernetes平台，然后他们把 Kubernetes 作为礼物开源给了社区 ，这再次改变了一切。

## Understanding Kubernetes by comparing it to vSphere

## 通过和 vSphere 的比较来理解 Kubernetes

> So what is Kubernetes? Simply put: it is to containers what vSphere was for VMs to make them data center ready. If you used to run VMware Workstation back in the early 2000s, you know that they were not seriously considered for running inside data centers. Kubernetes brings a way to run and operate containers in a production-ready manner. This is why we will start to compare vSphere side-by-side with Kubernetes in order to explain the details of this distributed system and get you up to speed on its features and technologies.

那么什么是 Kubernetes 呢？简单地说：Kubernetes 之于容器就像 vSphere 之于 VM 为 VM 准备好数据中心。如果你曾经在 21 世纪初运行过 VMware 工作站，你知道他们并未认真考虑在数据中心内部运行。Kubernetes 带来了一种以生产可用的方式来运行和操作容器的方法。这就是为什么我们将开始将 vSphere 与 Kubernetes 进行横向比较，以便解释此分布式系统的细节，并让你快速了解 Kubernetes 的特性和技术。

![](https://p.k8s.li/p2p3-1024x375.png)

> Figure: The VM evolution from Workstation to vSphere compared to the current evolution for containers to Kubernetes

图片：从容器到 Kubernetes 的与VM 从 Workstation 到 vSphere 演进的对比

## System Overview

## 系统概览

> Just like vSphere’s vCenter and ESXi hosts, Kuberentes has the concept of master and nodes. In this context, the K8s master is equivalent to vCenter in that it is the management plane of the distributed system. It is also the APIs’ entry point where you interact with your workloads management. Similarly, the K8s nodes act as the compute resources like ESXi hosts. This is where you run your actual workloads (in K8s’ case we call them pods). The nodes could be virtual machines or physical servers. In vSphere’s case, of course, the ESXi hosts have to be physical always.

与 vSphere 的 vCenter 和 ESXi 主机一样，Kuberentes 具有 master 节点和 node 节点的概念。在此处，K8s 中的 master 等效于 vCenter，因为它是分布式系统中的控制平面。也是你在集群中管理工作负载的 API 的入口。同样，K8s 中的节点充当像 ESXi 主机一样的计算资源。这里运行着实际工作负载（在 K8s 的实例中，我们称之为 Pod）。节点可以是虚拟机或物理服务器。当然，在 vSphere 中，ESXi 主机必须是物理机。

![](https://p.k8s.li/kubernetes-system-1024x624.png)

You can see also that K8s has a key-value store called “etcd.” It is similar to vCenter Server DB in that you store the cluster configuration as the desired state you want to adhere to there.

> 你还可以看到 K8s 具有名为"etcd"的数据库来存储键值对。它类似于 vCenter 服务器 DB，将群集配置存储为你期望的期望状态。

> On the differences side, K8s master can also run workloads, but vCenter cannot. The latter is just a virtual appliance dedicated to management. In K8s master case, it’s still considered a compute resource, but it’s not a good idea to run enterprise apps on it. Only system related apps would be fine.

不同的是，K8s master 节点也可以运行工作负载，但 vCenter 不能运行。后者只是专用于管理的虚拟机。在 K8s master 节点，它仍然被视为计算资源，但并不建议用来运行企业应用。 master 节点只适合运行与 kubernetes 系统相关的应用。

> So, how does this look in the real world? You will mainly use CLI to interact with this system (GUI is also a viable option). In the screenshot below, you can see that I am using a Windows machine to connect to my Kubernetes cluster via command like (I am using cmder in case you are wondering). We see in the screenshot that I have one master and 4 x nodes. They run K8s v1.6.5, and the nodes operating system is Ubuntu 16.04. At the time of this writing, we are mainly living in a Linux world where your master and nodes are always based on Linux distributions.

那么，在现实世界中是怎样的呢？你将主要使用 CLI 与此系统进行交互（GUI 也是一个可行的选项）。在下面的截图中，你可以看到我在 Windows 计算机上使用类似的命令（使用的是 cmder）连接到我的 Kubernetes 群集。我们在截图中看到，我有一个 master 节点和 4 个 node 节点。集群运行 K8s v1.6.5，节点操作系统为 Ubuntu 16.04。在撰写本文时，我们主要生活在 Linux 世界中，master 节点和 node 节点始终基于 Linux 发行版。

![](https://p.k8s.li/clidash-1024x563.png)

## Workloads Form-factor

## 工作负载

> In vSphere, a virtual machine is the logical boundary of an operating system. In Kubernetes, pods are the boundaries for containers. Just like an ESXi host that can run multiple VMs, a K8s node can run multiple pods. Each Pod gets a routed IP address just like VMs to communicate with other pods.

在 vSphere 中，虚拟机是操作系统的逻辑边界。而在 Kubernetes ，pods 是容器的边界。与可以运行多个 VM 的 ESXi 主机一样，K8s 节点可以运行多个 Pod。每个 Pod 获取路由 IP 地址，就像 VM 一样与其他 Pod 进行通信。

> In vSphere, applications run inside OS. In Kubernetes, applications run inside containers. A VM can run one single OS, while a Pod can run multiple containers.

在 vSphere 中，应用程序在操作系统内运行。而在 Kubernetes 中，应用程序在容器内运行。VM 可以运行单个操作系统，而 Pod 却可以运行多个容器。

![](https://p.k8s.li/kubernetes-pods-1024x486.png)

> This is how you can list the pods inside a K8s cluster using the kubectl tool from the CLI. You can check the health of the pods, the age, the IP addresses and the nodes they are currently running inside.

这是使用 CLI 中的 kubectl 工具列出 K8s 群集中的 Pod 的方式。你可以检查 Pod 的运行状况、创建时间、IP 地址以及它们当前运行在哪个节点。

![](https://p.k8s.li/cli2-1024x450.png)

## Management

## 管理

> So how do we manage our master, nodes and pods? In vSphere, we use the Web Client to manage most (if not all) the components in our virtual infrastructure. This is almost the same with Kubernetes with the use of the Dashboard. It is a nice GUI-based web portal where you can access your browser similarly to  Web Client. We’ve also seen in the previous sections that you can manage your K8s cluster using the kubectl command from the CLI. It’s always debatable where you will spend most of your time — the CLI or the Dashboard, especially because the latter is becoming more powerful every day (check [this video](https://www.youtube.com/watch?v=3lhf7T9Bp2E) for more details). I personally find the Dashboard very convenient for quickly monitoring the health or showing the details of the various K8s components rather than typing long commands. It’s a preference, and you will find the balance between them naturally.

那么，我们如何管理主机、节点和 Pod 呢？在 vSphere 中，我们使用 Web 客户端来管理虚拟化基础架构中的大多数（如果不是全部）组件。这和在 Kubernetes 使用仪表盘一样。这是一个通过浏览器访问、基于 GUI 、类似于 web 客户端的门户网站。我们在前几节中还看到，你可以使用  kubectl 命令来管理 K8s 群集。你总是在大部分时间里花在哪里——CLI 或仪表盘，特别是因为后者每天都在变得更强大（请查看[此视频](https://www.youtube.com/watch?v3lhf7T9Bp2E)，了解更多详情）。我个人认为仪表盘非常方便，可以快速查看运行状况或显示各种 k8s 组件的详细信息，而不是输入很长的命令。这是个人喜好，你会自然地在两者之间找到平衡。

![](https://p.k8s.li/kubernetes-management-1024x469.png)

## Configurations

## 配置

> One of the very profound concepts in Kubernetes is the desired state of configurations. You declare what you want for almost any Kubernetes component through a YAML file, and you create that using your kubectl (or through dashboard) as your desired state. Kubernetes will always strive from this moment on to keep that as a running state in your environment. For example, if you want to have four replicas of one pod, K8s will keep monitoring those pods. If one dies or the nodes it’s running have issues, it will self-heal and automatically create that pod somewhere else.

Kubernetes 中非常重要的概念之一是所描述的配置状态。通过 YAML 文件几乎可以声明任何 Kubernetes 组件所需的资源，并使用 kubectl 命令（或通过仪表盘）创建该对象作为所描述的状态。从创建后开始，在你的集群中Kubernetes 始终会努力将保持为所描述的运行状态。例如，如果要有一个 pod 的四个副本，K8s 将继续监视这些pod。如果一个 pod 挂掉或它正在运行的节点有问题，它将自我修复，并自动在其他节点创建该 pod 。

> Back to our YAML configuration files — you can think of them like a .VMX file for a VM, or a .OVF descriptor for a virtual appliance that you want to deploy in vSphere. Those files define the configuration of the workload/component you want to run. Unlike VMX/OVF files that are exclusive to VMs/Appliances, the YAML configuration files are used to define any K8s component like ReplicaSets, Services, Deployments, etc. as we will see in the coming sections.

回到我们的 YAML 配置文件 — 你可以将它们想象成 一个描述 VM 或 的 .VMX 文件或者在 vSphere 中部署虚拟设备所需的 .OVF 描述符文件。这些文件定义要运行的工作负载/组件的配置。与 VMX/OVF 文件是 VM/设备独有的不同的是，YAML 配置文件用于定义任何 K8s 组件，如 ReplicaSets、Services、 Deployments 等，我们将在下一节中讨论。

![](https://p.k8s.li/kubernetes-confiugrations-1024x511.png)

## Virtual Clusters

## 虚拟化集群

In vSphere, we have physical ESXi hosts grouped logically to form clusters. We can slice those clusters into other virtual clusters called “Resource Pools.” Those resource pools are mostly used for capping resources. In Kubernetes, we have something very similar. We call them “namespaces,” and they could also be used to ensure resource quotas as we will see in the next section. They are most commonly used, however, as a means of multi-tenancy across applications (or users if you are using shared K8s clusters). This is also one of the ways  we can perform security segmentation with NSX-T across those namespaces as we will see in future posts.

在 vSphere 中，我们将 ESXi 物理机逻辑分组以形成群集。我们可以将这些群集分割成其他虚拟化群集，称为"资源池"。这些资源池主要用于限制资源。在 Kubernetes 中，我们有一些非常相似的东西。我们称之为"命名空间"，它们还可用于确保资源配额，我们将在下一节中看到。但是，它们最常用作跨应用程序（或者使用共享 K8s 群集的用户）的多租户方法。这也是我们可以在这些命名空间使用 NSX-T 执行安全分段的方法之一，我们将在以后的帖子中看到。

![](https://p.k8s.li/kubernetes-namespaces-1024x651.png)

## Resource Management

## 资源管理

> As I mentioned in the previous section, namespaces in Kubernetes are commonly used as a means of segmentation. The other use case for it is resource allocation, and it is referred to as “Resource Quotas.” As we saw in previous sections, the definition of that is through YAML configuration files where we declare the desirted state. In vSphere, we similarly define this from the Resource Pools settings as you see in the screenshot below.

正如我在上一节中提到的那样，Kubernetes 中通常用命名空间来进行划分。它的另一个用途是资源分配，称之为"资源配额"。正如我们在前面各节中所看到的，它的定义是通过 YAML 配置文件来声明期所望的状态。在 vSphere 中，我们同样从资源池设置中定义这一点，如下图所示。

![](https://p.k8s.li/kubernetes-resource-quotas.png)

## Workloads Identification

## 标记工作负载

> This is fairly easy and almost identical between vSphere and Kubernetes. In the former, we use the concepts of tags to identify or group similar workloads, while in the latter we use the term “labels” to do this. In Kubernetes’ case, this is mandatory where we use things like “selectors” to identify our containers and apply the different configurations for them.

标记工作负载相当容易且 vSphere 和 Kubernetes 几乎一样。在 vSphere 中，我们使用 tags 的概念来识别或分组相似的工作负载，而在 Kubernetes 中，我们使用术语"labels"来执行此操作。在 Kubernetes 的案例中，我们强制使用"选择器"之类来识别我们的容器并为其应用不同的配置。

![](https://p.k8s.li/kubernetes-labels-1024x331.png)

## Redundancy

## 冗余

> Now to the real fun. If you were/are a big fan of vSphere FT like me, you will love this feature in Kubernetes despite some differences in the two technologies. In vSphere, this is a VM with a running instance and a shadow one in a lock-step. We record the instructions from the running instance and replay it in the shadow VM. If the running instance goes down, the shadow VM kicks in immediately. vSphere then tries to find another ESXi host to bring another shadow instance to maintain the same redundancy. In Kubernetes, we have something very similar here. The ReplicaSets are a number you specify to run multiple instances of a pod. If one pod goes down, the other instances are available to serve the traffic. In the same time, K8s will try to bring up a substitute for that pod on any available node to maintain the desired state of the configuration. The major difference, as you may have already noticed, is that in the case of K8s, the pod instances are always live and service traffic. They are not shadowed workloads.

精彩现在开始。如果你和我一样热衷于 vSphere FT，在 Kubernetes 中你会喜欢这个特性，尽管这两个技术有一些差异。在 vSphere 中，vSphere FT 是一个具有正在运行的 VM 影子实例 。我们记录正在运行的实例中的指令，并在卷影 VM 中重新执行它。如果正在运行的实例出现故障，则卷影 VM 会立即启动。然后，vSphere 会尝试寻找另一台 ESXi 主机，来导入另一个卷影 VM 实例以维护相同的冗余。在 Kubernetes 中也有类似的特性。副本集用来运行指定的数量 pod 的实例。如果一个 pod 出现故障，则其他 pod 实例可继续对外流量提服务。与此同时，K8s 将尝试将该 pod 调度到任何可用节点上，以维持配置文件所描述的状态。你可能已经注意到，主要区别是，在 K8s 中，pod 实例始终是存活状态并对外提供服务，它们并不是隐藏的工作负载。

![](https://p.k8s.li/kuberentes-replicasets-1024x546.png)

## Load Balancing

## 负载均衡

> While this might not be a built-in feature in vSphere, it is still a common thing to run load-balancers on that platform. In the vSphere world, we have either virtual or physical load-balancers to distribute the network traffic across multiple VMs. This could be running in many different configuration modes, but let’s assume here that we are referring to the one-armed configuration. In this case, you are load-balancing your network traffic east-west to your VMs.

虽然负载均衡可能不是 vSphere 中的内置功能，但在该平台上运行负载均衡器很普遍。在 vSphere 中，我们有虚拟或物理负载均衡器，用于在多个 VM 之间均衡网络流量。这可能在许多不同的配置模式下运行，但让我们在这里假设我们指的是单兵配置。在这种情况下，你将从东到西到 VM 的网络流量进行负载平衡。

> Similarly in Kubernetes, we have the concepts of “Services.” A K8s Service could also be used in different configuration modes, but let’s pick the “ClusterIP” configuration here to compare to the one-armed LB. In this case, our K8s Service will have a virtual IP (VIP) that is always static and does not change. This VIP will distribute the traffic across multiple pods. This is especially important in the Kubernetes world were pods are ephemeral by nature and where you lose the pod IP address the moment it dies or gets deleted. So you have to always be able to maintain a static VIP.

同样，在 Kubernetes 中，我们有"服务"的概念。K8s 服务，但让我们在这里选择"ClusterIP"配置，以便与单臂 LB 进行比较。在这种情况下，我们的 K8s 服务将有一个始终静态且不会更改的虚拟 IP （VIP）。此 VIP 将在多个 Pod 上分配流量。这一点在 Kubernetes 世界尤其重要，因为吊舱本质上是短暂的，当你死或被删除的时候，你失去了 pod IP地址。因此，你必须始终能够维护静态 VIP。

> As I mentioned, the Services have many other configurations like “NodePort,” where you basically assign a port on the node level and then do a port-address-translation down to the pods. There is also the “LoadBalancer,” where you spin up an LB instance from a 3rd-party or a cloud provider.

正如我提到的， Services 具有许多其他配置，如"NodePort"，其中你基本上在节点级别上分配一个端口，然后向下到 Pod 执行端口地址转换。还有"LoadBalancer"，从第三方或云提供商启动 LB 实例。

![](https://p.k8s.li/kubernetes-services-1024x389.png)

> There is another very important load-balancing mechanism in Kuberentes called “Ingress Controller.” You can think of this like an in-line application load-balancer. The core concept behind this is that an ingress-controller (in a form of pod) would be spun up with an externally visible IP address, and that IP could have something like a wild card DNS record. When traffic hits an ingress-controller using the external IP, it will inspect the headers and determine through a set of rules you pre-define to which pod that hostname should belong. Example: _sphinx-v1_.esxcloud.net will be directed to the service “sphinx-svc-1”, while the _sphinx-v2_.esxcloud.net will be directed to the service “sphinx-svc2” and so on and so forth.

在 Kuberentes 中还有另一个非常重要的负载均衡机制，称之为" Ingress 控制器"。你可以把它当作一个在线应用负载均衡器。The core concept behind this is that an ingress-controller (in a form of pod) would be spun up with an externally visible IP address, and that IP could have something like a wild card DNS record. 当流量使用 external IP 进入 ingress 控制器时，它将检查请求头部并通过主机名来判断流量应属于哪个一组 pod 。示例：_sphinx-v1_.esxcloud.net 将定向到服务"sphinx-svc-1"，而 _sphinx-v2_.esxcloud.net 将重定向到服务"sphinx-svc2"等。

![](https://p.k8s.li/kubernetes-ingress-1024x532.png)

## Storage & Networking

## 存储和网络

> Storage and networking are rich topics when it comes to Kubernetes. It is almost impossible to talk briefly about these two topics in an introduction blog post, but you can be sure that I will be blogging in details soon about the different concepts and options for each subject. For now, let’s quickly examine how the networking stack works in Kubernetes since we will have a dependency on it in a later section.

当谈到到 Kubernetes 时，存储和网络是重点关注的话题。在介绍性的博客文章中简要地谈论这两个主题几乎是不可能的，但你可以肯定，我将很快在博客上详细介绍每个主题的不同概念和特性。现在，让我们快速研究一下网络堆栈在 Kubernetes 中是如何工作的，因为我们将在后面的一节中依赖于它。

> Kubernetes has different networking “plugins” that you can use to set up your nodes and pods network. One of the common plugins is “kubenet,” which is currently used on mega-clouds like Google Cloud Provider (GCP) and Amazon Web Services. I am going to talk briefly here about the GCP implementation and then show you a practical example later to examine this yourself on Google Container Engine (GKE).

Kubernetes 具有不同的网络"插件"，你可以使用这些插件来设置节点和 Pod 网络。常见的插件之一是"kubenet"，它目前用于像谷歌云提供商（GCP）和亚马逊网络服务这样的云服务商巨头。我将在这里简要地谈谈 GCP 的实现，然后向你展示一个可以在谷歌容器引擎（GKE）上亲自研究的实例。

![](https://p.k8s.li/gke-kubernetes-networking-1024x747.png)

> This might be a bit too much to take in from a first glance, but hopefully you will be able to make sense of all that by the end of this blog post. First, we see that we have two Kubernetes nodes here: node 1 and node (m). Each node has an eth0 interface like any Linux machine, and that interface has an IP address to the external world—in our case here on subnet 10.140.0.0/24. The upstream L3 device is acting as our default gateway to route our traffic. This could be a L3 switch in your data center or a VPC router in a public cloud like GCP as we will see later. So far so good?

乍一看，这也许有点太过分了，但希望你能在博客文章的结尾理解这一切。首先，我们看到我们这里有两个 Kubernetes 节点：节点 1 和节点 （m）。每个节点都像其他 Linux 机器一样具有 eth0 接口，并且该接口具有 10.140.0.0/24 子网内的 IP 地址。上游 L3 设备充当我们的默认网关，用于路由我们的流量。这可能是数据中心中的 L3 交换机，也可以是公共云中的 VPC 路由器（如 GCP），我们稍后将对此进行介绍。目前为止，还可以理解吗？

> Next, we see inside the node that we have a **cbr0** bridge interface. That interface has the default gateway of an IP subnet—10.40.1.0/24 in case of node 1. This subnet gets assigned by Kubernetes to each node. The latter usually get a /24 subnet, but you can control that in case of NSX-T as we will see in future posts. For now, this subnet is the one that we will allocate the pod’s IP addresses from. Any pod inside node 1 will get an IP address from this subnet rage—in our case here, Pod 1 has an IP address of 10.40.1.10. Notice however that this pod has two nested containers within. Remember, a pod can run one or more containers that are tightly coupled together in terms of functionality. This is what we see here. Container 1 is listening to port 80, while container 2 is listening to port 90. Both containers share the same IP address of 10.40.1.10. but they do not own that networking namespace. Alright, so who owns this networking stack then? It’s actually a special container that we call the “Pause Container.” You see it in the diagram as the interface of that pod to the outer world. It owns this networking stack, including the IP address 10.40.1.10 and, of course, it forwards the traffic to container 1 using port 80 and traffic to container 2 using port 90.

接下来，我们看到在节点内，有一个 `cbr0` 网桥接口。该接口具有 IP 子网的默认网关 —在节点 1 的情况下—：10.40.1.0/24。此子网由 Kubernetes 分配给每个节点。后者通常得到一个 24 位的子网，但你可以控制在 NSX-T 的情况下，我们将在以后的帖子中看到。现在，此子网是我们将从中分配 Pod 的 IP 地址的子网。节点 1 内的任何 pod 都将从此子网中获得 IP 地址， 在我们的实例中，Pod 1 的 IP 地址为 10.40.1.10。但请注意，此 pod 内有两个容器。请记住，pod 可以运行一个或多个在功能方面紧密相关的容器。这就是我们在这里看到的。容器 1 监听端口 80，而容器 2 监听端口 90。两个容器共享同一个 IP 地址 10.40.1.10。但他们并不独自拥有网络命名空间。好吧，那么谁拥有这个网络堆栈呢？它实际上是一个特殊容器，我们称之为" puse 容器"。在图中，你将其视为该 pod 与外部世界的接口。它拥有此网络堆栈，包括 IP 地址 10.40.1.10，当然，它使用端口 80 将流量转发到容器 1，使用端口 90 将流量转发到容器 2。

> Now you should be asking, how is traffic forwarded to the external world? You see that we have a standard Linux IP forwarding enabled here to forward the traffic from cbr0 to eth0. This is great, but then how does the L3 device know how to forward this to the destination? We do not have dynamic routing here to advertise this network in this particular example. And so, this is why we need to have some kind of “static route” on that L3 device to know that in order to reach subnet 10.40.1.0/24, your entry point is the external IP of node 1 (10.140.0.11), and in order to reach subnet 10.40.2.0/24, your next hope is node (m) with the IP address 10.140.0.12.

现在你可能会问，流量是如何转发到集群外的呢？你看，我们在此启用了标准的 Linux IP 转发功能，将流量从 cbr0 转发到 eth0。这是非常棒的，但然后 L3 设备如何知道如何转发到目的地？在此特定示例中，我们没有动态路由来通告此网络。因此，这就是为什么我们需要有某种"静态路由"在 L3 设备上知道，为了达到子网10.40.1.0/24，你的入口点是节点1（10.140.0.11）的外部IP，并为了达到子网10.40.2.0/24，你的下一跳（m） 与 IP 地址 10.140.0.12。

> This is great, but you must be thinking that it’s a very unpractical way to manage your networks. This would be an absolute nightmare for network administrators to maintain all those routes as you scale with your cluster. And you’re right—this is why we need some kind of solution like the CNI (container network plugin) in Kubernetes to use a networking mechanism to manage this for you. NSX-T is one of those solutions with a powerful design for both the networking and security stacks.

这太好了，但你一定认为，这是一个非常不实际的方式来管理你的网络。对于网络管理员来说，在与群集进行扩展时维护所有这些路由绝对是一场噩梦。你说得对，这就是为什么我们需要某种解决方案，如 Kubernetes 中的CNI（容器网络插件），以使用网络机制为你管理。NSX-T 是这些解决方案之一，具有强大的网络和安全堆栈设计。

> Remember, we are examining here the kubernetes plugin, not CNI. The former is what GKE uses, and the way they do this is quite fascinating as it’s completely programmable and automated on their cloud. Those subnet allocations and associated routes are taken care of by GCP for you, as we will see in the next part.

请记住，我们正在测试 kubernetes 插件而不是CNI。前者是 GKE 使用的，他们这样做的方式是相当棒的，因为它是完全可编程和自动化的云。这些子网分配和相关路由由 GCP 为你负责，我们将在下一部分中看到。
