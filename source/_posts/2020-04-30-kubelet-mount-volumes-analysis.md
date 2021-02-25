---
title: kubelet 挂载 volume 原理分析
date: 2020-05-01
updated: 2020-05-01
slug:
categories: 技术
tag:
  - kubernetes
  - docker
  - 容器
  - 存储
  - volumes
copyright: true
comment: true
---

最近在 kubernetes 中使用 NFS 存储的时候遇到了一个小问题，也找到了解决办法，不过还是想深入地了解一下 kubelet 挂载存储的原理和过程，于是就水了这篇博客 😂。虽然平时也知道 PV 、PVC 、存储类等怎么使用，但背后的过程和原理却没有深究过，有点一知半解的感觉。唉，太菜了 😑 （`流下了没有技术的眼泪.jpg`

## 疑惑

> 当使用 NFS 存储的 Pod 调度到没有安装 NFS client (nfs-utils 、nfs-common) Node 节点上的时候，会提示 NFS volume 挂载失败，Node 宿主机安装上 NFS client 后就可以正常挂载了，我想是不是 kubelet 在启动容器之前是不是调用 system-run 去挂载 NFS ，如果 Node 宿主机没有安装 NFS client 就无法挂载。
>
> 翻了一下源码 [mount_linux.go](https://github.com/kubernetes/kubernetes/blob/master/vendor/k8s.io/utils/mount/mount_linux.go#L115) 和 [49640](https://github.com/kubernetes/kubernetes/pull/49640) 这个 PR。里面提到的是 kubelet 挂载存储卷的时候使用 system-run 挂载，这样一来，即便 kubelet 挂掉或者重启的时候也不会影响到容器使用 kubelet 挂载的存储卷。

请教了一下两个大佬 [Yiran](https://zdyxry.github.io/) 和 [高策](http://gaocegege.com/Blog/about/)，他们也不太熟悉😂，不过也找到了解决思路。在使用 GlusterFS 的时候，Node 节点也需要安装 GlusterFS 的客户端，不然 kubelet 也是无法挂载 Pod 的 volume。由此可以确认的是： kubelet 在为 Pod 挂载 volume 的时候，根据 volume 的类型（NFS、GlusterFS、Ceph 等），Pod 所在的 Node 节点宿主机也需要安装好对应的客户端程序。

## 问题复现

集群信息：

```shell
[root@k8s-master-01 opt]# kubectl get node
NAME            STATUS   ROLES    AGE    VERSION
k8s-master-01   Ready    master   8d     v1.17.4
k8s-master-02   Ready    master   8d     v1.17.4
k8s-master-03   Ready    master   8d     v1.17.4
k8s-node-02     Ready    <none> 8d     v1.17.4
k8s-node-3      Ready    <none> 3d3h   v1.17.4
node1           Ready    <none> 108s   v1.17.4
```

为了方便复现问题还是在 Rancher 上创建了 PV 和 PVC，以及包含两个 Pod 的一个 `Deploment`，在创建 Deploment 的时候，指定将 Pod 调度到新加入的节点上，即这个节点上并没有安装 NFS 客户端。

**PV 信息如下：**

```shell
[root@k8s-master-01 opt]# kubectl describe pv nfs211
Name:            nfs211
Labels:          cattle.io/creator=norman
Annotations:     field.cattle.io/creatorId: user-gwgpp
                 pv.kubernetes.io/bound-by-controller: yes
Finalizers:      [kubernetes.io/pv-protection]
StorageClass:    nfs216
Status:          Bound
Claim:           ops-test/nfs-211
Reclaim Policy:  Retain
Access Modes:    RWX
VolumeMode:      Filesystem
Capacity:        10Gi
Node Affinity:   <none>
Message:
Source:
    Type:      NFS (an NFS mount that lasts the lifetime of a pod)
    Server:    10.20.172.211
    Path:      /nfs
    ReadOnly:  false
Events:        <none>
```

**PVC 信息如下**

```json
{
    "accessModes": [
        "ReadWriteMany"
    ],
    "annotations": {
        "pv.kubernetes.io/bind-completed": "yes"
    },
    "baseType": "persistentVolumeClaim",
    "created": "2020-04-30T08:59:15Z",
    "createdTS": 1588237155000,
    "creatorId": "user-gwgpp",
    "id": "ops-test:nfs-211",
    "labels": {
        "cattle.io/creator": "norman"
    },
    "links": {
        "remove": "…/v3/project/c-rl5jz:p-knsxt/persistentVolumeClaims/ops-test:nfs-211",
        "self": "…/v3/project/c-rl5jz:p-knsxt/persistentVolumeClaims/ops-test:nfs-211",
        "update": "…/v3/project/c-rl5jz:p-knsxt/persistentVolumeClaims/ops-test:nfs-211",
        "yaml": "…/v3/project/c-rl5jz:p-knsxt/persistentVolumeClaims/ops-test:nfs-211/yaml"
    },
    "name": "nfs-211",
    "namespaceId": "ops-test",
    "projectId": "c-rl5jz:p-knsxt",
    "resources": {
        "requests": {
            "storage": "10Gi"
        },
        "type": "/v3/project/schemas/resourceRequirements"
    },
    "state": "bound",
    "status": {
        "accessModes": [
            "ReadWriteMany"
        ],
        "capacity": {
            "storage": "10Gi"
        },
        "phase": "Bound",
        "type": "/v3/project/schemas/persistentVolumeClaimStatus"
    },
    "storageClassId": "nfs216",
    "transitioning": "no",
    "transitioningMessage": "",
    "type": "persistentVolumeClaim",
    "uuid": "660dc8d1-7911-4d30-b575-b54990de8667",
    "volumeId": "nfs211",
    "volumeMode": "Filesystem"
}

```

**Deploment 信息如下：**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
    field.cattle.io/creatorId: user-gwgpp
  creationTimestamp: "2020-04-30T09:00:19Z"
  generation: 1
  labels:
    cattle.io/creator: norman
    workload.user.cattle.io/workloadselector: deployment-ops-test-node1-nfs-test
  name: node1-nfs-test
  namespace: ops-test
  resourceVersion: "1940561"
  selfLink: /apis/apps/v1/namespaces/ops-test/deployments/node1-nfs-test
  uid: 5d14a158-1eef-4a94-8433-15ad002ee55c
spec:
  progressDeadlineSeconds: 600
  replicas: 2
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      workload.user.cattle.io/workloadselector: deployment-ops-test-node1-nfs-test
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      annotations:
        cattle.io/timestamp: "2020-04-30T09:01:05Z"
        workload.cattle.io/state: '{"bm9kZTE=":"c-rl5jz:machine-wbs6r"}'
      creationTimestamp: null
      labels:
        workload.user.cattle.io/workloadselector: deployment-ops-test-node1-nfs-test
    spec:
      containers:
      - image: alpine
        imagePullPolicy: Always
        name: node1-nfs-test
        resources: {}
        securityContext:
          allowPrivilegeEscalation: false
          capabilities: {}
          privileged: false
          readOnlyRootFilesystem: false
          runAsNonRoot: false
        stdin: true
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        tty: true
        volumeMounts:
        - mountPath: /tmp
          name: vol1
      dnsPolicy: ClusterFirst
      nodeName: node1
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
      - name: vol1
        persistentVolumeClaim:
          claimName: nfs-211
```

创建完 Deploment 之后，使用 kubectl get pod 命令查看 Pod 创建的进度，发现一直卡在 `ContainerCreating` 状态

```shell
[root@k8s-master-01 opt]# kubectl get pod -n ops-test
NAME                              READY   STATUS              RESTARTS   AGE
node1-nfs-test-547c4d7678-j6kwv   0/1     ContainerCreating   0          2m12s
node1-nfs-test-547c4d7678-vwdqg   0/1     ContainerCreating   0          2m12s
```

kubectl describe pod 的日志如下：

```shell
[root@k8s-master-01 opt]# kubectl describe pod node1-nfs-test-547c4d7678-j6kwv -n ops-test
Name:           node1-nfs-test-547c4d7678-j6kwv
Namespace:      ops-test
Priority:       0
Node:           node1/10.10.107.214
Start Time:     Thu, 30 Apr 2020 17:00:33 +0800
Labels:         pod-template-hash=547c4d7678
                workload.user.cattle.io/workloadselector=deployment-ops-test-node1-nfs-test
Annotations:    cattle.io/timestamp: 2020-04-30T09:01:05Z
                workload.cattle.io/state: {"bm9kZTE=":"c-rl5jz:machine-wbs6r"}
Status:         Pending
IP:
IPs:            <none>
Controlled By:  ReplicaSet/node1-nfs-test-547c4d7678
Containers:
  node1-nfs-test:
    Container ID:
    Image:          alpine
    Image ID:
    Port:           <none>
    Host Port:      <none>
    State:          Waiting
      Reason:       ContainerCreating
    Ready:          False
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /tmp from vol1 (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-f6wjj (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             False
  ContainersReady   False
  PodScheduled      True
Volumes:
  vol1:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  nfs-211
    ReadOnly:   false
  default-token-f6wjj:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-f6wjj
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type     Reason       Age    From            Message
  ----  ------  ---- ----     -------
  Warning  FailedMount  8m49s  kubelet, node1  MountVolume.SetUp failed for volume "nfs211" : mount failed: exit status 32
Mounting command: systemd-run
Mounting arguments: --description=Kubernetes transient mount for /var/lib/kubelet/pods/cddc94e7-8033-4150-bed5-d141e3b71e49/volumes/kubernetes.io~nfs/nfs211 --scope -- mount -t nfs 10.20.172.211:/nfs /var/lib/kubelet/pods/cddc94e7-8033-4150-bed5-d141e3b71e49/volumes/kubernetes.io~nfs/nfs211
Output: Running scope as unit run-38284.scope.
mount: wrong fs type, bad option, bad superblock on 10.20.172.211:/nfs,
       missing codepage or helper program, or other error
       (for several filesystems (e.g. nfs, cifs) you might
       need a /sbin/mount.<type> helper program)

       In some cases useful info is found in syslog - try
       dmesg | tail or so.
  Warning  FailedMount  8m48s  kubelet, node1  MountVolume.SetUp failed for volume "nfs211" : mount failed: exit status 32
```

在 一台没有安装 NFS 客户端的节点尝试挂载一下 NFS 存储，发现报错的日志和 kubelet 的日志相同🤔

```shell
[root@k8s-master-03 ~]# mount -t nfs 10.20.172.211:/nfs /tmp
mount: wrong fs type, bad option, bad superblock on 10.20.172.211:/nfs,
       missing codepage or helper program, or other error
       (for several filesystems (e.g. nfs, cifs) you might
       need a /sbin/mount.<type> helper program)

       In some cases useful info is found in syslog - try
       dmesg | tail or so.
```

## 解决问题

看到 kubelet 报错的日志和我们在宿主机上使用 mount 名挂载 NFS 存储时的错误一样就可以断定为是宿主机的问题。搜了一下报错日志，在 [Why do I get “wrong fs type, bad option, bad superblock” error?](https://askubuntu.com/questions/525243/why-do-i-get-wrong-fs-type-bad-option-bad-superblock-error) 得到提示说需要安装一下 NFS 客户端 (nfs-common、nfs-utils) 😂。

```shell
╭─root@node1 ~
╰─# yum install nfs-utils
………………
Install  1 Package (+15 Dependent packages)

Total download size: 1.5 M
Installed size: 4.3 M
Is this ok [y/d/N]:
```

yum 一把梭后发现 `nfs-utils` 还真没有安装😂。

安装完时候使用 kubectl 删除掉之前的 Pod，Deploment 控制器会自动帮我们将 Pod 数量调和到指定的数量。可以发现 Pod 所在宿主机安装 NFS 客户端之后 kubelet 就能正常为 Pod 挂载 volume 了 而且 Pod 也正常运行了。

```shell
[root@k8s-master-01 ~]# kubectl delete pod node1-nfs-test-547c4d7678-j6kwv node1-nfs-test-547c4d7678-vwdqg -n ops-test
pod "node1-nfs-test-547c4d7678-j6kwv" deleted
pod "node1-nfs-test-547c4d7678-vwdqg" deleted
[root@k8s-master-01 ~]# kubectl get pod -n ops-test
NAME                              READY   STATUS    RESTARTS   AGE
node1-nfs-test-7589fb4787-cknz4   1/1     Running   0          18s
node1-nfs-test-7589fb4787-l9bt2   1/1     Running   0          22s
```

进入容器内查看一下容器内挂载点的信息：

```shell
[root@k8s-master-01 ~]# kubectl exec -it node1-nfs-test-7589fb4787-cknz4 -n ops-test sh
/ # df -h
Filesystem                Size      Used Available Use% Mounted on
overlay                  28.9G      4.1G     23.3G  15% /
10.20.172.211:/nfs       28.9G     14.5G     12.9G  53% /tmp
tmpfs                     1.8G         0      1.8G   0% /sys/firmware
/ # mount
rootfs on / type rootfs (rw)
10.20.172.211:/nfs on /tmp type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.20.172.211,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.20.172.211)

10.20.172.211:/nfs on /mnt/nfs type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.20.172.211,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.20.172.211)
```

至此问题已经解决了，接下来就到了正文：开始分析一下  kubelet 为 Pod 挂载 volume 的流程和原理😂

## 分析

### 容器存储

在分析 Pod 的 volume 之前需要先了解一下 docker 容器的存储。当我们使用 `docker inspect` <容器 ID> 命令来查看容器详细信息时，在容器元数据信息的 `GraphDriver` 字段下包含着一个 `Mounts` ，而 `Mounts` 字段里的正是容器挂载的存储，其中里面的 `Type` 字段里有 `bind` 和 `volume` ，其实还有一个 `tmpfs`。

另外其中的 `Data` 字段里的 `LowerDir` 正是容器的镜像层，关于容器镜像层的讲解建议阅读一下 [Docker源码分析—存储驱动](https://arkingc.github.io/2018/01/15/2018-01-15-docker-storage-overlay2/) ，这篇源码分析👍，在这里点到为止就不再细究了😂

> 现在，我们已经知道了解了层的创建和删除过程。但是我们一直没有提到一个问题：**我们在容器内看到的文件存在哪？**
>
> 我们已经知道层目录下有diff，merged和work 3个目录。diff存储的是该层的文件，work是执行一些特定操作时所要用到的目录，所以实际上，**在容器内看到的文件，就存在于merged目录下**
>
> **merged目录在容器未运行时，是一个空目录，当容器启动时会将该容器所有层的diff目录进行联合挂载，挂载到merged目录下，挂载时使用的文件系统就是内核OverlayFS文件系统**
>
> > 如果有看过我关于内核OverlayFS相关的博文，这里应该已经对Docker的overlay2存储驱动与内核OverlayFS的关系有了一个比较清晰的认识
>
> **当挂载完成后，容器处于一个子文件系统命名空间，只能看到merged目录下的文件，相当于chroot命令的效果**
>
> 所以，在停止一个容器时，实际上就是对merged目录执行一个卸载命令

```json
"GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/2a846f62b759d87bf8b2731960c4031585fb4ee14bbf313f58e0374c4fee9ce0-init/diff:/var/lib/docker/overlay2/29f9a1e9523d4ec323402a3c2da8a5e288cfe0e6f3168a57dd2388b63775c20a/diff:/var/lib/docker/overlay2/015afa447ae2fcfa592d257644312b286173b9a00d0f2017a4c6ede448a87d47/diff:/var/lib/docker/overlay2/2f71b56cd5550bf299ed33a04e385ef5578511e3a17d35162148f4b84bda4b26/diff",
                "MergedDir": "/var/lib/docker/overlay2/2a846f62b759d87bf8b2731960c4031585fb4ee14bbf313f58e0374c4fee9ce0/merged",
                "UpperDir": "/var/lib/docker/overlay2/2a846f62b759d87bf8b2731960c4031585fb4ee14bbf313f58e0374c4fee9ce0/diff",
                "WorkDir": "/var/lib/docker/overlay2/2a846f62b759d87bf8b2731960c4031585fb4ee14bbf313f58e0374c4fee9ce0/work"
            },
            "Name": "overlay2"
        },
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/opt/wordpress-nginx-docker/webp-server/config.json",
                "Destination": "/etc/config.json",
                "Mode": "rw",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "bind",
                "Source": "/opt/wordpress-nginx-docker/wordpress",
                "Destination": "/var/www/html",
                "Mode": "rw",
                "RW": true,
                "Propagation": "rprivate"
            },
            {
                "Type": "volume",
                "Name": "36d087638f2e9ba8472c441bcf906320cfd80419874291f56e039e4f7d1278e7",
                "Source": "/var/lib/docker/volumes/36d087638f2e9ba8472c441bcf906320cfd80419874291f56e039e4f7d1278e7/_data",
                "Destination": "/opt/exhaust",
                "Driver": "local",
                "Mode": "",
                "RW": true,
                "Propagation": ""
            }
        ]
