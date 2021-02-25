---
title: 清理毒瘤app在sdcard目录下拉屎产生的文件夹
date: 2019-05-16
categories: 搞机
slug:
tag:
  - android
  - 安卓刷机
copyright: true
comment: true
---

## 前言

国内的这些毒瘤 app，不遵守 Android 开发的规范，把数据不写到自己的 data 目录下，在私自 sdcard 文件目录下拉屎。每次打开文件管理器的时候就会看到这些毒瘤 app 拉的一堆屎，真的恶心到家。打开无线调试模式通过一系列排除操作，总算清理出来了一堆一堆的屎。

```bash
#!/bin/bash
# date: 2019-05-25
# rm rush app dir

# touch
cd /sdcard
touch backup .backups Documents .lmsdk obb QQBrowser Tasker .tbs amap backups
touch baidu Bmap .com.taobao.dp com.tencent.mobileqq .DataStorage ICBC media
touch msc ICBCWAPLog obj taobao Tasker tbs .UTSystemConfig .vivo alipay

# rm
cd /sdcard
rm -rfbackup .backups Documents .lmsdk obb QQBrowser Tasker .tbs amap backups
rm -rfbaidu Bmap .com.taobao.dp com.tencent.mobileqq .DataStorage ICBC media
rm -rfmsc ICBCWAPLog obj taobao Tasker tbs .UTSystemConfig .vivo alipay

# MobileQQ
cd /sdcard/tencent/MobileQQ
touch ArkApp WebViewCheck font_info log ptv_template thumb .apollo
touch shortvideo thumb2 QWallet artfilter early funcall data
touch qav theme_pkg webso RedPacket emoji portrait qbiz .gift .signatureTemplate
rm -rf ArkApp WebViewCheck font_info log ptv_template thumb .apollo
rm -rf shortvideo thumb2 QWallet artfilter early funcall data
rm -rf qav theme_pkg webso RedPacket emoji portrait qbiz .gift .signatureTemplate
touch ArkApp WebViewCheck font_info log ptv_template thumb .apollo
touch shortvideo thumb2 QWallet artfilter early funcall data
touch qav theme_pkg webso RedPacket emoji portrait qbiz .gift .signatureTemplate

# weixin
cd /sdcard/tencent/MicroMsg
touch Game card wallet CDNTemp Handler wxacache CheckResUpdate SQLTrace fts
touch newyear wxanewfiles FailMsgFileCache WeiXin  vusericon xlog wxafiles
rm -rf Game card wallet CDNTemp Handler wxacache CheckResUpdate SQLTrace fts
rm -rf newyear wxanewfiles FailMsgFileCache WeiXin  vusericon xlog wxafiles
touch Game card wallet CDNTemp Handler wxacache CheckResUpdate SQLTrace fts
touch newyear wxanewfiles FailMsgFileCache WeiXin  vusericon xlog wxafiles

# tencent
cd /sdcard/tencent/
touch msflogs wtlogin mta
rm -rf msflogs wtlogin mta
touch msflogs wtlogin mta
```

可以保存脚本执行，建议拆分成 tasker 任务，在添加触发规则。当你打开文件管理器的时候自动触发清理操作，这样再用文件管理器的时候，这些屎已经自动清理完了，看着也舒服了。

接下来添加 tasker 任务

```xml
<TaskerData sr="" dvi="1" tv="5.5.bf2">
	<Task sr="task18">
		<cdate>1558781710970</cdate>
		<edate>1558782246852</edate>
		<id>18</id>
		<nme>清理垃圾</nme>
		<pri>100</pri>
		<Action sr="act0" ve="7">
			<code>123</code>
			<se>false</se>
			<Str sr="arg0" ve="3">cd /sdcard
touch backup .backups Documents .lmsdk obb QQBrowser Tasker .tbs amap backups
touch baidu Bmap .com.taobao.dp com.tencent.mobileqq .DataStorage ICBC media
touch msc ICBCWAPLog obj taobao Tasker tbs .UTSystemConfig .vivo alipay
rm -rf backup .backups Documents .lmsdk obb QQBrowser Tasker .tbs amap backups
rm -rf baidu Bmap .com.taobao.dp com.tencent.mobileqq .DataStorage ICBC media
rm -rf msc ICBCWAPLog obj taobao Tasker tbs .UTSystemConfig .vivo alipay</Str>
			<Int sr="arg1" val="0"/>
			<Int sr="arg2" val="1"/>
			<Str sr="arg3" ve="3"/>
			<Str sr="arg4" ve="3"/>
			<Str sr="arg5" ve="3"/>
		</Action>
		<Action sr="act1" ve="7">
			<code>123</code>
			<Str sr="arg0" ve="3">cd /sdcardtencent/
touch msflogs wtlogin mta
rm -rf msflogs wtlogin mta
touch msflogs wtlogin mta</Str>
			<Int sr="arg1" val="0"/>
			<Int sr="arg2" val="1"/>
			<Str sr="arg3" ve="3"/>
			<Str sr="arg4" ve="3"/>
			<Str sr="arg5" ve="3"/>
		</Action>
		<Action sr="act2" ve="7">
			<code>123</code>
			<se>false</se>
			<Str sr="arg0" ve="3">cd /sdcardtencent/MicroMsg
touch Game card wallet CDNTemp Handler wxacache CheckResUpdate SQLTrace fts
touch newyear wxanewfiles FailMsgFileCache WeiXin  vusericon xlog wxafiles
rm -rf Game card wallet CDNTemp Handler wxacache CheckResUpdate SQLTrace fts
rm -rf newyear wxanewfiles FailMsgFileCache WeiXin  vusericon xlog wxafiles
touch Game card wallet CDNTemp Handler wxacache CheckResUpdate SQLTrace fts
touch newyear wxanewfiles FailMsgFileCache WeiXin  vusericon xlog wxafiles</Str>
			<Int sr="arg1" val="0"/>
			<Int sr="arg2" val="1"/>
			<Str sr="arg3" ve="3"/>
			<Str sr="arg4" ve="3"/>
			<Str sr="arg5" ve="3"/>
		</Action>
		<Action sr="act3" ve="7">
			<code>123</code>
			<se>false</se>
			<Str sr="arg0" ve="3">cd /sdcardtencent/MobileQQ
touch ArkApp WebViewCheck font_info log ptv_template thumb .apollo
touch shortvideo thumb2 QWallet artfilter early funcall data
touch qav theme_pkg webso RedPacket emoji portrait qbiz .gift .signatureTemplate
rm -rf ArkApp WebViewCheck font_info log ptv_template thumb .apollo
rm -rf shortvideo thumb2 QWallet artfilter early funcall data
rm -rf qav theme_pkg webso RedPacket emoji portrait qbiz .gift .signatureTemplate
touch ArkApp WebViewCheck font_info log ptv_template thumb .apollo
touch shortvideo thumb2 QWallet artfilter early funcall data
touch qav theme_pkg webso RedPacket emoji portrait qbiz .gift .signatureTemplate</Str>
			<Int sr="arg1" val="0"/>
			<Int sr="arg2" val="1"/>
			<Str sr="arg3" ve="3"/>
			<Str sr="arg4" ve="3"/>
			<Str sr="arg5" ve="3"/>
		</Action>
	</Task>
</TaskerData>
```
