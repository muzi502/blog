---
title: 使用 GitHub Actions 构建 kubespray 离线安装包
date: 2021-06-14
updated: 2021-06-20
slug:
categories: 技术
tag:
  - kubernetes
  - kubespray
copyright: true
comment: true
---

## 私有化部署

总体来讲使用 kubespray 来部署 kubernetes 集群大致需要依赖如下三种在线的资源

- 系统 OS 的 rpm/deb 包：如 docker-ce、containerd、ipvsadm 等；
- 二进制文件：如 kubelet、kubectl、kubeadm、helm、crictl 等；
- 组件容器镜像：如 kube-apiserver、kube-proxy、cordons、calico、flannel 等；

在安装包发布的时候，我们需要将这三种资源打包成离线安装包，然后在在集群部署的时候部署一个 nginx 服务用于提供一些 rpm/deb 包和一些二进制文件的下载，以及部署一个 registry 镜像仓库服务用于提供组件镜像的下载。

### 构建离线资源

- 系统 OS 的 rpm/deb 包
- 二进制文件
- 组件容器镜像

## 打包发布



### GitHub Actions 打包

## 私有化部署

这两个服务比较特殊，因此我们需要一台机器专门用于部署他们，部署的方式相对来讲也比较简单，使用 docker/nerdctl compose 将他们运行起来。

### offline-resource 服务

### kubernetes 集群

## 参考

- [云原生 PaaS 产品发布&部署方案](https://blog.k8s.li/pass-platform-release.html)
- [使用 docker build 制作 yum/apt 离线源](https://blog.k8s.li/make-offline-mirrors.html)
- [使用 Kubespray 本地开发测试部署 kubernetes 集群](https://blog.k8s.li/deploy-k8s-by-kubespray.html)
- [什么？发布流水线中镜像“同步”速度又提升了 15 倍 ！](https://blog.k8s.li/select-registry-images.html)
- [如何使用 registry 存储的特性](https://blog.k8s.li/skopeo-to-registry.html)
- [Jenkins 大叔与 kubernetes 船长手牵手 🧑‍🤝‍🧑](https://blog.k8s.li/jenkins-with-kubernetes.html)