```

根据 docker 的官方文档 [Manage data in Docker](https://docs.docker.com/storage/) ，docker 提供了 3 种方法将数据从 Docker 宿主机挂载（mount）到容器内，如下：

![](https://p.k8s.li/types-of-mounts.png)

`图片从 Docker 官方文档偷来的😂`

> - **Volumes** are stored in a part of the host filesystem which is *managed by Docker* (`/var/lib/docker/volumes/` on Linux). Non-Docker processes should not modify this part of the filesystem. Volumes are the best way to persist data in Docker.
> - **Bind mounts** may be stored *anywhere* on the host system. They may even be important system files or directories. Non-Docker processes on the Docker host or a Docker container can modify them at any time.
> - **`tmpfs` mounts** are stored in the host system’s memory only, and are never written to the host system’s filesystem.

可以看到容器可以使用的存储有三种：

- Volumes：使用 Docker 来管理的存储，默认存放在 ``/var/lib/docker/volumes/`` 下，我们可以使用 `docker volume` 子命令来管理这些 volume ，可以创建、查看、列出、清空、删除等操作。非 docker 进程不应该去修改该目录下的文件，**卷是 Docker 容器持久化数据的最好方式**。

> `-v`或`--volume`：由3个域组成，`':'`分隔
>
> - 第一个域：对于命名卷，为卷名；匿名卷，则忽略，此时会创建匿名卷
> - 第二个域：容器中的挂载点
> - 第三个域：可选参数，由`','`隔开，如`ro`

```shell
╭─root@sg-02 /home/ubuntu
╰─# docker volume
Usage:  docker volume COMMAND
Manage volumes
Commands:
  create      Create a volume
  inspect     Display detailed information on one or more volumes
  ls          List volumes
  prune       Remove all unused local volumes
  rm          Remove one or more volumes
