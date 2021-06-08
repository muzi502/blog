---
title: 使用 GitHub Actions 构建 kubespray 离线安装包
date: 2021-06-10
updated: 2021-06-10
slug:
categories: 技术
tag:
  - kubernetes
  - kubespray
copyright: true
comment: true

---

## 私有化交付

总体来讲 kubernetes 集群部署大致需要依赖如下三种在线的资源

- 系统 OS 的 rpm/deb 包：如 docker-ce、containerd、ipvsadm 等；
- 二进制文件：如 kubelet、kubectl、kubeadm、helm、GPU 驱动等；
- 组件容器镜像：如 kube-apiserver、kube-proxy、calico、flannel 等；

