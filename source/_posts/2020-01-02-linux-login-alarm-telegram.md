---
title: VPS 安全加固之用户登录后向 telegram 发送登录信息
date: 2020-01-02
updated:
categories: 工具
slug:
tag:
  - telegram
  - linux
copyright: true
comment: true
---

## 弄啥咧

- 汝担心自己服务器挂了吗？
- 汝担心服务器被爆破脱裤？
- 汝担心非法用户登录服务器 😂
- 汝的服务器使用口令登录，而且还是 123456 的那种 😂

虽然，咱拿到 VPS 第一件事儿就是禁止密码登录，禁止 root 登录，仅仅允许普通用户使用密钥登录。理论上来讲，只要我的私钥不泄露，想要爆破登录上去，不可能、不可能、不可能 😂。AES-256 密钥的机密强度，即便是穷尽最强的超算来破解，也得需要几十年。

那么，有什么办法当用户登录到服务器上时发送个警报信息到咱手机上，来确认是咱本人或者是咱授权的用户登录。发送信息到咱手机，且及时能收到的话，常见的就这三种：

### 通过 email

email 发送确实可以，但有些限制，比如 GCP 就 ban 掉了 GCE 的 25 端口，常规手段就无法发送邮件了。而且，Linux 命令行下配置 Email 的发送客户端实在是令人头疼。遂就弃坑啦 😂，折腾起来不方便。

### 通过手机

之前我是使用 twiio 的短信服务来发送信息的，通过 twiio 的 api 很简单地就能发送，不想 email 那样配来陪去地，使用一条 curl 命令就能完成发送短信到手机。不过 twiio 很有限制，免费用户会有 10$ 的额度，而且需要绑定信用卡，也比较麻烦，遂卒 😂

### 通过 telegram bot

主角上场啦，就是咱们大名鼎鼎的电报机器人啦。不得不说 telegram 真心很好用啊，聊天功能比微信 QQ 这种狗屎玩意儿高到不知道哪里去了。反正我很讨厌恶心使用微信和 QQ，这种毒瘤软件。功能臃肿无比而且最基本的消息同步功能做的跟狗屎一样烂。呵呵，也就这样烂狗屎软件却垄断了国内聊天软件。而 telegram 只把聊天功能做到优秀，其开放的电报机器人更是催生出了无数有趣且实用的机器人。而且啊，你用 telegram bot 不需要实名认证、也不需要你上传身份证。

通过 telegram 的 api ，使用 bot 你可以很轻松地向自己发送消息，比微信 QQ 那种狗屎玩意好用的多。

> 需要注意的是，如果是 IOS 用户的话，通过 IOS 的通知消息推送机制，可以不挂梯子就能正常收到 telegram 的通知。包括其他需要挂梯子的应用也是，比如 Google voice。

## 怎么弄

### 首先有个 telegram 账号

网上教程很多，在此不赘述。推荐某宝买个 Google Voice 来注册，千万千万不要使用 +86 手机号注册，注册完成之后墙裂建议在 app 或者桌面端 的 `settings` ==> `Privacy and  Security` 那些设置选项里全部设置为 `Nobody` 。另外再开启 `Local Passcode` 以及 `Two-setp verification` 。千千万万别拿着 +86 的手机号到处冲塔，你快很被安排上的。