Run 'docker volume COMMAND --help' for more information on a command.
```

假如在写 `Dockerfile` 的时候，使用 `VOLUME` 指令指定容器内的路径。在我们启动容器的时候 docker 会帮我们创建一个持久化存储的 volume。也可在 `docker run` 或者 `docker-compose.yaml` 指定 `volume` 。

```json
╭─root@sg-02 /home/ubuntu
╰─# docker volume ls
DRIVER              VOLUME NAME
local               docker-elk_elasticsearch
local               opt
╭─root@sg-02 /home/ubuntu
╰─# docker volume inspect opt
[
    {
        "CreatedAt": "2020-03-12T06:58:15Z",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/opt/_data",
        "Name": "opt",
        "Options": null,
        "Scope": "local"
    }
]
╭─root@sg-02 /home/ubuntu
╰─# docker inspect docker-elk_elasticsearch
[
    {
        "CreatedAt": "2020-04-24T01:37:07Z",
        "Driver": "local",
        "Labels": {
            "com.docker.compose.project": "docker-elk",
            "com.docker.compose.version": "1.25.4",
            "com.docker.compose.volume": "elasticsearch"
        },
        "Mountpoint": "/var/lib/docker/volumes/docker-elk_elasticsearch/_data",
        "Name": "docker-elk_elasticsearch",
        "Options": null,
        "Scope": "local"
    }
]
```

- Bind mounts：

使用 `Bind mounts` 将宿主机的目录或者文件挂载进容器内，这个文件和目录可以是宿主机文件系统上的任意位置，可以不受 docker 所管理，比如 kubelet 的 volumes 目录：`/var/lib/kubelet/pods/<Pod的ID>/volumes/` 。 kubelet 在为 Pod 挂载存储的时候也正是通过 `Bind mounts` 的方式将 Pod 的 volumes 挂载到容器内。所以当我们使用 docker inspect 命令去查看 Pod 内容器的 `Mounts` 信息是，`Type` 类型多为 `bind` 或者 `tmpfs` ，很少会用到 `volumes` 。可以理解为 kubelet 的 volumes 目录就像 docker 的 volumes 那样，是由 kubelet 自己来管理的，其他用户或进程不应该去修改它。

```json
╭─root@k8s-node-3 ~
╰─# docker inspect f1111ee6ac84
"Mounts": [
  {
      "Type": "bind",
      "Source": "/var/lib/kubelet/pods/73fed6f3-4cbe-46a7-af7b-6fd912e6ebd4/volumes/kubernetes.io~nfs/nfs211",
      "Destination": "/var/www/html",
      "Mode": "",
      "RW": true,
      "Propagation": "rprivate"
  },
  {
      "Type": "bind",
      "Source": "/var/lib/kubelet/pods/73fed6f3-4cbe-46a7-af7b-6fd912e6ebd4/volumes/kubernetes.io~secret/default-token-wgfd9",
      "Destination": "/var/run/secrets/kubernetes.io/serviceaccount",
      "Mode": "ro,Z",
      "RW": false,
      "Propagation": "rprivate"
  },
  {
      "Type": "bind",
      "Source": "/var/lib/kubelet/pods/73fed6f3-4cbe-46a7-af7b-6fd912e6ebd4/etc-hosts",
      "Destination": "/etc/hosts",
      "Mode": "Z",
      "RW": true,
      "Propagation": "rprivate"
  },
  {
      "Type": "bind",
      "Source": "/var/lib/kubelet/pods/73fed6f3-4cbe-46a7-af7b-6fd912e6ebd4/containers/nginx/f760f2be",
      "Destination": "/dev/termination-log",
      "Mode": "Z",
      "RW": true,
      "Propagation": "rprivate"
  }
]
```

使用`Bind mounts`可能会有安全问题：容器中运行的进程可以修改宿主机的文件系统，包括创建，修改，删除重要的系统文件或目录。不过可以加参数挂载为只读。

> `--mount`：由多个`','`隔开的键值对<key>=<value>组成：
>
> - 挂载类型：key为`type`，value为`bind`、`volume`或`tmpfs`
> - 挂载源：key为`source`或`src`，对于命名卷，value为卷名，对于匿名卷，则忽略
> - 容器中的挂载点：key为`destination`、`dst`或`target`，value为容器中的路径
> - 读写类型：value为`readonly`，没有key
> - 读写类型：value为`readonly`，没有key
> - volume-opt选项，可以出现多次。比如`volume-driver=local,volume-opt=type=nfs,...`

- tmps：

    用来存储一些不需要持久化的状态或敏感数据，比如 `kubernetes` 中的各种 `secret` 。比如当我们使用 `kubectl exec -it POD` ，进入到 Pod 容器内，然后使用 mount 命令查看容器内的挂载点信息就会有很多 tmpfs 类型的挂载点。其中的 `/run/secrets/kubernetes.io/serviceaccount/` 目录下就有着比较敏感的信息。

    ```shell
    tmpfs on /run/secrets/kubernetes.io/serviceaccount type tmpfs (ro,relatime)
    / # tree /run/secrets/kubernetes.io/serviceaccount/
    /run/secrets/kubernetes.io/serviceaccount/
    ├── ca.crt -> ..data/ca.crt
    ├── namespace -> ..data/namespace
    └── token -> ..data/token
    ```

> - `--tmpfs`：直接指定容器中的挂载点。不允许指定任何配置选项
>
> - --mount：由多个','隔开的键值对<key>=<value>组成：
>
>     挂载类型：key为`type`，value为`bind`、`volume`或`tmpfs`
>
>     容器中的挂载点：key为`destination`、`dst`或`target`，value为容器中的路径
>
>     `tmpfs-size`和`tmpfs-mode`选项

### kubelet 挂载存储

当对容器存储的类型有了大致了解之后，我们再来看一下 Pod 是如何进行 volume 挂载的。

当 Pod 被调度到一个 Node 节点上后，Node 节点上的 kubelet 组件就会为这个 Pod 创建它的 Volume 目录，默认情况下 kubelet 为 Volume 创建的目录在 kubelet 的工作目录（默认在 `/var/lib/kubelet` ），在 kubelet 启动的时候可以根据 `–root-dir` 参数来指定工作目录，不过一般没啥特殊要求还是使用默认的就好😂。Pod 的 volume 目录就在该目录下，路径格式如下：

```shell
/var/lib/kubelet/pods/<Pod的ID>/volumes/kubernetes.io~<Volume类型>/<Volume名字>

