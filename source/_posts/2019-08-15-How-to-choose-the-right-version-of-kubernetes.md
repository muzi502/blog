---
title: 生产环境如何保守地选择 kubernetes 版本
date: 2019-08-15
updated: 2020-03-01
categories: 技术
slug:  How-to-choose-the-right-version-of-kubernetes
tag:
  - kubernetes
copyright: true
comment: true
---

## 0. 要开始了？

听说汝公司准备或者正在使用 kubernetes 容器调度平台了？那么对于一些及其重要的线上环境，如何选择一个合适的 kubernetes 版本呢？Kubernetes 版本号最循着 x.y.z 的命名规范，相信大家肯定不会拿 1.15.0 这样的版本用于生产环境吧😂。如何选择一个稳定的版本号最好的方法就是参考各大云计算厂商(Google、AWS digitalocean)。他们提供 kubernetes 云平台，稳定性一般要高于我们平时的生产环境。他们如何选择 kubernetes 版本是个不错的参考依照。

目前绝大多数的教程或者博客都是以 1.14.3 、1.15.2 、1.13.2  等等小版本号低于 5 的版本来部署，虽说小版本号之间没有多大差异，但这样无疑就带来一种风气，就是我生产环境也选择使用这些版本。我认为这样并不恰当，在小版本号低于 5 之前的版本，存在一些漏洞或者问题是我们生产环境是无法容忍的。这也是为什么各大 kubernetes 云服务厂商在上线新版本是会经过三到六个月的测试，比如 1.13 版本，无论是 AKS、EKS、GKE 他们都是在 1.13.6 版本之才推出 1.13 版本的正式版，之前的小版本都是测试或者预览版本。选择 1.12.10 这名高的版本也合适吗？抱歉，依照现在的进度，预估计小版本 10 以后就很少在更新维护了，所以万一有什么问题 1.13.6 可以很轻松地通过升级到 1.13.7 版本能解决，但 1.12 版本升级到 1.13 版本是比较麻烦地，没有稳定升级的空间，因此接近小版本 10 的也不建议新集群部署使用。

## 1. kubernetes release timeline

下面是我根据 kubernetes GitHub 的 release 总结汇总的一张表格

### Kubernetes release

