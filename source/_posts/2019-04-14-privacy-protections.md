---
title: 浅谈保护隐私的几种方法
date: 2019-04-14
updated: 2020-03-01
categories: 互联网
slug:
tag:
  - 隐私保护
  - privacy project
  - life
copyright: true
comment: true
---

0.说在前面：百度李彦宏曾说过：“中国人对隐私问题的态度更加开放，相对来说也没那么敏感。如果他们可以用隐私换取便利和效率，在很多情况下他们就愿意这么做”。如果你不在乎个人隐私，愿意用个人隐私换取方便，那么这篇文章对你没有价值，浪费你的时间，请关闭退出就可以。

---

原则：尽量使用国外或开源的软件。
让美帝公司掌握了隐私数据要比让老大哥掌握了风险低，在国内让 baidu 这些毒瘤公司拿数据去卖假药什么的会造成伤害，还有可能被查水表，喝茶什么的。
而让 Google 掌握了吧，身在中国，Google 拿你的数据在美国干些坏事也影响不到你。
同理，美国人用中国的手机和软件比用美国的风险低
如果你想最大化保护你的个人隐私，那么我建议你：

---

## 1.浏览器

无论在移动端还是 PC 端，坚决不要使用任何国产浏览器，推荐使用开源软件 Firefox 或 Chromium ， Firefox 是 Mozilla 非营利性组织维护的开源浏览器，能够在某种程度上保护你的隐私数据，它是非营利性组织，不以盈利为目的，不会向第三方或政府披露你的数据。作为上网浏览新闻，博客，网站的主力工具，每个浏览器都会记录着每个你访问的网站。国产浏览器会夹带着一些其他的私货，比如屏蔽掉一些政府敏感的网站，进行言论审查和互联网封锁。不仅如此，为了盈利商业公司的浏览器会向第三方共享你的隐私数据，而且还会根据法律法规向政府披露你的数据。在用户客户端进行这种行为真的是卑鄙无耻。尤其是那些参与屏蔽 996.icu 的浏览器 [1](https://blog.k8s.li/privacy-protections#reference)，你可以完全放弃他们了。

---

## 2.杀毒软件

坚决不要使用国产杀毒软件，他们会监控你的上网纪录 [2](https://blog.k8s.li/privacy-protections#reference)(火绒除外，微点有待观察)。
国产杀毒软件会以根据法律法规和危险警告识别监控上网站 url,360 杀毒软件曾拦截屏蔽过美国驻华大使馆某些特定网址。近期也拦截过 996.icu 以及 github 上 996.icu 的 repo，并且做了个假的 404 网页，真他妈搞笑。杀毒软件有扫描磁盘全部内容的风险，如果你硬盘上有敏感隐私信息，不要使用这些国产杀毒软件。如果你在使用 Windows10 的话，那么自带的 Windows Defence 完全可以满足日常使用，有能力的也可以选择“裸奔”。如今免费盛行的国产杀毒软件早已沦为强制捆绑，广告推广，隐私收集的流氓软件。

---

## 3.安卓手机

解锁 Bootloader 进 root (但也面临着手机丢失后数据安全问题)。
拒绝使用和购买那些不提供解锁 Bootloader 的手机，比如华为，魅族，锤子，VIVO，OPPO 等。如果你不想折腾的话，苹果无疑是最好的选择，而且要将苹果账号选择在美国，而非云上贵州。
因为解锁 Bootloader 进行 root 是摆脱手机厂商监控的第一步。因为安卓手机厂商为了盈利收集的隐私信息，并向第三方共享你的隐私信息以获取广告推广盈利。只有进行 root 才能卸载掉那些监控手机的预装 app。随着大多数国产手机逐渐关闭解锁 Bootloader 和加大 Root 的难度，用户想要摆脱手机厂商的监控也越来越难。厂商希望没人 Root，因为不解锁 Bootloader 和 root，厂商就可以为所欲为了。国产手机都会自带某种“云服务”，选择和使用这些服务被手机厂商收集到的个人隐私信息也将更多。
对于解锁 bootloader 和 root 后的风险。使用 Android 手机和使用 Linux 并无多大区别。拥有 root 权限的风险只是将 root 权限授权给未知应用而已。只要你够细心这一点是可以避免的。
手机丢失后别人也可以使用你用的刷机办法解锁你的手机，窃取你手机里的隐私信息。那就祝愿你手机不会丢失吧 但也可以使用 tasker 解决，在手机丢失后执行一些操作，删除手机上的内容。比如设定 sim 卡 ID 以及，只要更换 Sim 卡就触发报警操作，发送短信触发 GPS 定位，返回 GPS 信息，摄像头拍照等等都可以通过 tasker 实现。

---

## 4.输入法

杜绝使用国产输入法，在此推荐使用 Google 输入法。
输入法作为文本信息输入的直接工具，就好比嘴一样与互联网说话沟通，如果输入法的记录被某些公司记录下来，就好比被人安装了窃听器一样。之前有报道过讯飞输入法拒绝翻译敏感词，早已证明这些党性十足的国产输入法会监控你的所有输入记录 [4](https://blog.k8s.li/privacy-protections#reference)，甚至监听你的麦克风[百度输入法监听麦克风](https://blog.k8s.li/privacy-protections#reference)。使用 google 输入法的好处在于，因为墙的缘故，你的输入记录无法上传到 Google 服务器 😂。

---

## 5.苹果用户

建议你将 Apple 账户进行转区到国外，国内的账户数据会存储在云上贵州那里，以供审查。Apple 在隐私保护方面做的还是不错的。毕竟苹果是为了保护用户隐私敢直接和 FBI 硬杠的公司 [5](https://blog.k8s.li/privacy-protections#reference)。如果很在乎隐私保护而且不想折腾，那么苹果手机无疑是最好的选择。即便苹果收集到你的隐私数据，这些隐私数据也不会落到政府那里，前提是你的苹果账号在国外。

---

## 6.安卓杀毒软件

你可以放心大胆地卸载掉所有 xx 安全管家，xx 安全中心，xx 安全，xx 大师。基于 Linux 内核的安卓手机不需要任何杀毒软件的。想要安全，Root 才是最彻底的方法，再次重申不要相信国内所谓 “Root 了很危险”这样的谣言，只要你有足够多的耐心和细心去研究，你就能够使用 root 权限把你的 Android 手机打造的固若金汤。那些所谓的安全管家，只不过是监控你手机，收集你隐私数据的工具而已。

---

## 7.安卓手机 ROM

选择更换开源 ROM，LineageOS，AOSP,Resurrection Remix OS 等开源的 ROM。
国产 Android 手机系统 ROM，对原生安卓做了极大的修改以及夹带一些社会主义特色，[7](https://blog.k8s.li/privacy-protections#reference)。建议刷上 XDA 社区的第三方开源的 ROM，能力强的可以自己拿来源码来编译 ROM，精简掉你不想要的 app，事实证明，一个安卓 7.1 的 AOSP ROM，仅仅需要 50 个系统 app 就可以完全满足日常使用。而国产手机 ROM 中系统 app 的数量往往在 170-250 个之间,其中包括大量无法卸载的垃圾流氓服务用来监控你，收集你的个人隐私。这也是为什么你的手机会越用越卡的原因。
开源社区的 ROM 不以盈利为目的，可以很少地收集你的信息，并不会向小米那样用于广告推广来盈利。当然第三方 ROM 质量上良莠不齐，要精心选择适合自己的 ROM。

---

## 8.安卓权限管理

Root 后使用 Google 原生安卓系统自带的 IFW 意图防火墙和 App Ops（Application Operations）来对应用进行更加精细的权限管理，专治那些不给权限就不让运行的流氓 app（比如支付宝，微信，QQ 等）。也可以使用 MyAndroidTools，绿色守护，冰箱等 Android 神器来压制国内毒瘤 App。也可以使用开源软件[应用管理](https://github.com/Tornaco/X-APM)伪造一些敏感信息，比如 Android ID， IMIE ,手机号码。

---

## 9.隐私政策

在注册和使用互联网服务时，一定要仔细阅读隐私政策/条款，是否有注销服务。如果临时使用可以考虑临时邮箱[#12](https://temp-mail.org)/短信接号网站[#13](https://www.pdflibr.com/) 注册。

---

## 10.其他

远离那些在用户手机上建墙进行言论审查、自我阉割、网络封锁、敏感词屏蔽的杀毒软件、输入法、浏览器、手机、国产 ROM 等。

---

记住，个人隐私保护，保护的不是你自己，而是与你相关的人，你的家人和朋友。
不要以为大数据时代无隐私可言，隐私保护不当与不保护是两种完全不同的风险程度，你用隐私换取的那点便利最后也会面临隐私泄露的风险。

---

## reference

0.[安全经验汇总](https://program-think.blogspot.com/2019/01/Security-Guide-for-Political-Activists.html)
1.[多家国产浏览器限制访问 996.ICU](https://www.solidot.org/story?sid=60108)
2.[多款国产浏览器封锁 996.ICU，中国程序员惹谁了？](https://www.infoq.cn/article/3ADVAG9_uwomgr82lGet)
3.[如何评价新版 MIUI 浏览器拦截 Github 等网站？](https://www.zhihu.com/question/313636694/answer/609135042)
4.[科大讯飞的应用被发现拒绝翻译敏感词](https://www.solidot.org/story?sid=58791)
5.[苹果发布了一支新广告，想告诉你手机中的“小秘密”同样需要重视](https://wallstreetcn.com/articles/3508008)
6.[IFW 介绍](https://bbs.letitfly.me/d/395)
7.[墙已经砌造国产 ROM(MIUI)中，深入人心、无处不在](https://t.me/notepad_by_kotomei/77)
8.[中国流行手机应用难以注销账号](https://www.solidot.org/story?sid=56914)
9.[不怕大厂「耍流氓」，想保护隐私的你可以这样管理 Android 权限](https://sspai.com/post/42779)
10.[2017 年中国 Android 手机隐私安全报告](http://www.dcci.com.cn/dynamic/view/cid/2/id/1324.html)
11.[letitfly](https://bbs.letitfly.me/)
12.[临时邮箱](https://temp-mail.org)
13.[云短信-在线接收短信](https://www.pdflibr.com/)
14.[MAT 介绍](https://bbs.letitfly.me/d/256)
15.[除了自己，没有人能保护你的隐私](https://typeblog.net/nobody-can-protect-your-privacy-except-yourself/)
16.[从 root 手机说起](https://typeblog.net/why-do-i-root-my-phone/#References)
