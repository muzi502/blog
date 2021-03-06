---
title: Jenkins 大叔与 kubernetes 船长手牵手 🧑‍🤝‍🧑
date: 2021-03-06
updated: 2021-03-06
slug:
categories: 技术
tag:
  - Jenkins
  - kubernetes
copyright: true
comment: true
---

## kubernetes 集群

关于 kubernetes 集群部署，使用 kubeadm 部署是最为方便的了，可参考我很早之前写过的文章《》，在这里只是简单介绍一下

- 使用 kubeadm 来创建一个单 master 节点的 kubernets 集群

```bash
root@jenkins:~ # kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.20.11
```

- 集群成功部署完成之后会有如下提示：

```bash
Your Kubernetes control-plane has initialized successfully!
To start using your cluster, you need to run the following as a regular user:
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

- 查看节点状态和 pod 都已经正常

```bash
root@jenkins:~ # kubectl get pod -A
NAMESPACE     NAME                              READY   STATUS    RESTARTS   AGE
kube-system   coredns-f9fd979d6-9t6qp           1/1     Running   0          89s
kube-system   coredns-f9fd979d6-hntm8           1/1     Running   0          89s
kube-system   etcd-jenkins                      1/1     Running   0          106s
kube-system   kube-apiserver-jenkins            1/1     Running   0          106s
kube-system   kube-controller-manager-jenkins   1/1     Running   0          106s
kube-system   kube-proxy-8pzkz                  1/1     Running   0          89s
kube-system   kube-scheduler-jenkins            1/1     Running   0          106s
root@jenkins:~ # kubectl get node
NAME      STATUS   ROLES    AGE    VERSION
jenkins   Ready    master   119s   v1.19.8
```

- 去除 master 节点上的污点，允许其他的 pod 调度在 master 节点上，不然后面 Jenkins 所创建的 pod 将无法调度在该节点上。

```bash
kubectl taint nodes $(hostname) node-role.kubernetes.io/master:NoSchedule-
```

## Jenkins server

至于 Jenkins server 的部署方式，建议使用 docker-compose 来部署。如果是构建任务或者使用 Jenkins 的用户较多也建议将 Jenkins 部署在单独的机器上。毕竟 Jenkins 是个传统的 java 应用程序，是十分占用资源的。运行在 kubernetes 集群集群中也没什么毛病，但对于后续的运维管理可能不太方便。

- `docker-compose.yaml`

```yaml
version: '3.6'
services:
  jenkins:
    image: jenkins/jenkins:2.263.4-lts-slim
    container_name: jenkins
    restart: always
    volumes:
      - ./jenkins_home:/var/jenkins_home
    network_mode: host
    user: root
    environment:
      - JAVA_OPTS=-Duser.timezone=Asia/Shanghai
