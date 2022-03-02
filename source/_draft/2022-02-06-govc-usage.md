---
title: ESXi/vCenter 自动化管理工具 govc 使用记录
date: 2022-02-06
updated: 2022-02-06
slug:
categories: 技术
tag:
  - govc
  - ESXi
  - vCenter
  - vSphere
copyright: true
comment: true
---

最近由于工作原因需要在 ESXi 主机上完成一些参数配置、虚拟交换机/网创建、虚拟机创建、VIB 安装、PCI 直通、虚拟机创建等工作，于是抽空整理了一下在使用 govc 时踩的一些坑。

## govc

[govc](https://github.com/vmware/govmomi/tree/master/govc) 是 VMware 官方 [govmomi](https://github.com/vmware/govmom) 库的一个封装实现。使用它可以完成对 ESXi 主机或 vCenter 的一些操作。比如创建虚拟机、管理快照等。基本上能在 ESXi 或 vCenter 上的操作，在 govmomi 中都有对应的实现。目前 govc 支持的 ESXi / vCenter 版本有 7.0, 6.7, 6.5 , 6.0 (5.x 版本太老了，干脆放弃吧)。

使用 govc 连接 ESXi 主机或 vCenter 可以通过设置环境变量或者命令行参数，建议使用环境变量，如果通过命令行 flag 的话，将明文规定用户名和密码输出来有一定的安全风险。

```shell
Options:
  -cert=                           Certificate [GOVC_CERTIFICATE]
  -dc=                             Datacenter [GOVC_DATACENTER]
  -debug=false                     Store debug logs [GOVC_DEBUG]
  -dump=false                      Enable Go output
  -host=                           Host system [GOVC_HOST]
  -host.dns=                       Find host by FQDN
  -host.ip=                        Find host by IP address
  -host.ipath=                     Find host by inventory path
  -host.uuid=                      Find host by UUID
  -json=false                      Enable JSON output
  -k=false                         Skip verification of server certificate [GOVC_INSECURE]
  -key=                            Private key [GOVC_PRIVATE_KEY]
  -persist-session=true            Persist session to disk [GOVC_PERSIST_SESSION]
  -tls-ca-certs=                   TLS CA certificates file [GOVC_TLS_CA_CERTS]
  -tls-known-hosts=                TLS known hosts file [GOVC_TLS_KNOWN_HOSTS]
  -trace=false                     Write SOAP/REST traffic to stderr
  -u=https://root@esxi.yoi.li/sdk  ESX or vCenter URL [GOVC_URL]
  -verbose=false                   Write request/response data to stderr
  -vim-namespace=vim25             Vim namespace [GOVC_VIM_NAMESPACE]
  -vim-version=7.0                 Vim version [GOVC_VIM_VERSION]
  -xml=false                       Enable XML output
```

通过 `GOVC_URL` 环境变量指定 ESXi 主机或 vCenter 的 URL，登录的用户名和密码可设置在 GOVC_URL 中或者单独设置 `GOVC_USERNAME` 和 `GOVC_PASSWORD`。如果 https 证书是自签的域名或者 IP 需要通过设置 `GOVC_INSECURE=true` 参数来允许不安全的 https 连接。

```shell
$ export GOVC_URL="https://root:password@esxi.k8s.li"
$ export GOVC_INSECURE=true
$ govc about
FullName:     VMware ESXi 7.0.2 build-17867351
Name:         VMware ESXi
Vendor:       VMware, Inc.
Version:      7.0.2
Build:        17867351
OS type:      vmnix-x86
API type:     HostAgent
API version:  7.0.2.0
Product ID:   embeddedEsx
UUID:
```
如果用户名和密码当中有特殊字符比如` \ @ /`，建议分别设置 `GOVC_URL`、`GOVC_USERNAME` 和 `GOVC_PASSWORD` 这样能避免特殊字符在 `GOVC_URL` 出现一些奇奇怪怪的问题。

## 获取主机信息

### `govc host.info`

通过 host.info 自命命令可以得到 ESXi 主机的基本信息，

- Path: 当前主机在集群中的资源路径
- Manufacturer: 硬件设备制造商
- Logical CPUs: 逻辑 CPU 的数量，以及 CPU 的基础频率
- Processor type: CPU 的具体型号，由于我的是 ES 版的 E-2126G，所以无法显示出具体的型号🤣
- CPU usage:  CPU 使用的负载情况
- Memory:  主机安装的内存大小
- Memory usage:  内存使用的负载情况
- Boot time: 开机时间
- State:  连接状态

```bash
$ govc host.info
Name:              hp-esxi.lan
  Path:            /ha-datacenter/host/hp-esxi.lan/hp-esxi.lan
  Manufacturer:    HPE
  Logical CPUs:    6 CPUs @ 3000MHz
  Processor type:  Genuine Intel(R) CPU 0000 @ 3.00GHz
  CPU usage:       3444 MHz (19.1%)
  Memory:          32613MB
  Memory usage:    26745 MB (82.0%)
  Boot time:       2021-12-05 06:11:53.42802 +0000 UTC
  State:           connected
```

如果加上 -json 参数会得到一个至少 3w 行的 json 输出，里面包含的 ESXi 主机的所有信息，然后可以使用 jq 命令去过滤出一些自己所需要的参数。

```bash
╭─root@esxi-debian-devbox ~
╰─# govc host.info -json=true > host_info.json
╭─root@esxi-debian-devbox ~
╰─# wc host_info.json
  34522   73430 1188718 host_info.json
╭─root@esxi-debian-devbox ~
╰─# govc host.info -json | jq '.HostSystems[0].Summary.Hardware'
{
  "Vendor": "HPE",
  "Model": "ProLiant MicroServer Gen10 Plus",
  "Uuid": "30363150",
  "MemorySize": 34197471232,
  "CpuModel": "Genuine Intel(R) CPU 0000 @ 3.00GHz",
  "CpuMhz": 3000,
  "NumCpuPkgs": 1,
  "NumCpuCores": 6,
  "NumCpuThreads": 6,
  "NumNics": 4,
  "NumHBAs": 3
}
```

如果加上 -dump 参数，则会以 Golang 结构体的格式来输出，输出的内容也是包含了 ESXi 主机的所有信息，用它可以比较方便地定位某个信息的结构体，这一点对基于 govmomi 来开发其他的功能来说十分方便。尤其是在写单元测试的时候，可以从这里 dump 出一些数据来进行 mock。需要注意的是，并不是所有的子命令都支持 json 格式的输出。

```golang
mo.HostSystem{
    ManagedEntity: mo.ManagedEntity{
        ExtensibleManagedObject: mo.ExtensibleManagedObject{
            Self:           types.ManagedObjectReference{Type:"HostSystem", Value:"ha-host"},
            Value:          nil,
            AvailableField: nil,
        },
        Parent:        &types.ManagedObjectReference{Type:"ComputeResource", Value:"ha-compute-res"},
        CustomValue:   nil,
        OverallStatus: "green",
        ConfigStatus:  "yellow",
        ConfigIssue:   []types.BaseEvent{
            &types.RemoteTSMEnabledEvent{
                HostEvent: types.HostEvent{
                    Event: types.Event{
                        Key:             1,
                        ChainId:         0,
                        CreatedTime:     time.Now(),
                        UserName:        "",
                        Datacenter:      (*types.DatacenterEventArgument)(nil),
                        ComputeResource: (*types.ComputeResourceEventArgument)(nil),
                        Host:            &types.HostEventArgument{
                            EntityEventArgument: types.EntityEventArgument{
                                EventArgument: types.EventArgument{},
                                Name:          "hp-esxi.lan",
                            },
                            Host: types.ManagedObjectReference{Type:"HostSystem", Value:"ha-host"},
                        },
                        Vm:                   (*types.VmEventArgument)(nil),
                        Ds:                   (*types.DatastoreEventArgument)(nil),
                        Net:                  (*types.NetworkEventArgument)(nil),
                        Dvs:                  (*types.DvsEventArgument)(nil),
                        FullFormattedMessage: "SSH for the host hp-esxi.lan has been enabled",
                        ChangeTag:            "",
                    },
                },
            },
        },
```

在写单元测试的时候，我经常用它来 mock 一些特殊硬件设备的信息，这比自己手写这些结构体要方便很多。比如以`mpx.vmhba<Adapter>:C<Channel>:T<Target>:L<LUN> ` 命名的硬盘可以通过  `PlugStoreTopology` 这个结构体来获取该硬盘的 NAA 号：

```golang
func getDiskIDByHostPlugStoreTopology(hpst *types.HostPlugStoreTopology, diskName string) string {
	for _, path := range hpst.Path {
		if path.Name == diskName {
			s := strings.Split(path.Target, "-sas.")
			return s[len(s)-1]
		}
	}
	return ""
}

// 单元测试代码如下：
var plugStoreTopology = &types.HostPlugStoreTopology{
	Path: []types.HostPlugStoreTopologyPath{
		{
			Key:           "key-vim.host.PlugStoreTopology.Path-vmhba0:C0:T1:L0",
			Name:          "vmhba0:C0:T1:L0",
			ChannelNumber: 0,
			TargetNumber:  1,
			LunNumber:     0,
			Adapter:       "key-vim.host.PlugStoreTopology.Adapter-vmhba0",
			Target:        "key-vim.host.PlugStoreTopology.Target-sas.500056b3d93828c0",
			Device:        "key-vim.host.PlugStoreTopology.Device-020000000055cd2e414dc39d4e494e54454c20",
		},
	},
}


func TestGetDiskIDByHostPlugStoreTopology(t *testing.T) {
	tests := []struct {
		name string
		want string
	}{
		{
			name: "vmhba0:C0:T1:L0",
			want: "500056b3d93828c0",
		},
		{
			name: "vmhba0:C0:T2:L0",
			want: "",
		},
		{
			name: "",
			want: "",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := getDiskIDByHostPlugStoreTopology(plugStoreTopology, tt.name); got != tt.want {
				t.Errorf("getDiskIDByHostPlugStoreTopology() = %v, want %v", got, tt.want)
			}
		})
	}
}
```

再比如 NVMe 硬盘可以通过 `NvmeTopology` 这个数据对象获取它的序列号

```golang
func getNVMeIDByHostNvmeTopology(hnt *types.HostNvmeTopology, diskName string) string {
	for _, adapter := range hnt.Adapter {
		for _, controller := range adapter.ConnectedController {
			for _, ns := range controller.AttachedNamespace {
				if ns.Name == diskName {
					return strings.TrimSpace(controller.SerialNumber)
				}
			}
		}
	}
	return ""
}

// 单元测试代码如下：
var nvmeTopology = &types.HostNvmeTopology{
	Adapter: []types.HostNvmeTopologyInterface{
		{
			Key:     "key-vim.host.NvmeTopology.Interface-vmhba0",
			Adapter: "key-vim.host.PcieHba-vmhba0",
			ConnectedController: []types.HostNvmeController{
				{
					Key:                     "key-vim.host.NvmeController-256",
					ControllerNumber:        256,
					Subnqn:                  "nqn.2021-06.com.intel:PHAB123502CU1P9SGN  ",
					Name:                    "nqn.2021-06.com.intel:PHAB123502CU1P9SGN",
					AssociatedAdapter:       "key-vim.host.PcieHba-vmhba0",
					TransportType:           "pcie",
					FusedOperationSupported: false,
					NumberOfQueues:          2,
					QueueSize:               1024,
					AttachedNamespace: []types.HostNvmeNamespace{
						{
							Key:              "key-vim.host.NvmeNamespace-t10.NVMe____Dell_Ent_NVMe_P5600_MU_U.2_1.6TB________00035CB406E4D25C@256",
							Name:             "t10.NVMe____Dell_Ent_NVMe_P5600_MU_U.2_1.6TB________00035CB406E4D25C",
							Id:               1,
							BlockSize:        512,
							CapacityInBlocks: 3125627568,
						},
					},
					VendorId:        "0x8086",
					Model:           "Dell Ent NVMe P5600 MU U.2 1.6TB        ",
					SerialNumber:    "PHAB123502CU1P9SGN  ",
					FirmwareVersion: "1.0.0   PCIe",
				},
			},
		},
		{
			Key:     "key-vim.host.NvmeTopology.Interface-vmhba1",
			Adapter: "key-vim.host.PcieHba-vmhba1",
			ConnectedController: []types.HostNvmeController{
				{
					Key:                     "key-vim.host.NvmeController-257",
					ControllerNumber:        257,
					Subnqn:                  "nqn.2021-06.com.intel:PHAB123602H81P9SGN  ",
					Name:                    "nqn.2021-06.com.intel:PHAB123602H81P9SGN",
					AssociatedAdapter:       "key-vim.host.PcieHba-vmhba1",
					TransportType:           "pcie",
					FusedOperationSupported: false,
					NumberOfQueues:          2,
					QueueSize:               1024,
					AttachedNamespace: []types.HostNvmeNamespace{
						{
							Key:              "key-vim.host.NvmeNamespace-t10.NVMe____Dell_Ent_NVMe_P5600_MU_U.2_1.6TB________00035CEE23E4D25C@257",
							Name:             "t10.NVMe____Dell_Ent_NVMe_P5600_MU_U.2_1.6TB________00035CEE23E4D25C",
							Id:               1,
							BlockSize:        512,
							CapacityInBlocks: 3125627568,
						},
					},
					VendorId:        "0x8086",
					Model:           "Dell Ent NVMe P5600 MU U.2 1.6TB        ",
					SerialNumber:    "PHAB123602H81P9SGN  ",
					FirmwareVersion: "1.0.0   PCIe",
				},
			},
		},
	},
}

func TestGetNVMeIDByHostNvmeTopology(t *testing.T) {
	tests := []struct {
		name string
		want string
	}{
		{
			name: "t10.NVMe____Dell_Ent_NVMe_P5600_MU_U.2_1.6TB________00035CEE23E4D25C",
			want: "PHAB123602H81P9SGN",
		},
		{
			name: "t10.NVMe____Dell_Ent_NVMe_P5600_MU_U.2_1.6TB",
			want: "",
		},
		{
			name: "",
			want: "",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := getNVMeIDByHostNvmeTopology(nvmeTopology, tt.name); got != tt.want {
				t.Errorf("getNVMeIDByHostNvmeTopology() = %v, want %v", got, tt.want)
			}
		})
	}
}
```

## 配置 ESXi 主机参数

通过 `host.option.ls` 可以列出当前 ESXi 主机所有的配置选项

```bash
$ govc host.option.ls
Annotations.WelcomeMessage:
BufferCache.FlushInterval:                          30000
BufferCache.HardMaxDirty:                           95
BufferCache.PerFileHardMaxDirty:                    50
BufferCache.SoftMaxDirty:                           15
CBRC.DCacheMemReserved:                             400
CBRC.Enable:                                        false
COW.COWMaxHeapSizeMB:                               192
COW.COWMaxREPageCacheszMB:                          256
COW.COWMinREPageCacheszMB:                          0
COW.COWREPageCacheEviction:                         1
Config.Defaults.host.TAAworkaround:                 true
Config.Defaults.monitor.if_pschange_mc_workaround:  false
Config.Defaults.security.host.ruissl:               true
Config.Defaults.vGPU.consolidation:                 false
Config.Etc.issue:
Config.Etc.motd:                                    The time and date of this login have been sent to the system logs.
```

通过 `host.option.set` 可以设置 ESXi 主机参数，例如如果想要配置 NFS 存储心跳超时时间可以通过如下方式

```bash
$ govc host.option.set NFS.HeartbeatTimeout 30
```

## 开启 ssh 服务

通过 `host.service` 可以对 ESXi 主机上的服务进行相关操作。

```shell
$ govc host.service
Where ACTION is one of: start, stop, restart, status, enable, disable

# 启动 ssh 服务
$ govc host.service start TSM-SSH
# 将 ssh 服务设置为开机自启
$ govc host.service enable TSM-SSH
# 查看 ssh 服务的状态
$ govc host.service status TSM-SSH
```

## 创建虚拟交换机和端口组

### 创建虚拟交换机

```
```

### 创建端口组

## 创建虚拟机

```bash
$ VM_NAME="centos-test"
$ govc vm.create -ds='datastore*' -net='VM Network' -net.adapter=vmxnet3 -disk 1G -on=false ${VM_NAME}
$ govc vm.change -cpu.reservation=%d -memory-pin=true -vm ${VM_NAME}
$ govc vm.change -g centos7_64Guest -c %d -m 16384 -latency high -vm ${VM_NAME}
$ govc device.pci.add -vm ${VM_NAME}
$ govc device.cdrom.add -vm ${VM_NAME}
$ govc device.cdrom.insert -vm ${VM_NAME} -device cdrom-3000
$ govc device.connect -vm ${VM_NAME} cdrom-3000
$ govc vm.power -on=true ${VM_NAME}
```

## 导入 ova 虚拟机

主流的 Linux 发行版提供 ova 模版的并不多，虽然 ova 作为一种开发的虚拟机模版标准，但是大家好像都不怎么使用。比如基本上都会提供 qcow2 或者 raw 格式的景象。但 ESXi 上只能使用 VMDK 的镜像，二者需要一定的转换才行。

- [bionic-server-cloudimg-amd64.ova](https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.ova)
- [focal-server-cloudimg-amd64.ova ](https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.ova)

## 执行 Guest 主机命令

## 克隆虚拟机

## 虚拟机快照

## govmomi

有些情况下 govc 或者 esxcli 命令支持的并不是很全，比如配置 PCI 设备直通。在 ESXi 7.0 以上可以通过 esxcli 命令配置 PCI 设备直通，但是 ESXI 7.0 以下的版本如 6.7.0 是不支持的。如果要支持的话，就需要自己去实现了，下面是我参照 govmomi 库实现的配置 PCI 通的功能。

```go
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"

	"github.com/vmware/govmomi"
	"github.com/vmware/govmomi/view"
	"github.com/vmware/govmomi/vim25/methods"
	"github.com/vmware/govmomi/vim25/mo"
	"github.com/vmware/govmomi/vim25/types"
	"k8s.io/klog/v2"
)

type EsxiClient struct {
	client   *govmomi.Client
	ctx      context.Context
	Host     string
	Username string
	Password string
}

// NewClient creates a ESXi client which embedded a govmomi client
// @param host: the ESXi host IP or FQDN
// @param username: the ESXi username
// @param password: the ESXi password
func NewEsxiClient(host string, username string, password string) (*EsxiClient, error) {
	sdkUrl := &url.URL{
		Scheme: "https",
		Host:   host,
		Path:   "/sdk",
	}
	ctx := context.Background()
	sdkUrl.User = url.UserPassword(username, password)
	client, err := govmomi.NewClient(ctx, sdkUrl, true)
	if err != nil {
		return nil, err
	}
	return &EsxiClient{
		Host:     host,
		Username: username,
		Password: password,
		client:   client,
		ctx:      ctx,
	}, nil
}

// Close closes the connection to ESXi host
func (ec *EsxiClient) Close() error {
	return ec.client.Logout(ec.ctx)
}

// ListPciDevices returns a list of PCI devices which support passthru
func (ec *EsxiClient) ListPciDevices() (*[]types.HostPciDevice, error) {
	client := ec.client.Client
	m := view.NewManager(client)
	m.Client()
	v, err := m.CreateContainerView(ec.ctx, client.ServiceContent.RootFolder, []string{"HostSystem"}, true)
	if err != nil {
		return nil, err
	}
	defer func() {
		if err := v.Destroy(ec.ctx); err != nil {
			klog.Errorf("failed to destroy container view: %v", err)
		}
	}()

	var hosts []mo.HostSystem
	if err := v.Retrieve(ec.ctx, []string{"HostSystem"}, []string{"name", "hardware", "config"}, &hosts); err != nil {
		return nil, err
	}

	host := hosts[0]
	pciDevices := make([]types.HostPciDevice, 0)

	for _, device := range host.Hardware.PciDevice {
		if isPciPassthruCapable(host.Config.PciPassthruInfo, device.Id) {
			pciDevices = append(pciDevices, device)
		}
	}
	return &pciDevices, nil
}

// UpdatePciPassthru updates the pci passthru configuration,
// @param pciID: the pci device id
// @param enable: true to enable, false to disable
func (ec *EsxiClient) UpdatePassthruConfig(id string, enabled bool) error {
	client := ec.client.Client
	m := view.NewManager(client)
	m.Client()
	v, err := m.CreateContainerView(ec.ctx, client.ServiceContent.RootFolder, []string{"HostSystem"}, true)
	if err != nil {
		return err
	}
	defer func() {
		if err := v.Destroy(ec.ctx); err != nil {
			klog.Errorf("failed to destroy container view: %v", err)
		}
	}()
	var hosts []mo.HostSystem
	err = v.Retrieve(ec.ctx, []string{"HostSystem"}, []string{"configManager.pciPassthruSystem", "hardware", "config"}, &hosts)
	if err != nil {
		klog.Error(err)
	}
	host0 := hosts[0]
	applyNow := bool(false)
	req := types.UpdatePassthruConfig{
		This: *host0.ConfigManager.PciPassthruSystem,
		Config: []types.BaseHostPciPassthruConfig{
			&types.HostPciPassthruConfig{
				Id:              id,
				ApplyNow:        &applyNow,
				PassthruEnabled: enabled,
			},
		},
	}
	resp, err := methods.UpdatePassthruConfig(ec.ctx, client.Client, &req)
	if err != nil {
		klog.Infof("UpdatePassthruConfig response: %v", resp)
		klog.Errorf("failed to update pci passthru config: %v", err)
	}
	if !isPciPassthruEnabled(host0.Config.PciPassthruInfo, id) {
		return errors.New("failed to enable pci passthru")
	}
	return nil
}

// IsPciPassthruEnabled returns true if the pci passthru is enableds
// @param id: the pci device id
func (ec *EsxiClient) IsPciPassthruActive(id string) (bool, error) {
	c := ec.client.Client
	m := view.NewManager(c)
	m.Client()
	v, err := m.CreateContainerView(ec.ctx, c.ServiceContent.RootFolder, []string{"HostSystem"}, true)
	if err != nil {
		return false, err
	}
	defer func() {
		if err := v.Destroy(ec.ctx); err != nil {
			klog.Errorf("failed to destroy container view: %v", err)
		}
	}()

	var hss []mo.HostSystem
	if err := v.Retrieve(ec.ctx, []string{"HostSystem"}, []string{"configManager.pciPassthruSystem", "hardware", "config"}, &hss); err != nil {
		return false, err
	}
	host0 := hss[0]
	if !isPciPassthruActive(host0.Config.PciPassthruInfo, id) {
		return false, errors.New("pci passthru is not active")
	}
	return true, nil
}

// isPciPassthruCapable returns true if the pci device is capable of passthru
// @param pciPassthruInfo: the pci passthru info
// @param id: the pci device id
func isPciPassthruCapable(pciPassthruInfo []types.BaseHostPciPassthruInfo, pciID string) bool {
	for _, pci := range pciPassthruInfo {
		if pci.GetHostPciPassthruInfo().Id == pciID {
			return pci.GetHostPciPassthruInfo().PassthruCapable
		}
	}
	return false
}

// isPciPassthruEnabled returns true if the pci device is enableds
// @param pciPassthruInfo: the pci passthru info
// @param id: the pci device id
func isPciPassthruEnabled(pciPassthruInfo []types.BaseHostPciPassthruInfo, pciID string) bool {
	for _, pci := range pciPassthruInfo {
		if pci.GetHostPciPassthruInfo().Id == pciID {
			return pci.GetHostPciPassthruInfo().PassthruEnabled
		}
	}
	return false
}

// isPciPassthruActive returns true if the pci device is active
// @param pciPassthruInfo: the pci passthru info
// @param id: the pci device id
func isPciPassthruActive(pciPassthruInfo []types.BaseHostPciPassthruInfo, pciID string) bool {
	for _, pci := range pciPassthruInfo {
		if pci.GetHostPciPassthruInfo().Id == pciID {
			return pci.GetHostPciPassthruInfo().PassthruActive
		}
	}
	return false
}

func main() {
	host := os.Getenv("ESXI_HOST")
	username := os.Getenv("ESXI_USERNAME")
	password := os.Getenv("ESXI_PASSWORD")
	ec, err := NewEsxiClient(host, username, password)
	defer func() {
		if err := ec.Close(); err != nil {
			klog.Errorf("failed to logout: %v", err)
		}
	}()
	if err != nil {
		klog.Errorf("failed to create esxi client: %v", err)
	}
	pciDevices, err := ec.ListPciDevices()
	if err != nil {
		klog.Errorf("get esxi host pci list failed", err)
	}
	output, err := json.Marshal(pciDevices)
	if err != nil {
		klog.Errorf("marshal pci devices failed", err)
	}
	fmt.Println(string(output))

	id := "0000:0b:00.0"
	if err := ec.UpdatePassthruConfig(id, true); err != nil {
		klog.Errorf("update pci passthru config failed: %v", err)
	}
}
```

## 参考

- [vSphere go命令行管理工具govc](https://gitbook.curiouser.top/origin/vsphere-govc.html)
