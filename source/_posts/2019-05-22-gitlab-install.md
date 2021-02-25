---
title: 部署 Gitlab 及 gitlab-runner
date: 2019-05-22
updated: 2019-05-22
categories: 技术
slug:
tag:
  - gitlab
  - CI
copyright: true
comment: true
---

目前gitlab官方给出的安装方式有很多种，普遍采用Omnibus包、Docker安装。官方说的😂**我们强烈建议使用 Omnibus 包安装 GitLab ，因为它安装起来更快、更容易升级版本，而且包含了其他安装方式所没有的可靠性功能。**

## 1.Omnibus包安装，也就是rpm包、deb包安装😂

### CentOS7

```bash
# 安装依赖
sudo yum install -y curl policycoreutils-python openssh-server
sudo systemctl enable sshd
sudo systemctl start sshd

# 配置防火墙
sudo firewall-cmd --permanent --add-service=http
sudo systemctl reload firewalld

# 添加官方的软件包源
# curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.rpm.sh | sudo bash

# 国内用户添加清华大学镜像站的源，下载速度会快些。
sudo cat > /etc/yum.repos.d/gitlab-ce.repo <<EOF
[gitlab-ce]
name=Gitlab CE Repository
baseurl=https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el7/
gpgcheck=0
enabled=1
Ece

sudo yum makecache
# 然后安装最新的版本
yum install -y gitlab-ce
# 安装指定版本 12.3.5
yum install gitlab-ce-12.3.5-ce.0.el7.x86_64.rpm

# 也可以使用 wget 的方式把 rpm 包下载下来安装
wget https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el7/gitlab-ce-12.8.2-ce.0.el7.x86_64.rpm
yum install gitlab-ce-12.8.2-ce.0.el7.x86_64.rpm
```

### Ubuntu 1804

```bash
sudo apt-get install openssh-server
curl https://packages.gitlab.com/gpg.key 2> /dev/null | sudo apt-key add - &>/dev/null

# 添加清华大学的镜像站源 bionic是 Ubuntu18.04 xenial是16.04，根据自己的 Ubuntu 发行版本修改一下下
deb https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/ubuntu bionic main
sudo apt-get update
sudo apt-get install gitlab-ce

# 也可以考虑使用 wget 的方式把 deb 包下载下来
wget https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/ubuntu/pool/bionic/main/g/gitlab-ce/gitlab-ce_12.3.5-ce.0_amd64.deb

opkg -i gitlab-ce/gitlab-ce_12.3.5-ce.0_amd64.deb
```

----

## 2.打补丁，补充汉化的补丁

```bash
git clone https://gitlab.com/xhang/gitlab.git
cd gitlab

# 获取当前安装的版本
gitlab_version=$(cat /opt/gitlab/embedded/service/gitlab-rails/VERSION)

# 生成对应版本补丁文件
git diff v${gitlab_version} v${gitlab_version}-zh > ../${gitlab_version}-zh.diff

gitlab-ctl stop

# 打补丁的时候会提示一些补丁文件不存在，一定要跳过这些文件，不然后面reconfig的时候会报错的。
patch -d /opt/gitlab/embedded/service/gitlab-rails -p1 < ${gitlab_version}-zh.diff

# 重启gitlab
gitlab-ctl reconfigure
gitlab-ctl restart
```

### reconfigure 失败

## 3.进行一些配置，gitlab的配置文件在/etc/gitlab/gitlab.rb

```json
# 修改为你自己的域名或者IP，是单引号，而且前面的 http 不要改
external_url  'http://gitlab.domain'

# 邮件配置，选用外部SMTP服务器
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.office365.com"
gitlab_rails['smtp_port'] =  587
gitlab_rails['smtp_user_name'] = "xxxx@outlook.com"
gitlab_rails['smtp_password'] = "password"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['smtp_tls'] = true
gitlab_rails['gitlab_email_from'] = 'xxxx@outlook.com'
```

## 安装 gitlab-runner

### CentOS/RHEL

新建 `/etc/yum.repos.d/gitlab-runner.repo`，内容为

```bash
[gitlab-runner]
name=gitlab-runner
baseurl=https://mirrors.tuna.tsinghua.edu.cn/gitlab-runner/yum/el7
repo_gpgcheck=0
gpgcheck=0
enabled=1
gpgkey=https://packages.gitlab.com/gpg.key
```

再执行

```bash
sudo yum makecache
sudo yum install gitlab-runner -y
# 安装指定版本 其中 12.3.5 即为指定的版本号
yum install gitlab-runner-12.3.5-1.x86_64 -y
```

### Debian/Ubuntu

首先信任 GitLab 的 GPG 公钥:

```bash
curl https://packages.gitlab.com/gpg.key 2> /dev/null | sudo apt-key add - &>/dev/null
```

再选择你的 Debian/Ubuntu 版本，文本框中内容写进 `/etc/apt/sources.list.d/gitlab-runner.list`

#### Debian