# 比如:
/var/lib/kubelet/pods/c4b1998b-f5c1-440a-b9bc-7fbf87f3c267/volumes/kubernetes.io~nfs/nfs211
```

在 Node 节点上可以使用 mount 命令来查看 kubelet 为 Pod 挂载的挂载点信息。

```shell
10.10.107.216:/nfs on /var/lib/kubelet/pods/6750b756-d8e4-448a-93f9-8906f9c44788/volumes/kubernetes.io~nfs/nfs-test type nfs (rw,relatime,vers=3,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.10.107.216,mountvers=3,mountport=56389,mountproto=udp,local_lock=none,addr=10.10.107.216)
```

```shell
╭─root@k8s-node-3 ~
╰─# mount | grep kubelet
tmpfs on /var/lib/kubelet/pods/45c55c5e-ce96-47fd-94b3-60a334e5a44d/volumes/kubernetes.io~secret/kube-proxy-token-h4dfb type tmpfs (rw,relatime,seclabel)
tmpfs on /var/lib/kubelet/pods/3fb63baa-27ec-4d76-8028-39a0a8f91749/volumes/kubernetes.io~secret/calico-node-token-4hks6 type tmpfs (rw,relatime,seclabel)
tmpfs on /var/lib/kubelet/pods/05c75313-f932-4913-b09f-d7bccdfb6e62/volumes/kubernetes.io~secret/nginx-ingress-token-5569x type tmpfs (rw,relatime,seclabel)
10.20.172.211:/nfs on /var/lib/kubelet/pods/c4b1998b-f5c1-440a-b9bc-7fbf87f3c267/volumes/kubernetes.io~nfs/nfs211 type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.20.172.211,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.20.172.211)
tmpfs on /var/lib/kubelet/pods/73fed6f3-4cbe-46a7-af7b-6fd912e6ebd4/volumes/kubernetes.io~secret/default-token-wgfd9 type tmpfs (rw,relatime,seclabel)
```

其中 kubernetes 目前支持的 Volume 的类型，可以使用 `kubectl explain pod.spec.volumes`  来查看。

```shell
╭─root@k8s-master-01 ~
╰─# kubectl explain pod.spec.volumes | grep Object | cut -d "<" -f1
RESOURCE: volumes
awsElasticBlockStore
azureDisk
azureFile
cephfs
cinder
configMap
csi
downwardAPI
emptyDir
fc
flexVolume
flocker
gcePersistentDisk
gitRepo
glusterfs
hostPath
iscsi
nfs
persistentVolumeClaim
photonPersistentDisk
portworxVolume
projected
quobyte
rbd
scaleIO
secret
storageos
vsphereVolume
```

### 管 systemd 什么事儿？

我们来回顾一下当初的错误日志：

```verilog
Events:
  Type     Reason       Age    From            Message
  ----  ------  ---- ----     -------
  Warning  FailedMount  8m49s  kubelet, node1  MountVolume.SetUp failed for volume "nfs211" : mount failed: exit status 32
