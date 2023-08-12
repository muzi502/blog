---
title: 基于 BMC 带外管理实现属服务器 OS 自动化安装
date: 2023-04-30
updated: 2023-04-30
slug:
categories: 技术
tag:
- BMC
- Redfish
- BareMetal
copyright: true
comment: true
---
给服务器装个破系统也能用到 K8s 😅

## 装系统 😂

要说最近一个月在瞎忙什么，可以总结为三个字：**装系统**，不过不是给个人 PC 装系统，而是给一些裸金属服务器安装 OS。之前也写过一篇博客《[使用 Redfish 自动化安装 ESXi OS](https://blog.k8s.li/redfish-esxi-os-installer.html)》介绍了如何使用 Redfish 来自动化安装 ESXi。不过那个方案还有很多不足之处，今天就对最近的工作做一下总结，完善一下之前的那个方案。

## 名词解释

### 网络

- **带外管理**（**Out-of-band management**）是指使用独立管理通道进行设备维护。它允许系统管理员远程监控和管理[服务器](https://zh.m.wikipedia.org/wiki/%E6%9C%8D%E5%8A%A1%E5%99%A8)、路由器、[网络交换机](https://zh.m.wikipedia.org/wiki/%E7%BD%91%E7%BB%9C%E4%BA%A4%E6%8D%A2%E6%9C%BA)和其他网络设备。
- 管理网络：系统管理网络，比如 ssh/rdp 远程登录服务器。
- 业务网络：承担业务流量的网络，对安全要求不高的情况下可以和管理在同一个网络。
- 存储网络：服务器连接存储设备的专用内部网络，通常是万兆及以上且设备间一般不会垮三层网关。

对网络安全十分重视的私有云环境中，上述四种网络都会做物理上的隔离，即不同的网络使用不同的网口连接不同的交换机设备。

## 技术调研

### PXE

### Cobber

### Ironinc

## 劝退三连

- 提前准备好 OS 的 ISO 安装镜像
- 需要有台戴尔、联想、HPE 服务器，且 BMC 支持 Redfish，一些旧型号的服务器可能不支持 Redfish
- 需要有个 K8s 集群，该工具是容器化运行的，且使用的是 argo-workflow 作为安装任务的编排引擎
