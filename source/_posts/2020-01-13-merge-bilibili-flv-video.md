---
title: 高效批量下载 B 站视频并合并转码为 mp4
date: 2020-01-13
updated:
categories: 工具
slug:
tag:
  - 技巧
copyright: true
comment: true
---

## 弄啥咧？

{% raw %}
<blockquote class="twitter-tweet"><p lang="zh" dir="ltr">B 站收藏夹里的视频一点一点 404 了，索性就把所有收藏里还存活的视频都使用 UWP 客户端下载下来了，大概 400 多 GB。<br>为了将 UWP 客户端下载的分段 .flv，写了个 shell 脚本来转码合并为 .mp4。<br>目前处理了 100 多GB 的 .flv 文件没啥大碍<br><br>需要的拿去<a href="https://t.co/GX4FsswcfC">https://t.co/GX4FsswcfC</a> <a href="https://t.co/LG37IGrMdI">pic.twitter.com/LG37IGrMdI</a></p>&mdash; 502.li (@muzi_ii) <a href="https://twitter.com/muzi_ii/status/1216726922157228035?ref_src=twsrc%5Etfw">January 13, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
{% endraw %}

好很久没上小破站了，翻了一下自己的收藏夹，我咧个去，将近三分之一的视频都 404 了……，存活的不知道会不会被拉清单。索性就把自己收藏的视频都下载下来，永久保存在自己的硬盘上，咱也不用担心删帖封号了。其中收藏的视频绝大多数都是纪录片和科普视频，在此还是推荐一下[纪录片之家字幕组]，中英双语是英语学习的好材料。尤其是`走进工厂`系列，基本上每次都会追着看完😂。

另外把这些视频下载下来就不用担心哪天这些优秀的 UP 炸号了，这么宝贵的资源就飞灰湮灭了。所以，自己收藏的视频还是第一时间下载下来为好，另外平时观看的时候也方便。

我是通过 Windows 应用商店里的 [哔哩哔哩动画]() 下载的，事实证明，这玩意下载起来最稳定，我房东家 100MBps 的带宽一直跑满，一天多的时间下载了将近 400GB 的视频。但下载的这些视频有的被分段存储了，而且格式都是 .flv 。然后就想着如何合并这些 flv 文件并转码为 mp4 格式。

## 劝退三要素😂

- 需要在 Linux 命令行下操作，任何 Linux 发行版或者 Windows Subsystem for Linux，推荐 WSL
- 需要在 Linux 环境下安装 `ffmpeg` 和 `jq` 命令
- 需要 UWP 哔哩哔哩动画客户端下载和缓存视频文件

## 咋弄

### 分析

使用哔哩哔哩动画客户端下载下来的视频，每个视频有一 P 或者多 P ，每一 P 分别存放在从 1 开始正整数命名的文件夹内。每个 P 有的被分割成了若干个 flv 文件，有的是单个 flv 文件。在每个 P 的目录下分别有以下文件.

#### 目录结构

```bash
- .flv # 视频文件，有一个或多个
- xml  # 弹幕文件，可忽略
- info # 视频元数据信息，有每个视频的 Title 以及每一 P 的名称
╭─debian@debian /mnt/d/Downloads/bilibili/6918663
╰─$ tree
.
├── 1
│   ├── 6918663_1_0.flv
│   ├── 6918663_1_10.flv
│   ├── 6918663_1_11.flv
│   ├── 6918663_1_12.flv
│   ├── 6918663_1_1.flv
│   ├── 6918663_1_2.flv
│   ├── 6918663_1_3.flv
│   ├── 6918663_1_4.flv
│   ├── 6918663_1_5.flv
│   ├── 6918663_1_6.flv
│   ├── 6918663_1_7.flv
│   ├── 6918663_1_8.flv
│   ├── 6918663_1_9.flv
│   ├── 6918663_1.xml # 视频弹幕文件
│   └── 6918663.info # 每 P 视频的元数据信息
├── 6918663.dvi # 视频元数据信息
└── cover.jpg # 视频封面
```

多 P 的情况下

