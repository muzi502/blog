---
title: tasker 神器
date: 2019-04-24
updated: 2020-03-01
categories: 搞机
slug:
tag:
  - andorid
  - 刷机
  - tasker
copyright: true
comment: true
---

## 1.使用tasker自动填写验证码

复制验证码 (25)
A1: 变量设置 [ 名称:%SYM 发往:%SMSRB Recurse Variables:关 无匹配:关 附加:关 ]
A2: 变量搜索替换 [ 变量:%SYM 搜索:[\d]{6}|[\d]{4} 忽略大小写:开 多行:开 只匹配一次:开 将匹配存储到:%SYM 替代匹配:关 替代为: ]
A3: 通知LED [ 标题:验证码 %SYM1 已复制到剪贴板 文字: 图标:null 数字:0 颜色:红色 速率:500 优先级:3 Repeat Alert:关 ]
A4: 设置剪贴板 [ 文字:%SYM1 添加:关 ]
A5: 输入 [ 文字:%SYM1 重复次数:1 ]

```xml
<TaskerData sr="" dvi="1" tv="5.5.bf2">
 <Task sr="task25">
  <cdate>1539441850928</cdate>
  <edate>1556107366039</edate>
  <id>25</id>
  <nme>复制验证码</nme>
  <pri>100</pri>
  <Action sr="act0" ve="7">
   <code>547</code>
   <Str sr="arg0" ve="3">%SYM</Str>
   <Str sr="arg1" ve="3">%SMSRB</Str>
   <Int sr="arg2" val="0"/>
   <Int sr="arg3" val="0"/>
   <Int sr="arg4" val="0"/>
  </Action>
  <Action sr="act1" ve="7">
   <code>598</code>
   <Str sr="arg0" ve="3">%SYM</Str>
   <Str sr="arg1" ve="3">[\d]{6}|[\d]{4}</Str>
   <Int sr="arg2" val="1"/>
   <Int sr="arg3" val="1"/>
   <Int sr="arg4" val="1"/>
   <Str sr="arg5" ve="3">%SYM</Str>
   <Int sr="arg6" val="0"/>
   <Str sr="arg7" ve="3"/>
  </Action>
  <Action sr="act2" ve="7">
   <code>525</code>
   <Str sr="arg0" ve="3">验证码 %SYM1 已复制到剪贴板</Str>
   <Str sr="arg1" ve="3"/>
   <Img sr="arg2" ve="2"/>
   <Int sr="arg3" val="0"/>
   <Int sr="arg4" val="0"/>
   <Int sr="arg5" val="500"/>
   <Int sr="arg6" val="3"/>
   <Int sr="arg7" val="0"/>
  </Action>
  <Action sr="act3" ve="7">
   <code>105</code>
   <Str sr="arg0" ve="3">%SYM1</Str>
   <Int sr="arg1" val="0"/>
  </Action>
  <Action sr="act4" ve="7">
   <code>702</code>
   <Str sr="arg0" ve="3">%SYM1</Str>
   <Int sr="arg1" val="1"/>
  </Action>
 </Task>
</TaskerData>

```

----

## 2. 使用tasker清除流量统计，适用于日租卡

