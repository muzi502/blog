---
title: 搬砖常用的 shell 片段记录
date: 2021-07-20
updated: 2021-07-20
slug:
categories: 技术
tag:
  - Linux
  - Bash
  - shell
copyright: true
comment: true
---

偶然间看到了 [**Z.S.K.'s Records**](https://izsk.me/) 大佬的一篇博客 《[有趣的Shell Snippet](https://izsk.me/2021/03/21/shell-funny-snippet/)》，突发奇想也准备写篇文章来记录一下常用的一些 shell 代码。

## Bash

### {} 展开

```bash
$ echo {hack,build}
hack build
```

### 变量替换

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

# 比如要获取镜像的 tag 常用的是 echo 然后 awk/cut 的方式

$ echo ${image} | awk -F ':' '{print $2}' 方式

# 可以直接使用 bash 内置的变量替换功能，截取特定字符串
$ image_name=${image%%:*}
$ image_tag=${image##*:}
$ image_repo=${image%%/*}
```

### 变量配置方式

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

### 判断字符串中是否包含子串

```bash
# 通过 ** 匹配
if [[ "${var}" == *"${sub_string}"* ]]; then
    printf '%s\n' "sub_string is in var."
fi

# 通过 bash 内置的 =~ 判断
if [[ "${sub_string}" =~ "${var}" ]]; then
    printf '%s\n' "sub_string is in var."
fi
```

## install

### 安装 docker-ce

```bash
$ curl -fsSL https://get.docker.com -o get-docker.sh
$ bash get-docker.sh --mirror Aliyun
```

另外可通过传入 DRY_RUN 的参数来输出际会执行的内容，这个输出的内容可以用来配置 docker-ce 的源，而不安装 docker。

```bash
$ DRY_RUN=1 sh ./get-docker.sh --mirror Aliyun > install.sh

# Executing docker install script, commit: 7cae5f8b0decc17d6571f9f52eb840fbc13b2737
apt-get update -qq >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq apt-transport-https ca-certificates curl >/dev/null
curl -fsSL "https://mirrors.aliyun.com/docker-ce/linux/debian/gpg" | apt-key add -qq - >/dev/null
echo "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/debian buster stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq >/dev/null
apt-get install -y -qq --no-install-recommends docker-ce >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce-rootless-extras >/dev/null
```

### 安装 helm

```bash
$ curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

### 安装 docker-compose

```bash
$ curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

$ chmod +x /usr/local/bin/docker-compose
```

## sed

### 匹配行的下一行插入

```bash
$ sed -i "/kube-node/a ${ip}" test
```

### 输出两个匹配行之间的内容

在不使用 yq 或者 jq 的情况下，需要输出 `downloads` 列表中的所有内容，即 `download:` 和 `download_defaults: `之间的内容

- [download.yml](https://github.com/kubernetes-sigs/kubespray/blob/master/roles/download/defaults/main.yml)

```yaml
dashboard_image_repo: "{{ docker_image_repo }}/kubernetesui/dashboard-{{ image_arch }}"
dashboard_image_tag: "v2.2.0"
dashboard_metrics_scraper_repo: "{{ docker_image_repo }}/kubernetesui/metrics-scraper"
dashboard_metrics_scraper_tag: "v1.0.6"

downloads:
  dashboard:
    enabled: "{{ dashboard_enabled }}"
    container: true
    repo: "{{ dashboard_image_repo }}"
    tag: "{{ dashboard_image_tag }}"
    sha256: "{{ dashboard_digest_checksum|default(None) }}"
    groups:
    - kube_control_plane

  dashboard_metrics_scrapper:
    enabled: "{{ dashboard_enabled }}"
    container: true
    repo: "{{ dashboard_metrics_scraper_repo }}"
    tag: "{{ dashboard_metrics_scraper_tag }}"
    sha256: "{{ dashboard_digest_checksum|default(None) }}"
    groups:
    - kube_control_plane

download_defaults:
  container: false
  file: false
  repo: None
  tag: None
  enabled: false
  dest: None
  version: None
  url: None
```

可使用 sed 的方式进行匹配输出 `sed -n '/$VAR1/,/$VAR2/p'`

```bash
$ sed -n '/^downloads:/,/download_defaults:/p'
```

### 奇偶行合并

接着上一个问题，通过 `sed -n "s/repo: //p;s/tag: //p"` 匹配出镜像的 repo 和 tag，但一个完整的镜像的格式是 `repo:tag`，因此需要将 repo 和 tag 行进行合并。

```yaml
    repo: "{{ dashboard_image_repo }}"
    tag: "{{ dashboard_image_tag }}"

    repo: "{{ dashboard_metrics_scraper_repo }}"
    tag: "{{ dashboard_metrics_scraper_tag }}"
```

可使用 `sed 'N;s#\n# #g'` 进行奇偶行合并

```bash
sed -n '/^downloads:/,/download_defaults:/p' ${REPO_ROOT_DIR}/${DOWNLOAD_YML} \
| sed -n "s/repo: //p;s/tag: //p" | tr -d ' ' | sed 's/{{/${/g;s/}}/}/g' \
| sed 'N;s#\n# #g' | tr ' ' ':' | sed 's/^/echo /g' >> ${TEMP_DIR}/generate.sh
```

### 去除换行符

```yaml
$ sed -i ':a;N;$!ba;s/\n/ /g'
```

##  grep/egrep

### 统计匹配行行数

```bash
$ lsof -i | grep sshd | wc -l

# grep 通过 -c 参数即可统计匹配行，不需要使用 wc 来统计
$ lsof -i | grep -c sshd
```

### 匹配 IPv4 地址

```bash
$ egrep --only-matching -E '([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}'
```

## docker

### 将镜像构建到本地目录

和 `FROM scratch`搭配起来使用，就可以将构建产物 build 到本地

```bash
$ DOCKER_BUILDKIT=1 docker build -o type=local,dest=$PWD -f Dockerfile .
```

比如使用 Dockerfile 构建 skopeo 静态链接文件

- Dockerfile

```dockerfile
FROM nixos/nix:2.3.11 as builder
WORKDIR /build
COPY . .
RUN nix build -f nix
FROM scratch
COPY --from=builder /build/result/bin/skopeo /skopeo
```

- build

```bash
DOCKER_BUILDKIT=1 docker build -o type=local,dest=$PWD .
```

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

- 获取集群中节点的 IP

```bash
$ kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }'
```

- 获取所有 Pod 的 IP

```bash
$ kubectl get pods -o jsonpath='{ $.items[*].status.podIP }'
```

- 获取所有 node 节点的子网信息

```bash
$ kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'
```

- 获取所有 service 的 IP

```bash
$ kubectl get svc --no-headers --all-namespaces -o jsonpath='{$.items[*].spec.clusterIP}'
```

- 根据 CPU/RAM 占用排序

```bash
# cpu
kubectl top pods --all-namespaces | sort --reverse --key 3 --numeric
# memory
kubectl top pods --all-namespaces | sort --reverse --key 4 --numeric
```

## yq/jq

### yq 根据某个 key 获取某个 value

```bash
$ cat cat > images_origin.yaml << EOF
---
# kubeadm core images
- src: k8s.gcr.io/kube-apiserver
  dest: library/kube-apiserver
- src: k8s.gcr.io/kube-controller-manager
  dest: library/kube-controller-manager
- src: k8s.gcr.io/kube-proxy
  dest: library/kube-proxy
- src: k8s.gcr.io/kube-scheduler
  dest: library/kube-scheduler
- src: k8s.gcr.io/coredns
  dest: library/coredns
- src: k8s.gcr.io/pause
  dest: library/pause

# docker registry for offline resources
- src: docker.io/library/registry
  dest: library/registry

# helm chartmuseum for offline resources
- src: ghcr.io/helm/chartmuseum
  dest: library/chartmuseum
EOF

$ yq eval '.[]|select(.dest=="library/chartmuseum") | .src' images_origin.yaml
```

### jq 遍历 json 数组/列表元素

```bash
for pmd_name in $(kubectl ${KUBECONFIG_ARG} get cpm --no-headers | cut -d ' ' -f1); do
    CPMD_NAME="${pmd_name}"
    JSON="${RCTL_TMP_PATH}/${pmd_name}.json"
    kubectl ${KUBECONFIG_ARG} get cpm ${pmd_name} -o jsonpath='{.spec}' > ${JSON}
    ((moudles_num=$(jq '.modules|length' ${JSON})-1))
    for i in $(seq 0 ${moudles_num}); do
        ((addons_num=$(jq ".modules[${i}].addons|length" ${JSON})-1))
        for j in $(seq 0 ${addons_num}); do
            addon_name=$(jq -r ".modules[${i}].addons[${j}].name" ${JSON})
            if [ "${CHART_NAME}" = "${addon_name}" ]; then
                PATCH_DATA=$(jq -c ".modules[${i}].addons[${j}].version = \"${VERSION}\"" ${JSON})
                break 3
            fi
        done
    done
done
```

## other

### 判断两个版本号大小

```bash
if printf "%s\\n%s\\n" v1.21 ${kube_version%.*} | sort --check=quiet --version-sort; then
	echo -n ${coredns_version};else echo -n ${coredns_version/v/}
fi
```

### 查看 x509 证书

```bash
$ openssl x509 -noout -text -in ca.cert
```

### 获取文件大小

```bash
$ stat -c '%s' file
```

### 获取本机 IP

```bash
$ ip r get 1 | awk 'NR==1 {print $NF}'
$ ip r get 1 | sed "s/uid.*//g" | awk 'NR==1 {print $NF}'
```

## function

一些 shell 脚本中常用的函数

### tar 进度条

避免 tar 解压文件的时候污染终端，建议使用进度条的方式展示解压过程

```bash
untar() {
  file_size=$(stat -c '%s' $1)
  block_size=$(expr $file_size / 51200); block_size=$(expr $block_size + 1)
  tar_info="Untar $1 progress:"
  tar --blocking-factor=$block_size --checkpoint=1 --checkpoint-action=ttyout="${tar_info} %u%  \r" -xpf $1 -C $2
}
```

### 正则匹配 IP

```bash
# regular match ip
match_ip() {
    local INPUT_IPS=$*
    local IPS=""
    if ! echo ${INPUT_IPS} | egrep --only-matching -E '([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}-[[:digit:]]{1,3}' > /dev/null; then
        IPS="$(echo ${INPUT_IPS} | egrep --only-matching -E '([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}' | tr '\n' ' ')"
    else
        ip_prefix="$(echo ${INPUT_IPS} | egrep --only-matching -E '([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}-[[:digit:]]{1,3}' | cut -d '.' -f1-3)"
        ip_suffix="$(echo ${INPUT_IPS} | egrep --only-matching -E '([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}-[[:digit:]]{1,3}' | cut -d '.' -f4 | tr '-' ' ')"
        for suffix in $(seq ${ip_suffix}); do IPS="${IPS} ${ip_prefix}.${suffix}"; done
    fi
    echo ${IPS} | egrep --only-matching -E '([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}' | tr '\n' ' '
}
```

### ssh 登录配置

```bash
Host *
	  StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    ForwardAgent yes
    ServerAliveInterval 10
    ServerAliveCountMax 10000
    TCPKeepAlive no
    ControlMaster auto
    ControlPath ~/.ssh/session/%h-%p-%r
    ControlPersist 12h

Host nas
    Hostname 172.20.0.10
    Port 22
    User root
    IdentityFile ~/.ssh/local-node.pem

Host 172.20.0.*
    Port 22
    User root
    IdentityFile ~/.ssh/local-node.pem

Host *github.com
    Hostname github.com
    User git
    IdentityFile ~/.ssh/github_muzi.pem
```

- `StrictHostKeyChecking no`：略过 HostKey 检查，避免出现 [How can I avoid SSH's host verification for known hosts?](https://superuser.com/questions/125324/how-can-i-avoid-sshs-host-verification-for-known-hosts)

### ssh 密码登录

日常工作中常常需要 ssh 登录到机房的一些虚拟机上，又因为不同的机器密码不同，遂使用该脚本 ssh 登录到节点上。

```bash
#!/bin/bash
IP=${1}
CMD=${2}
USER=root
ARGS="-o StrictHostKeyChecking=no -o ControlMaster=auto -o ControlPersist=12h -o ConnectionAttempts=100"
PASSWORDS="admin123456 test123456 centos1234"
ssh-keygen -R ${1} > /dev/null 2>&1
PASS=""
for pass in ${PASSWORDS}; do
    if sshpass -p ${pass} ssh ${ARGS} ${USER}@${IP} "hostname"; then PASS=${pass}; break ; fi
done
sshpass -p ${PASS} ssh ${ARGS} ${USER}@${IP} ${CMD}
exit 0
```

### 脚本中统计函数耗时

```bash
reset_global_timer() {
	export SEC0=$(date --utc +%s)
}

reset_function_timer(){
    export SEC1=$(date --utc +%s)
}

running_time()
{
    SEC2=$(date --utc +%s); DIFFSEC=$((${SEC2} - ${SEC1})); printf "\nSection Time: $(date +%H:%M:%S -ud @${DIFFSEC})\n"
    SEC2=$(date --utc +%s); DIFFSEC=$((${SEC2} - ${SEC0})); printf "Elapsed Time: $(date +%H:%M:%S -ud @${DIFFSEC})\n\n"
}

reset_global_timer
reset_function_timer
running_time
```

## OS

- dpkg 获取系统已经安装的包

```bash
$ dpkg-query -W -f='${binary:Package}=${Version}\n'
```

- 获取 CPU 架构

```bash
ARCHITECTURE=$(uname -m)
host_architecture=$(dpkg --print-architecture)
```

### 替换系统 OS 源

 使用华为云 yum 源

- CentOS 7

```bash
$ wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.huaweicloud.com/repository/conf/CentOS-7-anon.repo

# 安装华为云 EPEL 源
yum install epel-release -y
sed -i "s/#baseurl/baseurl/g" /etc/yum.repos.d/epel.repo
sed -i "s/metalink/#metalink/g" /etc/yum.repos.d/epel.repo
sed -i "s@https\?://download.fedoraproject.org/pub@https://mirrors.huaweicloud.com@g" /etc/yum.repos.d/epel.repo
```

- Debian

```bash
$ sed -i 's/deb.debian.org/mirrors.huaweicloud.com/g' /etc/apt/sources.list
$ sed -i 's|security.debian.org/debian-security|mirrors.huaweicloud.com/debian-security|g' /etc/apt/sources.list
```

- Ubuntu

```bash
$ sed -i 's/archive.ubuntu.com/mirrors.huaweicloud.com/g' /etc/apt/sources.list
```

- Alpine

```bash
$ echo "http://mirrors.huaweicloud.com/alpine/latest-stable/main/" > /etc/apk/repositories
$ echo "http://mirrors.huaweicloud.com/alpine/latest-stable/community/" >> /etc/apk/repositories
```

### CA 证书信任

- CentOS

```bash
$ update-ca-trust force-enable
$ cp domain.crt /etc/pki/ca-trust/source/anchors/domain.crt
$ update-ca-trust
```

- Debian

```bash
$ cp domain.crt /usr/share/ca-certificates/domain.crt
$ echo domain.crt >> /etc/ca-certificates.conf
$ update-ca-certificates
```

- Ubuntu

```bash
$ cp domain.crt /usr/local/share/ca-certificates/domain.crt
$ update-ca-certificates
```

### Git 操作

#### 修改历史 commit 信息

```bash
#!/bin/sh

git filter-branch --env-filter '
OLD_EMAIL="github-actions@github.com"
CORRECT_NAME="github-actions"
CORRECT_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"

if [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_COMMITTER_NAME="$CORRECT_NAME"
    export GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
fi
if [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_AUTHOR_NAME="$CORRECT_NAME"
    export GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
fi
' --tag-name-filter cat -- --branches --tags
```

#### 获取当前 repo 的最新 git tag

```bash
$ git describe --tags --always
```

## 未完待续

## 参考

- [pure-bash-bible](https://github.com/dylanaraps/pure-bash-bible)
- [鸟哥 Linux 私房菜](http://cn.linux.vbird.org/linux_basic/0320bash_2.php#variable_other)
- [jq 常用操作](https://mozillazg.com/2018/01/jq-use-examples-cookbook.html)
- [YAML处理工具yq之读写篇](https://lyyao09.github.io/2019/08/02/tools/The-usage-of-yq-read-write/)
