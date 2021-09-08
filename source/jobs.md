---
title: 求职贴：运维开发｜SRE
date: 2021-09-08
updated: 2021-09-08
slug:
categories:
tag:
copyright: true
comment: true
---

最近开始准备找工作和面试，奈何一直想去的那家公司没有 HC，再加上 10 月国庆回来之后房租就要到期，要在国庆放假前决定去哪个城市。所以最近有点焦虑担心国庆前拿到自己心仪的 offer 有一定的风险，因此就发篇求职贴，如贵司还需要我这样的运维开发或 SRE 不妨看下如何 😂。

![](https://p.k8s.li/2021-09-08-jobs-01.png)

## 个人经历

2019 年本科毕业，毕业之后去了一家国企工作，做传统的机房运维和公司的业务容器化转型上 K8s 的事情。在国企里面 955 的日子过得确实比较舒服，但考虑到技术氛围以及长期的发展，最终还是在去年 5 月份离职来到了杭州，入职了一家做 PaaS toB 产品的公司。不幸的是入职不久后公司又被字节跳动给收购了，从那之后就开始被迫跳动到今年的 7 月底离职。至于离职的原因主要是薪资和职级不太满意，想换个环境心安理得地拿一份与自己能力相匹配的薪水，其他同事离职大多也是因为这个原因。

离职这段时间一直在家休息，看书和学习。虽然毕业已经两年了，但仍有很多想要学习和了解的知识，不仅仅是技术这一层面，在其他领域比如古生物学、演化生物学这些自己一直都很想了解，这段时间看了大量的书籍和科普纪录片，增加了很多没用的知识。人总不能为了赚钱而活，多少有点属于自己的空间，满足自己的求知欲和好奇心，这样生活才能充满乐趣。

当然这段时间也没白闲着，花了两周左右的时间完成了两个开源项目：一个是用于构建 yum/apt/dnf 离线源的工具 [k8sli/os-packages](https://github.com/k8sli/os-packages) ，以及无网环境中离线部署 k8s 的工具  [k8sli/kubeplay](https://github.com/k8sli/kubeplay) 。

## 工作经历

离职前在字节跳动负责的工作事项偏向于运维开发或SRE：

### 版本发布

这块主要是负责 PaaS toB 产品 ([Compass](https://www.volcengine.com/product/compass) 和 [Clever](https://www.volcengine.com/product/clever)) 的版本发布工作。在开发团队规模较小的场景下这块其实并不太重要，几个开发搞一搞就完事儿了。但等到产品功能越来越复杂、所涉及的代码仓库越来越多、开发人员越来越多的时候，就需要有一套标准的版本发布流程和一些公共事务规范去协调这部分的工作了。我就是负责这块内容的，要和 RD、PM、PD、QA 各个角色的负责人对接以及各种无厘头的扯皮，总结起来三个字**事儿多**。其实这部分工作内容和 PingCAP 曾提到的 [Behind TiDB 5.0 - 聊聊 PingCAP 的工程体系](https://pingcap.com/zh/blog/behind-tidb-5.0-engineering-system-of-pingcap-1) 有相似之处。之前我也写过一篇博客 [云原生 PaaS 产品发布&部署方案](https://blog.k8s.li/pass-platform-release.html)，感兴趣的可以读一下。

### 运维部署

主要是负责开发平台底层 K8s 集群部署工具以及平台组件部署工具。有点类似于 Kubesphere 中负责集群部署的 [kubekey](https://github.com/kubesphere/kubekey) 和负责平台组件部署的 [ks-installer](https://github.com/kubesphere/ks-installer) 。不同于 ks-installer 为每个平台组件单独写一些 ansible 的 playbook 来完成平台组件部署，我们的平台组件部署工具是使用 helm chart 统一部署的。这样维护起来也更加方便，因为所有的平台组件部署都是 helm chart，这样版本发布、自动化打包以及后续的部署，这一整套都能统一在一起，维护的成本也比低。这部分内容可参考我写的博客：

-  [云原生 PaaS 产品发布&部署方案](https://blog.k8s.li/pass-platform-release.html)
- [万字长文详解 PaaS toB 场景下 K8s 离线部署方案](https://blog.k8s.li/pass-tob-k8s-offline-deploy.html)
- [使用 GitHub Actions 编译 kubernetes 组件](https://blog.k8s.li/build-k8s-binary-by-github-actions.html)
- [使用 kubeplay 来离线部署 kubernetes 集群](https://blog.k8s.li/deploy-k8s-by-kubeplay.html)
- [kubespray 部署常见问题和优化汇总](https://blog.k8s.li/kubespray-tips.html)
- [使用 Kubespray 本地开发测试部署 kubernetes 集群](https://blog.k8s.li/deploy-k8s-by-kubespray.html)

### 发布流水线

不同于传统的发布流水线，toB 产品的发布流水线主要是完成离线安装包的打包，然后前线运维使用这个安装包在客户环境中进行实施部署。从去年入职到今年 7 月底离职这段时间，不断地对产品的发布流水线进行打磨和优化，到我离职时基本上所有的代码都完全重构了，发布效率和性能也得到了质的提升。尤其是 [overlay2 在打包发布流水线中的应用](https://blog.k8s.li/overlay2-on-package-pipline.html) 中提到使用 overlay2 这种独特的方案，硬是将镜像同步的性能提升了 15 倍，在那段时间也学到了特别多的东西，收获颇丰。这部分内容可以参考我之前写的博客：

- [镜像搬运工 skopeo](https://blog.k8s.li/skopeo.html)
- [什么？发布流水线中镜像“同步”速度又提升了 15 倍 ！](https://blog.k8s.li/select-registry-images.html)
- [如何使用 registry 存储的特性](https://blog.k8s.li/skopeo-to-registry.html)
- [overlay2 在打包发布流水线中的应用](https://blog.k8s.li/overlay2-on-package-pipline.html)
- [docker registry 迁移至 harbor](https://blog.k8s.li/docker-registry-to-harbor.html)

### On-call 技术支持

这部分就是一些前线运维的 On-call 技术支持了，一般客户不会直接找到产品研发，而是通过前线运维实施的人员来找我们解决问题的。在这期间就自己维护这一个产品的运维部署 QA 文档，将产品以及有关 K8s 方面的问题大致地梳理总结了一下。如果其他同事或前线运维实施人员遇到同样的问题，在飞书上搜索就能检索到，也能帮助一下别人吧。这基本上都是我自己一个人维护的，之前我就一直很纳闷为什么没有这种文档，产品这么多问题也不梳理总结一下 😤，只有我来了之后才有这种文档，不过离职后有没有人在继续维护就不得而知了。

总之，个人在工作上还算用心吧，一些总结和梳理工作都是自己默默完成的（虽然 OKR 或者绩效评估时这些也无法体现出来）。有时候为了验证一个想法或方案也常常半夜一两点从床上爬起来到电脑桌旁一顿 xjb 搞。

----

之前在看 [PingCAP 招聘](https://careers.pingcap.com/) 的职位时就发现一些职位和自己做的十分相似，自己所负责的工作事项在 PingCAP 都有单独的职位：比如负责平台组件部署的[自动化运维研发工程师](https://careers.pingcap.com/apply/pingcap/39950/#/job/8319a481-94cf-44f0-97b4-2d42d7b22bbe)；负责产品版本发布的 [Release Manager](https://careers.pingcap.com/apply/pingcap/39950/#/job/a890aa70-d280-42aa-bfe0-d355cde3cc77)；负责组件 CI/CD 自动化流水线的 [Site Reliability Engineer](https://careers.pingcap.com/apply/pingcap/39950/#/job/5b9e8422-fc61-42cb-b291-1576da224c88)；负责 On-call 的 [售后技术支持](https://careers.pingcap.com/apply/pingcap/39950/#/job/5e8f330e-8326-48b5-b8c7-b2ebdd71028c)；

突然意识到自己一个人完成四种职能的工作 😂，可能是因为我们的产品还不算太复杂，没有 PingCAP 规模那么大，做的内容也没有那么精细，所以自己一个人 take 起来这些工作事项也没问题。这还不是因为年初的时候组织架构大调整导致之前的业务小组解散，整个小组遗留的工作都落在了我一个人身上，所以就一个人干完了这么多人做的事儿。想想自己一个人能 take 起来四个人的活儿，拿那么点的薪资就可气😡，不离职才怪。

----



## 技术能力

- 大学时就喜欢玩 Linux ，接触一些开源社区向大佬们学习。常见的 Linux 发行版如 CentOS、Ubuntu、Debian 基本的运维管理掌握的还算可以，日常的开发测试都在这些发行版上搞，也在这些发行版上是适配过 K8s 部署。一些常见的自动化运维工具如 Ansible、Terraform 等自己都是日常使用，掌握的还行。
- 对 IaaS 虚拟化有些了解，日常使用 ESXi 作为 NAS 主机 OS ，上面开了一些虚拟机跑了一些服务；使用 Proxmox VE/KVM 作为开发测试环境，qemu 和 cloud-init 管理虚拟机那是真香。

-  深入研究过容器镜像构建、存储、分发的流程和原理，并将其应用在产品的打包发布流水线中以提升产品发布效率。
-  熟悉云原生 PaaS ToB 产品版本发布和私有化交付全流程； 曾为近 20 个客户主导完成 50 多个 OEM 定制化补丁包版本发布，拥有一定的 ToB 项目管理经验； 能够推动并落地一些提升产品研发效率的公共事务规范，解决产品私有化交付过程中的遇到的痛点。

-  掌握了 Python、Shell、Ansible 编程，给 kubernetes 社区的 kubespray 项目贡献过十几个 [PR](https://github.com/kubernetes-sigs/kubespray/pulls?q=is%3Apr+author%3Amuzi502+is%3Aclosed)。
- 至于 Golang 目前还在学习中，算是掌握了一些基本的语法和数据结构。年初的时候写过一个 CLI 工具，使用 [go-gitlab](https://github.com/xanzy/go-gitlab) 库进行 CRUD 操作，从 Gitlab  repo 中获某个 tag 下的一些特定目录下的文件。当时体会到了写 Go 的乐趣，不过后来因为工作的原因很少会用 Go 写代码，基本上都是自己慢慢摸索着学。
- 能够使用 Jenkins、Gitlab CI、GitHub Actions 等工具为平台组件及产品构建 CI/CD 流水线、私有化打包发布流水线。
-  拥有腾讯云、GCP、AWS、Oracle 等云服务器，具备高速稳定的科学上网环境； 业余喜欢折腾 NAS 存储、虚拟化、OpenWrt 软路由。
- 文档写作能力还行，最近几个月一直坚持每月写至少两篇博客，之前在字节的时候也是负责撰写产品的各种文档，如安装手册、运维手册、实施方案、QA 文档等。
- 业余时间喜欢阅读大佬们的技术博客、收藏博客文章；自己也时常写博客，并以 [k8s.li](https://k8s.li/) 作为个人域名（日均 1.3K UV）；在云原生实验室、K8sMeetup、CNCF 等公众号投稿过至少 12 篇个人原创技术文章。
- 对技术一直保持着好奇心和求知欲，经常参加过一些像 CNCF、Rancher、青云 kubesphere 等社区举办的活动，向大佬们学习经验。

## 个人作品

-  [k8sli/kubeplay](https://github.com/k8sli/kubeplay)：无网环境中 K8s 离线部署的工具
- [registry-mirrors](https://github.com/muzi502/registry-mirrors)：使用 GitHub actions 自动同步镜像的工具
- [k8sli/os-packages](https://github.com/k8sli/os-packages)：yum/dnf/apt 离线源自动化构建工具 
- [tg.k8s.li](https://tg.k8s.li/)：Kubernetes 相关 RSS 频道，订阅人数 1300+，欢迎小伙伴们加入：）
- [kindle](https://github.com/muzi502/kindle) ：将 Kindle 上 `.txt` 格式的标注文本转换成 `.html` 的 Python 脚本

## 其他

### 匹配职位

偏向于 K8s 方向上的运维开发或SRE，以下是我个人认为一些与自己的能力和兴趣比较匹配的 JD

- 百度的 [ACG通用技术服务部_DOP 运维交付研发工程师](https://talent.baidu.com/external/baidu/index.html#/jobDetail/2/182608)

> - 职责要求:
>
> -计算机或者相关专业，本科及以上学历，2-3年以上相关行业工作经验，交付运维相关经验
>
> -熟悉kubernetes、docker的常用操作，对docker的网络、存储、安全有深入的理解
>
> -熟悉kubernetes、docker的网络解决方案，熟悉flannel、calico等开源网络组件优先
>
> -熟悉kubernetes、docker的存储解决方案，数据持久化，高可用，安全等
>
> -熟悉kubernetes的原理和使用
>
> -熟悉至少一门脚本语言（shell/python均可），具备底层脚本开发能力
>
> -熟悉当前热门的容器生态核心开源项目，如Docker、Kubernetes、Etcd等，能对它们-进行二次开发
>
> -熟悉Docker/Kubernetes等周边Service生态项目，如监控、日志、网络等方案，精通或者有实施经验者加分
>
> -DevOps背景，开源项目贡献维护经历加分

- 青云的 [容器解决方案工程师](https://kubesphere.com.cn/forum/d/1666-kubesphere-qingcloud/9)

> - 职位描述
>
> 开发和整合青云容器产品线以及相关合作伙伴应用或者产品，形成具有复制性的可落地的解决方案
>
> - 职位要求
>
> 熟悉 Linux、docker、Kubernetes
> 有 Kubernetes、helm 使用经验
> 了解 Kubernetes 网络及存储
> 熟练使用 shell、ansible，具备脚本开发能力，并至少熟悉其它一种编程语言（python/go）
> 学习能力强，具备独立解决问题的能力
> 优秀的团队合作和沟通能力
>
> - 加分项：
>
> 有网站开发经验，熟悉至少一种开发框架，如Spring MVC、Django 等
> 良好的英文书写和沟通能力
> 有开源社区经验或贡献
> 有云原生相关开源项目的运维和开发经验
> 熟悉 DevOps 流程，关注开源 CI/CD 技术工具
> CKA 证书

- PingCAP 的 [自动化运维研发工程师](https://careers.pingcap.com/apply/pingcap/39950/#/job/8319a481-94cf-44f0-97b4-2d42d7b22bbe) 以及 [SRE](https://careers.pingcap.com/apply/pingcap/39950/#/job/5b9e8422-fc61-42cb-b291-1576da224c88)

> **工作职责:**
>
> 1. 基于 CI/CD 构建自动化测试和发版系统，提高研发和发版效率；
> 2. 管理和维护 TiDB Cloud 基础设施，参与线上值班，确保复杂系统能够稳定地运行；
> 3. 进行稳定性测试和故障恢复测试，从而提高整体的故障恢复能力。
>
> **任职资格:**
>
> 1. 具有丰富的大型分布式系统运维经验，包括对分布式系统的分析、监控及故障排查；
> 2. 熟悉公有云（AWS，GCP，Azure），了解公有云最佳实践；
> 3. 熟悉 Prometheus，Grafana 等监控工具；
> 4. 熟悉 Terraform，AWS-CDK，Pulumi 等 Infra as Code 工具；
> 5. 熟悉常用 CI/CD 工具；
> 6. 熟悉 kubernetes 的原理和运维；
> 7. 较强的学习能力；
> 8. 结果导向，良好的沟通能力。

### 工作城市

期望的工作地区最好是杭州或上海；full remote 也可以哇；深圳/广州/成都因为搬家不方便我会考虑下；北京实在不想去，感觉在那儿生活不太习惯；其他城市看情况。

### 联系方式

- **Blog** 🏠 [blog.k8s.li](https://blog.k8s.li/)
- **Email** 📧 [muzi502.li@gmail.com](mailto:muzi502.li@@gmail.com)
- **Twitter** 🕊 [muzi_ii](https://twitter.com/muzi_ii)
- **GitHub** 🕸 [muzi502](https://github.com/muzi502)
- **Telegram** ☎️ [muzi_ii](https://telegram.me/muzi_ii)

最好能先提供一下贵司官网或者其他招聘网站上的 JD 链接，我需要看一下自己是否能符合要求，如果合适的话就将简历发送到大佬您的邮箱（最好是公司的域名邮箱）。

