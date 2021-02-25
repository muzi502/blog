---
title: moto z play addsion xt1635-02 刷机指南
date: 2019-04-12
updated: 2020-03-01
categories: 搞机
slug:
tag:
  - moto
  - android
  - ROM
copyright: true
comment: true
---

## 0.备份数据

刷机千万条，备份第一条，刷机不规范，机主两行泪😂

----

## 1.解锁bootloader

下载[Android SDK Platform Tools](https://developer.android.com/studio/releases/platform-tools.html),解压后将platform-tools所在的绝对路径添加到环境变量。
安装moto驱动程序，下载地址[win](http://www.motorola.com/getmdmwin)
解锁[官网](http://motorola.com/unlockbootloader),需要注册账户
开机键 + 音量减进入bootloader
fastboot oem get_unlock_data 获取设备ID,粘贴复制到下面
[解锁网页](https://motorola-global-portal.custhelp.com/app/standalone/bootloader/unlock-your-device-b)
申请后获取解锁码
fastboot oem unlock 【解锁码】
下载magisk zip包和magisk manager apk方便以后使用

----

## 2.刷recovery  twrp /升级bootloader

[TWRP官网](https://twrp.me/Devices/)
我的moto z play 刷 Android9.0 的 ROM 要求的 bootloader 必须为 Oreo 的0xC180 or 0xC182，下载 moto 官方固件刷入 bootloader.img 即可，官方固件 1.7GB，好大。总不能为了刷个几MB的 bootloader 下载整个固件包啊,还浪费我流量,于是保存firmware到Google Drive(还好固件分享是通过Google Drive),在挂载了 Google Drive 的 vps 上解压出来需要刷的那几个文件刷入即可.刷完 bootloader 后发现仅仅升级 bootloader 分区手机无法上网，还需要刷入基带。
最后在 XDA 社区找到了升级到 Oreo bootloader 的[帖子](https://forum.xda-developers.com/showpost.php?p=78379116&postcount=3)，大佬已经帮忙准备好了要刷入的文件。

```bash
fastboot flash partition gpt.bin
fastboot flash bootloader bootloader.img
fastboot flash modem NON-HLOS.bin
fastboot flash fsg fsg.mbn
fastboot flash dsp adspso.bin
fastboot flash oem oem.img
```

刷上下载的 Twrp
`fastboot flash recovery twrp-addison.img`
reboot 到 recovery 就行

----

## 3.刷ROM

把 ROM 的 zip 包以及 magisk 放到手机内部存储目录即可,在 INSTALL 那里选择 ROM 刷入
接着刷入 magisk 的zip包
reboot system

----

## 4.刷magisk

安装 magisk manager，有些精简的 ROM 没有文件管理器，可以在设置里->存储或下载管理器里找到apk 文件安装。
输入经常使用的 magisk 模块主要有

```text
1.Magisk Manager for Recovery Mode(mm)
2.DNSCrypt-Proxy
3.Enable doze for GMS Magisk Module
4.GPU Turbo Boost
5.Google Sans MOD Font
6.Pix3lify
7.ViPER4 Android FX Materialized
```

----

## 5.安装常用工具

```text
0.钛备份，每次刷完 ROM 接着 root 完后第一个装的就是钛备份，使用它来恢复下面的应用和数据
1.绿色守护，导入处方
2.RE 管理器，卸载删除不必要的应用，方便减少备份包大小
3.SD Maid，配合 RE 使用，卸载删除应用，分析分区占用大小
4.shadowsocks + obfs，你懂的
5.Tasker，高效率神器，用过的人都说好😂!
6.Solid Explorer，MD 风格的文件管理器，用了之后放弃RE了🙃
7.Telegram X 跨平台，16 年开始使用到现在，已经放弃用qq了
8.juiceSSH，用来执行 shell，同步硬件时钟用，免得 TWRP 时间回到 1970.
9.炼妖壶 发现能在这个 ROM 上使用，好好折腾一下
10.Lawnchair 替换掉原来的桌面，这个自从 2017 年使用后就从未更换过。精简！！！！特别适合我这种精简主义者。
11.My Android tools，同 IFW，用来镇压毒瘤 app
12.App Ops，用来驯服一些国内毒瘤 app，不给权限不让运行的毒瘤行为
13.IFW，意图防火墙，用来镇压一些国内的臃肿毒瘤 app
14.Pixel Icon Pack，图包，美化一下图标
15.moto 相机，感觉没有 aosp 的好用
16.快图相册，从Android4.4 开始一直使用，精简好用，速度极快
17.谷歌拼音输入法,精简
18.国内那些臃肿的毒瘤 app，最后再装😡！
19.MX player 看片儿用的
20.简洁·日历 就像名字那样，十分简洁，没有杂七杂八的功能，就是农历可能不准，记得去年的冬至吗😂
```

----

## 6.刷入 opengapps

推荐 pico 包，虽然足够小了，但还是可以精简很多不必要的 apk 的。需要注意的是，仅仅刷入 opengapps 包是无法登录 Google 账户的，还需要下载最新版的 Google play service APK 来更新 Google play service 。这样才能登录到 Google 账户。选择最后装 opengapps 的原因是，之前需要卸载删除一些系统 app，删除一些 app 后有可能会卡机无法启动，所以每次删除之前都需要备份一下，而 opengapps 刷入后备份的大小将会增加很多。于是最后等到删除完不必要的系统 app 后再刷入 opengapps。刷完之后再卸载掉 opengapps 里没用的 app。
登录 Google 账户，同步 chrome 书签。使用 opengapps 我唯一的需求就是 chrome，能同步 chrome 书签和密码就足够了。

----

## 7.个性化定义

```text
1.恢复导航栏布局
2.缩小导航栏高度
3.导航栏透明
4.全局沉浸模式
5.复制铃声到/system/media/ringtones,删除其他media文件
6.设置密码，指纹解锁
7.把一些不需要更新的app移动到/system/app
8.个性化状态栏，扩展状态栏
9.导航栏设定了四个虚拟按键
9.1.单击任务栏
9.2.单击home 长按休眠
9.3.单击返回 长按杀死应用
9.4。单击返回上一个应用 长按截屏
```

----

## 8.恢复Tasker里的任务

----

## 9.TWRP备份还原

把之前的在 twrp 做的备份复制到 PC，使用 tar 解压出备份文件。如果使用 7Z 或其他 GUI 的解压缩程序会提示错误，因为在 /system 分区里有一些硬链接文件，是无法解压出来的。使用 tar 就可以解压出来。解压出来后把 /etc/hosts 文件复制到新的ROM system 分区下，里面有一些自己屏蔽的一些域名，大部分是百度等一些毒瘤 app SDK 的域名，直接屏蔽掉。
复制 /data/system/ifw 下的 ifw.xml 是自己自定义的一些 IFW 规则，主要对付一些国内毒瘤 app。
复制 /system/media/ 下的开机动画，还是喜欢原来的开机动画。
使用钛备份还原 Solid Explorer 的数据，使用 smba 共享传输这些文件。

----

## 10.bug

1.重启可能卡在开机动画那里，需要长按电源键强制关机，再开机才能正常启动
2.~~开机启动后，Lawnchair 会随机性地挂掉😥，最后发现不是 Lawnchair 挂掉了，是 AOSIP 自带的 Quickstep~~
3.不能原生支持 xposed 框架，需要刷入其他包魔改一下，不清真，所以就没用
4.以前 xposed 我仅仅使用三个模块，绿色守护，应用管理，XinternalSD 。现在不需要也能满足日常使用了。
5.刷入 opengapps 包后,所有的 app 权限授权记录都消失了,需要重新授权,不知道是 bug 还是 feature 😂
6.安装微信后,6.7.3版本不能登录,必须7.0.3以上,fuck尼玛的微信😡.无奈装7.0.3再降回6.7.3.尼玛去死吧,毒瘤app.
7.开热点随机性地断流
8.twrp 里的硬件时钟经常会重设为 1970-- 谜之 bug
9.最后设置密码的原因是，使用twrp备份还原后密码错误，也是 twrp 的 bug

----

## 吐槽Android版微信

1.微信限制低版本登录，可以使用最新版本登录，保留原数据卸载微信高版本，重启后再装低版本就能登录
2.Google play 最新版微信7.0.3已经很臃肿了,世界上activity数目超过1000的Android 应用也就你们这些国产毒瘤吧,也就你们微信,美团了吧.毒瘤,臃肿的体验真让人恶心到家,还不让人家用低版本的,PC端登录还要扫码登录,我扫你🐎币.
3.微信会产生日志文件,在/data/data/com.tencent.mm/files/xlog目录里.删除这个目录,建立一个xlog的文件,修改000权限,就可以阻止微信产生垃圾日志文件.但也会在内部存储产生xlog日志,同理删除xlog目录,建立xlog文件就行.
4.平时很少使用微信,因为微信真的越来越臃肿,加一些我不想用的东西,还限制低版本的登录,我用低版本日你🐎了吗?用新版本的微信你就像闻到屎一样恶心人!
5.微信在我眼里是一坨一坨屎堆砌的app,臃肿,毒瘤,恶心,难用,还自带墙,言论审查,删帖封号,去死吧微信!
6.国内互联网公司带动了一些很差的使用体验风潮,各大公司都相互模仿,比如强制扫码🐎登录;下载APP查看完整内容(比如知乎,豆瓣,CSDN等等),还有菜鸟驿站必须拿身份证拍照取件,卑鄙无耻强制收集用户隐私;为了账户安全实名认证(微信支付宝淘宝);手机端访问为安装app强制跳转到应用商店(淘宝);不给权限不让运行(国内毒瘤app一贯特色);权限滥用;音乐软件里弄个商城(QQ音乐,网易云);浏览器弄个新闻推送;浏览器自带黑名单进行言论审查(屏蔽996.icu);杀毒软件弄个金融投资(360)~~~~等等,国内互联网都被这些毒瘤厂商带坏了.哎,悲哀啊.
7.我是个极简主义者,也是日常重度使用debian的Linux用户,遵循unix理念.一个程序只做一件事,把它做好就行.国内的这些毒瘤app完全向unix理念相反方向发展.整天用着一堆自己极其讨厌的app,真是很让人烦心!!因为家人朋友用微信,自己只能强制绑架着使用微信.没办法,像telegram这样甩微信十条街的应用国内被屏蔽了.

----

### 体验&收获

1.经过精简后的 AOSIP 9.0 P 的ROM，系统 app 的数量 75 个，其中包括了 opengapps 。相当精简了，比起国内那些魔改的ROM，要精简很多很多，这也是我为什么喜欢用原生ROM的原因，可以自己定制，精简，精简，精简再精简。以前刷 moto g 2nd 的时候，刷的 AOSP Android 5.1 最后精简到系统 app 仅仅 45 个，system 分区大小不足 400MB，流畅的一批，MSM8226 的 Soc 用的流畅的一批,精简到能够保障系统正常运行，清除 data 分区后，开机后可以正常初始化使用，打电话，发短信，安装应用等正常。但是无论精简再流畅,面对国内这些毒瘤 app,还是招架不了.
2.现在插上 USB 线可以默认选择为 MTP 了,不像以前那样需要打开开发者工具->USB设置那里选择 MTP ,比以前方便很多
3.MAT 还原的时候速度快了很多很多,几乎不到 3 秒完成还原
4.感觉基带信号不稳定,开热点会经常性地断流.估计是这个ROM的通病,或者是我基带的问题.
5.安装应用的时候速度比以前快了很多
6.在探索炼妖壶的使用,微信无法登录
7.Google TTS 可以正常使用了,以前没修好,现在配合tasker能实现手机丢失后报警,朗读警告信息的功能了,改天写一个使用taker处理的文章,好好探索折腾一下,估计这个月没时间写了,时间够忙的.

----

## 参考/推荐阅读

1.[LetITFly BBS](https://bbs.letitfly.me/)，里面介绍了IFW和MAT，刷机搞~~基~~机常去的地方。
2.[「绿色守护」处方推荐](https://cn.apkjam.com/greenify-prescription.html)