```

- 使用 docker-compose up 来启动，成功启动后会有如下提示，日志输出的密钥就是 `admin` 用户的默认密码，使用它来第一次登录 Jenkins。

```bash
jenkins    | 2021-03-06 02:22:31.741+0000 [id=41]	INFO	jenkins.install.SetupWizard#init:
jenkins    |
jenkins    | *************************************************************
jenkins    | *************************************************************
jenkins    | *************************************************************
jenkins    |
jenkins    | Jenkins initial setup is required. An admin user has been created and a password generated.
jenkins    | Please use the following password to proceed to installation:
jenkins    |
jenkins    | 4c2361968cd94323acdde17f7603d8e1
jenkins    |
jenkins    | This may also be found at: /var/jenkins_home/secrets/initialAdminPassword
jenkins    |
jenkins    | *************************************************************
jenkins    | *************************************************************
jenkins    | *************************************************************
```

- 登录上去之后，建议选择 `选择插件来安装`，尽可能少地安装插件，按需安装即可。

![image-20210306102735594](https://p.k8s.li/image-20210306102735594.png)

- 在 Jenkins 的插件管理那里安装上 kubernetes 插件

- ![image-20210306103352837](https://p.k8s.li/image-20210306103352837.png)

- 接下来开始配置 Jenkins 大叔如何与 kubernetes 船长手牵手🧑‍🤝‍🧑 :-)。配置 kubernets 的地方是在 `系统管理 > 节点管理 > Configure Clouds`。点击 `Add a new cloud`，来添加一个 kubernetes 集群。

![image-20210306111626079](https://p.k8s.li/image-20210306111626079.png)

- 配置连接参数

| 参数                                  | 值                         | 说明                                    |
| ------------------------------------- | -------------------------- | --------------------------------------- |
| 名称                                  | kubernetes                 |                                         |
| 凭据                                  | kubeconfig 凭据 id         | 使用 kubeconfig 文件来连接集群          |
| Kubernetes 地址                       | 默认即可                   |                                         |
| Use Jenkins Proxy                     | 默认即可                   |                                         |
| Kubernetes 服务证书 key               | 默认即可                   |                                         |
| 禁用 HTTPS 证书检查                   | 默认即可                   |                                         |
| Kubernetes 命名空间                   | 默认即可                   |                                         |
| WebSocket                             | 默认即可                   |                                         |
| Direct Connection                     | 默认即可                   |                                         |
| Jenkins 地址                          | http://jenkins.k8s.li:8080 | Jenkins pod 连接 Jenkins server 的  URL |
| Jenkins 通道                          | 50000                      | Jenkins `JNLP` 的端口，默认为 50000     |
| Connection Timeout                    | 默认即可                   | Jenkins 连接 kubernetes 超时时间        |
| Read Timeout                          | 默认即可                   |                                         |
| 容器数量                              | 默认即可                   | Jenkins pod 创建的最大数量              |
| Pod Labels                            | 默认即可                   | Jenkins pod 的 lables                   |
| 连接 Kubernetes API 的最大连接数      | 默认即可                   |                                         |
| Seconds to wait for pod to be running | 默认即可                   | 等待 pod 正常 running 的时间            |

- 在 Jenkins 的凭据那里添加上 kubeconfig 文件，凭据的类型选择为 `Secret file`，然后将上面使用 kubeadm 部署的 kubeconfig 上传到 Jenkins 上。

![image-20210306111037947](https://p.k8s.li/image-20210306111037947.png)

- 点击连接测试，如果提示 `Connected to Kubernetes v1.19.8` 就说明已经成功连接上了 kubernetes 阶段。

![image-20210306111148462](https://p.k8s.li/image-20210306111148462.png)

## Jenkinsfile

- 流水线 `Jenkinsfile`

```yaml
// Kubernetes pod template to run.
def JOB_NAME = "${env.JOB_NAME}"
def BUILD_NUMBER = "${env.BUILD_NUMBER}"
def POD_NAME = "jenkins-${JOB_NAME}-${BUILD_NUMBER}"
podTemplate(
# 这里定义 pod 模版
)
{ node(POD_NAME) {
    container(JOB_NAME) {
      stage("Build image") {
        sh """#!/bin/bash
          git clone https://github.com/webp-sh/webp_server_go /build
          cd /build
          docker build -t webps:0.3.2-rc.1 .
        """
      }
    }
  }
}
```

- pod 模版

```yaml
podTemplate(
  cloud: "kubernetes",
  namespace: "default",
  name: POD_NAME,
  label: POD_NAME,
  yaml: """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: ${JOB_NAME}
    image: "debian:buster-docker"
    imagePullPolicy: IfNotPresent
    tty: true
    volumeMounts:
    - name: dockersock
      mountPath: /var/run/docker.sock
  - name: jnlp
    args: ["\$(JENKINS_SECRET)", "\$(JENKINS_NAME)"]
    image: "jenkins/inbound-agent:4.3-4-alpine"
    imagePullPolicy: IfNotPresent
  volumes:
  - name: dockersock
    hostPath:
      path: /var/run/docker.sock
""",
) 
```

- 构建 `debian:buster-docker` 镜像，使用它来在 pod 的容器内构建 docker 镜像，使用的 `Dockerfile` 如下：

```dockerfile
FROM debian:buster
RUN apt update \
    && apt install -y --no-install-recommends \
        vim \
        curl \
        git \
        make \
        ca-certificates \
        gnupg \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://download.docker.com/linux/debian/gpg" | apt-key add -qq - >/dev/null \
    && echo "deb [arch=amd64] https://download.docker.com/linux/debian buster stable" > /etc/apt/sources.list.d/docker.list \
    && apt update -qq \
    && apt-get install -y -qq --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*