数据重置 (3)
A1: 移动数据 [ 设置:开 ]
A2: 运行外壳 [ 命令:rm -rf /data/system/netstats/* 超时（秒）:0 使用Root:开 输出存储到: 错误存储到: 将结果保存到: ]
A3: 通知震动 [ 标题:数据重置，即将关机 文字: 图标:null 数字:0 模式: 优先级:3 Repeat Alert:关 ]
A4: 等待 [ MS:0 秒:1 分:0 小时:0 天:0 ]
A5: 状态栏 [ 设置:展开 ]
A6: 执行任务 [ 名称:存储移动 优先级:%priority 参数 1 (%par1): 参数 2 (%par2): 返回值变量: 停止:关 ]
A7: 等待 [ MS:0 秒:0 分:3 小时:0 天:0 ]
A8: 重启 [ 类型:常规 ]

 ```xml
 <TaskerData sr="" dvi="1" tv="5.5.bf2">
 <Task sr="task3">
  <cdate>1539351038664</cdate>
  <edate>1556107131126</edate>
  <id>3</id>
  <nme>数据重置</nme>
  <pri>100</pri>
  <Action sr="act0" ve="7">
   <code>433</code>
   <Int sr="arg0" val="1"/>
  </Action>
  <Action sr="act1" ve="7">
   <code>123</code>
   <Str sr="arg0" ve="3">rm -rf /data/system/netstats/*</Str>
   <Int sr="arg1" val="0"/>
   <Int sr="arg2" val="1"/>
   <Str sr="arg3" ve="3"/>
   <Str sr="arg4" ve="3"/>
   <Str sr="arg5" ve="3"/>
  </Action>
  <Action sr="act2" ve="7">
   <code>536</code>
   <Str sr="arg0" ve="3">数据重置，即将关机</Str>
   <Str sr="arg1" ve="3"/>
   <Img sr="arg2" ve="2"/>
   <Int sr="arg3" val="0"/>
   <Str sr="arg4" ve="3"/>
   <Int sr="arg5" val="3"/>
   <Int sr="arg6" val="0"/>
  </Action>
  <Action sr="act3" ve="7">
   <code>30</code>
   <Int sr="arg0" val="0"/>
   <Int sr="arg1" val="1"/>
   <Int sr="arg2" val="0"/>
   <Int sr="arg3" val="0"/>
   <Int sr="arg4" val="0"/>
  </Action>
  <Action sr="act4" ve="7">
   <code>512</code>
   <Int sr="arg0" val="0"/>
  </Action>
  <Action sr="act5" ve="7">
   <code>130</code>
   <Str sr="arg0" ve="3">存储移动</Str>
   <Int sr="arg1">
    <var>%priority</var>
   </Int>
   <Str sr="arg2" ve="3"/>
   <Str sr="arg3" ve="3"/>
   <Str sr="arg4" ve="3"/>
   <Int sr="arg5" val="0"/>
  </Action>
  <Action sr="act6" ve="7">
   <code>30</code>
   <Int sr="arg0" val="0"/>
   <Int sr="arg1" val="0"/>
   <Int sr="arg2" val="3"/>
   <Int sr="arg3" val="0"/>
   <Int sr="arg4" val="0"/>
  </Action>
  <Action sr="act7" ve="7">
   <code>59</code>
   <Int sr="arg0" val="0"/>
  </Action>
 </Task>
</TaskerData>
```

----

## 3.使用tasker锁屏后进入打盹模式

⭐️ 省电 (37)
A1: 停止 [ 伴随错误:关 任务:🐳 均衡 ]
A2: 停止 [ 伴随错误:关 任务:⭐️ 省电 ] If [ %STATUS ~ 1 ]
<亮屏等待时间>
A3: 等待 [ MS:0 秒:0 分:5 小时:0 天:0 ]
<省电模式（节省一点电量带来更多卡顿，相对感知卡顿：115）>
A4: 运行外壳 [ 命令:sh /data/powercfg powersave 超时（秒）:0 使用Root:开 输出存储到: 错误存储到: 将结果保存到: ]
A5: 立即休眠 [ 配置:All greenified apps 超时（秒）:0 ]
A6: 嗜睡模式 [ 配置:打开 超时（秒）:0 ]
A7: 变量设置 [ 名称:%STATUS 发往:1 Recurse Variables:关 无匹配:开 附加:关 ]
A8: [X] 等待 [ MS:0 秒:0 分:0 小时:1 天:0 ]
A9: [X] 移动数据 [ 设置:关 ]

```xml
<TaskerData sr="" dvi="1" tv="5.5.bf2">
 <Task sr="task37">
  <cdate>1528600734643</cdate>
  <edate>1556107574089</edate>
  <id>37</id>
  <nme>⭐️ 省电</nme>
  <pri>6</pri>
  <Action sr="act0" ve="7">
   <code>137</code>
   <Int sr="arg0" val="0"/>
   <Str sr="arg1" ve="3">🐳 均衡</Str>
  </Action>
  <Action sr="act1" ve="7">
   <code>137</code>
   <Int sr="arg0" val="0"/>
   <Str sr="arg1" ve="3">⭐️ 省电</Str>
   <ConditionList sr="if">
    <Condition sr="c0" ve="3">
     <lhs>%STATUS</lhs>
     <op>2</op>
     <rhs>1</rhs>
    </Condition>
   </ConditionList>
  </Action>
  <Action sr="act2" ve="7">
   <code>30</code>
   <label>亮屏等待时间</label>
   <Int sr="arg0" val="0"/>
   <Int sr="arg1" val="0"/>
   <Int sr="arg2" val="5"/>
   <Int sr="arg3" val="0"/>
   <Int sr="arg4" val="0"/>
  </Action>
  <Action sr="act3" ve="7">
   <code>123</code>
   <label>省电模式（节省一点电量带来更多卡顿，相对感知卡顿：115）</label>
   <Str sr="arg0" ve="3">sh /data/powercfg powersave</Str>
   <Int sr="arg1" val="0"/>
   <Int sr="arg2" val="1"/>
   <Str sr="arg3" ve="3"/>
   <Str sr="arg4" ve="3"/>
   <Str sr="arg5" ve="3"/>
  </Action>
  <Action sr="act4" ve="7">
   <code>2056827700</code>
   <Bundle sr="arg0">
    <Vals sr="val">
     <com.twofortyfouram.locale.intent.extra.BLURB>All greenified apps</com.twofortyfouram.locale.intent.extra.BLURB>
     <com.twofortyfouram.locale.intent.extra.BLURB-type>java.lang.String</com.twofortyfouram.locale.intent.extra.BLURB-type>
     <net.dinglisch.android.tasker.subbundled>true</net.dinglisch.android.tasker.subbundled>
     <net.dinglisch.android.tasker.subbundled-type>java.lang.Boolean</net.dinglisch.android.tasker.subbundled-type>
     <source>net.dinglisch.android.taskerm</source>
     <source-type>java.lang.String</source-type>
    </Vals>
   </Bundle>
   <Str sr="arg1" ve="3">com.oasisfeng.greenify</Str>
   <Str sr="arg2" ve="3">com.oasisfeng.greenify.GreenifyShortcut</Str>
   <Int sr="arg3" val="0"/>
  </Action>
  <Action sr="act5" ve="7">
   <code>289233647</code>
   <Bundle sr="arg0">
    <Vals sr="val">
     <cmd>1</cmd>
     <cmd-type>java.lang.Integer</cmd-type>
     <com.twofortyfouram.locale.intent.extra.BLURB>打开</com.twofortyfouram.locale.intent.extra.BLURB>
     <com.twofortyfouram.locale.intent.extra.BLURB-type>java.lang.String</com.twofortyfouram.locale.intent.extra.BLURB-type>
     <net.dinglisch.android.tasker.subbundled>true</net.dinglisch.android.tasker.subbundled>
     <net.dinglisch.android.tasker.subbundled-type>java.lang.Boolean</net.dinglisch.android.tasker.subbundled-type>
     <state>true</state>
     <state-type>java.lang.Boolean</state-type>
     <targetActivity>TaskerPluginActivity</targetActivity>
     <targetActivity-type>java.lang.String</targetActivity-type>
    </Vals>
   </Bundle>
   <Str sr="arg1" ve="3">com.oasisfeng.greenify</Str>
   <Str sr="arg2" ve="3">com.oasisfeng.greenify.TaskerAggressiveDoze</Str>
   <Int sr="arg3" val="0"/>
  </Action>
  <Action sr="act6" ve="7">
   <code>547</code>
   <Str sr="arg0" ve="3">%STATUS</Str>
   <Str sr="arg1" ve="3">1</Str>
   <Int sr="arg2" val="0"/>
   <Int sr="arg3" val="1"/>
   <Int sr="arg4" val="0"/>
  </Action>
  <Action sr="act7" ve="7">
   <code>30</code>
   <on>false</on>
   <Int sr="arg0" val="0"/>
   <Int sr="arg1" val="0"/>
   <Int sr="arg2" val="0"/>
   <Int sr="arg3" val="1"/>
   <Int sr="arg4" val="0"/>
  </Action>
  <Action sr="act8" ve="7">
   <code>433</code>
   <on>false</on>
   <Int sr="arg0" val="0"/>
  </Action>
 </Task>
</TaskerData>
```

----

## 4.使用tasker提醒自己给lycamobile续命

lycamobile现在需要每两个月消费一次，不然会被收回。一年至少发送六次短信才能续命。
使用tasker设置个定时任务，每月月次提醒自己要给lycamobile续命啦😂

----

## 5.使用tasker自动开启代理

当时也Google play 应用商店、magisk、IDM、下载管理器、Chrome、Telegram等应用时自动开启代理软件。

----

## 6.使用tasker在播放音乐是自动开启蝰蛇音效

----

## 7.夜间静音，关闭移动数据，关闭蓝牙，关闭同步

----

## 8.打开Chrome时自动打开代理并开启同步

----

## 9.锁屏省电

锁屏后等待[n]分钟后执行以下操作
1.关闭移动数据
2.将cpu频率调节为最低
3.将cpu调度器调节为powersave模式
4.关闭同步
5.使用绿色守护特权模式无视状态进入打盹模式
6.使用绿色守护休眠所有应用
7.命令行执行pm disable com.google.android.gms来冻结Google play service ，解锁屏幕后别忘记恢复😂