Mounting command: systemd-run
Mounting arguments: --description=Kubernetes transient mount for /var/lib/kubelet/pods/cddc94e7-8033-4150-bed5-d141e3b71e49/volumes/kubernetes.io~nfs/nfs211 --scope -- mount -t nfs 10.20.172.211:/nfs /var/lib/kubelet/pods/cddc94e7-8033-4150-bed5-d141e3b71e49/volumes/kubernetes.io~nfs/nfs211
Output: Running scope as unit run-38284.scope.
mount: wrong fs type, bad option, bad superblock on 10.20.172.211:/nfs,
       missing codepage or helper program, or other error
       (for several filesystems (e.g. nfs, cifs) you might
       need a /sbin/mount.<type> helper program)

       In some cases useful info is found in syslog - try
       dmesg | tail or so.
  Warning  FailedMount  8m48s  kubelet, node1  MountVolume.SetUp failed for volume "nfs211" : mount failed: exit status 32
```

咦？当时我还寻思着 kubelet 挂载 volumes 和 systemd 什么关系？`systemd` 这个大妈怎么又来管这事儿了😂（之前我写过一篇[《Linux 的小伙伴 systemd 详解》](https://blog.k8s.li/systemd.html) ，戏称 systemd 是 Linux 的小伙伴，看来这个说法是不妥的。systemd 简直就是 Linux 里的物业大妈好嘛🤣，上管 service 下管 dev 、 mount 设备等。屑，简直就是个物业大妈管这管那的。回到正题，于是顺着这条报错日志顺藤摸瓜找到了 [Run mount in its own systemd scope.](https://github.com/kubernetes/kubernetes/pull/49640) 这个 PR。

> Kubelet needs to run /bin/mount in its own cgroup.
>
> - When kubelet runs as a systemd service, "systemctl restart kubelet" may kill all processes in the same cgroup and thus terminate fuse daemons that are needed for gluster and cephfs mounts.
> - When kubelet runs in a docker container, restart of the container kills all fuse daemons started in the container.
>
> Killing fuse daemons is bad, it basically unmounts volumes from running pods.
>
> This patch runs mount via "systemd-run --scope /bin/mount ...", which makes sure that any fuse daemons are forked in its own systemd scope (= cgroup) and they will survive restart of kubelet's systemd service or docker container.
>
> This helps with [#34965](https://github.com/kubernetes/kubernetes/issues/34965)
>
> As a downside, each new fuse daemon will run in its own transient systemd service and systemctl output may be cluttered.

正如提这个 PR 的大佬讲的，（之前）kubelet 需要在它自己的 `cgroup` 里运行宿主机上的 `/bin/mount` 来为 Pod 挂载 volumes ，而当 kubelet 进程重启或者挂掉的时候，这些在 kubelet 的  `cgroup` 里运行的进程也将会挂掉，比如（gluster，ceph）。然后大佬的这个 patch 通过 `systemd-run --scope /bin/mount` 来去启动一个临时的 systemd 单元来为 Pod 挂载 volumes，这样一来这些 `fuse daemons`  进程（gluster，ceph）就会 forked 到它自己的 systemd scope 里，这样即便 kubelet 重启或者挂掉也不会影响正在运行的容器使用 volumes。

这一点像 [containerd](https://github.com/containerd/containerd) 之于 dockerd ，即便 dockerd 重启也不会影响到容器的运行，因为，在运行时这一块，真正运行容器的是 containerd 下的各个 containerd-shim 子进程，可以使用 pstree 命令来看一下这种层级关系。

```shell
├─containerd─┬─5*[containerd-shim─┬─pause]
│            │                    └─9*[{containerd-shim}]]
│            ├─containerd-shim─┬─pause
│            │                 └─10*[{containerd-shim}]
│            ├─containerd-shim─┬─etcd───15*[{etcd}]
│            │                 └─9*[{containerd-shim}]
│            ├─containerd-shim─┬─kube-controller───12*[{kube-controller}]
│            │                 └─9*[{containerd-shim}]
│            ├─containerd-shim─┬─kube-apiserver───14*[{kube-apiserver}]
│            │                 └─9*[{containerd-shim}]
│            ├─containerd-shim─┬─kube-scheduler───13*[{kube-scheduler}]
│            │                 └─9*[{containerd-shim}]
│            ├─containerd-shim─┬─kube-proxy───11*[{kube-proxy}]
│            │                 └─9*[{containerd-shim}]
│            ├─containerd-shim─┬─flanneld───15*[{flanneld}]
│            │                 └─9*[{containerd-shim}]
│            └─26*[{containerd}]
```

接着顺藤摸瓜翻到这个 PR 对应的源码文件  [mount_linux.go](https://github.com/kubernetes/kubernetes/blob/master/vendor/k8s.io/utils/mount/mount_linux.go#L115)，关键内容如下：

```go
// doMount runs the mount command. mounterPath is the path to mounter binary if containerized mounter is used.
// sensitiveOptions is an extention of options except they will not be logged (because they may contain sensitive material)
func (mounter *Mounter) doMount(mounterPath string, mountCmd string, source string, target string, fstype string, options []string, sensitiveOptions []string) error {
	mountArgs, mountArgsLogStr := MakeMountArgsSensitive(source, target, fstype, options, sensitiveOptions)
	if len(mounterPath) > 0 {
		mountArgs = append([]string{mountCmd}, mountArgs...)
		mountArgsLogStr = mountCmd + " " + mountArgsLogStr
		mountCmd = mounterPath
	}

	if mounter.withSystemd {
		// Try to run mount via systemd-run --scope. This will escape the
		// service where kubelet runs and any fuse daemons will be started in a
		// specific scope. kubelet service than can be restarted without killing
		// these fuse daemons.
		//
		// Complete command line (when mounterPath is not used):
		// systemd-run --description=... --scope -- mount -t <type> <what> <where>
		//
		// Expected flow:
		// * systemd-run creates a transient scope (=~ cgroup) and executes its
		//   argument (/bin/mount) there.
		// * mount does its job, forks a fuse daemon if necessary and finishes.
		//   (systemd-run --scope finishes at this point, returning mount's exit
		//   code and stdout/stderr - thats one of --scope benefits).
		// * systemd keeps the fuse daemon running in the scope (i.e. in its own
		//   cgroup) until the fuse daemon dies (another --scope benefit).
		//   Kubelet service can be restarted and the fuse daemon survives.
		// * When the fuse daemon dies (e.g. during unmount) systemd removes the
		//   scope automatically.
		//
		// systemd-mount is not used because it's too new for older distros
		// (CentOS 7, Debian Jessie).
		mountCmd, mountArgs, mountArgsLogStr = AddSystemdScopeSensitive("systemd-run", target, mountCmd, mountArgs, mountArgsLogStr)
	} else {
		// No systemd-run on the host (or we failed to check it), assume kubelet
		// does not run as a systemd service.
		// No code here, mountCmd and mountArgs are already populated.
	}

	// Logging with sensitive mount options removed.
	klog.V(4).Infof("Mounting cmd (%s) with arguments (%s)", mountCmd, mountArgsLogStr)
	command := exec.Command(mountCmd, mountArgs...)
	output, err := command.CombinedOutput()
	if err != nil {
		klog.Errorf("Mount failed: %v\nMounting command: %s\nMounting arguments: %s\nOutput: %s\n", err, mountCmd, mountArgsLogStr, string(output))
		return fmt.Errorf("mount failed: %v\nMounting command: %s\nMounting arguments: %s\nOutput: %s",
			err, mountCmd, mountArgsLogStr, string(output))
	}
	return err
}
```

来看一下 `doMount` 这个函数的几个形参：

- mounterPath ：

就是我们宿主机上的挂载命令比如 `/sbin/mount.nfs` 、`/sbin/mount.glusterfs` 等。

- mountCmd：挂载命令就是 `systemd-run`

- source：挂载存储的源路径，比如 NFS 里的 `10.10.107.211:/nfs`

- target

就是我们的 Pod 的 volume ，在 `/var/lib/kubelet/pods/<Pod的ID>/volumes/kubernetes.io~<Volume类型>/<Volume名字>` ，着目录在容器启动的时候会 bind mount 到容器内的挂载点

- fstype：文件系统类型，NFS、ceph、GlusterFS

- options []string：挂载的参数，比如 NFS 的

```shell
(rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.20.172.211,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.20.172.211)
```

- sensitiveOptions []string，这个参数没去仔细看，就略过吧（

至此 kubelet 为 Pod 挂载的原理和流程也一目了然，其实很简单的逻辑，大致可以氛围

- Attach 阶段：kubelet 使用 systemd-run 单独起一个临时的 systemd scope 来运行后端存储的客户端比如（ nfs 、gluster、ceph），将这些存储挂载到 `/var/lib/kubelet/pods/<Pod的ID>/volumes/kubernetes.io~<Volume类型>/<Volume名字>`
- Mount 阶段：容器启动的时候通过 bind mount 的方式将  `/var/lib/kubelet/pods/<Pod的ID>/volumes/kubernetes.io~<Volume类型>/<Volume名字>` 这个目录挂载到容器内。这一步相当于使用`docker run -v /var/lib/kubelet/pods/<Pod的ID>/volumes/kubernetes.io~<Volume类型>/<Volume名字>:/<容器内的目标目录> 我的镜像` 启动一个容器。

关于更详细的 CSI 存储可以参考下面提到的文章

## 参考

虽然是一篇很简单的分析，在这个过程中参考了很多的博客，没有这些大佬的分享就没有这篇文章：），这些大佬们的博客文章比我写的`不知道高到哪里去了`，所以如果你看了这篇文章还是没懂的话，不妨也看一下下面的这些文章就能豁然开朗了😂。

### 源码

- [kubernetes/mount_linux.go at master · kubernetes/kubernetes](https://github.com/kubernetes/kubernetes/blob/master/vendor/k8s.io/utils/mount/mount_linux.go#L115)

- [Run mount in its own systemd scope. by jsafrane · Pull Request #49640 · kubernetes/kubernetes](https://github.com/kubernetes/kubernetes/pull/49640)

### 源码分析

- [kubelet源码分析（四）之 Pod的创建 - 胡伟煌 | Blog](https://www.huweihuang.com/article/source-analysis/kubelet/create-pod-by-kubelet/#66-mount-volumes)

- [Kubelet源码架构简介 | ljchen's Notes](http://ljchen.net/2018/10/28/kubelet%E6%BA%90%E7%A0%81%E6%9E%B6%E6%9E%84%E7%AE%80%E4%BB%8B/)

- [kubelet 源码分析 - Beantech | Newgoo | kubernates](http://newgoo.org/2019/09/03/k8s/kubelet-%E6%BA%90%E7%A0%81/)

- ["Kubelet启动源码分析" - 徐波的博客 | Xu Blog](http://blog.xbblfz.site/2018/10/12/Kubelet%E5%90%AF%E5%8A%A8%E5%8F%8A%E5%AF%B9Docker%E5%AE%B9%E5%99%A8%E7%AE%A1%E7%90%86%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/)

- [kubelet 源码分析：启动流程 | Cizixs Write Here](https://cizixs.com/2017/06/06/kubelet-source-code-analysis-part-1/)

- [kubelet分析(三)-volumeManager-v1.5.2 | fankangbest](https://fankangbest.github.io/2017/12/17/kubelet%E5%88%86%E6%9E%90(%E4%B8%89)-volumeManager-v1-5-2/)

- [Kubernetes源码分析之VolumeManager - Je pense donc je suis](https://wenfeng-gao.github.io/post/k8s-volume-manager-source-code-analysis/)

- [startKubelet · Kubernetes 学习笔记](https://www.huweihuang.com/kubernetes-notes/code-analysis/kubelet/startKubelet.html)

### 官方文档

- [Manage data in Docker | Docker Documentation](https://docs.docker.com/storage/)

- [Use bind mounts | Docker Documentation](https://docs.docker.com/storage/bind-mounts/)

- [Use bind mounts | Docker Documentation](https://docs.docker.com/storage/bind-mounts/)

- [mount 中文手册](http://www.jinbuguo.com/man/mount.html)

- [Use the OverlayFS storage driver](https://docs.docker.com/storage/storagedriver/overlayfs-driver/)

### 相关博客

- [kubernetes 简介： kubelet 和 pod | Cizixs Write Here](https://cizixs.com/2016/10/25/kubernetes-intro-kubelet/)

- [Docker数据管理-Volume， bind mount和tmpfs mount | Youmai の Blog](https://michaelyou.github.io/2017/09/17/Docker%E6%95%B0%E6%8D%AE%E7%AE%A1%E7%90%86-Volume%EF%BC%8C-bind-mount%E5%92%8Ctmpfs-mount/)

- [存储原理 \- K8S训练营](https://www.qikqiak.com/k8strain/storage/csi/)

- [Kubernetes 挂载 subpath 的容器在 configmap 变更后重启时挂载失败](https://blog.fatedier.com/2020/04/17/pod-loopcrash-of-k8s-subpath/)

- [理解kubernetes中的Storage | Infvie's Blog](https://www.infvie.com/ops-notes/kubernetes-storage.html)

- [Docker容器数据持久化](https://arkingc.github.io/2018/12/11/2018-12-11-docker-storage-persist/)

- [Docker源码分析—镜像存储](https://arkingc.github.io/2018/01/19/2018-01-19-docker-imagestore/)

- [Docker源码分析—存储驱动](https://arkingc.github.io/2018/01/15/2018-01-15-docker-storage-overlay2/)

- [Docker存储驱动—Overlay/Overlay2「译」](https://arkingc.github.io/2017/05/05/2017-05-05-docker-filesystem-overlay/)

- [Linux 的小伙伴 systemd 详解](https://blog.k8s.li/systemd.html)

## 结束

最后祝各位还在`搬砖`的工人们节日快乐！
