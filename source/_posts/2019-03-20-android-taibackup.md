---
title: 钛备份的逆向原理
date: 2019-02-20
updated:
categories: 搞机
slug:
tag:
  - 安卓
  - 刷机
copyright: true
comment: true
---

经常刷机的机友一定很熟悉钛备份，简直刷机备份数据的神器。有了它刷机爽得一批，备份应用数据，还原数据，真的很爽。钛备份是我刷完ROM，接着root后装得第一个应用，用它来还原之前得应用，十分方便。
对钛备份得备份原理很是好奇，在钛备份的 /data/data/com.keramidas.TitaniumBackup/files/ 下发现了busybox，猜想一定是使用tar 来备份的，压缩使用设定的gzip或xd，但我一般不采用压缩，能加快备份速度。接下来就使用adb 模拟钛备份的过程

------

1.先kill要备份应用
`killall -s STOP com.music.moto`

2.计算空间大小
`du -H -s /storage/emulated/0/Android/data/com.music.moto`

3.把sdcard下的data软连接过来
`ln -s /storage/emulated/0/Android/data/com.music.moto /data/data/.external.com.music.moto`

4.用tar备份，排除了lib和cache
`tar -cz /data/data/com.music.moto/. /data/data/.external.com.music.moto/. --exclude data/data/com.music.moto/./lib --exclude data/data/com.music.moto/./cache`

5.删除sdcard的data软连接
`rm /data/data/.external.com.music.moto`

6.剩下的应该是保存备份信息还有改备份文件的权限
`killall -s CONT com.music.moto`
`ls --color=never -d /data/app/com.music.moto-1/base.apk`
`ls --color=never /data/data/com.music.moto/databases/`
`chown media_rw:media_rw /storage/B35D-1F87/TWRP/TitaniumBackup/com.music.moto-20190412-174942.tar.gz`

2、恢复（已安装的程序）
1这两个命令合起来看，是把压缩文件解包
`cat /storage/B35D-1F87/TWRP/TitaniumBackup/com.music.moto-e9310c14ccf910db88f0bc4c842e515a.apk.gz`
bunzip2

2.改权限，应该有个安装应用的命令，pm没有替换，有的话应该能看到
`chmod 755 /data/local/tmp/com.keramidas.TitaniumBackup-install.apk`

3.删除应用
`rm /data/local/tmp/com.keramidas.TitaniumBackup-install.apk`

4将原来应用的data移动下
`mv /data/data/com.music.moto /data/data/.com.music.moto`

5删除sdcard下的data并链接过来
`rm -R /storage/emulated/0/Android/data/com.music.moto`
`ln -s /storage/emulated/0/Android/data/com.music.moto /data/data/.external.com.music.moto`

6解包数据，排除lib
`cat /storage/emulated/0/TitaniumBackup/com.music.moto-20171004-052037.tar.gz`
`tar -C / -x --exclude data/data/com.music.moto/lib --exclude data/data/com.music.moto/./lib`

7.删除sdcard的data链接
`rm /data/data/.external.com.music.moto`

8改用户组
`chown -R media_rw:media_rw /data/media/0/Android/data/com.music.moto`
`chown -hR 10118:10118 /data/data/com.music.moto`

9改权限
`chmod -R u+rwx /data/data/com.music.moto`

10将原应用的lib移到新恢复应用的data目录下
`mv /data/data/.com.music.moto/lib /data/data/com.music.moto`

11删除原应用的data
`rm -R /data/data/.com.music.moto`
