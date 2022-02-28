---
title: 使用 kubectl 自动归档 argo workflow 日志
date: 2022-02-28
updated:  2022-02-28
slug:
categories: 技术
tag:
  - kubectl
  - argo-workflow
copyright: true
comment: true
---

项目上使用到 [argo-workflow](https://github.com/argoproj/argo-workflows) 作为工作流引擎来编排运行一些 [超融合](https://www.smartx.com/solution/virtualization/) 集群部署相关的任务，整套环境运行在一个单节点的 K3s 上。之所以选择 argo-workflow + K3s 的搭配主要是想尽可能少地占用系统资源，因为这套环境将来会运行在各种硬件配置不同的笔记本电脑上 😂。综合调研了一些常见的 K8s 部署工具最终就选择了系统资源占用较少的 K3s。

现在项目的一个需求就是在集群部署完成或失败之后需要将 workflow 的日志归档保存下来。虽然可以在 workflow 的 spec 字段中使用 `archiveLogs: true` 来让 argo 帮我们自动归档日志，但这个特性依赖于一个 S3 对象存储 [Artifact Repository](https://argoproj.github.io/argo-workflows/configure-artifact-repository/) 。这就意味着还要再部署一个支持 S3 对象存储的组件比如 [Minio](https://min.io/) ，直接把我给整不会了 🌚

![](https://p.k8s.li/2021-08-31-pass-tob-k8s-offline-deploy-2.jpeg)

其实嘛这个需求很简单的，我就想保存一个日志文件而已，你还再让我安装一个 [Minio](https://min.io/)，实在是太过分了！本来系统的资源十分有限，需要尽可能减少安装一些不必要依赖，为的就是将资源利用率将到最低。但现在为了归档存储一个日志文件储而大动干戈装一个 minio 实在是不划算。这就好比你费了好大功夫部署一套 3 节点的 kubernetes 集群，然而就为了运行一个静态博客那样滑稽 😂

{% raw %}

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Deployed my blog on Kubernetes <a href="https://t.co/XHXWLrmYO4">pic.twitter.com/XHXWLrmYO4</a></p>&mdash; For DevOps Eyes Only (@dexhorthy) <a href="https://twitter.com/dexhorthy/status/856639005462417409?ref_src=twsrc%5Etfw">April 24, 2017</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

{% endraw %}

对于咱这种 `用不起` S3 对象存储的穷人家孩子，还是想一些其他办法吧，毕竟自己动手丰衣足食。

## kubectl

实现起来也比较简单，对于咱这种 YAML 工程师来说，kubectl 自然再熟悉不过了。想要获取 workflow 的日志，只需要通过 kubectl logs 命令获取出 workflow 所创的 pod 日志就行了呀，要什么 S3 对象存储 😖

### 筛选 pod

对于同一个 workflow 来将，每个 stage 所创建出来的 pod name 有一定的规律。在定义 workflow 的时候，[generateName](https://argoproj.github.io/argo-workflows/fields/#objectmeta) 参数通常使用 `${name}-` 格式。以 `-` 作为分隔符，最后一个字段是随机生成的一个数字 ID，倒数第二个字段则是 argo 随机生成的 workflow ID，剩余前面的字符则是我们定义的 generateName。

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: archive-log-test-
```

```bash
archive-log-test-jzt8n-3498199655                          0/2     Completed   0               4m18s
archive-log-test-jzt8n-3618624526                          0/2     Completed   0               4m8s
archive-log-test-jzt8n-2123203324                          0/2     Completed   0               3m58s
```

在 pod 的 labels 中同样也包含着该 workflow 所对应的 ID，因此我们可以根据此 labels 过滤出该 workflow 所创建出来的 pod。

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    workflows.argoproj.io/node-id: archive-log-test-jzt8n-3498199655
    workflows.argoproj.io/node-name: archive-log-test-jzt8n[0].list-default-running-pods
  creationTimestamp: "2022-02-28T12:53:32Z"
  labels:
    workflows.argoproj.io/completed: "true"
    workflows.argoproj.io/workflow: archive-log-test-jzt8n
  name: archive-log-test-jzt8n-3498199655
  namespace: default
  ownerReferences:
  - apiVersion: argoproj.io/v1alpha1
    blockOwnerDeletion: true
    controller: true
    kind: Workflow
    name: archive-log-test-jzt8n
    uid: e91df2cb-b567-4cf0-9be5-3dd6c72854cd
  resourceVersion: "1251330"
  uid: ce37a709-8236-445b-8d00-a7926fa18ed0
```

通过 `-l lables` 过滤出一个 workflow 所创建的 pod；通过 `--sort-by` 以创建时间进行排序；通过 `-o name` 只输出 pod 的 name：

```bash
$ kubectl get pods -l workflows.argoproj.io/workflow=archive-log-test-jzt8n --sort-by='.metadata.creationTimestamp' -o name
pod/archive-log-test-jzt8n-3498199655
pod/archive-log-test-jzt8n-3618624526
pod/archive-log-test-jzt8n-2123203324
```

### 获取日志

通过上面的步骤我们就可以获取到一个 workflow 所创建的 pod 列表。然后再通过 kubectl logs 命令获取 pod 中 main 容器的日志，为方便区分日志的所对应的 workflow ，我们就以 workflow 的 ID 为前缀名。

```bash
$ kubectl logs archive-log-test-jzt8n-3618624526 -c main
```

```bash
LOG_PATH=/var/log
NAME=archive-log-test-jzt8n
kubectl get pods -l workflows.argoproj.io/workflow=${NAME} \
--sort-by='.metadata.creationTimestamp' -o name \
| xargs -I {} -t kubectl logs {} -c main >> ${LOG_PATH}/${NAME}.log
```

### workflow

根据 argo-workflow 官方提供的 [**exit-handlers.yaml**](https://github.com/argoproj/argo-workflows/blob/master/examples/exit-handlers.yaml) example，我们就照葫芦画瓢搓一个 workflow 退出后自动调用使用 kubectl 获取 workflow 日志的一个 step，定义的 exit-handler 内容如下：

```yaml
    - name: exit-handler
      container:
        name: "kubectl"
        image: lachlanevenson/k8s-kubectl:v1.23.2
        command:
          - sh
          - -c
          - |
            kubectl get pods -l workflows.argoproj.io/workflow=${POD_NAME%-*} \
            --sort-by=".metadata.creationTimestamp" -o name | grep -v ${POD_NAME} \
            | xargs -I {} -t kubectl logs {} -c main >> ${LOG_PATH}/${POD_NAME%-*}.log
        env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: LOG_PATH
            value: /var/log/workflow
        resources: {}
        volumeMounts:
          - name: nfs-datastore
            mountPath: /var/log/workflow
      retryStrategy:
        limit: "5"
        retryPolicy: OnFailure
  entrypoint: archive-log-test
  serviceAccountName: default
  volumes:
    - name: nfs-datastore
      nfs:
        server: NFS_SERVER
        path: /data/workflow/log
  onExit: exit-handler
```

将上述定义的 `exit-handler` 内容复制粘贴到你的 workflow spec 配置中就可以。由于日志需要持久化存储，我这里使用的是 NFS 存储，也可以根据自己的需要换成其他存储，只需要修改一下 `volumes` 配置即可。

完整的 [workflow example](https://gist.github.com/muzi502/9b26c6854c509c42ecd7f7004436ca23) 如下：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: archive-log-test-
  namespace: default
spec:
  templates:
    - name: archive-log-test
      steps:
        - - name: list-default-running-pods
            template: kubectl
            arguments:
              parameters:
                - name: namespace
                  value: default
        - - name: list-kube-system-running-pods
            template: kubectl
            arguments:
              parameters:
                - name: namespace
                  value: kube-system

    - name: kubectl
      inputs:
        parameters:
          - name: namespace
      container:
        name: "kubectl"
        image: lachlanevenson/k8s-kubectl:v1.23.2
        command:
          - sh
          - -c
          - |
            kubectl get pods --field-selector=status.phase=Running -n {{inputs.parameters.namespace}}

    - name: exit-handler
      container:
        name: "kubectl"
        image: lachlanevenson/k8s-kubectl:v1.23.2
        command:
          - sh
          - -c
          - |
            kubectl get pods -l workflows.argoproj.io/workflow=${POD_NAME%-*} \
            --sort-by=".metadata.creationTimestamp" -o name | grep -v ${POD_NAME} \
            | xargs -I {} -t kubectl logs {} -c main >> ${LOG_PATH}/${POD_NAME%-*}.log
        env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: LOG_PATH
            value: /var/log/workflow
        resources: {}
        volumeMounts:
          - name: nfs-datastore
            mountPath: /var/log/workflow
      retryStrategy:
        limit: "5"
        retryPolicy: OnFailure
  entrypoint: archive-log-test
  serviceAccountName: default
  volumes:
    - name: nfs-datastore
      nfs:
        server: NFS_SERVER
        path: /data/workflow/log
  onExit: exit-handler
```
