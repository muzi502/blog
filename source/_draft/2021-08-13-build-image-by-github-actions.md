---
title: 使用 GitHub Action 构建镜像与优化
date: 2021-01-01
updated:
slug:
categories:
tag:
copyright: true
comment: true
---

最近在折腾使用 GitHub Actions 来运行一些构建任务

## multi arch ？

### image manifest

### manifest index

### buildx and qemu

## GitHub Actions

### 参数传递

![image-20210814150359150](https://p.k8s.li/2021-08-13-build-image-by-github-actions/image-20210814150359150.png)

![image-20210814150429680](https://p.k8s.li/2021-08-13-build-image-by-github-actions/image-20210814150429680.png)

### 产物传递

## Runner

### github-hosted

### self-hosted

## 不足

### 参数化构建

### job 集中式管理

## 磁盘扩容 🤔️

```yaml
      - name: Maximize rootfs space
        run: |
          df -h
          mkdir -p temp
          sudo rsync --delete-before -d temp/ /usr/share/dotnet/
          sudo rsync --delete-before -d temp/ /usr/local/lib/android/
          df -h
```