```bash
╭─debian@debian /mnt/d/Downloads/bilibili/29656570
╰─$ tree
.
├── 1
│   ├── 29656570_1_0.flv
│   ├── 29656570_1.xml
│   └── 29656570.info
├── 10
│   ├── 29656570_10_0.flv
│   ├── 29656570_10_1.flv
│   ├── 29656570_10_2.flv
│   ├── 29656570_10_3.flv
│   ├── 29656570_10_4.flv
│   ├── 29656570_10_5.flv
│   ├── 29656570_10_6.flv
│   ├── 29656570_10_7.flv
│   ├── 29656570_10.xml
│   └── 29656570.info
├── 11
│   ├── 29656570_11_0.flv
│   ├── 29656570_11_1.flv
│   ├── 29656570_11_2.flv
│   ├── 29656570_11_3.flv
│   ├── 29656570_11_4.flv
│   ├── 29656570_11_5.flv
│   ├── 29656570_11_6.flv
│   ├── 29656570_11_7.flv
│   ├── 29656570_11.xml
│   └── 29656570.info
├── 12
│   ├── 29656570_12_0.flv
│   ├── 29656570_12_1.flv
│   ├── 29656570_12_2.flv
│   ├── 29656570_12_3.flv
│   ├── 29656570_12_4.flv
│   ├── 29656570_12_5.flv
│   ├── 29656570_12_6.flv
│   ├── 29656570_12_7.flv
│   ├── 29656570_12.xml
│   └── 29656570.info
├── 13
│   ├── 29656570_13_0.flv
│   ├── 29656570_13.xml
│   └── 29656570.info
├── 2
│   ├── 29656570_2_0.flv
│   ├── 29656570_2.xml
│   └── 29656570.info
├── 29656570.dvi
├── 3
│   ├── 29656570_3_0.flv
│   ├── 29656570_3.xml
│   └── 29656570.info
├── 4
│   ├── 29656570_4_0.flv
│   ├── 29656570_4_1.flv
│   ├── 29656570_4_2.flv
│   ├── 29656570_4_3.flv
│   ├── 29656570_4_4.flv
│   ├── 29656570_4_5.flv
│   ├── 29656570_4_6.flv
│   ├── 29656570_4_7.flv
│   ├── 29656570_4.xml
│   └── 29656570.info
├── 5
│   ├── 29656570_5_0.flv
│   ├── 29656570_5_1.flv
│   ├── 29656570_5_2.flv
│   ├── 29656570_5_3.flv
│   ├── 29656570_5_4.flv
│   ├── 29656570_5_5.flv
│   ├── 29656570_5_6.flv
│   ├── 29656570_5_7.flv
│   ├── 29656570_5.xml
│   └── 29656570.info
├── 6
│   ├── 29656570_6_0.flv
│   ├── 29656570_6.xml
│   └── 29656570.info
├── 7
│   ├── 29656570_7_0.flv
│   ├── 29656570_7_1.flv
│   ├── 29656570_7_2.flv
│   ├── 29656570_7_3.flv
│   ├── 29656570_7_4.flv
│   ├── 29656570_7_5.flv
│   ├── 29656570_7_6.flv
│   ├── 29656570_7_7.flv
│   ├── 29656570_7.xml
│   └── 29656570.info
├── 8
│   ├── 29656570_8_0.flv
│   ├── 29656570_8_1.flv
│   ├── 29656570_8_2.flv
│   ├── 29656570_8_3.flv
│   ├── 29656570_8_4.flv
│   ├── 29656570_8_5.flv
│   ├── 29656570_8_6.flv
│   ├── 29656570_8_7.flv
│   ├── 29656570_8.xml
│   └── 29656570.info
├── 9
│   ├── 29656570_9_0.flv
│   ├── 29656570_9_1.flv
│   ├── 29656570_9_2.flv
│   ├── 29656570_9_3.flv
│   ├── 29656570_9_4.flv
│   ├── 29656570_9_5.flv
│   ├── 29656570_9_6.flv
│   ├── 29656570_9_7.flv
│   ├── 29656570_9.xml
│   └── 29656570.info
├── cover.jpg
└── desktop.ini
```

#### info 文件

这个 .info 文件时是以视频 av 号命名的(老司机们不要误以为是番号😂)，是压缩过的 json 格式，在 Linux 命令行下可以使用 jq 命令来格式化压缩过的 json 文件

