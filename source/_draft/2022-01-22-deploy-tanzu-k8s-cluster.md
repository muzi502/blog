---
title: VMware tanzu kubernetes 发行版部署尝鲜
date: 2022-01-01
updated:
slug:
categories:
tag:
copyright: true
comment: true
---

## 劝退三连 😂

### bootstrap

bootstrap 节点，即 tanzu installer 运行节点

| item                                                         |
| :----------------------------------------------------------- |
| Arch: x86; ARM is currently unsupported                      |
| RAM: 6 GB                                                    |
| CPU: 2                                                       |
| [Docker](https://docs.docker.com/engine/install/) Add your non-root user account to the docker user group. Create the group if it does not already exist. This lets the Tanzu CLI access the Docker socket, which is owned by the root user. For more information, see steps 1 to 4 in the [Manage Docker as a non-root user](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user) procedure in the Docker documentation. |
| [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) |
| Latest version of Chrome, Firefox, Safari, Internet Explorer, or Edge |
| System time is synchronized with a Network Time Protocol (NTP) server. |
| Ensure your bootstrap machine is using [cgroup v1](https://man7.org/linux/man-pages/man7/cgroups.7.html). For more information, see [Check and set the cgroup](https://tanzucommunityedition.io/docs/latest/support-matrix/#check-and-set-the-cgroup). |

### vCenter

```bash
FullName:     VMware vCenter Server 7.0.3 build-18778458
Name:         VMware vCenter Server
Vendor:       VMware, Inc.
Version:      7.0.3
Build:        18778458
OS type:      linux-x64
API type:     VirtualCenter
API version:  7.0.3.0
Product ID:   vpx
UUID:         0b49e119-e38f-4fbc-84a8-d7a0e548027d
```



```bash
$ govc datacenter.create SH-IDC
$ govc cluster.create -dc=SH-IDC Tanzu-Cluster
$ govc folder.create /SH-IDC/vm/Tanzu-node
$ govc import.ova -ds='datastore*'  photon-3-kube-v1.21.2+vmware.1-tkg.2-12816990095845873721.ova
$ govc vm.markastemplate photon-3-kube-v1.21.2
```



### ESXi

```bash
Name:              192.168.69.76
  Path:            /Datacenter/host/Tanzu/192.168.69.76
  Manufacturer:    Dell
  Logical CPUs:    24 CPUs @ 2195MHz
  Processor type:  Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz
  CPU usage:       9105 MHz (17.3%)
  Memory:          130629MB
  Memory usage:    83566 MB (64.0%)
  Boot time:       2022-01-13 05:29:46.507529 +0000 UTC
  State:           connected
```

## 部署原理

## 部署流程

### 导入 OVA

### 初始化 bootstrap 节点

bootstrap 节点我是直接使用的 VMware 官方的 [Photon OS 4.0 Rev2](https://github.com/vmware/photon/wiki/Downloading-Photon-OS#photon-os-40-rev2-binaries) ，下载 OVA 格式的镜像直接导入到 ESXi 主机启动一台虚拟机即可。

```bash
$ wget https://packages.vmware.com/photon/4.0/Rev2/ova/photon-ova-4.0-c001795b80.ova
$ govc import.ova -ds='datastore*' -name bootstrap-node photon-ova-4.0-c001795b80.ova
$ govc vm.change -c 4 -m 8192 bootstrap-node
$ govc vm.power -on bootstrap-node
$ ssh root@192.168.74.10
# 密码默认为 changeme，输入完密码之后提示在输入一遍 changeme，然后再修改新的密码
root@photon-machine [ ~ ]# cat /etc/os-release
NAME="VMware Photon OS"
VERSION="4.0"
ID=photon
VERSION_ID=4.0
PRETTY_NAME="VMware Photon OS/Linux"
ANSI_COLOR="1;34"
HOME_URL="https://vmware.github.io/photon/"
BUG_REPORT_URL="https://github.com/vmware/photon/issues"
```

- 安装部署需要的一些工具，Photon OS 里竟然连个 tar 命令都没有，吃惊 😱

```bash
root@photon-machine [ ~ ]# tdnf install sudo tar -y
root@photon-machine [ ~ ]# curl -LO https://dl.k8s.io/release/v1.21.2/bin/linux/amd64/kubectl
root@photon-machine [ ~ ]# sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

- 启动 docker，bootstrap 节点会以 kind 的方式运行一个 K8s 集群，需要用到 docker

```bash
root@photon-machine [ ~ ]# systemctl enable docker --now
root@photon-machine [ ~ ]# docker info
Client:
 Context:    default
 Debug Mode: false

Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 20.10.11
 Storage Driver: overlay2
  Backing Filesystem: extfs
  Supports d_type: true
  Native Overlay Diff: true
  userxattr: false
 Logging Driver: json-file
 Cgroup Driver: cgroupfs
 Cgroup Version: 1
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local logentries splunk syslog
 Swarm: inactive
 Runtimes: io.containerd.runc.v2 io.containerd.runtime.v1.linux runc
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: 05f951a3781f4f2c1911b05e61c160e9c30eaa8e
 runc version: 14faf1c20948688a48edb9b41367ab07ac11ca91
 init version: de40ad0
 Security Options:
  apparmor
  seccomp
   Profile: default
 Kernel Version: 5.10.83-6.ph4-esx
 Operating System: VMware Photon OS/Linux
 OSType: linux
 Architecture: x86_64
 CPUs: 8
 Total Memory: 15.64GiB
 Name: photon-machine
 ID: TKEZ:L2WF:ZAFU:B5G6:IA55:V3UK:FICU:WKSO:M5HM:7TSF:3VIK:7L3S
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Registry: https://index.docker.io/v1/
 Labels:
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false
 Product License: Community Engine
```

- 从 [vmware-tanzu/community-edition](https://github.com/vmware-tanzu/community-edition/releases/tag/v0.9.1) 下载 tanzu 社区版的安装包，然后解压后安装；

```bash
root@photon-machine [ ~ ]# curl -LO  https://github.com/vmware-tanzu/community-edition/releases/download/v0.9.1/tce-linux-amd64-v0.9.1.tar.gz
root@photon-machine [ ~ ]# tar -xf tce-linux-amd64-v0.9.1.tar.gz
root@photon-machine [ ~ ]# cd tce-linux-amd64-v0.9.1/
root@photon-machine [ ~ ]# bash install.sh
```

然而不幸地翻车了， install.sh 脚本中禁止 root 用户运行

```bash
+ ALLOW_INSTALL_AS_ROOT=
+ [[ 0 -eq 0 ]]
+ [[ '' != \t\r\u\e ]]
+ echo 'Do not run this script as root'
Do not run this script as root
+ exit 1
```

我就偏偏要以 root 用户来运行怎么惹！



![告诉你！我就不表情包.jpg](pics/2022-01-22-deploy-tanzu-k8s-cluster/1536808420587637.jpg)

```bash
# sed 去掉第一个 exit 1 就可以了
root@photon-machine [ ~ ]# sed -i.bak "s/exit 1//" install.sh
root@photon-machine [ ~ ]# bash install.sh
```

安装好之后会输出 `Installation complete!`（讲真官方的 install.sh 脚本输出很不友好，污染我的 terminal

```bash
+ tanzu init
| initializing ✔  successfully initialized CLI
++ tanzu plugin repo list
++ grep tce
+ TCE_REPO=
+ [[ -z '' ]]
+ tanzu plugin repo add --name tce --gcp-bucket-name tce-tanzu-cli-plugins --gcp-root-path artifacts
++ tanzu plugin repo list
++ grep core-admin
+ TCE_REPO=
+ [[ -z '' ]]
+ tanzu plugin repo add --name core-admin --gcp-bucket-name tce-tanzu-cli-framework-admin --gcp-root-path artifacts-admin
+ echo 'Installation complete!'
Installation complete!
```

### 部署管理集群

先是部署一个 cluster-api 的管理集群，有两种方式，一种是通过官方文档中提到的。UI。其实这个 UI 界面比较羸弱。主要是用来让用户填写一些配置参数，然后调用后台的 tanzu 命令还部署集群。并把集群部署的日志和进度展示出来。这一步同样也可以指通过 tanzu 命令来完成。

- 集群配置文件

```yaml
root@photon-machine [ ~ ]# cat /root/.config/tanzu/tkg/clusterconfigs/4tk4nbnuxz.yaml
# Cluster Pod IP 的 CIDR
CLUSTER_CIDR: 100.96.0.0/11
# Service 的 CIDR
SERVICE_CIDR: 100.64.0.0/13
# 集群的名称
CLUSTER_NAME: tanzu-control-plan
# 集群的类型
CLUSTER_PLAN: dev
# 集群节点的 arch
OS_ARCH: amd64
# 集群节点的 OS 名称
OS_NAME: photon
# 集群节点 OS 版本
OS_VERSION: "3"
# 基础设施资源的提供方
INFRASTRUCTURE_PROVIDER: vsphere

# 集群的 VIP
VSPHERE_CONTROL_PLANE_ENDPOINT: 192.168.75.194
# control-plan 节点的磁盘大小
VSPHERE_CONTROL_PLANE_DISK_GIB: "20"
# control-plan 节点的内存大小
VSPHERE_CONTROL_PLANE_MEM_MIB: "8192"
# control-plan 节点的 CPU 核心数量
VSPHERE_CONTROL_PLANE_NUM_CPUS: "4"
# work 节点的磁盘大小
VSPHERE_WORKER_DISK_GIB: "20"
# work 节点的内存大小
VSPHERE_WORKER_MEM_MIB: "4096"
# work 节点的 CPU 核心数量
VSPHERE_WORKER_NUM_CPUS: "2"

# vCenter 的 Datacenter 路径
VSPHERE_DATACENTER: /SH-IDC
# 虚拟机创建的 Datastore 路径
VSPHERE_DATASTORE: /SH-IDC/datastore/datastore1
# 虚拟机创建的文件夹
VSPHERE_FOLDER: /SH-IDC/vm/Tanzu-node
# 虚拟机使用的网络
VSPHERE_NETWORK: /SH-IDC/network/VM Network
# 虚拟机关联的资源池
VSPHERE_RESOURCE_POOL: /SH-IDC/host/Tanzu-Cluster/Resources

# vCenter 的 IP
VSPHERE_SERVER: 192.168.75.110
# vCenter 的用户名
VSPHERE_USERNAME: administrator@vsphere.local
# vCenter 的密码，以 base64 编码
VSPHERE_PASSWORD: <encoded:base64password>
# vCenter 的证书指纹，可以通过 govc about.cert -json | jq -r '.ThumbprintSHA1' 获取
VSPHERE_TLS_THUMBPRINT: EB:F3:D8:7A:E8:3D:1A:59:B0:DE:73:96:DC:B9:5F:13:86:EF:B6:27
# 虚拟机注入的 ssh 公钥，需要用它来 ssh 登录集群节点
VSPHERE_SSH_AUTHORIZED_KEY: ssh-rsa

# 一些默认参数
AVI_ENABLE: "false"
IDENTITY_MANAGEMENT_TYPE: none
ENABLE_AUDIT_LOGGING: "false"
ENABLE_CEIP_PARTICIPATION: "false"
TKG_HTTP_PROXY_ENABLED: "false"
DEPLOY_TKG_ON_VSPHERE7: "true"
```

- 通过 tanzu CLI 部署管理集群

```bash
$ tanzu management-cluster create --file mgt-cluster.yaml -v6

# 如果没有配置 VSPHERE_TLS_THUMBPRINT 会有一个确认 vSphere thumbprint 的交互，输入 Y 就可以
Validating the pre-requisites...
Do you want to continue with the vSphere thumbprint EB:F3:D8:7A:E8:3D:1A:59:B0:DE:73:96:DC:B9:5F:13:86:EF:B6:27 [y/N]: y
```

### 部署进度

```bash
compatibility file (/root/.config/tanzu/tkg/compatibility/tkg-compatibility.yaml) already exists, skipping download
BOM files inside /root/.config/tanzu/tkg/bom already exists, skipping download
CEIP Opt-in status: false

Validating the pre-requisites...

vSphere 7.0 Environment Detected.

You have connected to a vSphere 7.0 environment which does not have vSphere with Tanzu enabled. vSphere with Tanzu includes
an integrated Tanzu Kubernetes Grid Service which turns a vSphere cluster into a platform for running Kubernetes workloads in dedicated
resource pools. Configuring Tanzu Kubernetes Grid Service is done through vSphere HTML5 client.

Tanzu Kubernetes Grid Service is the preferred way to consume Tanzu Kubernetes Grid in vSphere 7.0 environments. Alternatively you may
deploy a non-integrated Tanzu Kubernetes Grid instance on vSphere 7.0.
Note: To skip the prompts and directly deploy a non-integrated Tanzu Kubernetes Grid instance on vSphere 7.0, you can set the 'DEPLOY_TKG_ON_VSPHERE7' configuration variable to 'true'

Do you want to configure vSphere with Tanzu? [y/N]: n
Would you like to deploy a non-integrated Tanzu Kubernetes Grid management cluster on vSphere 7.0? [y/N]: y
Deploying TKG management cluster on vSphere 7.0 ...
Identity Provider not configured. Some authentication features won't work.
Checking if VSPHERE_CONTROL_PLANE_ENDPOINT 192.168.75.190 is already in use

Setting up management cluster...
Validating configuration...
Using infrastructure provider vsphere:v0.7.10
Generating cluster configuration...
Setting up bootstrapper...
Fetching configuration for kind node image...
kindConfig:
 &{{Cluster kind.x-k8s.io/v1alpha4}  [{  map[] [{/var/run/docker.sock /var/run/docker.sock false false }] [] [] []}] { 0  100.96.0.0/11 100.64.0.0/13 false } map[] map[] [apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
imageRepository: projects.registry.vmware.com/tkg
etcd:
  local:
    imageRepository: projects.registry.vmware.com/tkg
    imageTag: v3.4.13_vmware.15
dns:
  type: CoreDNS
  imageRepository: projects.registry.vmware.com/tkg
  imageTag: v1.8.0_vmware.5] [] [] []}
Creating kind cluster: tkg-kind-c7mde4tkvpdsddjp6jhg
Creating cluster "tkg-kind-c7mde4tkvpdsddjp6jhg" ...
Ensuring node image (projects.registry.vmware.com/tkg/kind/node:v1.21.2_vmware.1) ...
Pulling image: projects.registry.vmware.com/tkg/kind/node:v1.21.2_vmware.1 ...

$ root@photon-machine [ ~ ]# cp /root/.kube-tkg/tmp/config_7qWiNeHb /root/.kube/config
```

```bash
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  32s                default-scheduler  Successfully assigned kube-system/metrics-server-6694b975cd-khflk to tanzu-control-plan-md-0-7cdc97c7c6-pjsfg
  Normal   BackOff    26s                kubelet            Back-off pulling image "projects.registry.vmware.com/tkg/metrics-server@sha256:3490ace6c30facd345cf4d8901f945aaff1a7a5d486500b154ce503b55f61525"
  Warning  Failed     26s                kubelet            Error: ImagePullBackOff
  Normal   Pulling    13s (x2 over 31s)  kubelet            Pulling image "projects.registry.vmware.com/tkg/metrics-server@sha256:3490ace6c30facd345cf4d8901f945aaff1a7a5d486500b154ce503b55f61525"
  Warning  Failed     9s (x2 over 27s)   kubelet            Failed to pull image "projects.registry.vmware.com/tkg/metrics-server@sha256:3490ace6c30facd345cf4d8901f945aaff1a7a5d486500b154ce503b55f61525": rpc error: code = FailedPrecondition desc = failed to pull and unpack image "projects.registry.vmware.com/tkg/metrics-server@sha256:3490ace6c30facd345cf4d8901f945aaff1a7a5d486500b154ce503b55f61525": failed commit on ref "layer-sha256:87cb1fbb952de6da2885403d3a77d5084e784c7816e8b8397f1cd18b1a315b5b": "layer-sha256:87cb1fbb952de6da2885403d3a77d5084e784c7816e8b8397f1cd18b1a315b5b" failed size validation: 12582912 != 24072527: failed precondition
  Warning  Failed     9s (x2 over 27s)   kubelet            Error: ErrImagePull

root [ /home/capv ]# crictl  pull projects.registry.vmware.com/tkg/metrics-server@sha256:3490ace6c30facd345cf4d8901f945aaff1a7a5d486500b154ce503b55f61525
FATA[0004] pulling image: rpc error: code = FailedPrecondition desc = failed to pull and unpack image "projects.registry.vmware.com/tkg/metrics-server@sha256:3490ace6c30facd345cf4d8901f945aaff1a7a5d486500b154ce503b55f61525": failed commit on ref "layer-sha256:87cb1fbb952de6da2885403d3a77d5084e784c7816e8b8397f1cd18b1a315b5b": "layer-sha256:87cb1fbb952de6da2885403d3a77d5084e784c7816e8b8397f1cd18b1a315b5b" failed size validation: 12582912 != 24072527: failed precondition
```

### 部署流程

```go
https://github.com/vmware-tanzu/tanzu-framework/blob/main/pkg/v1/tkg/client/init.go


// management cluster init step constants
const (
	StepConfigPrerequisite                 = "Configure prerequisite"
	StepValidateConfiguration              = "Validate configuration"
	StepGenerateClusterConfiguration       = "Generate cluster configuration"
	StepSetupBootstrapCluster              = "Setup bootstrap cluster"
	StepInstallProvidersOnBootstrapCluster = "Install providers on bootstrap cluster"
	StepCreateManagementCluster            = "Create management cluster"
	StepInstallProvidersOnRegionalCluster  = "Install providers on management cluster"
	StepMoveClusterAPIObjects              = "Move cluster-api objects from bootstrap cluster to management cluster"
)

// InitRegionSteps management cluster init step sequence
var InitRegionSteps = []string{
	StepConfigPrerequisite,
	StepValidateConfiguration,
	StepGenerateClusterConfiguration,
	StepSetupBootstrapCluster,
	StepInstallProvidersOnBootstrapCluster,
	StepCreateManagementCluster,
	StepInstallProvidersOnRegionalCluster,
	StepMoveClusterAPIObjects,
}
```

#### 管理集群创建流程

```golang
// InitRegion create management cluster
func (c *TkgClient) InitRegion(options *InitRegionOptions) error { //nolint:funlen,gocyclo
	var err error
	var regionalConfigBytes []byte
	var isSuccessful = false
	var isStartedRegionalClusterCreation = false
	var isBootstrapClusterCreated = false
	var bootstrapClusterName string
	var regionContext region.RegionContext
	var filelock *fslock.Lock

	bootstrapClusterKubeconfigPath, err := getTKGKubeConfigPath(false)
	if err != nil {
		return err
	}

	log.SendProgressUpdate(statusRunning, StepValidateConfiguration, InitRegionSteps)

	log.Info("Validating configuration...")
	defer func() {
		if regionContext != (region.RegionContext{}) {
			filelock, err = utils.GetFileLockWithTimeOut(filepath.Join(c.tkgConfigDir, constants.LocalTanzuFileLock), utils.DefaultLockTimeout)
			if err != nil {
				log.Warningf("cannot acquire lock for updating management cluster configuration, %s", err.Error())
			}
			err := c.regionManager.SaveRegionContext(regionContext)
			if err != nil {
				log.Warningf("Unable to persist management cluster %s info to tkg config", regionContext.ClusterName)
			}

			err = c.regionManager.SetCurrentContext(regionContext.ClusterName, regionContext.ContextName)
			if err != nil {
				log.Warningf("Unable to use context %s as current tkg context", regionContext.ContextName)
			}
			if err := filelock.Unlock(); err != nil {
				log.Warningf("unable to release lock for updating management cluster configuration, %s", err.Error())
			}
		}

		if isSuccessful {
			log.SendProgressUpdate(statusSuccessful, "", InitRegionSteps)
		} else {
			log.SendProgressUpdate(statusFailed, "", InitRegionSteps)
		}

		// if management cluster creation failed after bootstrap kind cluster was successfully created
		if !isSuccessful && isStartedRegionalClusterCreation {
			c.displayHelpTextOnFailure(options, isBootstrapClusterCreated, bootstrapClusterKubeconfigPath)
			return
		}

		if isBootstrapClusterCreated {
			if err := c.teardownKindCluster(bootstrapClusterName, bootstrapClusterKubeconfigPath, options.UseExistingCluster); err != nil {
				log.Warning(err.Error())
			}
		}
		_ = utils.DeleteFile(bootstrapClusterKubeconfigPath)
	}()

	if customImageRepo, err := c.TKGConfigReaderWriter().Get(constants.ConfigVariableCustomImageRepository); err != nil && customImageRepo != "" && tkgconfighelper.IsCustomRepository(customImageRepo) {
		log.Infof("Using custom image repository: %s", customImageRepo)
	}

	providerName, _, err := ParseProviderName(options.InfrastructureProvider)
	if err != nil {
		return errors.Wrap(err, "unable to parse provider name")
	}

	// validate docker only if user is not using an existing cluster
	// Note: Validating in client code as well to cover the usecase where users use client code instead of command line.

	if err := c.ValidatePrerequisites(!options.UseExistingCluster, true); err != nil {
		return err
	}

	// validate docker resources if provider is docker
	if providerName == "docker" {
		if err := c.ValidateDockerResourcePrerequisites(); err != nil {
			return err
		}
	}

	log.Infof("Using infrastructure provider %s", options.InfrastructureProvider)
	log.SendProgressUpdate(statusRunning, StepGenerateClusterConfiguration, InitRegionSteps)
	log.Info("Generating cluster configuration...")

	// Obtain management cluster configuration of a provided flavor
	if regionalConfigBytes, options.ClusterName, err = c.BuildRegionalClusterConfiguration(options); err != nil {
		return errors.Wrap(err, "unable to build management cluster configuration")
	}

	log.SendProgressUpdate(statusRunning, StepSetupBootstrapCluster, InitRegionSteps)
	log.Info("Setting up bootstrapper...")
	// Ensure bootstrap cluster and copy boostrap cluster kubeconfig to ~/kube-tkg directory
	if bootstrapClusterName, err = c.ensureKindCluster(options.Kubeconfig, options.UseExistingCluster, bootstrapClusterKubeconfigPath); err != nil {
		return errors.Wrap(err, "unable to create bootstrap cluster")
	}

	isBootstrapClusterCreated = true
	log.Infof("Bootstrapper created. Kubeconfig: %s", bootstrapClusterKubeconfigPath)
	bootStrapClusterClient, err := clusterclient.NewClient(bootstrapClusterKubeconfigPath, "", clusterclient.Options{OperationTimeout: c.timeout})
	if err != nil {
		return errors.Wrap(err, "unable to get bootstrap cluster client")
	}

	// configure variables required to deploy providers
	if err := c.configureVariablesForProvidersInstallation(nil); err != nil {
		return errors.Wrap(err, "unable to configure variables for provider installation")
	}

	log.SendProgressUpdate(statusRunning, StepInstallProvidersOnBootstrapCluster, InitRegionSteps)
	log.Info("Installing providers on bootstrapper...")
	// Initialize bootstrap cluster with providers
	if err = c.InitializeProviders(options, bootStrapClusterClient, bootstrapClusterKubeconfigPath); err != nil {
		return errors.Wrap(err, "unable to initialize providers")
	}

	isStartedRegionalClusterCreation = true

	targetClusterNamespace := defaultTkgNamespace
	if options.Namespace != "" {
		targetClusterNamespace = options.Namespace
	}

	log.SendProgressUpdate(statusRunning, StepCreateManagementCluster, InitRegionSteps)
	log.Info("Start creating management cluster...")
	err = c.DoCreateCluster(bootStrapClusterClient, options.ClusterName, targetClusterNamespace, string(regionalConfigBytes))
	if err != nil {
		return errors.Wrap(err, "unable to create management cluster")
	}

	// save this context to tkg config incase the management cluster creation fails
	bootstrapClusterContext := "kind-" + bootstrapClusterName
	if options.UseExistingCluster {
		bootstrapClusterContext, err = getCurrentContextFromDefaultKubeConfig()
		if err != nil {
			return err
		}
	}
	regionContext = region.RegionContext{ClusterName: options.ClusterName, ContextName: bootstrapClusterContext, SourceFilePath: bootstrapClusterKubeconfigPath, Status: region.Failed}

	kubeConfigBytes, err := c.WaitForClusterInitializedAndGetKubeConfig(bootStrapClusterClient, options.ClusterName, targetClusterNamespace)
	if err != nil {
		return errors.Wrap(err, "unable to wait for cluster and get the cluster kubeconfig")
	}

	regionalClusterKubeconfigPath, err := getTKGKubeConfigPath(true)
	if err != nil {
		return err
	}
	// put a filelock to ensure mutual exclusion on updating kubeconfig
	filelock, err = utils.GetFileLockWithTimeOut(filepath.Join(c.tkgConfigDir, constants.LocalTanzuFileLock), utils.DefaultLockTimeout)
	if err != nil {
		return errors.Wrap(err, "cannot acquire lock for updating management cluster kubeconfig")
	}

	mergeFile := getDefaultKubeConfigFile()
	log.Infof("Saving management cluster kubeconfig into %s", mergeFile)
	// merge the management cluster kubeconfig into user input kubeconfig path/default kubeconfig path
	err = MergeKubeConfigWithoutSwitchContext(kubeConfigBytes, mergeFile)
	if err != nil {
		return errors.Wrap(err, "unable to merge management cluster kubeconfig")
	}

	// merge the management cluster kubeconfig into tkg managed kubeconfig
	kubeContext, err := MergeKubeConfigAndSwitchContext(kubeConfigBytes, regionalClusterKubeconfigPath)
	if err != nil {
		return errors.Wrap(err, "unable to save management cluster kubeconfig to TKG managed kubeconfig")
	}

	if err := filelock.Unlock(); err != nil {
		log.Warningf("cannot acquire lock for updating management cluster kubeconfigconfig, reason: %v", err)
	}

	regionalClusterClient, err := clusterclient.NewClient(regionalClusterKubeconfigPath, kubeContext, clusterclient.Options{OperationTimeout: c.timeout})
	if err != nil {
		return errors.Wrap(err, "unable to get management cluster client")
	}

	log.SendProgressUpdate(statusRunning, StepInstallProvidersOnRegionalCluster, InitRegionSteps)
	log.Info("Installing providers on management cluster...")
	if err = c.InitializeProviders(options, regionalClusterClient, regionalClusterKubeconfigPath); err != nil {
		return errors.Wrap(err, "unable to initialize providers on management cluster")
	}

	if err := regionalClusterClient.PatchClusterAPIAWSControllersToUseEC2Credentials(); err != nil {
		return err
	}

	log.Info("Waiting for the management cluster to get ready for move...")
	if err := c.WaitForClusterReadyForMove(bootStrapClusterClient, options.ClusterName, targetClusterNamespace); err != nil {
		return errors.Wrap(err, "unable to wait for cluster getting ready for move")
	}

	log.Info("Waiting for addons installation...")
	if err := c.WaitForAddons(waitForAddonsOptions{
		regionalClusterClient: bootStrapClusterClient,
		workloadClusterClient: regionalClusterClient,
		clusterName:           options.ClusterName,
		namespace:             options.Namespace,
		waitForCNI:            true,
	}); err != nil {
		return errors.Wrap(err, "error waiting for addons to get installed")
	}

	log.SendProgressUpdate(statusRunning, StepMoveClusterAPIObjects, InitRegionSteps)
	log.Info("Moving all Cluster API objects from bootstrap cluster to management cluster...")
	// Move all Cluster API objects from bootstrap cluster to created to management cluster for all namespaces
	if err = c.MoveObjects(bootstrapClusterKubeconfigPath, regionalClusterKubeconfigPath, targetClusterNamespace); err != nil {
		return errors.Wrap(err, "unable to move Cluster API objects from bootstrap cluster to management cluster")
	}

	regionContext = region.RegionContext{ClusterName: options.ClusterName, ContextName: kubeContext, SourceFilePath: regionalClusterKubeconfigPath, Status: region.Success}

	err = c.PatchClusterInitOperations(regionalClusterClient, options, targetClusterNamespace)
	if err != nil {
		return errors.Wrap(err, "unable to patch cluster object")
	}

	if err != nil {
		return errors.Wrap(err, "unable to parse provider name")
	}

	// start CEIP telemetry cronjob if cluster is opt-in
	if options.CeipOptIn {
		bomConfig, err := c.tkgBomClient.GetDefaultTkgBOMConfiguration()
		if err != nil {
			return errors.Wrapf(err, "failed to get default bom configuration")
		}

		httpProxy, httpsProxy, noProxy := "", "", ""
		if httpProxy, err = c.TKGConfigReaderWriter().Get(constants.TKGHTTPProxy); err == nil && httpProxy != "" {
			httpsProxy, _ = c.TKGConfigReaderWriter().Get(constants.TKGHTTPSProxy)
			noProxy, err = c.getFullTKGNoProxy(providerName)
			if err != nil {
				return err
			}
		}

		if err = regionalClusterClient.AddCEIPTelemetryJob(options.ClusterName, providerName, bomConfig, "", "", httpProxy, httpsProxy, noProxy); err != nil {
			log.Error(err, "Failed to start CEIP telemetry job on management cluster")

			log.Warningf("\nTo have this cluster participate in VMware CEIP:")
			log.Warningf("\ttanzu management-cluster ceip-participation set true")
		}
	}

	log.Info("Waiting for additional components to be up and running...")
	if err := c.WaitForAddonsDeployments(regionalClusterClient); err != nil {
		return err
	}

	log.Info("Waiting for packages to be up and running...")
	if err := c.WaitForPackages(regionalClusterClient, regionalClusterClient, options.ClusterName, targetClusterNamespace, true); err != nil {
		log.Warningf("Warning: Management cluster is created successfully, but some packages are failing. %v", err)
	}

	log.Infof("You can now access the management cluster %s by running 'kubectl config use-context %s'", options.ClusterName, kubeContext)
	isSuccessful = true
	return nil
}
```





```bash
root@photon-machine [ ~/tce-linux-amd64-v0.9.1 ]# tanzu management-cluster create --file /root/.config/tanzu/tkg/clusterconfigs/8yapkyf51a.yaml -v 6
compatibility file (/root/.config/tanzu/tkg/compatibility/tkg-compatibility.yaml) already exists, skipping download
BOM files inside /root/.config/tanzu/tkg/bom already exists, skipping download
CEIP Opt-in status: false

Validating the pre-requisites...

vSphere 7.0 Environment Detected.

You have connected to a vSphere 7.0 environment which does not have vSphere with Tanzu enabled. vSphere with Tanzu includes
an integrated Tanzu Kubernetes Grid Service which turns a vSphere cluster into a platform for running Kubernetes workloads in dedicated
resource pools. Configuring Tanzu Kubernetes Grid Service is done through vSphere HTML5 client.

Tanzu Kubernetes Grid Service is the preferred way to consume Tanzu Kubernetes Grid in vSphere 7.0 environments. Alternatively you may
deploy a non-integrated Tanzu Kubernetes Grid instance on vSphere 7.0.
Note: To skip the prompts and directly deploy a non-integrated Tanzu Kubernetes Grid instance on vSphere 7.0, you can set the 'DEPLOY_TKG_ON_VSPHERE7' configuration variable to 'true'

Do you want to configure vSphere with Tanzu? [y/N]: n
Would you like to deploy a non-integrated Tanzu Kubernetes Grid management cluster on vSphere 7.0? [y/N]: y
Deploying TKG management cluster on vSphere 7.0 ...
Identity Provider not configured. Some authentication features won't work.
Checking if VSPHERE_CONTROL_PLANE_ENDPOINT 192.168.75.190 is already in use

Setting up management cluster...
Validating configuration...
Using infrastructure provider vsphere:v0.7.10
Generating cluster configuration...
Setting up bootstrapper...
Fetching configuration for kind node image...
kindConfig:
 &{{Cluster kind.x-k8s.io/v1alpha4}  [{  map[] [{/var/run/docker.sock /var/run/docker.sock false false }] [] [] []}] { 0  100.96.0.0/11 100.64.0.0/13 false } map[] map[] [apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
imageRepository: projects.registry.vmware.com/tkg
etcd:
  local:
    imageRepository: projects.registry.vmware.com/tkg
    imageTag: v3.4.13_vmware.15
dns:
  type: CoreDNS
  imageRepository: projects.registry.vmware.com/tkg
  imageTag: v1.8.0_vmware.5] [] [] []}
Creating kind cluster: tkg-kind-c7mdj9tkvpds01kldv60
Creating cluster "tkg-kind-c7mdj9tkvpds01kldv60" ...
Ensuring node image (projects.registry.vmware.com/tkg/kind/node:v1.21.2_vmware.1) ...
Image: projects.registry.vmware.com/tkg/kind/node:v1.21.2_vmware.1 present locally
Preparing nodes ...
Writing configuration ...
Starting control-plane ...
Installing CNI ...
Installing StorageClass ...
Waiting 2m0s for control-plane = Ready ...
Ready after 29s
Bootstrapper created. Kubeconfig: /root/.kube-tkg/tmp/config_XeymX3N6
Installing providers on bootstrapper...
Fetching providers
Installing cert-manager Version="v1.1.0"
Waiting for cert-manager to be available...
Installing Provider="cluster-api" Version="v0.3.23" TargetNamespace="capi-system"
Installing Provider="bootstrap-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-bootstrap-system"
Installing Provider="control-plane-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-control-plane-system"
Installing Provider="infrastructure-vsphere" Version="v0.7.10" TargetNamespace="capv-system"
installed  Component=="cluster-api"  Type=="CoreProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="BootstrapProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="ControlPlaneProvider"  Version=="v0.3.23"
installed  Component=="vsphere"  Type=="InfrastructureProvider"  Version=="v0.7.10"
Waiting for provider infrastructure-vsphere
Waiting for provider bootstrap-kubeadm
Waiting for provider control-plane-kubeadm
Waiting for provider cluster-api
Waiting for resource capi-kubeadm-control-plane-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
Waiting for resource capv-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
Waiting for resource capi-kubeadm-bootstrap-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-kubeadm-bootstrap-system', retrying
Waiting for resource capi-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-system', retrying
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-kubeadm-bootstrap-system', retrying
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-system', retrying
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-kubeadm-bootstrap-system', retrying
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-system', retrying
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-kubeadm-bootstrap-system', retrying
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-system', retrying
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-kubeadm-bootstrap-system', retrying
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-system', retrying
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-kubeadm-bootstrap-system', retrying
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-system', retrying
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
Waiting for resource capi-kubeadm-bootstrap-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-webhook-system', retrying
Waiting for resource capi-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-webhook-system', retrying
Waiting for resource capi-kubeadm-control-plane-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-webhook-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-webhook-system', retrying
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-webhook-system', retrying
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-webhook-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-webhook-system', retrying
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-webhook-system', retrying
Passed waiting on provider control-plane-kubeadm after 45.090421449s
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
Passed waiting on provider bootstrap-kubeadm after 45.145190037s
Passed waiting on provider cluster-api after 45.164279414s
Waiting for resource capv-controller-manager of type *v1.Deployment to be up and running
Passed waiting on provider infrastructure-vsphere after 50.136019294s
Success waiting on all providers.
Start creating management cluster...
patch cluster object with operation status:
	{
		"metadata": {
			"annotations": {
				"TKGOperationInfo" : "{\"Operation\":\"Create\",\"OperationStartTimestamp\":\"2022-01-23 04:31:48.203724236 +0000 UTC\",\"OperationTimeout\":1800}",
				"TKGOperationLastObservedTimestamp" : "2022-01-23 04:31:48.203724236 +0000 UTC"
			}
		}
	}
cluster control plane is still being initialized, retrying
cluster control plane is still being initialized, retrying
cluster control plane is still being initialized, retrying
cluster control plane is still being initialized, retrying
cluster control plane is still being initialized, retrying
Getting secret for cluster
Waiting for resource tanzu-control-plan-kubeconfig of type *v1.Secret to be up and running
Saving management cluster kubeconfig into /root/.kube/config
Installing providers on management cluster...
Fetching providers
Installing cert-manager Version="v1.1.0"
Waiting for cert-manager to be available...
Installing Provider="cluster-api" Version="v0.3.23" TargetNamespace="capi-system"
Installing Provider="bootstrap-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-bootstrap-system"
Installing Provider="control-plane-kubeadm" Version="v0.3.23" TargetNamespace="capi-kubeadm-control-plane-system"
Installing Provider="infrastructure-vsphere" Version="v0.7.10" TargetNamespace="capv-system"
installed  Component=="cluster-api"  Type=="CoreProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="BootstrapProvider"  Version=="v0.3.23"
installed  Component=="kubeadm"  Type=="ControlPlaneProvider"  Version=="v0.3.23"
installed  Component=="vsphere"  Type=="InfrastructureProvider"  Version=="v0.7.10"
Waiting for provider infrastructure-vsphere
Waiting for provider control-plane-kubeadm
Waiting for provider bootstrap-kubeadm
Waiting for provider cluster-api
Waiting for resource capi-kubeadm-control-plane-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
Waiting for resource capv-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
Waiting for resource capi-kubeadm-bootstrap-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-kubeadm-bootstrap-system', retrying
Waiting for resource capi-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-controller-manager' in namespace 'capi-system', retrying
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
Waiting for resource capi-kubeadm-bootstrap-controller-manager of type *v1.Deployment to be up and running
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-webhook-system', retrying
Waiting for resource capi-controller-manager of type *v1.Deployment to be up and running
Passed waiting on provider cluster-api after 5.222704053s
pods are not yet running for deployment 'capi-kubeadm-control-plane-controller-manager' in namespace 'capi-kubeadm-control-plane-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-webhook-system', retrying
Waiting for resource capi-kubeadm-control-plane-controller-manager of type *v1.Deployment to be up and running
Passed waiting on provider control-plane-kubeadm after 15.071911826s
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
pods are not yet running for deployment 'capi-kubeadm-bootstrap-controller-manager' in namespace 'capi-webhook-system', retrying
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
Passed waiting on provider bootstrap-kubeadm after 20.136969953s
pods are not yet running for deployment 'capv-controller-manager' in namespace 'capv-system', retrying
Waiting for resource capv-controller-manager of type *v1.Deployment to be up and running
Passed waiting on provider infrastructure-vsphere after 30.107974737s
Success waiting on all providers.
Waiting for the management cluster to get ready for move...
Waiting for resource tanzu-control-plan of type *v1alpha3.Cluster to be up and running
Waiting for resources type *v1alpha3.MachineDeploymentList to be up and running
Waiting for resources type *v1alpha3.MachineList to be up and running
Waiting for addons installation...
Waiting for resources type *v1alpha3.ClusterResourceSetList to be up and running
Waiting for resource antrea-controller of type *v1.Deployment to be up and running
Moving all Cluster API objects from bootstrap cluster to management cluster...
Performing move...
Discovering Cluster API objects
Moving Cluster API objects Clusters=1
Creating objects in the target cluster
Deleting objects from the source cluster
Waiting for additional components to be up and running...
Waiting for resource tanzu-addons-controller-manager of type *v1.Deployment to be up and running
Waiting for resource tkr-controller-manager of type *v1.Deployment to be up and running
Waiting for resource kapp-controller of type *v1.Deployment to be up and running
Waiting for packages to be up and running...
Waiting for package: antrea
Waiting for package: metrics-server
Waiting for package: tanzu-addons-manager
Waiting for package: vsphere-cpi
Waiting for package: vsphere-csi
Waiting for resource vsphere-csi of type *v1alpha1.PackageInstall to be up and running
Waiting for resource antrea of type *v1alpha1.PackageInstall to be up and running
Waiting for resource tanzu-addons-manager of type *v1alpha1.PackageInstall to be up and running
Waiting for resource metrics-server of type *v1alpha1.PackageInstall to be up and running
Waiting for resource vsphere-cpi of type *v1alpha1.PackageInstall to be up and running
packageinstalls.packaging.carvel.dev "vsphere-csi" not found, retrying
packageinstalls.packaging.carvel.dev "antrea" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-cpi" not found, retrying
packageinstalls.packaging.carvel.dev "metrics-server" not found, retrying
Successfully reconciled package: tanzu-addons-manager
packageinstalls.packaging.carvel.dev "metrics-server" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-cpi" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-csi" not found, retrying
packageinstalls.packaging.carvel.dev "antrea" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-cpi" not found, retrying
packageinstalls.packaging.carvel.dev "metrics-server" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-csi" not found, retrying
packageinstalls.packaging.carvel.dev "antrea" not found, retrying
packageinstalls.packaging.carvel.dev "metrics-server" not found, retrying
packageinstalls.packaging.carvel.dev "antrea" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-cpi" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-csi" not found, retrying
packageinstalls.packaging.carvel.dev "antrea" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-csi" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-cpi" not found, retrying
packageinstalls.packaging.carvel.dev "metrics-server" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-cpi" not found, retrying
packageinstalls.packaging.carvel.dev "metrics-server" not found, retrying
packageinstalls.packaging.carvel.dev "antrea" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-csi" not found, retrying
packageinstalls.packaging.carvel.dev "metrics-server" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-cpi" not found, retrying
packageinstalls.packaging.carvel.dev "antrea" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-csi" not found, retrying
packageinstalls.packaging.carvel.dev "antrea" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-cpi" not found, retrying
packageinstalls.packaging.carvel.dev "vsphere-csi" not found, retrying
packageinstalls.packaging.carvel.dev "metrics-server" not found, retrying
waiting for 'metrics-server' Package to be installed, retrying
waiting for 'vsphere-csi' Package to be installed, retrying
waiting for 'antrea' Package to be installed, retrying
waiting for 'vsphere-cpi' Package to be installed, retrying
waiting for 'metrics-server' Package to be installed, retrying
waiting for 'vsphere-cpi' Package to be installed, retrying
waiting for 'vsphere-csi' Package to be installed, retrying
waiting for 'antrea' Package to be installed, retrying

waiting for 'vsphere-cpi' Package to be installed, retrying
waiting for 'metrics-server' Package to be installed, retrying
waiting for 'antrea' Package to be installed, retrying
waiting for 'vsphere-csi' Package to be installed, retrying
waiting for 'vsphere-csi' Package to be installed, retrying
waiting for 'vsphere-cpi' Package to be installed, retrying
waiting for 'metrics-server' Package to be installed, retrying
waiting for 'antrea' Package to be installed, retrying
waiting for 'vsphere-csi' Package to be installed, retrying
waiting for 'vsphere-cpi' Package to be installed, retrying
waiting for 'antrea' Package to be installed, retrying
waiting for 'metrics-server' Package to be installed, retrying
waiting for 'vsphere-csi' Package to be installed, retrying
waiting for 'vsphere-cpi' Package to be installed, retrying
waiting for 'metrics-server' Package to be installed, retrying
waiting for 'antrea' Package to be installed, retrying
package reconciliation failed: kapp: Error: Timed out waiting after 30s, retrying
waiting for 'vsphere-cpi' Package to be installed, retrying
waiting for 'vsphere-csi' Package to be installed, retrying
waiting for 'antrea' Package to be installed, retrying
Successfully reconciled package: antrea
waiting for 'metrics-server' Package to be installed, retrying
Successfully reconciled package: vsphere-csi
Failure while waiting for package 'metrics-server'
Warning: Management cluster is created successfully, but some packages are failing. Failure while waiting for packages to be installed: package reconciliation failed: kapp: Error: Timed out waiting after 30s
Context set for management cluster tanzu-control-plan as 'tanzu-control-plan-admin@tanzu-control-plan'.
Deleting kind cluster: tkg-kind-c7mdj9tkvpds01kldv60

Management cluster created!


You can now create your first workload cluster by running the following:

  tanzu cluster create [name] -f [file]


Some addons might be getting installed! Check their status by running the following:

  kubectl get apps -A
```

## 部署 workload 集群

根据官方文档 [vSphere Workload Cluster Template](https://tanzucommunityedition.io/docs/latest/vsphere-wl-template/) 中给出的模版创建一个配置文件即可

```yaml
#! ---------------------------------------------------------------------
#! Basic cluster creation configuration
#! ---------------------------------------------------------------------

CLUSTER_NAME: user-cluster-1
CLUSTER_PLAN: dev
NAMESPACE: default
CNI: antrea

#! ---------------------------------------------------------------------
#! vSphere configuration
#! ---------------------------------------------------------------------

OS_ARCH: amd64
OS_NAME: photon
OS_VERSION: "3"
TKG_HTTP_PROXY_ENABLED: "false"
VSPHERE_CONTROL_PLANE_DISK_GIB: "20"
VSPHERE_CONTROL_PLANE_ENDPOINT: 192.168.75.192
VSPHERE_CONTROL_PLANE_MEM_MIB: "8192"
VSPHERE_CONTROL_PLANE_NUM_CPUS: "4"
VSPHERE_DATACENTER: /SH-IDC
VSPHERE_DATASTORE: /SH-IDC/datastore/datastore1
VSPHERE_FOLDER: /SH-IDC/vm/Tanzu-node
VSPHERE_NETWORK: /SH-IDC/network/VM Network
VSPHERE_PASSWORD: <encoded:SEMM=>
VSPHERE_RESOURCE_POOL: /SH-IDC/host/Tanzu-Cluster/Resources
VSPHERE_SERVER: 192.168.75.110
VSPHERE_SSH_AUTHORIZED_KEY: ssh-rsa 
VSPHERE_TLS_THUMBPRINT: EB:F3:D8:7A:E8:3D:1A:59:B0:DE:73:96:DC:B9:5F:13:86:EF:B6:27
VSPHERE_USERNAME: administrator@vsphere.local
VSPHERE_WORKER_DISK_GIB: "20"
VSPHERE_WORKER_MEM_MIB: "4096"
VSPHERE_WORKER_NUM_CPUS: "2"

#! ---------------------------------------------------------------------
#! Machine Health Check configuration
#! ---------------------------------------------------------------------

ENABLE_MHC: true
MHC_UNKNOWN_STATUS_TIMEOUT: 5m
MHC_FALSE_STATUS_TIMEOUT: 12m

#! ---------------------------------------------------------------------
#! Common configuration
#! ---------------------------------------------------------------------

# TKG_CUSTOM_IMAGE_REPOSITORY: ""
# TKG_CUSTOM_IMAGE_REPOSITORY_CA_CERTIFICATE: ""

# TKG_HTTP_PROXY: ""
# TKG_HTTPS_PROXY: ""
# TKG_NO_PROXY: ""

ENABLE_AUDIT_LOGGING: true

ENABLE_DEFAULT_STORAGE_CLASS: true

CLUSTER_CIDR: 100.96.0.0/11
SERVICE_CIDR: 100.64.0.0/13

# OS_NAME: ""
# OS_VERSION: ""
# OS_ARCH: ""

#! ---------------------------------------------------------------------
#! Autoscaler configuration
#! ---------------------------------------------------------------------

ENABLE_AUTOSCALER: false
```

## 扩容集群

### 扩容 control-plan 节点

```bash
root@photon-machine [ ~ ]# kubectl scale kcp user-cluster-1-control-plane --replicas=3
root@photon-machine [ ~ ]# kubectl get machine
NAME                                   PROVIDERID                                       PHASE     VERSION
user-cluster-1-control-plane-nc9w5     vsphere://42166405-f905-30e2-9c80-4446a5db3843   Running   v1.21.2+vmware.1
user-cluster-1-control-plane-ph6nw                                                      Pending   v1.21.2+vmware.1
user-cluster-1-md-0-7d5d6958b8-phqnx   vsphere://4216471e-2aeb-cf3f-ea8c-dc2bf4d4b2de   Running   v1.21.2+vmware.1
root@photon-machine [ ~ ]# kubectl get machine
NAME                                   PROVIDERID                                       PHASE          VERSION
user-cluster-1-control-plane-nc9w5     vsphere://42166405-f905-30e2-9c80-4446a5db3843   Running        v1.21.2+vmware.1
user-cluster-1-control-plane-ph6nw                                                      Provisioning   v1.21.2+vmware.1
user-cluster-1-md-0-7d5d6958b8-phqnx   vsphere://4216471e-2aeb-cf3f-ea8c-dc2bf4d4b2de   Running        v1.21.2+vmware.1
root@photon-machine [ ~ ]# kubectl get machine

root@photon-machine [ ~ ]# kubectl get machine
NAME                                   PROVIDERID                                       PHASE          VERSION
user-cluster-1-control-plane-nc9w5     vsphere://42166405-f905-30e2-9c80-4446a5db3843   Running        v1.21.2+vmware.1
user-cluster-1-control-plane-ph6nw     vsphere://42160071-77a8-2edf-aed7-9f3dacd57e93   Provisioning   v1.21.2+vmware.1
user-cluster-1-md-0-7d5d6958b8-phqnx   vsphere://4216471e-2aeb-cf3f-ea8c-dc2bf4d4b2de   Running        v1.21.2+vmware.1
```

### 扩容 work 节点

```bash
root@photon-machine [ ~ ]# kubectl scale md user-cluster-1-control-plane --replicas=3
root@photon-machine [ ~ ]# kubectl get machine
NAME                                   PROVIDERID                                       PHASE          VERSION
user-cluster-1-control-plane-ph6nw     vsphere://42160071-77a8-2edf-aed7-9f3dacd57e93   Running        v1.21.2+vmware.1
user-cluster-1-md-0-7d5d6958b8-f2pmr                                                    Provisioning   v1.21.2+vmware.1
user-cluster-1-md-0-7d5d6958b8-fdmd5                                                    Provisioning   v1.21.2+vmware.1
user-cluster-1-md-0-7d5d6958b8-hncwr   vsphere://4216189f-1ed6-f850-337f-aef1d0e74e59   Running        v1.21.2+vmware.1

root@photon-machine [ ~ ]# kubectl get machine -o wide
NAME                                   PROVIDERID                                       PHASE     VERSION            NODENAME
user-cluster-1-control-plane-ph6nw     vsphere://42160071-77a8-2edf-aed7-9f3dacd57e93   Running   v1.21.2+vmware.1   user-cluster-1-control-plane-ph6nw
user-cluster-1-md-0-7d5d6958b8-f2pmr   vsphere://4216ea4f-551a-5660-e4b5-e5ec2ed88cda   Running   v1.21.2+vmware.1   user-cluster-1-md-0-7d5d6958b8-f2pmr
user-cluster-1-md-0-7d5d6958b8-fdmd5   vsphere://421662d8-3feb-3b79-2c1f-232e31c81968   Running   v1.21.2+vmware.1   user-cluster-1-md-0-7d5d6958b8-fdmd5
user-cluster-1-md-0-7d5d6958b8-hncwr   vsphere://4216189f-1ed6-f850-337f-aef1d0e74e59   Running   v1.21.2+vmware.1   user-cluster-1-md-0-7d5d6958b8-hncwr
```