根据自己的发行版代号修改一下 `stretch`

```bash
deb http://mirrors.tuna.tsinghua.edu.cn/gitlab-runner/debian stretch main
```

#### Ubuntu

根据自己的发行版代号修改一下 `bionic`

```bash
deb https://mirrors.tuna.tsinghua.edu.cn/gitlab-runner/ubuntu bionic main
```

配置好 deb 源之后再执行

```bash
sudo apt uodate
apt install gitlab-runner -y
```

## 注册 gitlab-runner

使用 root 用户从 web 端登录到 gitlab 管理中心。在 `概览` --> `Runner` 。在右上角会有以下，稍后会用到。

- 在 Runner 设置时指定以下 URL
- 在安装过程中使用以下注册令牌：

![image-20200310202057916](https://blog.k8s.li/img/20200310202057916.png)

安装好 gitlab-runner 之后如果直接向 gitlab 注册则会失败，提示 `ERROR: Registering runner... failed   runner=qRGh2M86 status=500 Internal Server Error`

```bash
╭─root@gitlab ~
╰─# gitlab-runner register
Runtime platform                                    arch=amd64 os=linux pid=6818 revision=1b659122 version=12.8.0
Running in system-mode.

Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
http://10.10.107.216/
Please enter the gitlab-ci token for this runner:
qRGh2M86iTasjBn1dU8L
Please enter the gitlab-ci description for this runner:
[gitlab]: runner-centos
Please enter the gitlab-ci tags for this runner (comma separated):
centos
ERROR: Registering runner... failed   runner=qRGh2M86 status=500 Internal Server Error
PANIC: Failed to register this runner. Perhaps you are having network problems
```

### 修改 gitlab 默认网络设置

使用 root 用户从 web 端登录到 gitlab 管理中心 http://${ip}/admin 。管理中心 --> 设置 --> 网络 –> 外发请求 –> 允许来自钩子和服务的对本地网络的请求。以下选项全部允许，才能通过外部请求的方式注册 gitlab-runner。

- Allow requests to the local network from web hooks and services
- Allow requests to the local network from system hooks

**为了安全起见**，也可以在 Whitelist to allow requests to the local network from hooks and services 下方的那个框框里添加上白名单，允许授权的 IP 。修改好之后不要忘记点击底部那个绿色按钮 `保存修改` 。

#### 500 错误

如果点击 `保存修改` 之后就跳转到 Gitlab 500 错误的页面，这种情况比较僵硬😂。尝试在管理中心修改其他设置保存时，也会出现 500 的情况。在安装 gitlab 的机器上查看一下日志。运行 `gitlab-ctl tail` 查看实时的日志。此时等到日志输出减慢的时候我们多按几下回车，然后就立即去点击`保存修改`  按钮，这样就能捕捉到此刻的错误日志。

```verilog
==> /var/log/gitlab/gitlab-rails/production.log <==
Started PATCH "/admin/application_settings/network" for 10.0.30.2 at 2020-03-10 11:08:20 +0000
Processing by Admin::ApplicationSettingsController#network as HTML
  Parameters: {"utf8"=>"✓", "authenticity_token"=>"[FILTERED]", "application_setting"=>{"allow_local_requests_from_web_hooks_and_services"=>"[FILTERED]", "allow_local_requests_from_system_hooks"=>"[FILTERED]", "outbound_local_requests_whitelist_raw"=>"", "dns_rebinding_protection_enabled"=>"1"}}
Completed 500 Internal Server Error in 40ms (ActiveRecord: 14.5ms | Elasticsearch: 0.0ms)

OpenSSL::Cipher::CipherError ():

lib/gitlab/crypto_helper.rb:27:in `aes256_gcm_decrypt'
app/models/concerns/token_authenticatable_strategies/encrypted.rb:45:in `get_token'
app/models/concerns/token_authenticatable_strategies/base.rb:27:in `ensure_token'
app/models/concerns/token_authenticatable_strategies/encrypted.rb:32:in `ensure_token'
app/models/concerns/token_authenticatable.rb:38:in `block in add_authentication_token_field'
app/services/application_settings/update_service.rb:36:in `execute'
lib/gitlab/metrics/instrumentation.rb:161:in `block in execute'
lib/gitlab/metrics/method_call.rb:36:in `measure'
lib/gitlab/metrics/instrumentation.rb:161:in `execute'
app/controllers/admin/application_settings_controller.rb:128:in `perform_update'
app/controllers/admin/application_settings_controller.rb:14:in `block (2 levels) in <class:ApplicationSettingsController>'
lib/gitlab/session.rb:11:in `with_session'
app/controllers/application_controller.rb:450:in `set_session_storage'
lib/gitlab/i18n.rb:55:in `with_locale'
lib/gitlab/i18n.rb:61:in `with_user_locale'
app/controllers/application_controller.rb:444:in `set_locale'
lib/gitlab/middleware/rails_queue_duration.rb:27:in `call'
lib/gitlab/metrics/rack_middleware.rb:17:in `block in call'
lib/gitlab/metrics/transaction.rb:57:in `run'
lib/gitlab/metrics/rack_middleware.rb:17:in `call'
lib/gitlab/request_profiler/middleware.rb:17:in `call'
lib/gitlab/middleware/go.rb:20:in `call'
lib/gitlab/etag_caching/middleware.rb:13:in `call'
lib/gitlab/middleware/correlation_id.rb:16:in `block in call'
lib/gitlab/middleware/correlation_id.rb:15:in `call'
lib/gitlab/middleware/multipart.rb:117:in `call'
lib/gitlab/middleware/read_only/controller.rb:42:in `call'
lib/gitlab/middleware/read_only.rb:18:in `call'
lib/gitlab/middleware/basic_health_check.rb:25:in `call'
lib/gitlab/request_context.rb:26:in `call'
lib/gitlab/metrics/requests_rack_middleware.rb:29:in `call'
lib/gitlab/middleware/release_env.rb:12:in `call'

==> /var/log/gitlab/gitlab-rails/production_json.log <==
{"method":"PATCH","path":"/admin/application_settings/network","format":"html","controller":"Admin::ApplicationSettingsController","action":"network","status":500,"error":"OpenSSL::Cipher::CipherError: ","duration":40.08,"view":0.0,"db":14.47,"time":"2020-03-10T11:08:20.061Z","params":[{"key":"utf8","value":"✓"},{"key":"_method","value":"patch"},{"key":"authenticity_token","value":"[FILTERED]"},{"key":"application_setting","value":{"allow_local_requests_from_web_hooks_and_services":"[FILTERED]","allow_local_requests_from_system_hooks":"[FILTERED]","outbound_local_requests_whitelist_raw":"","dns_rebinding_protection_enabled":"1"}}],"remote_ip":"10.0.30.2","user_id":1,"username":"root","ua":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36","queue_duration":2.55,"correlation_id":"9rvflpksdj2"}
```

其中错误的只要输出是在 `OpenSSL::Cipher::CipherError ():`

```verilog
Processing by Admin::ApplicationSettingsController#network as HTML
  Parameters: {"utf8"=>"✓", "authenticity_token"=>"[FILTERED]", "application_setting"=>{"allow_local_requests_from_web_hooks_and_services"=>"[FILTERED]", "allow_local_requests_from_system_hooks"=>"[FILTERED]", "outbound_local_requests_whitelist_raw"=>"", "dns_rebinding_protection_enabled"=>"1"}}
Completed 500 Internal Server Error in 40ms (ActiveRecord: 14.5ms | Elasticsearch: 0.0ms)
OpenSSL::Cipher::CipherError ():
```

> 搜索了一下，发现网上说是由于迁移导入项目后，没有导入原来的加密信息`/etc/gitlab/gitlab-secrets.json`， 但是原来的加密信息文件我已经找不到了，后面发现可以直接重置就行了
>
> 参考 [自搭gitlab报500错误](https://hihozhou.com/blog/2019/08/01/gitlab-500.html)

命令行输入`gitlab-rails console`，然后输入

`ApplicationSetting.current.reset_runners_registration_token!`即可，这样在保存修改的时候就不会再报 500 的问题了。应该是我重新安装 Gitlab 之后的加密信息不对所致🤔。

```bash
╭─root@gitlab ~
╰─# gitlab-rails console
--------------------------------------------------------------------------------
 GitLab:       12.3.5 (2417d5becc7)
 GitLab Shell: 10.0.0
 PostgreSQL:   10.9
--------------------------------------------------------------------------------
Loading production environment (Rails 5.2.3)
irb(main):001:0> ApplicationSetting.current.reset_runners_registration_token!
=> true
irb(main):002:0> exit
```

### 注册

以上已经安装好并修改默认的网络设置允许 runner 所在的 IP 向 gitlab 发起外部请求。运行 `gitlab-runner register` 根据相应的提示输入 `URL` 和 `token` 即可。最后根据机器的类型选择好 runner 的类型，这个也是跑 CI 任务时的环境，到时候可以在项目的设置中选择启动相应的 runner 。

```bash
╭─root@runner ~
╰─# gitlab-runner register                                                                                    128 ↵
Runtime platform                                    arch=amd64 os=linux pid=7501 revision=1b659122 version=12.8.0
Running in system-mode.

Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
http://10.10.107.216/
Please enter the gitlab-ci token for this runner:
4hjjA7meRGuxEm3LyMjq
Please enter the gitlab-ci description for this runner:
[runner]:
Please enter the gitlab-ci tags for this runner (comma separated):
centos
Registering runner... succeeded                     runner=4hjjA7me
Please enter the executor: shell, ssh, virtualbox, docker-ssh+machine, kubernetes, docker, docker-ssh, parallels, docker+machine, custom:
[shell]: shell
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
```

提示成功之后然后在 `管理中心`--> `概览` --> `Runner` 可以查看到相应的 runner