| month   | stable                                                       | stable                                                       | stable                                                       | stable                                                       |
| ------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 2020-02 | [v1.17.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.17.3) | [v1.16.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.16.7) | [v1.15.10](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.10) |                                                              |
| 2020-01 | [v1.17.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.17.2)<br>[v1.17.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.17.1) | [v1.16.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.16.6)<br>[v1.16.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.16.5) | [v1.15.9](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.9)<br>[v1.15.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.8) | CVE                                                          |
| 2019-12 | [v1.17.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.17.0) | [v1.16.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.16.4) | [v1.15.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.7) | [v1.14.10](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.10) |
| 2019-11 | [v1.16.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.16.3) | [v1.15.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.6) | [v1.14.9](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.9) |                                                              |
| 2019-10 | [v1.16.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.16.1) <br>[v1.16.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.16.2) | [v1.15.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.5) | [v1.14.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.8) | [v1.13.12](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.12) |
| 2019-09 | [v1.16.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.16.0) | [v1.15.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.4) | [v1.14.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.7) | [v1.13.11](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.11) |
| 2019-08 | [v1.15.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.2)<br>[v1.15.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.3) | [v1.14.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.5) <br>[v1.14.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.6) | [v1.13.9](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.9) <br>[v1.13.10](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.10) | CVE                                                          |
| 2019-07 | [v1.15.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.1) | [v1.14.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.4) | [v1.13.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.8) | [v1.12.10](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.10) |
| 2019-06 | [v1.15.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.15.0) | [v1.14.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.3) | [v1.13.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.7) |                                                              |
| 2019-05 | [v1.14.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.2) | [v1.13.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.6) | [v1.12.9](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.9) | [v1.11.10](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.10) |
| 2019-04 | [v1.14.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.1) | [v1.12.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.8) |                                                              |                                                              |
| 2019-03 | [v1.14.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.14.0) | [v1.13.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.5) | [v1.12.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.7) | [v1.11.9](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.9) <br> [v1.11.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.8) |
| 2019-02 | [v1.13.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.4) <br>[v1.13.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.3) | [v1.12.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.6) | [v1.10.13](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.13) |                                                              |
| 2019-01 | [v1.13.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.2) | [v1.12.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.5) | [v1.11.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.7) |                                                              |
| 2018-12 | [v1.13.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.1) <br>[v1.13.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.13.0) | [v1.12.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.4) | [v1.11.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.6) | [v1.10.12](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.12) |
| 2018-11 | [v1.12.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.3) | [v1.11.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.5) | [v1.10.11](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.11) <br>[v1.10.10](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.10) |                                                              |
| 2018-10 | [v1.12.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.2) <br>[v1.12.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.1) | [v1.11.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.4) | [v1.10.9](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.9) | [v1.9.11](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.11) |
| 2018-09 | [v1.12.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.12.0) | [v1.11.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.3) | [v1.10.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.8) |                                                              |
| 2018-08 | [v1.11.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.2) | [v1.10.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.7) | [v1.9.10](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.10) |                                                              |
| 2018-07 | [v1.11.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.1) | [v1.10.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.6) | [v1.8.15](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.15) |                                                              |
| 2018-06 | [v1.11.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.11.0) | [v1.10.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.5) <br>[v1.10.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.4) | [v1.9.9](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.9) | [v1.8.14](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.14) |
| 2018-05 | [v1.10.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.3) | [v1.9.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.8) | [v1.8.13](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.13) |                                                              |
| 2018-04 | [v1.10.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.2) <br> [v1.10.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.1) | [v1.9.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.7) | [v1.8.11](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.11) <br>[v1.8.12](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.12) | [v1.7.16](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.16) |
| 2018-03 | [v1.10.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.10.0) | [v1.9.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.6) <br>[v1.9.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.5)  <br>[v1.9.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.4) | [v1.8.10](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.10) <br>[v1.8.9](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.9) | [v1.7.15](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.15) <br>[v1.7.14](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.14) <br>[v1.7.13](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.13) |
| 2018-02 | [v1.9.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.3) | [v1.8.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.8) |                                                              |                                                              |
| 2018-01 | [v1.9.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.2) <br>[v1.9.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.1) | [v1.8.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.7) |                                                              |                                                              |
| 2017-12 | [v1.9.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.9.0) | [v1.8.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.6) <br>[v1.8.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.5) | [v1.7.12](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.12) |                                                              |
| 2017-11 | [v1.8.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.4) <br>[v1.8.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.3) | [v1.7.11](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.11) <br>[v1.7.10](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.10) | [v1.6.13](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.13) |                                                              |
| 2017-10 | [v1.8.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.2) <br>[v1.8.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.1) | [v1.7.9](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.9) <br>[v1.7.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.8) | [v1.6.12](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.12) | [v1.5.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.5.8) |
| 2017-09 | [v1.8.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.8.0) | [v1.7.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.7) <br>[v1.7.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.6) | [v1.6.11](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.11) <br>[v1.6.10](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.10) |                                                              |
| 2017-08 | [v1.7.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.5) <br>[v1.7.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.4) <br>[v1.7.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.3) | [v1.6.9](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.9) <br>[v1.6.8](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.8) |                                                              |                                                              |
| 2017-07 | [v1.7.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.2) <br>[v1.7.1](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.1) | [v1.6.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.7) |                                                              |                                                              |
| 2017-06 | [v1.7.0](https://github.com/kubernetes/kubernetes/releases/tag/v1.7.0) | [v1.6.6](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.6) <br>[v1.6.5](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.5) |                                                              |                                                              |
| 2017-05 | [v1.6.4](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.4) <br>[v1.6.3](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.3) |                                                              |                                                              |                                                              |
| 2017-04 | [v1.6.2](https://github.com/kubernetes/kubernetes/releases/tag/v1.6.2) | [v1.5.7](https://github.com/kubernetes/kubernetes/releases/tag/v1.5.7) | [v1.4.12](https://github.com/kubernetes/kubernetes/releases/tag/v1.4.12) |                                                              |

根据这张 kubernetes release 的时间线我们大致可以总结出一下几点：

1. 每个小版本号即 x.y.z 中的 z ，一般情况下每个月会更新一次，到 10 以后更新周期会变长
2. 每个版本从 alpha 到 stable 周期为三个月，release stable 版本以后会继续更新维护 12 个月左右
3. 每个 x.y.z 中的 y 版本的整个生命周期大概为 15 个月，前三个月为开发测试阶段，后 12 个月为修复阶段
4. 平均每个月 kubernetes 维护的 y 版本为 4 个，现在维护的是 1.15.x、1.14x、1.13.x、1.12.x 还有 alpha 阶段的 1.16.x。1.11.x 应该已经放弃支持了，因为已经三个月没有更新了。
5. 综上所述我们可以大致推断出下个月更新的版本为 1.15.3 、1.14.6 、1.13.10

### GKE 、AKS 、EKS 支持 Kubernetes 版本情况

截至 2019-11-05

|                           Provider                           |                   Kubernetes                    | Docker |  Kernel   |
| :----------------------------------------------------------: | :---------------------------------------------: | :----: | :-------: |
|      [GKE](https://cloud.google.com/kubernetes-engine/)      | 1.15.4(alpha), 1.14.7(default), 1.13.11(stable) | 19.03  | 5.2, 4.19 |
| [AKS](https://azure.microsoft.com/en-us/services/kubernetes-service/) |      1.15.5(GA), 1.14.8, 1.13.12, 1.12.10       |        |           |
|            [EKS](https://aws.amazon.com/cn/eks/)             |   1.14.6(default), 1.13.10, 1.12.10, 1.11.10    |        |           |

## 2. Google kubernetes

**Google kubernetes [官方文档](https://cloud.google.com/kubernetes-engine/docs/release-notes)**

 August 1, 2019

```ini
1.13.7-gke.15
1.12.9-gke.10
1.12.7-gke.26
1.12.8-gke.12
```

**June 27, 2019**

```ini
1.11.8-gke.10
1.11.10-gke.4
1.12.7-gke.10
1.12.7-gke.21
1.12.7-gke.22
1.12.8-gke.6
1.12.8-gke.7
1.12.9-gke.3
1.13.6-gke.5
1.13.6-gke.6
1.13.7-gke.0
```

**June 4, 2019**

```ini
1.11.8-gke.6
1.11.9-gke.8
1.11.9-gke.13
1.14.2-gke.1 [Preview]
```

**May 20, 2019**

```ini
1.10.x (nodes only, completing)					1.11.8-gke.6
1.12.6-gke.10									1.12.6-gke.11
1.14.1-gke.4 and older 1.14.x (Alpha)			1.14.1-gke.5 (Alpha)

--------

1.12.x clusters v1.12.7-gke.17 and newer
1.13.x clusters v1.13.5-gke.10 and newer
1.14.x (Alpha) clusters v1.14.1-gke.5 and newer
```

## 3. AWS kubernetes

AWS 的 Kubernetes 平台叫做 EKS，在创建 kubernetes 集群时可以选择的版本没有 GKE 那么详细，仅仅有 1.13 、1.12 、1.11 这样的版本号，没有最后一位修补版本号，但我收到过 EKS 的产品更新邮件提醒，当 EKS 推出 1.13 版本的时候第一个 1.13 版本是使用的 1.13.7。[这里](https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html) 有 EKS 版本的详细信息。目前的版本还是 1.13 、1.12、1.11。虽然 1.14.5 版本都推出了，但至今 EKS 也没有 1.14 版本的 Kubernetes 可用。由此可以推断，到 1.13之后。EKS 团队在选择 kubernetes 版本的时候更倾向于 x.y.z 中 z 大于 6 的版本。因为前面的 6 个小版本的修复已经使得这个版本的稳定性适用于生产环境了。

> Kubernetes 社区大约会每隔三个月发布次要版本。 这些版本包括新增功能和改进。 修补程序版本更为频繁（有时会每周发布），并且仅用于次要版本中的关键 Bug 修复。 这些修补程序版本包括针对影响大量客户以及在生产中基于 Kubernetes 运行的产品的安全漏洞或重大 Bug 的修复。
>
> AKS 旨在完成上游版本发布后的 30 天内，根据该版本的稳定性认证和发布新的 Kubernetes 版本
>
> 此处剽窃 Azure 的官方文档 [Azure Kubernetes 服务 (AKS) 中支持的 Kubernetes 版本]( https://docs.microsoft.com/zh-cn/azure/aks/supported-kubernetes-versions )

下面我就直接剽窃一下 EKS 的[官方文档](https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html)😂

**Kubernetes version 1.13**

| Kubernetes Version | Release Notes                                                |
| :----------------- | :----------------------------------------------------------- |
| `1.13.8`           | New platform version updating Amazon EKS Kubernetes 1.13 clusters to a patched version of 1.13.8 to address [CVE-2019-11247](https://groups.google.com/forum/#!topic/kubernetes-security-announce/vUtEcSEY6SM). |
| `1.13.7`           | Initial release of Kubernetes 1.13 for Amazon EKS. For more information, see [Kubernetes 1.13](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html#kubernetes-1.13). |

**Kubernetes version 1.12**

| Kubernetes Version | Release Notes                                                |
| :----------------- | :----------------------------------------------------------- |
| `1.12.10`          | New platform version updating Amazon EKS Kubernetes 1.12 clusters to a patched version of 1.12.10 to address [CVE-2019-11247](https://groups.google.com/forum/#!topic/kubernetes-security-announce/vUtEcSEY6SM). |
| `1.12.6`           | New platform version to support custom DNS names in the Kubelet certificate and improve `etcd` performance. This fixes a bug that caused worker node Kubelet daemons to request a new certificate every few seconds. |
| `1.12.6`           | Initial release of Kubernetes 1.12 for Amazon EKS.           |

**Kubernetes version 1.11**

| Kubernetes Version | Release Notes                                                |
| ------------------ | ------------------------------------------------------------ |
| `1.11.10`          | New platform version updating Amazon EKS Kubernetes 1.11 clusters to to a patched version of 1.11.10 to address [CVE-2019-11247](https://groups.google.com/forum/#!topic/kubernetes-security-announce/vUtEcSEY6SM). |
| `1.11.8`           | New platform version to support custom DNS names in the Kubelet certificate and improve `etcd`performance. |
| `1.11.8`           | New platform version updating Amazon EKS Kubernetes 1.11 clusters to patch level 1.11.8 to address [CVE-2019-1002100](https://discuss.kubernetes.io/t/kubernetes-security-announcement-v1-11-8-1-12-6-1-13-4-released-to-address-medium-severity-cve-2019-1002100/5147). |
| `1.11.5`           | Initial release of Kubernetes 1.11 for Amazon EKS.           |

## 4. AKS

再补充一下 M$ 家的 AKS 貌似和阿里云的 kubernetes 重名？😂

看来 M$ 家的更新和支持挺快的，要比 kubernetes 亲爹 Google 还要快？不愧是最佳 Android 开发者😂。

[AKS-release](https://github.com/Azure/AKS/releases)

1.  [2019-08-05](https://github.com/Azure/AKS/releases/tag/2019-08-05)

    since this release

    **This release is rolling out to all regions**

    **Please Note**: This release includes new Kubernetes versions 1.13.9 &
    1.14.5 (GA today) these include the fixes for CVEs CVE-2019-11247 and
    CVE-2019-11249. Please see our [customer guidance](https://github.com/Azure/AKS/issues/1145)

2.  [2019-07-08](https://github.com/Azure/AKS/releases/tag/2019-07-08)

    since this release

    - Preview Features
        - Kubernetes 1.14.3 is now available for preview users.

看来 M$ 的 kubernetes 平台比 Google 更新的还要快，版本 GA 的时候也要早于 GKE 。即便如此，各大云计算厂商仍然会倾向于等到 kubernetes 版本修复得差不了才将上线新版本。

## 5. DigitalOcean kubernetes

## 6. 宿主机系统的参考

如果汝刚开始准备使用 Kubernetes ，那就抛弃 CentOS ，因为 CentOS 7.6 (1810) 的内核是 3.10 版本的，而 3.10 版本的内核是 2013 年 [release](https://kernelnewbies.org/Linux_3.10) 的 ，那时候的 Docker 还在妈妈的怀抱里吃奶呢😂。如今 Docker 容器虚拟化的一些特性需要新版本的 kernel 支持才能稳定低运行，而有些特性在 3.10 版本是不稳定的。`新版docker启用Linux CGroup memory这个feature，但这个feature在kernel 4.0以下版本中是非稳定版本` [来自](http://blog.allen-mo.com/2018/08/27/kubernetes_ops_troubleshooting/) 。

综上，为了少折腾，少踩坑还是更新的长期支持的高版本内核吧。都 9102 年了，就不要再相信使用旧版本更稳定的言论了😂。你看，人家 Google GKE 的节点的宿主机系统都是使用的 4.14 的内核，没故障吧。

```bash
System Info:
 Machine ID:                 acd0a47b56b6a4e6f775daaf31da236b
 System UUID:                ACD0A47B-56B6-A4E6-F775-DAAF31DA236B
 Boot ID:                    3b811f67-58cb-40af-8d6b-6e77e951dcee
 Kernel Version:             4.14.127+
 OS Image:                   Container-Optimized OS from Google
 Operating System:           linux
 Architecture:               amd64
 Container Runtime Version:  docker://17.3.2
 Kubelet Version:            v1.12.8-gke.10
 Kube-Proxy Version:         v1.12.8-gke.10
```

```bash
╭─root@deploy ~
╰─# cat /etc/centos-release
CentOS Linux release 7.6.1810 (Core)
╭─root@deploy ~
╰─# uname -a
Linux deploy 3.10.0-957.el7.x86_64 #1 SMP Thu Nov 8 23:39:32 UTC 2018
```

## 6. 综上

综上所述，汝对 Kubernetes 版本的选择也有了个大致的方向。在此我并没有使用国内的一些云计算厂商做测试。总的来说吧 Google 对 Kubernetes 的驾驭程度肯定要秒杀其他云计算厂商吧，毕竟是亲爹嘛。所以当汝也开始选择 Kubernetes 版本时，适用于生产环境的话，还是要再小版本号 6 以上才合适，比如 1.14.6 1.15.6 1.13.8 等等，都是比较保守的选择。之前的版本可以做测试用。其实选择 1.14.5 1.15.5 等也合适，M$ 家的 kubernetes 就是从 5 开始 GA 的。
