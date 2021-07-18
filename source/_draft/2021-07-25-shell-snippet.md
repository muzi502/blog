---
title: 一些 Shell Snippet 记录
date: 2021-07-01
updated:
slug:
categories:
tag:
copyright: true
comment: true
---

偶然间看到了 [**Z.S.K.'s Records**](https://izsk.me/) 大佬的一篇博客 《[有趣的Shell Snippet](https://izsk.me/2021/03/21/shell-funny-snippet/)》，突发奇想也准备写篇文章来记录一下常用的一些 shell 代码。

## bash

- 变量替换

> http://cn.linux.vbird.org/linux_basic/0320bash_2.php#variable_other
>
> 我们将这部份作个总结说明一下：
>
> | 变量配置方式                                         | 说明                                                         |
> | ---------------------------------------------------- | ------------------------------------------------------------ |
> | ${变量#关键词} ${变量##关键词}                       | 若变量内容从头开始的数据符合『关键词』，则将符合的最短数据删除 若变量内容从头开始的数据符合『关键词』，则将符合的最长数据删除 |
> | ${变量%关键词} ${变量%%关键词}                       | 若变量内容从尾向前的数据符合『关键词』，则将符合的最短数据删除 若变量内容从尾向前的数据符合『关键词』，则将符合的最长数据删除 |
> | ${变量/旧字符串/新字符串} ${变量//旧字符串/新字符串} | 若变量内容符合『旧字符串』则『第一个旧字符串会被新字符串取代』 若变量内容符合『旧字符串』则『全部的旧字符串会被新字符串取代』 |

```bash
$ image="library/nginx:1.19"
$ image_name=${image%%:*}
$ image_tag=${image##*:}
$ image_repo=${image%%/*}
```

- 变量配置方式

| 变量配置方式     | str 没有配置       | str 为空字符串     | str 已配置非为空字符串 |
| ---------------- | ------------------ | ------------------ | ---------------------- |
| var=${str-expr}  | var=expr           | var=               | var=$str               |
| var=${str:-expr} | var=expr           | var=expr           | var=$str               |
| var=${str+expr}  | var=               | var=expr           | var=expr               |
| var=${str:+expr} | var=               | var=               | var=expr               |
| var=${str=expr}  | str=expr var=expr  | str 不变 var=      | str 不变 var=$str      |
| var=${str:=expr} | str=expr var=expr  | str=expr var=expr  | str 不变 var=$str      |
| var=${str?expr}  | expr 输出至 stderr | var=               | var=$str               |
| var=${str:?expr} | expr 输出至 stderr | expr 输出至 stderr | var=$str               |

## install

- 安装 docker-ce

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
bash get-docker.sh --mirror Aliyun
```

- 使用 kubeadm 快速安装 k8s

## tar

- tar 显示进度条

```bash
file_size=$(ls -l images.tar | awk '{print $5}')
block_size=$(expr $file_size / 51200); block_size=$(expr $block_size + 1)
tar --blocking-factor=$block_size --checkpoint=1 --checkpoint-action=ttyout="%u%  \r" -xf images.tar
```

## sed

- 匹配行的下一行插入

```
```

- 奇偶行合并

```bash
sed -n '/^downloads:/,/download_defaults:/p' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
| sed -n "s/repo: //p;s/tag: //p" | tr -d ' ' | sed 's/{{/${/g;s/}}/}/g' \
| sed 'N;s#\n# #g' | tr ' ' ':' | sed 's/^/echo /g' >> ${TEMP_DIR}/generate.sh
```

## awk

##  grep 

## kubectl

- 获取集群中所有 pod 运行需要的镜像

```bash
$ kubectl get pods -A -o=custom-columns='IMAGE:spec.containers[*].image' | tr ',' '\n' | sort -u
```

- 获取所有 namespace 的 events 日志并按照时间戳排序

```bash
$ kubectl get events --all-namespaces -o wide --sort-by=.metadata.creationTimestamp
```

- 导出一个 namespaces 下所有 pod 的日志

```bash
$ kubectl get pod -n kube-system | awk '{print $1}' | xargs -L1 -I {} bash -c "kubectl -n kube-system logs {} > {}.log"
```

- 导出 k8s 组件的 pod 日志

```bash
$ kubectl get pod -n kube-system | grep -E "kube-apiserver|kube-controller|kube-proxy|kube-scheduler|coredns" | awk '{print $1}' | xargs -L1 -I {} sh -c "kubectl -n kube-system logs {} > {}.log"
```

## network

- 获取本机内网 IP

```bash
$ ip r get 1 | awk 'NR==1 {print $NF}'
$ ip r get 1 | sed "s/uid.*//g" | awk 'NR==1 {print $NF}'
```

## other

- 判断两个版本号大小

```
if printf "%s\\n%s\\n" v1.21 ${kube_version%.*} | sort --check=quiet --version-sort; then
	echo -n ${coredns_version};else echo -n ${coredns_version/v/}
fi
```

- 查看 x509 证书

```bash
$ openssl x509 -noout -text -in ca.cert
```

## function

一些 shell 脚本中常用的函数

### tar 进度条

```bash
untar() {
  file_size=$(ls -l $1 | awk '{print $5}')
  block_size=$(expr $file_size / 51200); block_size=$(expr $block_size + 1)
  tar_info="Untar $1 progress:"
  tar --blocking-factor=$block_size --checkpoint=1 --checkpoint-action=ttyout="${tar_info} %u%  \r" -xpf $1 -C $2
}
```

## Makefile

```bash
# Current version of the project.
VERSION      ?= $(shell git describe --tags --always --dirty)
BRANCH       ?= $(shell git branch | grep \* | cut -d ' ' -f2)
GITCOMMIT    ?= $(shell git rev-parse HEAD)
GITTREESTATE ?= $(if $(shell git status --porcelain),dirty,clean)
BUILDDATE    ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Track code version with Docker Label.
DOCKER_LABELS ?= git-describe="$(shell date -u +v%Y%m%d)-$(shell git describe --tags --always --dirty)"
```

