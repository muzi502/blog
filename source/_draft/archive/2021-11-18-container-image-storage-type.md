---
title: 容器镜像存储的方式
date: 2021-11-18
updated:
slug:
categories:
tag:
copyright: true
comment: true
---
## OCI spec？

谈到容器镜像就不得不提一下 OCI 规范

## 镜像的组成

- image layer
- image config
- image manifest

## 镜像存储的方式

- runtime
- registry
- dir：以目录的形式进行存储 tar 包或者 gzip
- tar：以 tar 包的方式进行存储，runtime 可以将它们 load 到本地的 graph storage

## runtime

### docker

### podman

### containerd

## registry

## tar

### docker-save

### podman-save

### skopeo-copy

## dir

### OCI-image

### skopeo
