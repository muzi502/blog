---
title: 同步 docker hub library 镜像到本地 registry
date: 2020-02-10
updated: 2020-02-11
slug:
categories: 技术
tag:
  - registry
  - images
copyright: true
comment: true
---

## docker 恰烂钱？

作为世界上最大的镜像仓库站点，docker 公司

为了恰点烂钱就进行限制：

-   **未登录用户，每 6 小时只允许 pull 100 次**
-   **已登录用户，每 6 小时只允许 pull 200 次**

而且，限制的手段也非常地粗暴，通过限制请求镜像的 manifest 文件，

-   [突破 DockerHub 限制，全镜像加速服务](https://moelove.info/2020/09/20/%E7%AA%81%E7%A0%B4-DockerHub-%E9%99%90%E5%88%B6%E5%85%A8%E9%95%9C%E5%83%8F%E5%8A%A0%E9%80%9F%E6%9C%8D%E5%8A%A1/)
-   [绕过从 Docker Hub pull 镜像时的 429 toomanyrequests](https://nova.moe/bypass-docker-hub-429/)
-   [如何绕过 DockerHub 拉取镜像限制](https://www.chenshaowen.com/blog/how-to-cross-the-limit-of-dockerhub.html)

## 不如脱下整个 library



## 本地 pull 镜像



## Dockerfile 里 push 镜像

不如给 docker 戴个绿帽🤣，有点过分了哦，在他家的 docker hub 上把镜像 push 到自己的 registry 中。