```

## 流水线

- 在 Jenkins 上新建一个任务，选择任务的类型为 `流水线`

![image-20210306185651025](https://p.k8s.li/image-20210306185651025.png)

- 将定义好的 Jenkinsfile 内容复制粘贴到流水线定义 `Pipeline script` 中并点击保存。

![image-20210306185838845](https://p.k8s.li/image-20210306185838845.png)

- 在 kubernetes 集群的机器上使用 kubectl 命令查看 pod 是否正常 Running

```bash
root@jenkins:~ # kubectl get pod
NAME                              READY   STATUS    RESTARTS   AGE
jenkins-webps-9-bs78x-5x204   2/2     Running   0          66s
```

- Job 正常运行并且也已经执行成功

![image-20210306190124096](https://p.k8s.li/image-20210306190124096.png)

- 在 kubernetes 集群机器上查看 docker 镜像是否构建成功

```bash
root@jenkins:~ # docker images | grep webps
webps                                0.3.2-rc.1          f68f496c0444        20 minutes ago      13.7MB
```

## 踩坑

- pod 无法正常 Running

```bash
Running in Durability level: MAX_SURVIVABILITY
[Pipeline] Start of Pipeline
[Pipeline] podTemplate
[Pipeline] {
[Pipeline] node
Created Pod: kubernetes default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r][Scheduled] Successfully assigned default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r to jenkins
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r][Pulling] Pulling image "debian:buster"
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r][Pulled] Successfully pulled image "debian:buster" in 2.210576896s
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r][Created] Created container debian
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r][Started] Started container debian
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r][Pulling] Pulling image "jenkins/inbound-agent:4.3-4-alpine"
Still waiting to schedule task
‘debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r’ is offline
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r][Pulled] Successfully pulled image "jenkins/inbound-agent:4.3-4-alpine" in 3.168311973s
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r][Created] Created container jnlp
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-9wm0r][Started] Started container jnlp
Created Pod: kubernetes default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-qdw4m
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-qdw4m][Scheduled] Successfully assigned default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-qdw4m to jenkins
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-qdw4m][Pulled] Container image "debian:buster" already present on machine
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-qdw4m][Created] Created container debian
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-qdw4m][Started] Started container debian
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-qdw4m][Pulled] Container image "jenkins/inbound-agent:4.3-4-alpine" already present on machine
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-qdw4m][Created] Created container jnlp
[Normal][default/debian-35a11b49-087b-4a8c-abac-bd97d7eb5a1f-fkmzq-qdw4m][Started] Started container jnlp
```

这是因为 Jenkins pod 中的 jnlp 容器无法连接 Jenkins server，无法向 Jenkins server 注册自己。可以检查一下 `系统管理 > 节点管理 > Configure Clouds` 中 `Jenkins 地址` 和 `Jenkins 通道` 这两个是否配置正确。

- pod 异常退出

Job Pod 可以正常创建，但执行 sh 命令后会立即退出，并提示 403 Forbidden 错误

```java
Commit message: "feat(Jenkinsfile): reset download out time"[Pipeline] }[Pipeline] // retry[Pipeline] shjava.net.ProtocolException: Expected HTTP 101 response but was '403 Forbidden'
```

在本地使用 kubectl 进入到 相应的pod 中执行命令时也提示 forbidden 错误。

```bash
[root@jenkins ~]$ kubectl exec -it jenkins-1v39-088m3 bash
Use 'kubectl describe pod/jenkins--1v39-088m3 -n kube-system' to see all of the containers in this pod.
Error from server (Forbidden): pods "jenkins-1v39-088m3" is forbidden: cannot exec into or attach to a privileged container
```

解决办法：配去掉 APIserver 的 --enable-admission-plugins 插件中的 `PodSecurityPolicy` 或者配置正确的 PSP 策略，允许特权容器执行 `exec`

```yaml
#- --enable-admissionplugins=PodSecurityPolicy
```

## 结束

到此为止，我们就完成了让 Jenkins 大叔与 kubernetes 船长手牵手🧑‍🤝‍🧑啦！上面使用了一个简单的例子来展示了如果将 Jenkins 的 Job 任务运行在 kubernetes 集群上，但在实际工作中遇到的情形可能比这要复杂一些，流水线需要配置的参数也要多一些。那么我将会在下一篇博客中再讲一下高级的用法：使用 Jenkins 完成 kubespray 离线安装包打包。
