---
title: Cluster API 调研
date: 2022-01-10
updated: 2022-01-12
slug:
categories: 技术
tag:
  - k8s
  - cluster-api
copyright: true
comment: true
---

## 私有化 K8s 部署

笔者在字节跳动的时候负责火山引擎 PaaS 容器云产品底层 K8s 集群部署相关工作。在部署 K8s 的时候往往不需要关注 IaaS 资源是如何提供的。只需客户提供好一堆三层可达的节点以及 ssh 登录信息就能完成集群的部署。

但是这种部署场景也有一些弊端，比如无法做到集群节点的动态扩缩容。

## cluster-api

### Provider

- Bootstrap Provider
  - [Bootstrap](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/bootstrap.html)
- ControlPlane Provider
  - [ControlPlane](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/control-plane.html)

### Core

- Core
  - [Cluster](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/cluster.html)
  - [Machine](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/machine.html)
  - [MachineSet](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/machine-set.html)
  - [MachineDeployment](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/machine-deployment.html)
  - [MachineHealthCheck](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/machine-health-check.html)
  - [MachinePool](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/machine-pool.html)
- ClusterClass
- [Cluster Topology](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/cluster-topology.html)

### machine

### machine set

### machine pool

### machine class

### machine deployment

### cluster

```yaml
- apiVersion: cluster.x-k8s.io/v1alpha3
  kind: Cluster
    name: b-cluster
    namespace: default
    resourceVersion: "66771"
    uid: 463ade86-8127-4219-b18f-55002921c253
  spec:
    clusterNetwork:
      pods:
        cidrBlocks:
        - 100.96.0.0/11
      services:
        cidrBlocks:
        - 100.64.0.0/13
    controlPlaneEndpoint:
      host: 192.168.73.192
      port: 6443
    controlPlaneRef:
      apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
      kind: KubeadmControlPlane
      name: b-cluster-control-plane
      namespace: default
    infrastructureRef:
      apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
      kind: VSphereCluster
      name: b-cluster
      namespace: default
```

- KubeadmControlPlane

```yaml
apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
kind: KubeadmControlPlane
metadata:
  annotations:
  creationTimestamp: "2021-12-16T10:07:52Z"
  finalizers:
  - kubeadm.controlplane.cluster.x-k8s.io
  generation: 1
  labels:
    cluster.x-k8s.io/cluster-name: b-cluster
  name: b-cluster-control-plane
  namespace: default
  ownerReferences:
  - apiVersion: cluster.x-k8s.io/v1alpha3
    blockOwnerDeletion: true
    controller: true
    kind: Cluster
    name: b-cluster
    uid: 463ade86-8127-4219-b18f-55002921c253
  resourceVersion: "67768"
  uid: 2bfc3d73-79df-4741-a070-73f4e94a2033
spec:
  infrastructureTemplate:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
    kind: VSphereMachineTemplate
    name: b-cluster-control-plane
    namespace: default
  kubeadmConfigSpec:
    clusterConfiguration:
      apiServer:
        extraArgs:
          cloud-provider: external
          tls-cipher-suites: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
        timeoutForControlPlane: 8m0s
      controllerManager:
        extraArgs:
          cloud-provider: external
          tls-cipher-suites: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
      dns:
        imageRepository: projects.registry.vmware.com/tkg
        imageTag: v1.8.0_vmware.5
        type: CoreDNS
      etcd:
        local:
          dataDir: /var/lib/etcd
          extraArgs:
            cipher-suites: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
          imageRepository: projects.registry.vmware.com/tkg
          imageTag: v3.4.13_vmware.15
      imageRepository: projects.registry.vmware.com/tkg
      networking: {}
      scheduler:
        extraArgs:
          tls-cipher-suites: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
    files:
    - content: |
        apiVersion: v1
        kind: Pod
        metadata:
          creationTimestamp: null
          name: kube-vip
          namespace: kube-system
        spec:
          containers:
          - args:
            - start
            env:
            - name: vip_arp
              value: "true"
            - name: vip_leaderelection
              value: "true"
            - name: address
              value: 192.168.73.192
            - name: vip_interface
              value: eth0
            - name: vip_leaseduration
              value: "15"
            - name: vip_renewdeadline
              value: "10"
            - name: vip_retryperiod
              value: "2"
            image: projects.registry.vmware.com/tkg/kube-vip:v0.3.3_vmware.1
            imagePullPolicy: IfNotPresent
            name: kube-vip
            resources: {}
            securityContext:
              capabilities:
                add:
                - NET_ADMIN
                - SYS_TIME
            volumeMounts:
            - mountPath: /etc/kubernetes/admin.conf
              name: kubeconfig
          hostNetwork: true
          volumes:
          - hostPath:
              path: /etc/kubernetes/admin.conf
              type: FileOrCreate
            name: kubeconfig
        status: {}
      owner: root:root
      path: /etc/kubernetes/manifests/kube-vip.yaml
    initConfiguration:
      localAPIEndpoint:
        advertiseAddress: ""
        bindPort: 0
      nodeRegistration:
        criSocket: /var/run/containerd/containerd.sock
        kubeletExtraArgs:
          cloud-provider: external
          tls-cipher-suites: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
        name: '{{ ds.meta_data.hostname }}'
    joinConfiguration:
      discovery: {}
      nodeRegistration:
        criSocket: /var/run/containerd/containerd.sock
        kubeletExtraArgs:
          cloud-provider: external
          tls-cipher-suites: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
        name: '{{ ds.meta_data.hostname }}'
    preKubeadmCommands:
    - hostname "{{ ds.meta_data.hostname }}"
    - echo "::1         ipv6-localhost ipv6-loopback" >/etc/hosts
    - echo "127.0.0.1   localhost" >>/etc/hosts
    - echo "127.0.0.1   {{ ds.meta_data.hostname }}" >>/etc/hosts
    - echo "{{ ds.meta_data.hostname }}" >/etc/hostname
    useExperimentalRetryJoin: true
    users:
    - name: capv
      sshAuthorizedKeys:
      - ssh-rsa
      sudo: ALL=(ALL) NOPASSWD:ALL
  replicas: 1
  rolloutStrategy:
    rollingUpdate:
      maxSurge: 1
    type: RollingUpdate
  version: v1.21.2+vmware.1
```
