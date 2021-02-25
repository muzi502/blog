---
title: zabbix 监控服务
date: 2019-05-13
categories: 技术
slug:
tag:
  - zabbix
  - 运维
  - 监控
copyright: true
comment: true
---

## 0.运行环境

(a). 要部署在docker容器中的服务：`MySQL` 、`zabbix-server` 、 `zabbix-web` 、 `zabbix-java-gateway`

(b). zabbix服务端机器所需软件包版本
OS: CentOS Linux release 7.6.1810 (Core)

```ini
docker-ce-stable 18.09.6
docker-compose 1.24.0
MySQL-server 5.7
zabbix-server 4.0.7 LTS
zabbix-web 4.0.7 LTS
zabbix-get 4.0.7 LTS
zabbix-java-gateway 4.0.7 LTS
```

(c). zabbix服务端机器所需的docker镜像

```ini
mysql:5.7
zabbix/zabbix-java-gateway:centos-4.0-latest
zabbix/zabbix-server-mysql:centos-4.0-latest
zabbix/zabbix-web-nginx-mysql:centos-4.0-latest
```

(d). 被监控机器所需软件包

```txt
CentOS  zabbix-agent 4.0.7 LTS
Windows Server 2012  zabbix_agent-4.0.7-win-amd64-openssl LTS
```

## 1.安装docker和docker-compose

1.安装 yum-utils 提供 yum-config-manager 工具
devicemapper存储驱动依赖 device-mapper-persistent-data 和 lvm2
`sudo yum install -y yum-utils device-mapper-persistent-data lvm2`

2.添加aliyun软件包源
`sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo`

3.安装docker-ce-stable
`sudo yum list docker-ce.x86_64  --showduplicates |sort -r` 选择docker-ce-stable版

4.添加Docker 用户和用户组
`sudo usermod -aG docker $USER`

(a)或使用官方脚本安装，aliyun镜像站点
`sudo curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun`

6.启动docker并添加到开机自启
sudo systemctl start docker.service
sudo systemctl enable docker.service

5.安装docker-compose，需要在GitHub上下载二进制文件，速度会很慢，先下载到本地再scp复制到/usr/local/bin

```bash
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

6.使用 docker 镜像加速器来加速下载 docker 镜像下载速度

```bash
sudo curl -sSL https://get.daocloud.io/daotools/set_mirror.sh | sh -s http://f1361db2.m.daocloud.io
sudo systemctl restart docker.service
```

## 2.使用docker-compose启动

1.复制 zabbix-compose.yml 文件到工程目录
2.按需修改 docker-compose 文件中的环境变量、PSAAWORD 等信息

```yml
version: '3.0'
services:
  mysql:
    image: mysql:5.7
    container_name: mysql
    environment:
      MYSQL_USER: zabbix
      MYSQL_DATABASE: zabbix
      MYSQL_PASSWORD: zabbix
      MYSQL_ROOT_PASSWORD: zabbix
    volumes:
      - /data/mysql:/var/lib/mysql
    ports:
      - 127.0.0.1:3306:3306
    restart: always
    networks:
      - zabbix
    command: ['mysqld', '--character-set-server=utf8', '--collation-server=utf8_bin']

  zabbix-java-gateway:
    image: zabbix/zabbix-java-gateway:centos-4.0-latest
    container_name: zabbix-java-gateway
    ports:
      - 10052:10052
    restart: always
    networks:
      - zabbix

  zabbix-server:
    image: zabbix/zabbix-server-mysql:centos-4.0-latest
    container_name: zabbix-server
    environment:
      ZBX_JAVAGATEWAY: zabbix-java-gateway
      ZBX_JAVAGATEWAY_ENABLE: "true"
      DB_SERVER_HOST: mysql
      MYSQL_DATABASE: zabbix
      MYSQL_USER: zabbix
      MYSQL_PASSWORD: zabbix
      MYSQL_ROOT_PASSWORD: zabbix
    volumes:
      - /data/zabbix/alertscripts:/usr/lib/zabbix/alertscripts
      - /data/zabbix/externalscripts:/usr/lib/zabbix/externalscripts
    links:
      - mysql
    ports:
      - 10051:10051
    depends_on:
      - mysql
    restart: always
    networks:
      - zabbix

  zabbix-web:
    image: zabbix/zabbix-web-nginx-mysql:centos-4.0-latest
    container_name: zabbix-web
    environment:
      PHP_TZ: Asia/Shanghai
      DB_SERVER_HOST: mysql
      MYSQL_DATABASE: zabbix
      MYSQL_USER: zabbix
      MYSQL_PASSWORD: zabbix
      MYSQL_ROOT_PASSWORD: zabbix
    links:
      - mysql
    ports:
      - 80:80
    depends_on:
      - zabbix-server
      - mysql
    restart: always
    networks:
      - zabbix

networks:
  zabbix:
    driver: bridge