```json
{
  "Type": 0,
  "GroupKey": null,
  "File": null,
  "IsSelected": false,
  "IsLastHit": false,
  "DownloadState": "正在下载弹幕",
  "Aid": "6918663",
  "Cid": "11273505",
  "SeasonId": null,
  "EpisodeId": null,
  "Title": "【宇宙】卡西尼号：去往土星的伟大航程【中英字幕】",
  "Uploader": "魔术师Magic",
  "Description": "人人影视 卡西尼号：去往土星的伟大航程（Cassini-Epic Journey at Saturn）",
  "CoverURL": "http://i1.hdslb.com/bfs/archive/8430c49571dc1f61f3f9a7260f06ceb79418235f.jpg",
  "Tag": null,
  "From": "vupload",
  "PartNo": "1",
  "PartName": null,
  "Format": 1,
  "TotalParts": 13,
  "DownloadTimeRelative": 166896023,
  "CreateDate": "2016-11-01 19:14",
  "TotalTime": "01:16:21.0890000",
  "TotalTimeString": null,
  "PartTime": [
    327169,
    408276,
    240210,
    429477,
    417077,
    325544,
    297610,
    469810,
    286511,
    493610,
    370544,
    197277,
    317974
  ],
  "TotalSizeString": "544MB",
  "IsSinglePart": true,
  "IsDownloaded": false,
  "HasDanmaku": false,
  "FontSize6": 10,
  "FontSize8": 12,
  "FontSize10": 14,
  "FontSize12": 16,
  "FontSize14": 18,
  "FontSize16": 20,
  "FontSize18": 22,
  "FontSize20": 24,
  "FontSize22": 26,
  "FontSize24": 28,
  "FontSize30": 34,
  "FontSize34": 38
}
```

我们需要在这个 info 文件中提取几个关键字段来重命合并转码后的 mp4 文件，为了方便起见我们选择 `Title` 、`PartName` 、 `CreateDate` 这三个字段来重命名转码合并后的视频文件。如果视频是单 P 的话 `PartName` 的值为 `null`。在 shell 中获取这三个值也比较简单。在此用 `tr` 命令去除掉不能当作文件名的特殊字符。

- Title

```bash
# 使用 sed 和 tr 去除不能当作文件名的特殊字符
video_name=$(jq ".Title" *.info | tr -d "[:punct:]\040\011\012\015")
```

- PartName

```bash
part_name=$(jq ".PartName" *.info | tr -d "[:punct:]\040\011\012\015")
```

- CreateDate

```bash
upload_time=$(grep -Eo "20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" *.info)
```

## flv 合并

合并 flv 视频文件使用 ffmpeg 工具很简单就能完成，debian/ubuntu 的下直接 `apt update && apt install ffmpeg -y` 一把梭就行啦，其他发行使用各自的包管理器安装即可

```bash
# 如果执行环境没有安装 jq 命令的话需要安装上哦
apt update
apt install ffmpeg jq -y
```

### 合并多个 flv 文件

使用 ffmpeg 合并文件需要准备一个文本文件，里面记录类似一下的格式：

```bash
file '/path/1.flv'
file '/path/2.flv'
file '/path/3.flv'
```

而我们在 shell 脚本中可以通过 `ls *.flv > ff.txt;sed -i ‘s/^/file /g’ ff.txt` 来生成该文件

## 脚本