![](https://p.k8s.li/20200102212730956.png)

### 注册 bot

#### 1.打开与 @BotFather 的对话框

![](https://p.k8s.li/20200102213100935.png)

#### 2.发送/start 开始会话

![](https://p.k8s.li/20200102213250311.png)

#### 3.发送/newbot

![](https://p.k8s.li/20200102213314119.png)

> Alright, a new bot. How are we going to call it? Please choose a name for your bot.

#### 4.发送 Bot 的 name 和 username

> Good. Now let's choose a username for your bot. It must end in `bot`. Like this, for example: TetrisBot or tetris_bot.

![](https://p.k8s.li/20200102213405851.png)

bot 有两个名字，第一个发送的是 `first_name`: "linuxloginbot"，第二个发送的是"`username`": "linuxlogin_bot" 。其中 username 有要求，要 `xxx_bot` 来命名 比如 `linuxlogin_bot`

#### 5.得到 Bot 的 token，用于标识这个 Bot

![](https://p.k8s.li/20200102214900940.png)

> Done! Congratulations on your new bot. You will find it at t.me/linuxlogin_bot. You can now add a description, about section and profile picture for your bot, see /help for a list of commands. By the way, when you've finished creating your cool bot, ping our Bot Support if you want a better username for it. Just make sure the bot is fully operational before you do this.
>
> Use this token to access the HTTP API:
>
> 1067765083:AAFjONxxx-F2Y6IRSxxxxxVAAgRxxx89MXpk
>
> Keep your token secure and store it safely, it can be used by anyone to control your bot.
>
> For a description of the Bot API, see this page: [https://core.telegram.org/bots/api](https://core.telegram.org/bots/api)

由上面得到的 `1067765083:AAFjONxxx-F2Y6x89MXpk` 格式的字符串为该 bot 的 token，发送信息需要这个 token ，要保存好，不要泄露出去。

#### 6.得到自己的 chat ID

telegram 中每个用户、频道、群组都会有一个 chat ID ，而 telegram bot 的 chat ID 就是你自己，也就是说，bot 机器人想你发送信息是通过你的 ID 来标识的，也可以将 bot 加入到频道或者群组中，向群组中发送信息。

通过 `@getidsbot` 这个机器人来获取自己的 ID，ID 一般都是 6 开头的。

![](https://p.k8s.li/20200102220002156.png)

#### 7. 和 bot 对话

这一步非常重要，当 bot 新建完成之后就点击你的 bot 链接，然后在点击下面的 start 按钮。你不点击 start 开始和 bot 会话的话，bot 是无法想你发送信息的。我就在这个坑里爬了很久 😂

![](https://p.k8s.li/20200102215325530.png)

#### 7.构造 GET 请求

可以参考 telegram bot api 的官方文档 [Telegram Bot API](https://core.telegram.org/bots/api)

```php+HTML
https://api.telegram.org/bot（ 这里加上你的token ）/sendMessage?chat_id=66666666 &text=message
```

- 例如：

```bash
https://api.telegram.org/bot1067796083:AAFjONLJ9-F2Y6IRSmQoBVAAgRhd589MXpk/sendMessage?chat_id=613640483&text=message
```

把这段 `url` 复制粘贴到浏览器测试一下即可，或者通过 `curl` & `wget` 命令也可以。看看你的 telegram 能否正常接受消息。如果出现的话，恭喜你成功了第一步 😂

```json
{
  "ok": true,
  "result": {
    "message_id": 2,
    "from": {
      "id": 13,
      "is_bot": true,
      "first_name": "linuxloginbot",
      "username": "linuxlogin_bot"
    },
    "chat": {
      "id": 13,
      "first_name": "木子",
      "username": "muzi_ii",
      "type": "private"
    },
    "date": 1577973988,
    "text": "message"
  }
}

```

![](https://p.k8s.li/20200102220642854.png)

#### 8.用户登录后执行脚本

```bash
#!/bin/bash
# filename: 00-ssh-login-alarm-telegram.sh
# date: 2019-12-18
# for: ssh login alarm to telegram

# token 和 id 修改为自己的
token=97xxx718:AAExExPY9zxxxxxQ0L7iA2MCGYRQ
id=613420483

message=$(hostname && TZ=UTC-8 date && who && w | awk  'BEGIN{OFS="\t"}{print $1,$8}')

curl -s "https://api.telegram.org/bot${token}/sendMessage?chat_id=${id}" --data-binary "&text=${message}"
```

- 将该脚本放到 `/etc/profile.d/` 目录下，并 把该脚本的权限设置为 ` 555` ，即任何用户都可执行。
- `/etc/profile.d/` 下的脚本文件会在用户登录成功后自动执行，如还需要其他的操作追加在脚本里即可。
- message 需要传递的数据根据自身需求设定即可，通过 `&&`  将多个命令的执行结果传递到 message 变量。`hostname` 获取主机名，以区分多台服务器；`TZ=UTC-8 date` 来获取登录时刻的北京时间；`who` 用来获取当前用户和 IP 等信息；`w` 命令用于获取当前用户登录后执行的命令。

#### 大功告成啦

ssh 退出登录，测试一下 😋

```bash
Oracle
Thu Jan  2 22:23:33 UTC 2020
ubuntu   pts/0        2020-01-02 09:23 (5.129.16.28)
09:23:33 load
USER WHAT
ubuntu -bash
```

![](https://p.k8s.li/20200102222349027.png)

## 解锁其他功能？

### 监控某个端口是否存活

这个适用于宿舍，比如，我的笔记本使用 frpc 和服务器端的 frps 保持长连接，如果我的笔记本被盗或者网络挂了，那么服务端的端口会 down 掉的，通过监控这个端口来判断笔记本的状态。只要笔记本和 frps 断掉就发送警报信息到 telegram。

### 发送 nginx 当日访问量最高的链接

因为不喜欢 Google Analytics 来在自己的博客上收集读者们的隐私数据，所以就自己手搓脚本，通过 nginx 日志来获取博客访问数据。简单粗暴 😂

### 发送服务器监控信息

服务器磁盘满了；服务器被日了；服务器被 down 掉了……
