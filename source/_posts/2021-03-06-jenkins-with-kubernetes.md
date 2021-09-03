---
title: Jenkins 大叔与 kubernetes 船长手牵手 🧑‍🤝‍🧑
date: 2021-03-06
updated: 2021-03-07
slug:
categories: 技术
tag:
  - Jenkins
  - kubernetes
copyright: true
comment: true
---

## 背景

虽然云原生时代有了 [JenkinsX](https://jenkins-x.io/)、[Drone](https://www.drone.io/)、[Tekton](https://tekton.dev) 这样的后起之秀，但 Jenkins 这样一个老牌的 CI/CD 工具仍是各大公司主流的使用方案。比如我司的私有云产品打包发布就是用这老家伙完成的。然而传统的 Jenkins Slave 一主多从方式会存在一些痛点，比如：

* 每个 Slave 的配置环境不一样，来完成不同语言的编译打包等操作，但是这些差异化的配置导致管理起来非常不方便，维护起来也是比较费劲
* 资源分配不均衡，有的 Slave 要运行的 job 出现排队等待，而有的 Slave 处于空闲状态
* 资源有浪费，每台 Slave 可能是物理机或者虚拟机，当 Slave 处于空闲状态时，也不会完全释放掉资源。

正因为上面的 Jenkins slave 存在这些种种痛点，我们渴望一种更高效更可靠的方式来完成这个 CI/CD 流程，而 Docker 虚拟化容器技术能很好的解决这个痛点，又特别是在 Kubernetes 集群环境下面能够更好来解决上面的问题，下图是基于 Kubernetes 搭建 Jenkins slave 集群的简单示意图：

![k8s-jenkins](https://p.k8s.li/k8s-jenkins-slave.png)

从图上可以看到 Jenkins Master 是以 docker-compose 的方式运行在一个节点上。Jenkins Slave 以 Pod 形式运行在 Kubernetes 集群的 Node 上，并且它不是一直处于运行状态，它会按照需求动态的创建并自动删除。这种方式的工作流程大致为：当 Jenkins Master 接受到 Build 请求时，会根据配置的 Label 动态创建一个运行在 Pod 中的 Jenkins Slave 并注册到 Master 上，当运行完 Job 后，这个 Slave 会被注销并且这个 Pod 也会自动删除，恢复到最初状态。

那么我们使用这种方式带来了以下好处：

* **动态伸缩**，合理使用资源，每次运行 Job 时，会自动创建一个 Jenkins Slave，Job 完成后，Slave 自动注销并删除容器，资源自动释放，而且 Kubernetes 会根据每个资源的使用情况，动态分配 Slave 到空闲的节点上创建，降低出现因某节点资源利用率高，还排队等待在该节点的情况。
* **扩展性好**，当 Kubernetes 集群的资源严重不足而导致 Job 排队等待时，可以很容易的添加一个 Kubernetes Node 到集群中，从而实现扩展。

上面的大半段复制粘贴自 [基于 Jenkins 的 CI/CD (一)](https://www.qikqiak.com/k8s-book/docs/36.Jenkins%20Slave.html) 🤐

## kubernetes 集群

关于 kubernetes 集群部署，使用 kubeadm 部署是最为方便的了，可参考我很早之前写过的文章《[使用 kubeadm 快速部署体验 K8s](https://blog.k8s.li/kubeadm-deploy-k8s-v1.17.4.html)》，在这里只是简单介绍一下：

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

##  Jenkins master

至于  Jenkins master 的部署方式，个人建议使用 docker-compose 来部署。运行在 kubernetes 集群集群中也没什么毛病，可以参考 [基于 Jenkins 的 CI/CD (一)](https://www.qikqiak.com/k8s-book/docs/36.Jenkins%20Slave.html) 这篇博客。但从个人运维踩的坑来讲，还是将  Jenkins master 独立于 kubernetes 集群部署比较方便😂。

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

| 参数                                  | 值                         | 说明                                     |
| ------------------------------------- | -------------------------- | ---------------------------------------- |
| 名称                                  | kubernetes                 | 也是后面 pod 模板中的 `cloud` 的值       |
| 凭据                                  | kubeconfig 凭据 id         | 使用 kubeconfig 文件来连接集群           |
| Kubernetes 地址                       | 默认即可                   |                                          |
| Use Jenkins Proxy                     | 默认即可                   |                                          |
| Kubernetes 服务证书 key               | 默认即可                   |                                          |
| 禁用 HTTPS 证书检查                   | 默认即可                   |                                          |
| Kubernetes 命名空间                   | 默认即可                   |                                          |
| WebSocket                             | 默认即可                   |                                          |
| Direct Connection                     | 默认即可                   |                                          |
| Jenkins 地址                          | http://jenkins.k8s.li:8080 | Jenkins pod 连接  Jenkins master 的  URL |
| Jenkins 通道                          | 50000                      | Jenkins `JNLP` 的端口，默认为 50000      |
| Connection Timeout                    | 默认即可                   | Jenkins 连接 kubernetes 超时时间         |
| Read Timeout                          | 默认即可                   |                                          |
| 容器数量                              | 默认即可                   | Jenkins pod 创建的最大数量               |
| Pod Labels                            | 默认即可                   | Jenkins pod 的 lables                    |
| 连接 Kubernetes API 的最大连接数      | 默认即可                   |                                          |
| Seconds to wait for pod to be running | 默认即可                   | 等待 pod 正常 running 的时间             |

- 在 Jenkins 的凭据那里添加上 kubeconfig 文件，凭据的类型选择为 `Secret file`，然后将上面使用 kubeadm 部署生成的 kubeconfig 上传到这里。

![image-20210306111037947](https://p.k8s.li/image-20210306111037947.png)

- 点击连接测试，如果提示 `Connected to Kubernetes v1.19.8` 就说明已经成功连接上了 kubernetes 集群。

![image-20210306111148462](https://p.k8s.li/image-20210306111148462.png)

-   关于 pod 模板

其实就是配置 Jenkins Slave 运行的 Pod 模板，个人不太建议使用插件中的模板去配置，推荐将 pod 的模板放在 Jenkinsfile 中，因为这些配置与我们的流水线紧密相关，把 pod 的配置存储在 Jenkins 的插件里实在是不太方便；不方便后续的迁移备份之类的工作；后续插件升级后这些配置也可能会丢失。因此建议将 pod 模板的配置直接定义在 Jenkinsfile 中，灵活性更高一些，不会受 Jenkins 插件升级的影响。总之用代码去管理这些 pod 配置维护成本将会少很多。

## Jenkinsfile

- 流水线 `Jenkinsfile`，下面是一个简单的任务，用于构建 [webp-server-go](https://github.com/webp-sh/webp_server_go) 项目的 docker 镜像。

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

- pod 模版如下，将模板的内容复制粘贴到上面的 Jenkinsfile 中。在容器中构建镜像，我们使用 dind 的方案：将 pod 所在宿主机的 docker sock 文件挂载到 pod 的容器内，pod 容器内只要安装好 docker-cli 工具就可以像宿主机那样直接使用 docker 了。

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

定义好 jenkinsfile 文件并且构建好 pod 模板中的镜像后，接下来我们开始使用它来创建流水线任务。

## 流水线

- 在 Jenkins 上新建一个任务，选择任务的类型为 `流水线`

![image-20210306185651025](https://p.k8s.li/image-20210306185651025.png)

- 将定义好的 Jenkinsfile 内容复制粘贴到流水线定义 `Pipeline script` 中并点击保存。在新建好的 Job 页面点击 `立即构建` 来运行流水线任务。

![image-20210306185838845](https://p.k8s.li/image-20210306185838845.png)

- 在 kubernetes 集群的机器上使用 kubectl 命令查看 pod 是否正常 Running

```bash
root@jenkins:~ # kubectl get pod
NAME                              READY   STATUS    RESTARTS   AGE
jenkins-webps-9-bs78x-5x204   2/2     Running   0          66s
```

- Job 正常运行并且状态为绿色表明该 job 已经成功执行了。

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

这是因为 Jenkins pod 中的 jnlp 容器无法连接  Jenkins master。可以检查一下 Jenkins master 上 `系统管理 > 节点管理 > Configure Clouds` 中 `Jenkins 地址` 和 `Jenkins 通道` 这两个参数是否配置正确。

## 结束

到此为止，我们就完成了让 Jenkins 大叔与 kubernetes 船长手牵手🧑‍🤝‍🧑啦！上面使用了一个简单的例子来展示了如何将 Jenkins 的 Job 任务运行在 kubernetes 集群上，但在实际工作中遇到的情形可能比这要复杂一些，流水线需要配置的参数也要多一些。那么我将会在下一篇博客中再讲一下高级的用法：使用 Jenkins 完成 kubespray 离线安装包打包。

## 参考

-   [使用 Kubernetes 和 Jenkins 创建一个 CI/CD 流水线](https://jenkins-zh.cn/wechat/articles/2020/03/2020-03-10-create-a-ci-cd-pipeline-with-kubernetes-and-jenkins/)
-   [基于 Jenkins 的 CI/CD (一)](https://www.qikqiak.com/k8s-book/docs/36.Jenkins%20Slave.html)

-   [PingCAP 面试：Jenkins 和 Kubernetes](https://a-wing.top/kubernetes/2021/01/27/jenkins_and_kubernetes.html)
-   [基于 Kubernetes 的 Jenkins 服务也可以去 Docker 了](https://www.chenshaowen.com/blog/using-podman-to-build-images-under-kubernetes-and-jenkins.html)

-   [Jenkins Pipeline 使用及调试](https://www.chenshaowen.com/blog/jenkins-pipeline-usging-and-debug.html)
-   [在 Kubernetes 上动态创建 Jenkins Slave](https://www.chenshaowen.com/blog/creating-jenkins-slave-dynamically-on-kubernetes.html)
-   [Jenkins X 不是 Jenkins ，而是一个技术栈](https://www.chenshaowen.com/blog/jenkins-x-is-not-jenkins-but-stack.html)
-   [Jenkins CI/CD (一) 基于角色的授权策略](https://atbug.com/using-role-based-authorization-strategy-in-jenkins/)