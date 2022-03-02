---
title: 基于 Gitlab-ci + Harbor 的 CI 流水线
date: 2020-04-12
updated: 2020-04-12
slug:
categories: 技术
tag:
  - gitlab
  - CI/CD
  - harbor
copyright: true
comment: true
---

对于 CI/CD（持续集成与持续交付）的基本概念网络上已经有很多大佬在普及啦，咱才疏学浅怕误人子弟所以就剽窃一下别人的解释啦 😂。下面就剽窃一下红帽子家的 [CI/CD 是什么？如何理解持续集成、持续交付和持续部署](https://www.redhat.com/zh/topics/devops/what-is-ci-cd) 官方文档：

**CI 持续集成**

![](https://p.k8s.li/409-images-for-snap-blog-postedit_image1.png)

图片剽窃自  [The Product Managers’ Guide to Continuous Delivery and DevOps](https://www.mindtheproduct.com/what-the-hell-are-ci-cd-and-devops-a-cheatsheet-for-the-rest-of-us/)

> CI/CD 中的“CI”始终指持续集成，它属于开发人员的自动化流程。成功的 CI 意味着应用代码的新更改会定期构建、测试并合并到共享存储库中。该解决方案可以解决在一次开发中有太多应用分支，从而导致相互冲突的问题。

**CD 持续交付**

![](https://p.k8s.li/409-images-for-snap-blog-postedit_image4-manual.png)

图片剽窃自 [The Product Managers’ Guide to Continuous Delivery and DevOps](https://www.mindtheproduct.com/what-the-hell-are-ci-cd-and-devops-a-cheatsheet-for-the-rest-of-us/)

> CI/CD 中的“CD”指的是持续交付和/或持续部署，这些相关概念有时会交叉使用。两者都事关管道后续阶段的自动化，但它们有时也会单独使用，用于说明自动化程度。
>
> 持续*交付*通常是指开发人员对应用的更改会自动进行错误测试并上传到存储库（如 [GitHub](https://redhatofficial.github.io/#!/main) 或容器注册表），然后由运维团队将其部署到实时生产环境中。这旨在解决开发和运维团队之间可见性及沟通较差的问题。因此，持续交付的目的就是确保尽可能减少部署新代码时所需的工作量。

**持续部署**

![](https://p.k8s.li/409-images-for-snap-blog-postedit_image4-manual-1585574252795.png)

图片剽窃自  [The Product Managers’ Guide to Continuous Delivery and DevOps](https://www.mindtheproduct.com/what-the-hell-are-ci-cd-and-devops-a-cheatsheet-for-the-rest-of-us/)

> 持续*部署*（另一种“CD”）指的是自动将开发人员的更改从存储库发布到生产环境，以供客户使用。它主要为了解决因手动流程降低应用交付速度，从而使运维团队超负荷的问题。持续部署以持续交付的优势为根基，实现了管道后续阶段的自动化。

总之而言  CI/CD 是一整套软件开发的流水线，开发人员提交完更新的代码之后，根据流水线的触发情况来执行自定义的流水线任务，比如代码质量检测、构建 docker 镜像为交付产品、自动化部署到测试环境或生产环境等等。这些需要一系列相关的软件来构建这套 CI/CD 的系统，本文就通过 Gitlab + gitlab-ci + Harbor 构建一个简陋的 CI/CD 流水线。

另外推荐读一下这篇 [The Product Managers’ Guide to Continuous Delivery and DevOps ](https://www.mindtheproduct.com/what-the-hell-are-ci-cd-and-devops-a-cheatsheet-for-the-rest-of-us/)

## Gitlab

目前 Gitlab 官方给出的安装方式有很多种，普遍采用 Omnibus 包、Docker 安装。也可以用官方的 helm Chart 部署在 Kubernenets 集群中，然后使用网络存储，比如 Gluster、NFS、Ceph、vSAN 等进行 PG 数据库和代码仓库持久化存储。

**官方建议采用 Omnibus 方式安装：**

> 我们强烈建议使用 Omnibus 包安装 GitLab ，因为它安装起来更快、更容易升级版本，而且包含了其他安装方式所没有的可靠性功能。

### Omnibus 包安装方式比较

摘自官方文档

- ✅ - Installed by default
- ⚙ - Requires additional configuration, or GitLab Managed Apps
- ⤓ - Manual installation required
- ❌ - Not supported or no instructions available
- N/A - Not applicable

| Component                                                                                                     | Description                                                                                                                                                                                                                                                                                                                                                                             |                                    [Omnibus GitLab](https://docs.gitlab.com/omnibus/)                                    |                             [GitLab chart](https://docs.gitlab.com/charts/)                             |                                          [GitLab.com](https://gitlab.com/)                                          |
| :------------------------------------------------------------------------------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------------------------: |
| [NGINX](https://docs.gitlab.com/ee/development/architecture.html#nginx)                                       | Routes requests to appropriate components, terminates SSL                                                                                                                                                                                                                                                                                                                               |                                     [✅](https://docs.gitlab.com/omnibus/settings/)                                     |                            [✅](https://docs.gitlab.com/charts/charts/nginx/)                            |   [✅](https://about.gitlab.com/handbook/engineering/infrastructure/production/architecture/#service-architecture)   |
| [Unicorn (GitLab Rails)](https://docs.gitlab.com/ee/development/architecture.html#unicorn)                    | Handles requests for the web interface and API                                                                                                                                                                                                                                                                                                                                          |                               [✅](https://docs.gitlab.com/omnibus/settings/unicorn.html)                               |                       [✅](https://docs.gitlab.com/charts/charts/gitlab/unicorn/)                       |                         [✅](https://docs.gitlab.com/ee/user/gitlab_com/index.html#unicorn)                         |
| [Sidekiq](https://docs.gitlab.com/ee/development/architecture.html#sidekiq)                                   | Background jobs processor                                                                                                                                                                                                                                                                                                                                                               |      [✅](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template)      |                       [✅](https://docs.gitlab.com/charts/charts/gitlab/sidekiq/)                       |                         [✅](https://docs.gitlab.com/ee/user/gitlab_com/index.html#sidekiq)                         |
| [Gitaly](https://docs.gitlab.com/ee/development/architecture.html#gitaly)                                     | Git RPC service for handling all Git calls made by GitLab                                                                                                                                                                                                                                                                                                                               |                            [✅](https://docs.gitlab.com/ee/administration/gitaly/index.html)                            |                        [✅](https://docs.gitlab.com/charts/charts/gitlab/gitaly/)                        |   [✅](https://about.gitlab.com/handbook/engineering/infrastructure/production/architecture/#service-architecture)   |
| [Praefect](https://docs.gitlab.com/ee/development/architecture.html#praefect)                                 | A transparent proxy between any Git client and Gitaly storage nodes.                                                                                                                                                                                                                                                                                                                    |                            [✅](https://docs.gitlab.com/ee/administration/gitaly/index.html)                            |                        [❌](https://docs.gitlab.com/charts/charts/gitlab/gitaly/)                        |   [✅](https://about.gitlab.com/handbook/engineering/infrastructure/production/architecture/#service-architecture)   |
| [GitLab Workhorse](https://docs.gitlab.com/ee/development/architecture.html#gitlab-workhorse)                 | Smart reverse proxy, handles large HTTP requests                                                                                                                                                                                                                                                                                                                                        |      [✅](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template)      |                       [✅](https://docs.gitlab.com/charts/charts/gitlab/unicorn/)                       |   [✅](https://about.gitlab.com/handbook/engineering/infrastructure/production/architecture/#service-architecture)   |
| [GitLab Shell](https://docs.gitlab.com/ee/development/architecture.html#gitlab-shell)                         | Handles `git` over SSH sessions                                                                                                                                                                                                                                                                                                                                                         |      [✅](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template)      |                     [✅](https://docs.gitlab.com/charts/charts/gitlab/gitlab-shell/)                     |   [✅](https://about.gitlab.com/handbook/engineering/infrastructure/production/architecture/#service-architecture)   |
| [GitLab Pages](https://docs.gitlab.com/ee/development/architecture.html#gitlab-pages)                         | Hosts static websites                                                                                                                                                                                                                                                                                                                                                                   |                             [⚙](https://docs.gitlab.com/ee/administration/pages/index.html)                             |                       [❌](https://gitlab.com/gitlab-org/charts/gitlab/issues/37)                       |                       [✅](https://docs.gitlab.com/ee/user/gitlab_com/index.html#gitlab-pages)                       |
| [Registry](https://docs.gitlab.com/ee/development/architecture.html#registry)                                 | Container registry, allows pushing and pulling of images                                                                                                                                                                                                                                                                                                                                | [⚙](https://docs.gitlab.com/ee/administration/packages/container_registry.html#container-registry-domain-configuration) |                          [✅](https://docs.gitlab.com/charts/charts/registry/)                          | [✅](https://docs.gitlab.com/ee/user/packages/container_registry/index.html#build-and-push-images-using-gitlab-cicd) |
| [Redis](https://docs.gitlab.com/ee/development/architecture.html#redis)                                       | Caching service                                                                                                                                                                                                                                                                                                                                                                         |                                [✅](https://docs.gitlab.com/omnibus/settings/redis.html)                                |                        [✅](https://docs.gitlab.com/omnibus/settings/redis.html)                        |   [✅](https://about.gitlab.com/handbook/engineering/infrastructure/production/architecture/#service-architecture)   |
| [PostgreSQL](https://docs.gitlab.com/ee/development/architecture.html#postgresql)                             | Database                                                                                                                                                                                                                                                                                                                                                                                |                               [✅](https://docs.gitlab.com/omnibus/settings/database.html)                               |                    [✅](https://github.com/helm/charts/tree/master/stable/postgresql)                    |                        [✅](https://docs.gitlab.com/ee/user/gitlab_com/index.html#postgresql)                        |
| [PgBouncer](https://docs.gitlab.com/ee/development/architecture.html#pgbouncer)                               | Database connection pooling, failover                                                                                                                                                                                                                                                                                                                                                   |                     [⚙](https://docs.gitlab.com/ee/administration/high_availability/pgbouncer.html)                     |               [❌](https://docs.gitlab.com/charts/installation/deployment.html#postgresql)               |  [✅](https://about.gitlab.com/handbook/engineering/infrastructure/production/architecture/#database-architecture)  |
| [Consul](https://docs.gitlab.com/ee/development/architecture.html#consul)                                     | Database node discovery, failover                                                                                                                                                                                                                                                                                                                                                       |                      [⚙](https://docs.gitlab.com/ee/administration/high_availability/consul.html)                      |               [❌](https://docs.gitlab.com/charts/installation/deployment.html#postgresql)               |                          [✅](https://docs.gitlab.com/ee/user/gitlab_com/index.html#consul)                          |
| [GitLab self-monitoring: Prometheus](https://docs.gitlab.com/ee/development/architecture.html#prometheus)     | Time-series database, metrics collection, and query service                                                                                                                                                                                                                                                                                                                             |                     [✅](https://docs.gitlab.com/ee/administration/monitoring/prometheus/index.html)                     |                    [✅](https://github.com/helm/charts/tree/master/stable/prometheus)                    |                        [✅](https://docs.gitlab.com/ee/user/gitlab_com/index.html#prometheus)                        |
| [GitLab self-monitoring: Alertmanager](https://docs.gitlab.com/ee/development/architecture.html#alertmanager) | Deduplicates, groups, and routes alerts from Prometheus                                                                                                                                                                                                                                                                                                                                 |      [⚙](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template)      |                    [✅](https://github.com/helm/charts/tree/master/stable/prometheus)                    |                           [✅](https://about.gitlab.com/handbook/engineering/monitoring/)                           |
| [GitLab self-monitoring: Grafana](https://docs.gitlab.com/ee/development/architecture.html#grafana)           | Metrics dashboard                                                                                                                                                                                                                                                                                                                                                                       |            [✅](https://docs.gitlab.com/ee/administration/monitoring/performance/grafana_configuration.html)            |                     [⤓](https://github.com/helm/charts/tree/master/stable/grafana)                     |                      [✅](https://dashboards.gitlab.com/d/RZmbBr7mk/gitlab-triage?refresh=30s)                      |
| [GitLab self-monitoring: Sentry](https://docs.gitlab.com/ee/development/architecture.html#sentry)             | Track errors generated by the GitLab instance                                                                                                                                                                                                                                                                                                                                           |        [⤓](https://docs.gitlab.com/omnibus/settings/configuration.html#error-reporting-and-logging-with-sentry)        |                      [❌](https://gitlab.com/gitlab-org/charts/gitlab/issues/1319)                      |              [✅](https://about.gitlab.com/handbook/support/workflows/500_errors.html#searching-sentry)              |
| [GitLab self-monitoring: Jaeger](https://docs.gitlab.com/ee/development/architecture.html#jaeger)             | View traces generated by the GitLab instance                                                                                                                                                                                                                                                                                                                                            |                              [❌](https://gitlab.com/gitlab-org/omnibus-gitlab/issues/4104)                              |                      [❌](https://gitlab.com/gitlab-org/charts/gitlab/issues/1320)                      |                            [❌](https://gitlab.com/gitlab-org/omnibus-gitlab/issues/4104)                            |
| [Redis Exporter](https://docs.gitlab.com/ee/development/architecture.html#redis-exporter)                     | Prometheus endpoint with Redis metrics                                                                                                                                                                                                                                                                                                                                                  |                [✅](https://docs.gitlab.com/ee/administration/monitoring/prometheus/redis_exporter.html)                |                            [✅](https://docs.gitlab.com/charts/charts/redis/)                            |                           [✅](https://about.gitlab.com/handbook/engineering/monitoring/)                           |
| [PostgreSQL Exporter](https://docs.gitlab.com/ee/development/architecture.html#postgresql-exporter)           | Prometheus endpoint with PostgreSQL metrics                                                                                                                                                                                                                                                                                                                                             |               [✅](https://docs.gitlab.com/ee/administration/monitoring/prometheus/postgres_exporter.html)               |                    [✅](https://github.com/helm/charts/tree/master/stable/postgresql)                    |                           [✅](https://about.gitlab.com/handbook/engineering/monitoring/)                           |
| [PgBouncer Exporter](https://docs.gitlab.com/ee/development/architecture.html#pgbouncer-exporter)             | Prometheus endpoint with PgBouncer metrics                                                                                                                                                                                                                                                                                                                                              |              [⚙](https://docs.gitlab.com/ee/administration/monitoring/prometheus/pgbouncer_exporter.html)              |               [❌](https://docs.gitlab.com/charts/installation/deployment.html#postgresql)               |                           [✅](https://about.gitlab.com/handbook/engineering/monitoring/)                           |
| [GitLab Exporter](https://docs.gitlab.com/ee/development/architecture.html#gitlab-exporter)                   | Generates a variety of GitLab metrics                                                                                                                                                                                                                                                                                                                                                   |                [✅](https://docs.gitlab.com/ee/administration/monitoring/prometheus/gitlab_exporter.html)                |              [✅](https://docs.gitlab.com/charts/charts/gitlab/gitlab-exporter/index.html)              |                           [✅](https://about.gitlab.com/handbook/engineering/monitoring/)                           |
| [Node Exporter](https://docs.gitlab.com/ee/development/architecture.html#node-exporter)                       | Prometheus endpoint with system metrics                                                                                                                                                                                                                                                                                                                                                 |                 [✅](https://docs.gitlab.com/ee/administration/monitoring/prometheus/node_exporter.html)                 |                      [N/A](https://gitlab.com/gitlab-org/charts/gitlab/issues/1332)                      |                           [✅](https://about.gitlab.com/handbook/engineering/monitoring/)                           |
| [Mattermost](https://docs.gitlab.com/ee/development/architecture.html#mattermost)                             | Open-source Slack alternative                                                                                                                                                                                                                                                                                                                                                           |                                 [⚙](https://docs.gitlab.com/omnibus/gitlab-mattermost/)                                 |               [⤓](https://docs.mattermost.com/install/install-mmte-helm-gitlab-helm.html)               |                      [⤓](https://docs.gitlab.com/ee/user/project/integrations/mattermost.html)                      |
| [MinIO](https://docs.gitlab.com/ee/development/architecture.html#minio)                                       | Object storage service                                                                                                                                                                                                                                                                                                                                                                  |                                              [⤓](https://min.io/download)                                              |                            [✅](https://docs.gitlab.com/charts/charts/minio/)                            |   [✅](https://about.gitlab.com/handbook/engineering/infrastructure/production/architecture/#storage-architecture)   |
| [Runner](https://docs.gitlab.com/ee/development/architecture.html#gitlab-runner)                              | Executes GitLab CI/CD jobs                                                                                                                                                                                                                                                                                                                                                              |                                          [⤓](https://docs.gitlab.com/runner/)                                          |                       [✅](https://docs.gitlab.com/runner/install/kubernetes.html)                       |                      [✅](https://docs.gitlab.com/ee/user/gitlab_com/index.html#shared-runners)                      |
| [Database Migrations](https://docs.gitlab.com/ee/development/architecture.html#database-migrations)           | Database migrations                                                                                                                                                                                                                                                                                                                                                                     |           [✅](https://docs.gitlab.com/omnibus/settings/database.html#disabling-automatic-database-migration)           |                      [✅](https://docs.gitlab.com/charts/charts/gitlab/migrations/)                      |                                                          ✅                                                          |
| [Certificate Management](https://docs.gitlab.com/ee/development/architecture.html#certificate-management)     | TLS Settings, Let’s Encrypt                                                                                                                                                                                                                                                                                                                                                            |                                 [✅](https://docs.gitlab.com/omnibus/settings/ssl.html)                                 |                        [✅](https://docs.gitlab.com/charts/installation/tls.html)                        |    [✅](https://about.gitlab.com/handbook/engineering/infrastructure/production/architecture/#secrets-management)    |
| [GitLab Geo Node](https://docs.gitlab.com/ee/development/architecture.html#gitlab-geo)                        | Geographically distributed GitLab nodes                                                                                                                                                                                                                                                                                                                                                 |              [⚙](https://docs.gitlab.com/ee/administration/geo/replication/index.html#setup-instructions)              |                        [❌](https://gitlab.com/gitlab-org/charts/gitlab/issues/8)                        |                                                          ✅                                                          |
| [LDAP Authentication](https://docs.gitlab.com/ee/development/architecture.html#ldap-authentication)           | Authenticate users against centralized LDAP directory                                                                                                                                                                                                                                                                                                                                   |                              [⤓](https://docs.gitlab.com/ee/administration/auth/ldap.html)                              |                      [⤓](https://docs.gitlab.com/charts/charts/globals.html#ldap)                      |                                  [❌](https://about.gitlab.com/pricing/#gitlab-com)                                  |
| [Outbound email (SMTP)](https://docs.gitlab.com/ee/development/architecture.html#outbound-email)              | Send email messages to users                                                                                                                                                                                                                                                                                                                                                            |                                 [⤓](https://docs.gitlab.com/omnibus/settings/smtp.html)                                 | [⤓](https://docs.gitlab.com/charts/installation/command-line-options.html#outgoing-email-configuration) |                    [✅](https://docs.gitlab.com/ee/user/gitlab_com/index.html#mail-configuration)                    |
| [Inbound email (SMTP)](https://docs.gitlab.com/ee/development/architecture.html#inbound-email)                | Receive messages to update issues                                                                                                                                                                                                                                                                                                                                                       |                           [⤓](https://docs.gitlab.com/ee/administration/incoming_email.html)                           | [⤓](https://docs.gitlab.com/charts/installation/command-line-options.html#incoming-email-configuration) |                    [✅](https://docs.gitlab.com/ee/user/gitlab_com/index.html#mail-configuration)                    |
| [Elasticsearch](https://docs.gitlab.com/ee/development/architecture.html#elasticsearch)                       | Improved search within GitLab                                                                                                                                                                                                                                                                                                                                                           |                             [⤓](https://docs.gitlab.com/ee/integration/elasticsearch.html)                             |                     [⤓](https://docs.gitlab.com/ee/integration/elasticsearch.html)                     |                                [❌](https://gitlab.com/groups/gitlab-org/-/epics/153)                                |
| [Sentry integration](https://docs.gitlab.com/ee/development/architecture.html#sentry)                         | Error tracking for deployed apps                                                                                                                                                                                                                                                                                                                                                        |                       [⤓](https://docs.gitlab.com/ee/user/project/operations/error_tracking.html)                       |               [⤓](https://docs.gitlab.com/ee/user/project/operations/error_tracking.html)               |                     [⤓](https://docs.gitlab.com/ee/user/project/operations/error_tracking.html)                     |
| [Jaeger integration](https://docs.gitlab.com/ee/development/architecture.html#jaeger)                         | Distributed tracing for deployed apps                                                                                                                                                                                                                                                                                                                                                   |                          [⤓](https://docs.gitlab.com/ee/user/project/operations/tracing.html)                          |                  [⤓](https://docs.gitlab.com/ee/user/project/operations/tracing.html)                  |                        [⤓](https://docs.gitlab.com/ee/user/project/operations/tracing.html)                        |
| [GitLab Managed Apps](https://docs.gitlab.com/ee/development/architecture.html#gitlab-managed-apps)           | Deploy [Helm](https://helm.sh/docs/), [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/), [Cert-Manager](https://docs.cert-manager.io/en/latest/), [Prometheus](https://prometheus.io/docs/introduction/overview/), a [Runner](https://docs.gitlab.com/runner/), [JupyterHub](https://jupyter.org/), [Knative](https://cloud.google.com/knative/) to a cluster |                [⤓](https://docs.gitlab.com/ee/user/project/clusters/index.html#installing-applications)                |        [⤓](https://docs.gitlab.com/ee/user/project/clusters/index.html#installing-applications)        |              [⤓](https://docs.gitlab.com/ee/user/project/clusters/index.html#installing-applications)              |

## 安装 Gitlab

咱遵从官方的建议，使用 Omnibus 包的方式来部署 Gitlab 实例。

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

### CentOS7

```bash
# 安装依赖
sudo yum install -y curl policycoreutils-python openssh-server

# 配置防火墙
sudo firewall-cmd --permanent --add-service=http
sudo systemctl reload firewalld

# 使用清华大学镜像站的源，下载速度会快些。
sudo cat > /etc/yum.repos.d/gitlab-ce.repo <<EOF
[gitlab-ce]
name=Gitlab CE Repository
baseurl=https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el7/
gpgcheck=0
enabled=1
Ece

sudo yum makecache

# 查看可用的版本neng'b
yum list gitlab-ce --showduplicates
# 然后安装最新的版本
yum install -y gitlab-ce
# 安装指定版本 12.3.5
yum install gitlab-ce-12.3.5-ce.0.el7.x86_64.rpm

# 也可以使用 wget 的方式把 rpm 包下载下来安装
wget https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el7/gitlab-ce-12.8.2-ce.0.el7.x86_64.rpm
yum install gitlab-ce-12.8.2-ce.0.el7.x86_64.rpm
```

安装成功之后会出现 Gitlab 的 Logo

```shell
           *.                  *.
          ***                 ***
         *****               *****
        .******             *******
        ********            ********
       ,,,,,,,,,***********,,,,,,,,,
      ,,,,,,,,,,,*********,,,,,,,,,,,
      .,,,,,,,,,,,*******,,,,,,,,,,,,
          ,,,,,,,,,*****,,,,,,,,,.
             ,,,,,,,****,,,,,,
                .,,,***,,,,
                    ,*,.

         _______ __  __          __
        / ____(_) /_/ /   ____ _/ /_
       / / __/ / __/ /   / __ `/ __ \
      / /_/ / / /_/ /___/ /_/ / /_/ /
      \____/_/\__/_____/\__,_/_.___/

    Thank you for installing GitLab!
    GitLab was unable to detect a valid hostname for your instance.
    Please configure a URL for your GitLab instance by setting `external_url`
    configuration in /etc/gitlab/gitlab.rb file.
    Then, you can start your GitLab instance by running the following command:
      sudo gitlab-ctl reconfigure
```

### 2.打补丁，补充汉化的补丁

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
```

### 3. 修改默认配置

修改 gitlab 的配置文件 `/etc/gitlab/gitlab.rb`

```ini
# 修改为你自己的域名或者 IP，是单引号，而且前面的 http 不要改
external_url  'http://gitlab.domain'

# 邮件配置，没有邮件服务器可以关闭邮件服务功能
gitlab_rails['smtp_enable'] = false
gitlab_rails['smtp_address'] = ""
gitlab_rails['smtp_port'] =  587
gitlab_rails['smtp_user_name'] = ""
gitlab_rails['smtp_password'] = ""
gitlab_rails['smtp_authentication'] = ""
gitlab_rails['smtp_enable_starttls_auto'] =
gitlab_rails['smtp_tls'] =
gitlab_rails['gitlab_email_from'] = ''
```

### 4. 初始化设置

修改完成配置之后使用 `gitlab-ctl reconfigure` 重新更新一下 gitlab 服务的配置，更新完成配置之后使用
`gitlab-ctl restart` 来重新启动 gitlab 。如果 reconfigure 失败，则需要 `systemctl enable gitlab- runsvdir && systemctl restart gitlab- runsvdir` 重启一下  `gitlab-runsvdir` 服务。

打开浏览器进行初始化账户设定密码，这个密码为 root 管理员账户的密码。设置完密码之后会自动跳转到登录页面。username 为 `root` 密码为刚刚设置的密码。

## 安装 gitlab-runner

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

### CentOS7

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

### 注册 gitlab-runner

使用 root 用户从 web 端登录到 gitlab 管理中心。在 `概览` --> `Runner` 。在右上角会有以下，稍后会用到。

- 在 Runner 设置时指定以下 URL
- 在安装过程中使用以下注册令牌：

安装好 gitlab-runner 之后如果直接向 gitlab 注册则会提示失败，提示 `ERROR: Registering runner... failed   runner=qRGh2M86 status=500 Internal Server Error` 。这是因为 Gitlab 默认禁止了私有网段 IP 里的 API 请求，需要手动开启才行。

```bash
╭─root@gitlab ~
╰─# gitlab-runner register
Runtime platform   arch=amd64 os=linux pid=6818 revision=1b659122 version=12.8.0
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

如果点击 `保存修改` 之后就跳转到 Gitlab 500 错误的页面。尝试在管理中心修改其他设置保存时，也会出现 500 的情况。在安装 gitlab 的机器上查看一下日志。运行 `gitlab-ctl tail` 查看实时的日志。此时等到日志输出减慢的时候我们多按几下回车，然后就立即去点击 `保存修改`  按钮，这样就能捕捉到此刻的错误日志。

```verilog
==> /var/log/gitlab/gitlab-rails/production.log <==
Started PATCH "/admin/application_settings/network" for 10.0.30.2 at 2020-03-10 11:08:20 +0000
Processing by Admin::ApplicationSettingsController#network as HTML
  Parameters: {"utf8"=>"✓", "authenticity_token"=>"[FILTERED]", "application_setting"=>{"allow_local_requests_from_web_hooks_and_services"=>"[FILTERED]", "allow_local_requests_from_system_hooks"=>"[FILTERED]", "outbound_local_requests_whitelist_raw"=>"", "dns_rebinding_protection_enabled"=>"1"}}
Completed 500 Internal Server Error in 40ms (ActiveRecord: 14.5ms | Elasticsearch: 0.0ms)
OpenSSL::Cipher::CipherError ():
lib/gitlab/crypto_helper.rb:27:in `aes256_gcm_decrypt'
```

其中错误的输出是在 `OpenSSL::Cipher::CipherError ():`

```verilog
Processing by Admin::ApplicationSettingsController#network as HTML
  Parameters: {"utf8"=>"✓", "authenticity_token"=>"[FILTERED]", "application_setting"=>{"allow_local_requests_from_web_hooks_and_services"=>"[FILTERED]", "allow_local_requests_from_system_hooks"=>"[FILTERED]", "outbound_local_requests_whitelist_raw"=>"", "dns_rebinding_protection_enabled"=>"1"}}
Completed 500 Internal Server Error in 40ms (ActiveRecord: 14.5ms | Elasticsearch: 0.0ms)
OpenSSL::Cipher::CipherError ():
```

> 搜索了一下，发现网上说是由于迁移导入项目后，没有导入原来的加密信息 `/etc/gitlab/gitlab-secrets.json`， 但是原来的加密信息文件我已经找不到了，后面发现可以直接重置就行了
>
> 参考 [自搭 gitlab 报 500 错误](https://hihozhou.com/blog/2019/08/01/gitlab-500.html)

命令行输入 `gitlab-rails console`，然后输入

`ApplicationSetting.current.reset_runners_registration_token!` 即可，这样在保存修改的时候就不会再报 500 的问题了。应该是重新安装 Gitlab 之后的加密信息不对所致。

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

### 在项目中注册 Runner

以上已经安装好并修改默认的网络设置允许 runner 所在的 IP 向 gitlab 发起外部请求。运行 `gitlab-runner register` 根据相应的提示输入 `URL` 和 `token` 即可。最后根据机器的类型选择好 runner 的类型，这个也是跑 CI 任务时的环境，到时候可以在项目的设置中选择启动相应的 runner 。

```bash
╭─root@runner ~
╰─# gitlab-runner register
Runtime platform   arch=amd64 os=linux pid=7501 revision=1b659122 version=12.8.0
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

- 提示成功之后然后在 `管理中心`--> `概览` --> `Runner` 可以查看到相应的 Runner 了。也可以手动编辑 `/etc/gitlab-runner/config.toml` 来注册相应类型的  Runner

```toml
concurrent = 1
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "runner"
  url = "http://10.10.107.216/"
  token = "ZTSAQ3q6x_upW9toyKTY"
  executor = "shell"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]

[[runners]]
  name = "docker-runner"
  url = "http://10.10.107.216/"
  token = "Cf1cy6yx4Y-bGjVnRf8m"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
  [runners.docker]
  # 在这里需要添加上 harbor 的地址，才能允许 pull 私有 registry 的镜像
    allowed_images = ["10.10.107.217/*:*"]
    tls_verify = false
    image = "golang:latest"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
```

## 部署 Harbor

- 在 harbor 项目的 release 页面下载离线安装包 [harbor-offline-installer-v1.9.4.tgz](https://github.com/goharbor/harbor/releases/download/v1.9.4/harbor-offline-installer-v1.9.4.tgz) 到部署的机器上。部署之前需要安装好 `docker` 和 `docker-compose` 。之后再修改 `harbor.yml` 配置文件中的以下内容：

```yaml
# hostname 需要修改为相应的域名或者 IP
hostname: 10.10.107.217

# http related config
http:
  # port for http, default is 80. If https enabled, this port will redirect to https port
  port: 80

# 首次登录时设定的 admin 账户密码
harbor_admin_password: Harbor12345

# 数据存储的目录
data_volume: /data

# clair CVE 漏洞数据库更新，这里建议设置为 1h
# 由于 clair 数据库在国内网络访问问题，需要设置 http 代理
clair:
  # The interval of clair updaters, the unit is hour, set to 0 to disable the updaters.
  updaters_interval: 1
proxy:
  http_proxy: 10.20.172.106:2080
  https_proxy:
  no_proxy:
  components:
    - clair
```

- 修改完配置文件之后再运行 `./install.sh --with-clair --with-chartmuseum` 将 clair 集成到 harbor 中。

```shell
╭─root@harbor /opt/harbor
╰─# ./install.sh --with-clair --with-chartmuseum
[Step 0]: checking installation environment ...
[Step 1]: loading Harbor images ...
[Step 2]: preparing environment ...
[Step 3]: starting Harbor ...
Creating network "harbor_harbor" with the default driver
Creating network "harbor_harbor-clair" with the default driver
Creating network "harbor_harbor-chartmuseum" with the default driver
Creating harbor-log ... done
Creating harbor-db     ... done
Creating registryctl   ... done
Creating harbor-portal ... done
Creating chartmuseum   ... done
Creating registry      ... done
Creating redis         ... done
Creating clair         ... done
Creating harbor-core   ... done
Creating harbor-jobservice ... done
Creating nginx             ... done

✔ ----Harbor has been installed and started successfully.----

Now you should be able to visit the admin portal at http://10.20.172.236.
For more details, please visit https://github.com/goharbor/harbor .
```

- 使用 `docker-compose ps` 检查 harbor 相关容器是否正常。

```shell
╭─root@harbor /opt/harbor
╰─# docker-compose ps
      Name                     Command                  State                 Ports
---------------------------------------------------------------------------------------------
chartmuseum         /docker-entrypoint.sh            Up (healthy)   9999/tcp
clair               /docker-entrypoint.sh            Up (healthy)   6060/tcp, 6061/tcp
harbor-core         /harbor/harbor_core              Up (healthy)
harbor-db           /docker-entrypoint.sh            Up (healthy)   5432/tcp
harbor-jobservice   /harbor/harbor_jobservice  ...   Up (healthy)
harbor-log          /bin/sh -c /usr/local/bin/ ...   Up (healthy)   127.0.0.1:1514->10514/tcp
harbor-portal       nginx -g daemon off;             Up (healthy)   8080/tcp
nginx               nginx -g daemon off;             Up (healthy)   0.0.0.0:80->8080/tcp
redis               redis-server /etc/redis.conf     Up (healthy)   6379/tcp
registry            /entrypoint.sh /etc/regist ...   Up (healthy)   5000/tcp
registryctl         /harbor/start.sh                 Up (healthy)
```

![](https://p.k8s.li/20200326163733610.png)

### 设置 insecure registry

- 在 runner 服务器上设置一下 `/etc/docker/daemon.json` 将私有 registry 的 IP 地址填入到 `insecure-registries` 数组中。这样才可以推送和拉取镜像

```json
{
  "insecure-registries" : ["10.10.107.217"]
}
```

- 使用 `docker login` 测试是否能登录成功：

```shell
╭─root@docker-230 /opt
╰─# docker login 10.10.107.217
Username: admin
Password:
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store
Login Succeeded
```

- 登录到 harbor 新建一个项目仓库，并按照 `docker tag SOURCE_IMAGE[:TAG] 10.20.172.236/ciest/IMAGE[:TAG]` 格式给本地 docker 镜像打上 tag 并测试推送到 harbor 是否成功。

```shell
╭─root@docker-230 /opt
╰─# docker tag openjdk:8-jdk-alpine 10.10.107.217/ops/openjdk:8-jdk-alpine
╭─root@docker-230 /opt
╰─# docker push !$
╭─root@docker-230 /opt
╰─# docker push 10.10.107.217/ops/openjdk:8-jdk-alpine
The push refers to repository [10.10.107.217/ops/openjdk]
ceaf9e1ebef5: Mounted from ops/ci-test
9b9b7f3d56a0: Mounted from ops/ci-test
f1b5933fe4b5: Mounted from ops/ci-test
8-jdk-alpine: digest: sha256:44b3cea369c947527e266275cee85c71a81f20fc5076f6ebb5a13f19015dce71 size: 947
```

- 在 harbor 项目的页面查看是否推送成功

![](https://p.k8s.li/20200326170403918.png)

## 测试 CI/CD 项目

- 在 Gitlab 中使用 Spring 模板新建一个项目，并添加 `.gitlab-ci.yaml` 配置文件。

![](https://p.k8s.li/20200326170523433.png)

```yaml
stages:
  - build
build-master:
  # Official docker image.
  image: docker:latest
  tags:
    - maven-runner
  stage: build
  services:
    - docker:dind
  before_script:
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" $CI_REGISTRY
  script:
    - docker info
    - docker build --pull -t "$CI_REGISTRY_IMAGE" .
    - docker push "$CI_REGISTRY_IMAGE"
  allow_failure: true

build:
  # Official docker image.
  image: docker:latest
  stage: build
  services:
    - docker:dind
  before_script:
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" $CI_REGISTRY
  script:
    - docker build --pull -t "$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_SLUG" .
    - docker push "$CI_REGISTRY_IMAGE:$CI_COMMIT_REF_SLUG"
  except:
    - master
```

### .gitlab-ci.yaml

`.gitlab-ci.yaml` 文件的配置高度依赖于项目本身，以及 CI/CD 流水线的需求。其配置文件主要由以下部分组成：

#### Pipeline

一次 Pipeline 其实相当于一次构建任务，里面可以包含很多个流程，如安装依赖、运行测试、编译、部署测试服务器、部署生产服务器等流程。任何提交或者 Merge Request 的合并都可以触发 Pipeline 构建，如下图所示：

```
+------------------+           +----------------+
|                  |  trigger  |                |
|   Commit / MR    +---------->+    Pipeline    |
|                  |           |                |
+------------------+           +----------------+
```

#### Stages

Stages 表示一个构建阶段，也就是上面提到的一个流程。我们可以在一次 Pipeline 中定义多个 Stages，这些 Stages 会有以下特点：

- 所有 Stages 会按照顺序运行，即当一个 Stage 完成后，下一个 Stage 才会开始
- 只有当所有 Stages 完成后，该构建任务 (Pipeline) 才会成功
- 如果任何一个 Stage 失败，那么后面的 Stages 不会执行，该构建任务 (Pipeline) 失败

Stages 和 Pipeline 的关系如下所示：

```txt
+--------------------------------------------------------+
|                                                        |
|  Pipeline                                              |
|                                                        |
|  +-----------+     +------------+      +------------+  |
|  |  Stage 1  |---->|   Stage 2  |----->|   Stage 3  |  |
|  +-----------+     +------------+      +------------+  |
|                                                        |
+--------------------------------------------------------+
```

#### Jobs

Jobs 表示构建工作，表示某个 Stage 里面执行的工作。我们可以在 Stages 里面定义多个 Jobs，这些 Jobs 会有以下特点：

- 相同 Stage 中的 Jobs 会并行执行
- 相同 Stage 中的 Jobs 都执行成功时，该 Stage 才会成功
- 如果任何一个 Job 失败，那么该 Stage 失败，即该构建任务 (Pipeline) 失败

Jobs 和 Stage 的关系如下所示：

```txt
+------------------------------------------+
|                                          |
|  Stage 1                                 |
|                                          |
|  +---------+  +---------+  +---------+   |
|  |  Job 1  |  |  Job 2  |  |  Job 3  |   |
|  +---------+  +---------+  +---------+   |
|                                          |
+------------------------------------------+
```

下面是一个 `.gitlab-ci.yaml`  样例：

```yaml
stages:
  - analytics
  - test
  - build
  - package
  - deploy

build:
  stage: analytics
  only:
    - master
    - tags
  tags:
    -
  script:
    - echo "=============== 开始代码质量检测 ==============="
    - echo "=============== 结束代码质量检测 ==============="

build:
  stage: build
  only:
    - master
    - tags
  tags:
    - runner-tag
  script:
    - echo "=============== 开始编译任务 ==============="
    - echo "=============== 结束编译任务 ==============="

package:
  stage: package
  tags:
    - runner-tag
  script:
    - echo "=============== 开始打包任务  ==============="
    - echo "=============== 结束打包任务  ==============="

build:
  stage: test
  only:
    - master
    - tags
  tags:
    - runner-tag
  script:
    - echo "=============== 开始测试任务 ==============="
    - echo "=============== 结束测试任务 ==============="

deploy_test:
  stage: deploy
  tags:
    - runner-tag
  script:
    - echo "=============== 自动部署到测试服务器  ==============="
  environment:
    name: test
    url: https://staging.example.com

deploy_test_manual:
  stage: deploy
  tags:
    - runner-tag
  script:
    - echo "=============== 手动部署到测试服务器  ==============="
  environment:
    name: test
    url: https://staging.example.com
  when: manual

deploy_production_manual:
  stage: deploy
  tags:
    - runner-tag
  script:
    - echo "=============== 手动部署到生产服务器  ==============="
  environment:
    name: production
    url: https://staging.example.com
  when: manual
```

- 修改好 `.gitlab-ci.yaml` 之后，将 CI/CD 过程中使用到的一些敏感信息，使用变量的方式填入在 项目 `设置` —> `CI/CD` —> `变量` 里。比如 Harbor 仓库的用户名密码、ssh 密钥信息、数据库配置信息等机密信息。

```ini
CI_REGISTRY: # Harbor 镜像仓库的地址
CI_REGISTRY_USER: # Harbor 用户名
CI_REGISTRY_PASSWORD: # Harbor 密码
CI_REGISTRY_IMAGE: # 构建镜像的名称
SSH_PASSWORD: # 部署测试服务器 ssh 密码
```

![](https://p.k8s.li/20200327102511419.png)

- 设置好相关变量之后在，在项目页面的 `CI/CD` —–> `流水线` 页面点击 `运行流水线` 手动触发流水线任务进行测试。

![](https://p.k8s.li/20200325163138089.png)

- 如果流水线任务构建成功的话，会显示 `已通过` 的表示

![](https://p.k8s.li/20200325163254316.png)

- 登录到 Harbor [http://10.10.107.217](http://10.10.107.217) 查看镜像是否构建成功

![](https://p.k8s.li/20200325163400519.png)

## 参考/推荐

- [GitLab Runner Docs](https://docs.gitlab.com/runner/)
- [GitLab Docs](https://docs.gitlab.com/ee/README.html)
- [kubernetes 系列之《构建企业级 CICD 平台(一)》](https://nicksors.cc/2019/07/12/kubernetes%E7%B3%BB%E5%88%97%E4%B9%8B%E3%80%8A%E6%9E%84%E5%BB%BA%E4%BC%81%E4%B8%9A%E7%BA%A7CICD%E5%B9%B3%E5%8F%B0-%E4%B8%80-%E3%80%8B.html)
- [GitLab 的 CI/CD 使用问题汇总](https://notes.mengxin.science/2018/09/02/gitlab-ci-cd-question-and-answer/)
- [基于 GitLab 的 CI 实践](https://moelove.info/2018/08/05/%E5%9F%BA%E4%BA%8E-GitLab-%E7%9A%84-CI-%E5%AE%9E%E8%B7%B5/)
- [gitlab-notes](https://blog.fleeto.us/courses/gitlab-notes/)
- [gitlab runner 部署细节优化](https://xiaogenban1993.github.io/18.5/xiaomi_gitlabrunner.html)
- [Jenkins 的 Pipeline 脚本在美团餐饮 SaaS 中的实践](https://tech.meituan.com/2018/08/02/erp-cd-jenkins-pipeline.html)
- [GitLab CI 示例：Docker 镜像打包发布 & SSH 部署](https://laogen.site/gitlab-ci/example-docker-ssh-deploy/)
- [gitlab CI/CD 优化](https://theviper.xyz/gitlab-ci-cd-optimize.html)
- [GitLab-CI 使用 Docker 进行持续部署](http://zacksleo.top/2017/04/22/GitLab-CI%E4%BD%BF%E7%94%A8Docker%E8%BF%9B%E8%A1%8C%E6%8C%81%E7%BB%AD%E9%83%A8%E7%BD%B2/)
- [Docker Gitlab CI 部署 Spring Boot 项目](https://furur.xyz/2019/11/03/docker-gitlab-ci-deploy-springboot-project/)
- [RHEL7/CentOS7 在线和离线安装 GitLab 配置使用实践](https://wsgzao.github.io/post/gitlab/)
- [GitLab Shell 如何通过 SSH 工作](https://wayjam.me/post/how-gitlab-shell-works-with-ssh.md)
- [GitLab 镜像手册](https://websoft9.gitbook.io/gitlab-image-guide/)
- [Gitlab 部署和汉化以及简单运维](https://xuanwo.io/2016/04/13/gitlab-install-intro/)

## 社群问答 QA | CI/CD 相关

以下内容是整理摘自 [《(2000+) kubernetes 社群分享 QA 汇总》](https://blog.k8s.li/K8s-QA.html)，中有关 CI/CD 相关的问答，从 2000 多个 QA 里使用关键字搜索 Gitlab、CI/CD、Jenkins 等，然后将一些相关的问题进行汇总。方便问题自查和从中吸取经验。

### 2019-04-03：容器环境下的持续集成最佳实践

> Q：Kubernetes 上主流的 CI/CD 方案是啥？

A：其实这无关 Kubernetes，从市场占有率来看，前三名分别是 Jenkins、JetBrains TeamCity、CircleCI。[来源：](https://www.datanyze.com/market-share/ci)

> Q：GitLab 自带的 CI 与 Jenkins 和 GitLab 结合的 CI，该如何选择？想知道更深层次的理解。

A：还是要结合自己团队的实际情况做选择。从成熟度来说，肯定是 Jenkins 用户最多，成熟度最高，缺点是侧重 Java，配置相对繁琐。GitLab 自带的 CI 相对简单，可以用 yaml，和 GitLab 结合的最好，但功能肯定没有 Jenkins 全面。如果是小团队新项目，GitLab CI 又已经可以满足需求的话，并不需要上 Jenkins，如果是较大的团队，又是偏 Java 的，个人更偏向 Jenkins。

> Q：Jenkins 如果不想运行在 Kubernetes 里面，该怎么和 Kubernetes 集成？

A：从 CI 的流程来说，CI 应用是不是跑在 Kubernetes 的并不重要，CI 只要能访问代码库，有权限在生产环境发布，是不是跑在容器里从效果来说其实没有区别，只是用 Kubernetes 部署 Jenkins 的话，运维的一致性比较好，运维团队不用额外花时间维护一套物理机的部署方案。

> Q：Kubernetes 的回滚方案是回滚代码，重做镜像，还是先切流量，后做修改？

A：代码一定是打包到镜像里的，镜像的版本就是代码的版本，所以一定是切镜像。至于回滚操作本身，Kubernetes 已经内置了很多滚动发布（Rollingupdate）的策略，无论是发新版本还是回滚版本，都可以做到用户无感知。

> Q：镜像大到几 G 的话如何更新部署，有什么好的实践呢，以及如何回滚？

A：几个要点：> Q：Drone 开放 API 服务吗？这样方便其他系统集成。

A：可以调整一下思路，直接把需要的功能做成镜像在 Drone 里调用就好了。

> Q：如果有 Drone 的 Server 怎么做高可用？

A：Drone serve r 用 Kubernetes 部署的话本身只起到了一个任务调度的作用，很难会遇到性能瓶颈。真的有性能问题可以尝试水平扩展 Drone server，共享同一数据库。

### [基于 GitLab 的 CI 实践](https://moelove.info/2018/08/05/%E5%9F%BA%E4%BA%8E-GitLab-%E7%9A%84-CI-%E5%AE%9E%E8%B7%B5/)

> Q：您提到把各种依赖都以 Service 的提供，请问是以哪种方式呢？ 比如 Python 的依赖，怎么做成 Service 呢？

A：Service 化的依赖，主要是指类似 DB / MySQL/ Reids 之类的。 或者是 dind 其实它提供的是 2375 端口的 TCP 服务。 Python 的依赖，我推荐的做法是， 构建一个换了源的 Python 镜像。 安装依赖的时候，耗时会少很多。 或者说， 可以在定义 Pipeline 的时候， 将虚拟环境的 venv 文件夹作为 cache ，之后的安装也会检查这个，避免不必要的安装。

> Q：请问，你们为什么不用 Jenkins Pipeline，而使用 GitLab CI？

A：主要原因是我提到的那几个方面。 集成较好， 界面美观优雅， 使用简单（所有有仓库写权限的人 都可以使用， 只要创建 .gitlab-ci.yml 并且配置了 Runner 即可使用） 。换个角度，我们来看下使用 Jenkins 的问题， Jenkins 对于项目的配置其实和 GitLab 的代码是分离的， 两部分的， 用户（或者说我们的开发者）在使用的时候， 需要有两个平台， 并且，大多数时候， Jenkins 的权限是不放开的。 对用户来讲， 那相当于是个黑盒。 那可能的问题是什么呢？ 遇到构建失败了， 但是只有运维知道发生了什么，但是研发无能为力，因为没有权限。 使用 GItLab 的好处，这个时候就更加突出了， 配置就在代码仓库里面，并且使用 YAML 的配置，很简单。 有啥问题，直接查，直接改。

> Q：关于 Runner 的清理的问题，在长时间使用后，Runner 机器上回产生很多的 Cache 容器，如何清理呢。能够在任务中自动清除吗？

A：这个就相对简单了，首先， 如果你的 Cache 容器确认没用了， 每个 Cache 容器其实都有名字的， 直接按 Cache 的名字过略， 批量删掉。 如果你不确定它是否有用，那你直接删掉也是不影响的， 因为 Docker Excutor 的执行机制是创建完 Service 容器后， 创建 Cache 容器。 要是删掉了，它只是会再创建一次。 如果你想在任务中清除， 目前还没做相关的实践，待我实践后，看看有没有很优雅的方式。

> Q：请问下 Maven 的 settings.xml 怎么处理？本地 Maven 仓库呢？

A：我们构建了私有的 Maven 镜像， 私有镜像中是默认使用了我们的私有源。 对于项目中用户无需关注 settings.xml 中是否配置 repo。

> Q：在 GitLab 的 CD 方案中，在部署的时候，需要在变量中配置跳板机的私钥，如果这个项目是对公司整部门开发，那么如何保护这个私钥呢？

A：可以使用 secret variable 将私钥写入其中， （但是项目的管理员，具备查看该 variable 的权限）开发一个 web server （其实只要暴露 IP 端口之类的就可以） 在 CI 执行的过程中去请求， server 对来源做判断 （比如 执行 CI 的时候，会有一些特定的变量，以此来判断，是否真的是 CI 在请求）然后返回私钥。

> Q：GitLab CI 适合什么类型的项目呢？国内目前还比较小众吧？

A：国内目前还较为小众（相比 Jenkins 来说）其实只要需要 CI 的项目，它都适合。

## 2015-09-23：基于 Docker 和 Java 的持续集成实践

> Q：CI 过程中 test 需要连接数据库的代码时，您在写测试案例方面有哪些经验分享？

A：单元测试不能依赖外部资源，用 mock，或者用 h2 等内存数据库替代。集成测试的时候是从接口层直接调用测试的，测试用例对数据库无感知。

> Q：请问部署到生产环境是自动触发还是需要手动审批？SQL 执行或回滚是否自动化？

A：当前是需要手动触发。SQL 更新当前没做到自动化，这块正在改进，因为部署私有环境需要。SQL 不支持回滚，代码做兼容。Docker 镜像回滚没有自动化。

> Q： 问一下你们的 Redis 内存版是用的什么？

A：我们用的内存版的 redis 是 [spullara/redis-protocol](https://github.com/spullara/redis-protocol) 中的 server 实现。不过这个实现部分功能没支持，比如 lua 脚本，我们自己做了改进。

> Q：介绍下 workflow 带来的好处。

A：workflow 的好处我那篇文章中有说明，如果没有 workflow，所有的步骤都在同一个配置的不同 step 实现，如果后面的失败，要重新从头开始。workflow 可以中途开始，并且每一步骤完成都会触发通知。

> Q：h2 并不完全兼容 MySQL 脚本，你们如何处理的？

A：我们通过一些 hack 的办法，会探测下数据库是什么类型的，替换掉一些不兼容的 SQL，进行容错。

> Q：请问你们在构建的时候，你说有些需要半个小时左右，那么构建过程的进度监控和健康监控你们怎么做的呢，如果有 build 失败了怎么处理呢？

A：CI 的每一步都有进度的，并且我们的团队通讯工具可以和 CI 集成，如果失败会发消息到群里通知大家。

> Q：cleanup 脚本做哪些？

A：主要是清理旧的 Docker 镜像，以及清理自动化测试产生的垃圾数据。

> Q：请问你们文件存储怎么解决的呢，使用自己的网络文件系统还是云服务？

A：文件系统支持多种 storage 配置，可以是本地目录（便于测试），也可以使云服务（比如 s3）。

> Q：刚才说你们能通过一键部署，但是中间无法监控，测试环境可以这么玩，那生产环境你们是怎么做的呢？还有你们后续的改造方向是自己开发？还是采用集成第三方软件？

A：生产环境 shell 当前只能是多加错误判断。这块我们在改进，比如通过 ansible 等工具，以及使用 Kubernetes 内置的 rolling-update。自动化部署这块还没有好的开源工具。

> Q：你们的测试用了很多代替方案、如 h2 代 MySQL，要保证测试效果，除了你们用的 hack 方法之外，是不是从写代码的时候就开始做了方便测试的设计？

A：对。这也是我文章中分享的观点之一。测试用例的编写人员要有业务代码的修改权限，最好是同一个人。要做自动化测试，业务代码必须要给测试留各种钩子以及后门。

> Q：请问你们的集群应用编排怎么做的？

A：上面说了，还没用到编排。一直等编排工具的成熟。正在测试 k8s。

> Q：你们做这个项目选型是出于什么考虑的，介绍里有提到使用一些脚本来管理容器解决开发和测试各种问题，感觉这种管理容器方式过于简单会带来管理问题，为何不用第三方开源项目来做二次开发，如：Kubernetes；另一个问题是，下一步有没有考虑如何让你的 Docker 和云服务平台结合，要解决运营成本问题（Docker 最大吸引力在这里），而不只是解决开发测试问题？

A：因为我们最早用的时候 k8s 1.0 还没有，变化太大，创业团队没精力跟进，脚本是粗暴简单的办法。一直在等待各种基于 Docker 的云解决方案呀，肯定考虑结合。

> Q：对于 Docker storage 分区用完问题，我想问一下，你们是使用 Docker 官方提供的 Registry 仓库吗，如何解决仓库单点问题，这机器要是故障了怎么办？

A：Registry 用的是官方的，后端存储是挂载到 s3 上的。没有 s3,推荐使用京东田琪团队开源的 [Speedy](https://github.com/jcloudpub/speedy)，实现了分布式存储。

> Q：除了介绍的 Java 相关的 CI 方案，对于 C/C++ 开发语言有没有推荐的 CI 方案？

A：Teamcity/Jenkins 等 CI 工具支持任何语言的。其实任何语言的 CI 都差不多，单元测试，集成测试。关键还在于依赖环境的准备以及集成测试用例的管理。

> Q：我看到你们为了方便测试和调试会有独立的集合 Docker 环境，这种环境和上线环境其实是有差别的，这样测试的结果能够代表线上环境吗？这种问题怎么看待？

A：所以我们有多个流程。清理数据的测试环境，以及不清理环境的沙箱环境。但这也不能避免一部分线上环境的数据导致的 bug。另外就是配合灰度上线机制。当前我们的灰度是通过代码中的开关实现的，使用这种方案的也很多，比如 facebook 的 Gatekeeper。

> Q：请问 Grouk 有涉及前端（Node.js 方面的）并结合 Docker 的 CI/CD 经历吗，可以分享下吗？

A：这我们也在尝试。当前 js 的测试主要还是基于 [ariya/phantomjs](https://github.com/ariya/phantomjs)，纯粹的 js 库比较方便测试，但如果牵扯到界面，就比较复杂些了。

## 2015-12-22：基于 Docker 和 Git 的持续集成工作流

> Q：开发每提交一个 bugfix，都会触发 jinkens 去构建镜像，那么多的开发者，岂不是要构建很多镜像？

A：没有错，我们是每次都触发构建 image，由于 image 是分层的，底层已经存在的父对象，是不用存储，只存储变化的部分所以再用的磁盘空间很低，在系统开始初，我做过统计，1000 个 image 也不到 9G，这其中还有很多基础镜像。

> Q：想问一个集群相关的，像 Docker 部署这部是直接调用 Docker 部署容器，还是通过 Ansible 或其他工具？

A：有了 Kubernetes 管理集群后，发布的工作就比较简单了，用不上 Ansible。但是 Ansible 还是有它的用处的，比如清理集群中过时的 image，和已经退出的 Container 等。

> Q：你好，以前也做过类似的服务"第三步：Jenkins 会把相应的 image 部署到服务器集群中，开发者就可以通过 iss001.kingdee 这个域名访问刚刚对应分支的服务了"，单独一个分支解决了对应的 bug，但实际生产中非常容易修改一个 bug 引起其他的 bug，你们是怎么去把控整体的稳定性？如何提高这种单个 bug 分支单个测试环境的意义？

A：这个 pull-request 的工作方式是应对功能开发的，如像长期开发某个 new feature，你刚刚说的一个 bug 产生另外一个 bug，我们的做法是有回归测试，我们有一个 smoke 分支，持续不断的对其做功能回归测试，只有通过的才能 cherry pick 到 release 上。

> Q：测试环境依赖的 redis/MQ 之类的外部服务如何做的隔离?每次测试单独拉起来一套外部依赖的服务吗？

A：我们通过多个手段来实现共享数据：master、smoke、release 分支测试都有自己独立的中间件，要是不用访问共享的数据，可以部署如 MQ image，代码层面的，如 MQ key 的名称加上机器的 IP。

> Q：有没有用到 Mesos？是否容易遇到问题？这方面的文档好像并不多。

A：Mesos 是个二级调度，适用于像存在多套集群的情况，来均衡资源，如：部署了 Hadoop 和 storm ，一般会使用 storm 来处理实时的请求，Hadoop 做离线工作。晚上和白天就存在一种可能就是 Hadoop 闲置，但是 storm 可能很忙，这时 Mesos 这样的二级调度就可以平衡资源，节约成本，我们暂时没有这样的需求。至于文档方面我也没有深入研究，建议看官方文档。

> Q：请问你们在构建的时候，你说有些需要半个小时左右，那么构建过程的进度监控和健康监控你们怎么做的呢，如果有 build 失败了怎么处理呢？

A：CI 的每一步都有进度的，并且我们的团队通讯工具可以和 CI 集成，如果失败会发消息到群里通知大家。

## QA Gitlab

> Q9：gitlab 接收一个 push event 触发构建，这个是监控所有的分支吗，分支模型是怎么样的

A：不是的，按需。我们内部分支模型大概有四种，dev——>test——>release——>master。master 以外的为了效率都会做自动触发

> Q11：为什么不直接用 gitlab-runner 而接 jenkins

A：gitlab-runner 需要每个仓库都配置构建信息，当需要统一修改构建的时候很麻烦

> Q：持续集成系统具体的细节可以透露下吗？基于 gitlab ci，jekins？或者小公司可以直接用 Spinnaker 这些吗？

A：ci cd 的话因为我们有自己现有的发布平台，背后的原理实际上还是调用 jenkins 去处理

> Q：和 gitlab ci 相比有什么优势

A： 和 gitlab ci 相比的优势可以参考下 jenkins 与 jenkins x 的对比。在用户角度来说，以应用为视角使用起来会更加方便，也方便利用社区资源。从架构和可维护性来说，Jenkins X 的架构会相对更加先进（与诞生年代有直接关系)。

> Q： 目前我们使用的 gitlab-ci-runner 部署于 k8s 之外实现 ci/cd。发现 gitlab-ci 在实际使用中，经常会遇到卡死报错。请问下，相比 jenkins 做 ci/cd 是会有什么优势，之前并没有使用过 jenkins.

A：gitlab-ci 生产环境中，我们也没有使用，我们调研的结果是 1、有侵入性 2、pipeline 功能较弱，但是有一个好处是遇到错误好像还可以继续执行。jenkins 遇到错误会中断流程。

> Q：请问 Jenkinswebhook 那些构建参数如何传入 GitLab 触发？

A：webhook 的触发和界面参数会有一些区别，我们在脚本里面做了处理。

> Q：离线部署，是不是通过打出镜像压缩包，然后带着镜像包到现场部署的容器云平台上，上传部署的方式？

A：是在家里打出镜像压缩包，然后到现场解压出来，根据镜像类型进行处理，比如一些基础镜像，会直接上传到节点，业务的镜像会在部署完成后上传到 Harbor，然后节点从 Harbor 去拉取。

> Q：GitLab 自带的 CI 与 Jenkins 和 GitLab 结合的 CI，该如何选择？想知道更深层次的理解。

A：还是要结合自己团队的实际情况做选择。从成熟度来说，肯定是 Jenkins 用户最多，成熟度最高，缺点是侧重 Java，配置相对繁琐。GitLab 自带的 CI 相对简单，可以用 yaml，和 GitLab 结合的最好，但功能肯定没有 Jenkins 全面。如果是小团队新项目，GitLab CI 又已经可以满足需求的话，并不需要上 Jenkins，如果是较大的团队，又是偏 Java 的，个人更偏向 Jenkins。

> Q：有了 Gerrit，为什么还要 GitLab，Gerrit 也可以托管代码啊？

A：这个是有历史背景的，我们是先选择使用 GitLab 做代码托管，后期才加入 Gerrit 做 code review。Gerrit 在代码 review 方面比 GitLab 的 merge request 要方便许多，更适合企业内部使用。关于这个，我的想法是，要么将 GitLab 迁移到 Gerrit，要么不用 Gerrit，可以使用 GitLab 的 merge request 来进行 review，那 GitLab 其实是可以不要的。

> Q：公司环境较复杂：包含 Java 项目、PHP 项目，Java 项目目前大多是 SpringBoot 框架，PHP 是 ThinkPHP 框架，项目架构并不复杂，有少许 Java 项目需要用 Redis 到 Memcached、缓存机制。最大问题的是多，项目应该如何较好的依托 Kubernetes 顺利架构，将项目可持续集成？

A：我们的 Redis 这一类中间件还放在 VM 上，目前尚未打算搬移到 Kubernetes 上，Kubernetes+Docker 天然是跨平台的，PHP 也可以支持，并且对容器集群（既应用集群）管理非常出色，包含部分自动化运维，并不会因多种开发语言而增加负担，持续集成是另外一块，目前各大 CI 工具厂商也都支持 Kubernetes，比较友好，我们采用的是 GitLab-CI。

> Q：SonarQube 的权限控制及性能当面？

A：权限控制使用 SonarQube 提供的 API，将项目跟 GitLab 中相应项目权限匹配起来，GitLab 中可以查看这个项目代码，那么 SonarQube 中就能看到这个项目结果和 Code。

> Q: 你们是直接将 SonarQube、GitLab/Jenkins 的权限控制到一起了？怎样做的统一？

A：使用 LDAP 认证。

> Q：Git Checkout 的时候，你们的 Git SCM 没有考虑隐私安全的事情吗，比如代码权限受限？

A：Jenkins 使用了一个最小权限用户去 GitLab 上拉代码。安全方面，Jenkins 所有节点都是可控的。

> Q：Jenkins 的持续集成是怎么实现的？比如不同的源码仓库的提交触发，如 GitHub、GitLab 版本号怎么控制的？

A：Jenkins 的 CI 流程触发可以有很多种，代码提交触发，定时触发，手动触发。版本号的控制也可以有很多方案，比如使用 job 的编号，使用 Git 的 commit 号，使用时间戳等等。

> Q：请问，我们是 java 项目，在业务代码打成 war 包后，war 包很大的情况下，在发布流程中，如何完成 pod 中的容器的代码更新，是采用挂载代码后重启容器方式，还是采用每次重新构建代码镜像，直接更新容器，或者有什么更好的建议吗

A：配置分离（上配置中心)，参数通过启动鉴权下载配置文件启动，这样子环境的更新只需要基于通过一个包即可。

> Q：一个 Job 生成所有的 Docker 镜像，如果构建遇到问题，怎么去追踪这些记录？

A：在项目前期接入时，生成镜像的流程都作了宣传和推广。标准化的流程，会减少产生问题的机率。如果在构建中遇到问题，Prism4k 的界面中，会直接有链接到本次建的次序号。点击链接，可直接定位到 Console 输出。

> Q：Job 和 dind 如何配合去实现打包镜像的呢？

A：首先是 dind 技术，通过挂载宿主机的 docker client 和 dockersock，可以实现在容器内调用宿主机的 Docker 来做一些事情，这里我们主要就用于 build。Kubernetes 的 Job 则是用于执行这个构建 worker 的方式，利用 Kubernetes 的 Job 来调度构建任务，充分利用测试集群的空闲资源。

> Q：请问下 Maven 的 settings.xml 怎么处理？本地 Maven 仓库呢？

A：我们构建了私有的 Maven 镜像， 私有镜像中是默认使用了我们的私有源。 对于项目中用户无需关注 settings.xml 中是否配置 repo。

> Q：生成新的镜像怎么自动打新的 tag？

A：我们镜像 Tag 使用本次构建选定的 Git 版本，如分支名称或者 Tag。

> Q： 如何动态生成 Dockerfile，如何在 Docker 镜像里配置 JVM 参数？

A：Dockerfile 文件：我们是使用 sh 脚本生成的，将内容 >> Dockerfile 中；JVM 参数是在应用中配置的，发送构建消息时，作为消息内容送过去。

> Q：Docker 的正确的使用姿势，在本地环境已经构建了企业私有 Registry Harbor，那么我要构建基于业务的应用时，是先从 Linux 系列的像 Ubuntu 或 CentOS 的 Base 的 Docker 镜像开始，然后通过 Dockerfile 定制业务需求，来使用吗？

A：我们基础镜像统一采用 CentOS 6.8，不同的业务有不同的 Dockerfile 模板，生成镜像的过程业务对 Dockerfile 是透明的。

> Q：使用 Pipeline 先构建编译环境镜像，再编译，是否会导致整个流程需要很长时间？是否有优化方案？

A：编译镜像由于不会经常变动，因此这个镜像的构建通常使用 cache 就能直接完成，另外我们也把编译环境镜像打包这个步骤抽出来单独作为 job 执行了，这样在实际编译流程中就无需再进行编译环境构建。

> Q：Docker 存储考虑过 Overlay 当时吗？据说这种构建镜像比较快。

A：考虑过，当时也做过各个方面的测试，这种增量式的构建，肯定最快，但是我们需要有专人从源码级别对其进行维护，成本对于我们还是有点高，我们后期打算采用环境和代码分离的方式，即环境部署一次，代码多次部署来提升效率。

> Q：您提到不过分强调测试自动化，尽量不改变测试流程，那么对于自动构建和单元测试的自动化有没有考虑呢？毕竟这些是比较消耗人力的部分。

A：自动构建我认为比较现实，单元测试有考虑。不过我们测试案例过于复杂，目前看短期实现不太现实。而且性能也是个问题，如果下一步要做我们会更多考虑一些特定场景。比如产品发布后的回归测试，这个有可能，但不会是普遍应用。

> Q：自动化构建过程中，对应用的测试是怎么实现的？

A：单元测试可以在编译的时候完成，功能测试需要启动部署。

> Q：通过镜像的构建脚本是怎么生成镜像的？在基础镜像上执行相关脚本么？一些端口存储卷环境变量这些镜像中的信息是怎么解决的？

A：我们对 Dockerfile 进行了封装，业务和开发人员不需要关心 Dockerfile 语法，直接写一个镜像构建脚本，最后根据一定的规则由 Harbor 生成 Dockerfile，之后调用 docker build 去生成镜像。在这个过程中， 镜像的名称，版本都已经根据规则生成

> Q：在构建时候，这些环境可以提前安装好？

A：应用里都有自己的版本概念，每个应用版本里有：镜像版本，环境变量、 export、Volmue 等信息，所以在回退或者升级时候，最终的表现形式就是杀掉旧容器，根据版本的参数创建新容器。

> Q：请问构建一次平均要多长时间？

A：现在 Java、Dubbo、Python、go 的多， 一般 2 分钟，而且有的镜像用户开启了自动构建后，在他们没意识的过程中，都已经构建完成。 到时候升级时候，选择对应的镜像版本即可。

> Q：App 的每一次提交都是一个 version 吗，是不是每次构建完测试完成，就可以发布了？

A：App 没有提交的概念，您说的应该是镜像，我们设计的是一个镜像对应一个 Git 仓库以及分支。当有 push 或者 tag 操作后，会自动触发构建，构建的行为是根据用户写的镜像构建 shell 脚本来决定的。 一般我们建议业务部门做出的镜像跟测试环境和生成环境没关系。 镜像就是镜像，只有应用有测试环境和生产环境。