```

3.启动容器
`sudo docker-compose -f zabbix-compose.yml up -d`

4.添加监听端口防火墙规则
zabbix web `sudo firewall-cmd --zone=public --add-port=80/tcp --permanent`
zabbix-server `sudo firewall-cmd --zone=public --add-port=10051/tcp --permanent`
zabbix-java-gateway `sudo firewall-cmd --zone=public --add-port=10052/tcp --permanent`

## 3.部署zabbix-agent

### 1.CentOS7

1.下载安装 zabbix-agent rpm包
`sudo rpm -Uvh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-agent-4.0.7-1.el7.x86_64.rpm`
2.修改 /etc/zabbix/zabbix_agentd.conf 配置文件，为zabbix-server的IP
`Server=`
`SourceIP=`
`ServerActive=`
3.为zabbix-agent监听端口10050添加添加防火墙出站规则
`sudo firewall-cmd --zone=public --add-port=10050/tcp --permanent`
`sudo firewall-cmd --reload`

### 4.Windows Server 2012

1.下载zabbix-agent windows 安装包，安装在需要监控的Windows server机器上
下载地址为`https://assets.zabbix.com/downloads/4.0.7/zabbix_agent-4.0.7-win-amd64-openssl.msi`
默认安装路径为`C:\Program Files\Zabbix Agent`
2.修改配置文件`C:\Program Files\Zabbix Agent\zabbix_agentd.conf` 为 zabbix-server 的 IP
`Server=`
`SourceIP=`
`ServerActive=`
3.添加zabbix-agent监听端口10050防火墙规则
4.打开任务管理器重新启动zabbix-agent服务

## 4.进入zabbix web管理界面添加监控主机

http://zabbix-webIP/zabbix
默认用户名为`Admin`
默认密码为`zabbix`
管理->主机->创建主机
主机名称: 自定义名称 (注意:Windows 端需要和zabbix_agentd.conf配置文件中的Hostname相同)
群组: ->选择 按需添加
IP地址: 所需监控机器IP 端口10050
->模板 按需链接所需要的监控模板

## 5.添加邮件报警

1.管理->报警媒介类型->Email
2.修改以下配置:
SMTP服务器: smtp.office365.com
SMTP HELO: smtp.office365.com
SMTP 电邮: outlook 的邮箱地址
安全链接: STARTTLS
认证: 用户和密码
3.创建报警动作
配置->动作->创建动作
名称: Zabbix_warning
计算方式: 默认
条件: 按需选择添加触发报警条件
->操作
默认操作步骤持续时间: 1h
默认标题: `『服务器警报』 {HOST.NAME}:{ITEM.NAME}:{EVENT.NAME}`
消息内容:

```txt
告警主机: {HOSTNAME1}
告警时间: {EVENT.DATE} {EVENT.TIME}
告警等级: {TRIGGER.SEVERITY}
告警信息: {TRIGGER.NAME}
告警项目: {TRIGGER.KEY1}
问题详情: {ITEM.NAME}: {ITEM.VALUE}
当前状态: {TRIGGER.STATUS}: {ITEM.VALUE1}
事件ID: {EVENT.ID}
```

->操作
`发送消息给用户群组: Zabbix administrators 通过 Email`

4.管理->用户->Admin->报警媒介->添加
类型: Email
收件人: 接收报警信息的邮件地址

## 6.添加手机/短信报警

1.zabbix_phone.sh

```bash
#!/bin/bash
# -*- coding: utf-8 -*-
# date 2019-05-10
# zabbix报警，通过电话通知警报信息接收人，通过短信发送警报信息
# 修改To=+86***********为警报信息接收人手机，需要到twilio绑定该手机号

# via phone
curl -X POST https://api.twilio.com/2010-04-01/Accounts/ACe4a6468bf4ffda94718c3749/Calls.json \
--data-urlencode "Url=http://demo.twilio.com/docs/voice.xml" \
--data-urlencode "To=+86***********" \
--data-urlencode "From=+1**********" \
-u ACe4a6 04cd7 1970c9 ab7 >> twilio.log

# via message
curl -X POST https://api.twilio.com/2010-04-01/Accounts/ACe4a64b4ffda94718c3749/Messages.json \
--data-urlencode "StatusCallback=http://postb.in/1234abcd" \
--data-urlencode "Body= $1 " \
--data-urlencode "To=+86***********" \
--data-urlencode "From=+1**********" \
-u ACe4a646 1970c93 aab7 >> twilio.log
```

2.将该脚本复制到zabbix-server容器中```/usr/lib/zabbix/alertscripts/```目录下
zabbix-compose.yml 默认映射的存储卷为```/data/zabbix/alertscripts```

3.修改脚本权限
`chown zabbix zabbix_phone.sh`
`chmod +x zabbix_phone.sh`

4.在zabbix-web管理界面 添加报警媒介规则
管理->报警媒介类型->创建媒体类型
名称: Phone_warning
类型: 脚本
脚本名称: zabbix_phone.sh
脚本参数: {ALERT.MESSAGE}
-> 点击更新保存

5.创建报警动作
配置->动作->创建动作
名称: Zabbix_warning
计算方式: 默认
条件: 按需选择添加触发报警条件
->操作
默认操作步骤持续时间: 1h
默认标题: 『服务器警报』 {HOST.NAME}:{ITEM.NAME}:{EVENT.NAME}
消息内容:

```txt
告警主机: {HOSTNAME1}
告警时间: {EVENT.DATE} {EVENT.TIME}
告警等级: {TRIGGER.SEVERITY}
告警信息: {TRIGGER.NAME}
告警项目: {TRIGGER.KEY1}
问题详情: {ITEM.NAME}: {ITEM.VALUE}
当前状态: {TRIGGER.STATUS}: {ITEM.VALUE1}
事件ID: {EVENT.ID}

```

->操作
发送消息给用户群组: Zabbix administrators 通过 Email
发送消息给用户: Admin (Zabbix Administrator) 通过 Phone_warning

3.管理->用户->Admin->报警媒介->添加
类型: Phone_warning
收件人: @ALL

## 7.zabbix自动发现

配置->自动发现->创建发现规则
名称: Local network
IP范围: 按需指定监控机器IP地址网段
更新间隔: 1h
检查: Zabbix客户端"system.uname"
设备唯一性准则: IP地址