我放在了 GitHub 上，[mbcf ](https://github.com/muzi502/mbcf/blob/master/merge_bilibili_client_flv.sh) 方便维护和问题反馈

```bash
#!/bin/bash
# for: bulk merge bilibili UWP download file *.flv
# by: muzi502 blog.502.li
# date: 2019-01-12
# 执行环境需要安装 ffmpeg、jq

set -xu
start_time=$(date)
root_dir=$(pwd)
mp4_dir=${root_dir}/mp4
mkdir -p ${root_dir}/mp4

for dir in $(ls | sort -n | grep -v .sh | grep -v mp4)
do
  cd ${root_dir}/${dir}
  for p_dir in $(ls | sort -n | grep -E -v ".dvi|.jpg|.ini|.mp4|.txt")
  do
    cd ${root_dir}/${dir}/${p_dir}
    video_name=$(jq ".Title" *.info | tr -d "[:punct:]\040\011\012\015")
    part_name=$(jq ".PartName" *.info | tr -d "[:punct:]\040\011\012\015")
    upload_time=$(grep -Eo "20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" *.info)
    if [ "null" = "${part_name}" ];then
      mp4_file_name=${upload_time}_${video_name}.mp4
    else
      mp4_file_name=${upload_time}_${video_name}_${p_dir}_${part_name}.mp4
    fi
    ls *.flv | sort -n > ff.txt
    sed -i 's/^/file /g' ff.txt
    ffmpeg -f concat -i ff.txt -c copy ${mp4_dir}/"${mp4_file_name}";rm -rf ff.txt
    cd ${root_dir}/${dir}
  cd ${root_dir}
  done
# 如果需要保留原视频请注释掉下面这一行
# rm -rf ${root_dir}/${dir}
done
```

把 UWP 哔哩哔哩动画客户端或者 Android 客户端下载缓存视频的目录拷贝到 PC 工作目录下（我的环境是 `Windows 10 WSL GNU/Debian`），然后创建该脚本。接着安装好 ffmpeg 和 jq 这两个工具。然后在命令行下执行这个脚本就可以了。合并转码后的 mp4 文件都放在了脚本执行目录下的 mp4 文件夹中。在此一定要将脚本放在正确的目录下执行。

```bash
╭─debian@debian /mnt/d/Downloads/bilibili
╰─$ tree
364 directories, 1542 files
╭─debian@debian /mnt/d/Downloads/bilibili
╰─$ du -sh
114G    .
╭─debian@debian /mnt/d/Downloads/bilibili
╰─$ ./merge_bilibili_video.sh
+ end_time='Tue 14 Jan 2020 10:52:32 AM CST'
++ du -sh /mnt/d/Downloads/bilibili/mp4
+ mp4_size='113G        /mnt/d/Downloads/bilibili/mp4'
+ echo 'Tue 14 Jan 2020 10:42:07 AM CST'
Tue 14 Jan 2020 10:42:07 AM CST
+ echo 'Tue 14 Jan 2020 10:52:32 AM CST'
Tue 14 Jan 2020 10:52:32 AM CST
+ echo 'all flv size 114G       /mnt/d/Downloads/bilibili'
all flv size 114G       /mnt/d/Downloads/bilibili
+ echo 'all output mp4 size 113G        /mnt/d/Downloads/bilibili/mp4'
all output mp4 size 113G        /mnt/d/Downloads/bilibili/mp4
```

## 效果

合并转码的速度主要取决于磁盘性能，我放在 5200RPM 的机械硬盘下转码合并 110 多 GB 的 flv 文件，耗时 1 个多小时，放在 NVME 的固态硬盘下十几分钟就转换完了。

- 截取一小部分😂

```ini
2016-08-06_【木鱼微剧场】《帝国的毁灭》万恶之源.mp4
2018-06-06_【木鱼微剧场】蝴蝶效应真的存在吗？《混沌：数学探秘》（下）.mp4
2018-06-22_【木鱼微剧场】《海豚湾》豆瓣Top250排名最高的纪录片.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_10_大国崛起10新国新梦——美国.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_11_大国崛起11危局新政——美国.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_12_大国崛起12大道行思——大国之谜.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_13_《大国崛起》高清片头国语高清.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_1_大国崛起1海洋时代——葡萄牙、西班牙.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_2_大国崛起2小国大业——荷兰.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_3_大国崛起3走向现代——英国.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_4_大国崛起4工业先声——英国.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_5_大国崛起5激情岁月——法国.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_6_大国崛起6帝国春秋——德国.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_7_大国崛起7百年维新——日本.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_8_大国崛起8寻道图强——俄罗斯.mp4
2018-08-19_央视纪录片《大国崛起TheRiseOfGreatNations》全12集国语中字720P高清纪录片_9_大国崛起9风云新途——俄罗斯.mp4
2018-08-30_生命起源的奇幻旅程ROSETTACOMETCHASERAJOURNEYTOTHEO.mp4
2019-02-18_【经济】复旦大学新城与债务：造城运动真的带来发展吗？全4讲主讲陆铭_1_1.mp4
2019-02-18_【经济】复旦大学新城与债务：造城运动真的带来发展吗？全4讲主讲陆铭_2_2.mp4
2019-02-18_【经济】复旦大学新城与债务：造城运动真的带来发展吗？全4讲主讲陆铭_3_3.mp4
2019-02-18_【经济】复旦大学新城与债务：造城运动真的带来发展吗？全4讲主讲陆铭_4_4.mp4
2019-04-07_湊あくあlettersong自制spiral版.mp4
2019-04-12_【爱的旋律】与你相遇，便是我生命中最美好的时光——最美的爱情.mp4
2020-01-14_【纪录片】食物的历史4【双语特效字幕】【纪录片之家字幕组】.mp4
```

