---
title: Python 处理 kindle 标注文本
date: 2021-11-30
updated:
slug:
categories:
tag:
copyright: true
comment: true
---

## kindle 标注

大学毕业之后不再像在校时那样能随便去图书馆看书，就从传统纸质书的阅转换到了 kindle 上来。这两年就一直习惯使用 kindle 来看书，读书过程中遇到一些不错的句子或段落往往会标注记录下来。这样时间一长，现在的 Kindle 上就积累了 共 189 本书和 3522 条笔记 😂。本人有个习惯就是会进行笔记整理，通过这些标注来回忆当时读书时的一些想法，整理一下读书笔记。Kindle 标注的文本都是以 txt 格式方式存储在 Kindle 的 `/documents/My Clippings.txt` 文件中。由于 txt 格式的文本数据阅读起来实在是太费劲了，于是之前参考了 [kindleNote](https://github.com/cyang812/kindleNote) 和 [书伴网 Clippings Fere 工具](https://bookfere.com/tools#ClippingsFere) 缝合了一个工具 **[muzi502/kindle](https://github.com/muzi502/kindle)**。用它来将 txt 格式的标注文本渲染成 html 的格式。这样每一本书就能有一个单独的 html 页面来展示标注的内容，阅读起来就十分方便。最近花了点时间重构了一下该工具，并新增了 svg 日历图的生成方式，本文就介绍一下这个工具的实现思路和方法。

## 分隔

由于 Kindle 的标注文本有一定的规律可循，实现起来还是比较方便滴。大致思路就是先读取 Kindle 的标注文件 `My Clippings.txt`，然后根据分隔符 `==========` 分割每一个标注；每个标注包含着书名、标注时间、标注内容等信息，规律如下：

- 第一行：书籍的名称以及作者，可以以半角括号来拆分出书名和作者；
- 第二行：标注的位置和时间，以 `|` 拆分出标注位置和标注时间；
- 第三行：空行，可以将这一行去除掉，即取出标注文件中所有的空行；
- 第四行：标注文本内容，Kindle 标注的正文是没有换行的，即便是连续标注了几段也都会压缩在一行里面；
- 第五行： 即分隔符`==========` ，所有的标注都是以它来进行分隔；

```bash
娱乐至死 ([美]尼尔·波兹曼)
- 您在位置 #109-110的标注 | 添加于 2019年10月27日星期日 下午11:09:01

电视需要的内容和其他媒体截然不同。电视无法表现政治哲学，电视的形式注定了它同政治哲学是水火不相容的。
==========
娱乐至死 ([美]尼尔·波兹曼)
- 您在位置 #110-112的标注 | 添加于 2019年10月27日星期日 下午11:09:19

信息、内容，或者如果你愿意，可以称之为构成“今日新闻”的“素材”，在一个缺乏媒介的世界里是不存在的——是不能存在的。
==========
娱乐至死 ([美]尼尔·波兹曼)
- 您在位置 #114-115的标注 | 添加于 2019年10月27日星期日 下午11:09:52

电报使无背景的信息能够以难以置信的速度跨越广阔的空间。
==========
通往奴役之路 (弗里德里希·奥古斯特·冯·哈耶克)
- 您在位置 #259-261的标注 | 添加于 2019年11月8日星期五 下午12:50:33

在安排我们的事务时，应该尽可能多地运用自发的社会力量，而尽可能少地借助于强制，这个基本原则能够作千变万化的应用。深思熟虑地创造一种使竞争能尽可能地有益进行的体制，和被动地接受既定的制度，二者之间的差别尤其悬殊。
==========
通往奴役之路 (弗里德里希·奥古斯特·冯·哈耶克)
- 您在位置 #312-318的标注 | 添加于 2019年11月8日星期五 下午12:54:46

尽管绝大部分的新思想，尤其是社会主义，并非起源于德国，但正是在德国它们得到完善，并在19世纪的最后25年和20世纪的最初25年，得到最充分的发展。现在，人们常常忽略了，德国在这一时期社会主义的理论和实际的发展中起了多么巨大的领导作用；在社会主义成为这个国家的一个严重问题以前的那一代，德国国会中已有一个很大的社会主义政党；并且在不久以前，社会主义学说的发展，几乎完全是在德国和奥地利进行的，以致于今天俄国人的讨论，在很大程度上是从德国人中止的地方进行的；绝大部分英国的社会主义者尚未意识到，他们才开始发现的大多数问题，德国社会主义者很早以前已彻底讨论过了。
==========
见识城邦·童年的消逝（媒介文化研究大师尼尔·波兹曼20年经典畅销作品） (尼尔·波兹曼)
- 您在位置 #536-539的标注 | 添加于 2019年11月21日星期四 上午6:47:26

列奥·洛文塔尔（Leo Lowenthal）说道：“自从文艺复兴以来，关于人类本性的普遍哲学是建立在这样的构想之上的：每个个人都是离经叛道者。在很大程度上，个人的存在就在于坚持个性，反对社会的限制和规范要求。”
==========
```

- 首先定义一个书籍列表，列表中的每个元素为一个字典，字典中记录的信息如下：

```json
[
  {
    "name": book_name,
    "author": book_author,
    "url": book_url,
    "nums": 0,
    "marks": [],
	}
]
```

- 每本书的标注列表

```json
[
  {
    "time": mark_time, 
    "address": mark_address, 
    "content": mark_content
	}
]
```

- 转换后的 json 格式

```json
[
  {
    "name": "娱乐至死 ",
    "author": "尼尔·波兹曼",
    "url": "dd0875de349e84eb7e6a2402c64bd95a",
    "nums": 3,
    "marks": [
      {
        "time": " 添加于 2019年10月27日星期日 下午11:09:01",
        "address": "您在位置 #109-110的标注",
        "content": "电视需要的内容和其他媒体截然不同。电视无法表现政治哲学，电视的形式注定了它同政治哲学是水火不相容的。"
      },
      {
        "time": " 添加于 2019年10月27日星期日 下午11:09:19",
        "address": "您在位置 #110-112的标注",
        "content": "信息、内容，或者如果你愿意，可以称之为构成“今日新闻”的“素材”，在一个缺乏媒介的世界里是不存在的——是不能存在的。"
      },
      {
        "time": " 添加于 2019年10月27日星期日 下午11:09:52",
        "address": "您在位置 #114-115的标注",
        "content": "电报使无背景的信息能够以难以置信的速度跨越广阔的空间。"
      }
    ]
  },
  {
    "name": "通往奴役之路 ",
    "author": "弗里德里希·奥古斯特·冯·哈耶克",
    "url": "646a2a825b48c4c9df653a42aa72b702",
    "nums": 2,
    "marks": [
      {
        "time": " 添加于 2019年11月8日星期五 下午12:50:33",
        "address": "您在位置 #259-261的标注",
        "content": "在安排我们的事务时，应该尽可能多地运用自发的社会力量，而尽可能少地借助于强制，这个基本原则能够作千变万化的应用。深思熟虑地创造一种使竞争能尽可能地有益进行的体制，和被动地接受既定的制度，二者之间的差别尤其悬殊。"
      },
      {
        "time": " 添加于 2019年11月8日星期五 下午12:54:46",
        "address": "您在位置 #312-318的标注",
        "content": "尽管绝大部分的新思想，尤其是社会主义，并非起源于德国，但正是在德国它们得到完善，并在19世纪的最后25年和20世纪的最初25年，得到最充分的发展。现在，人们常常忽略了，德国在这一时期社会主义的理论和实际的发展中起了多么巨大的领导作用；在社会主义成为这个国家的一个严重问题以前的那一代，德国国会中已有一个很大的社会主义政党；并且在不久以前，社会主义学说的发展，几乎完全是在德国和奥地利进行的，以致于今天俄国人的讨论，在很大程度上是从德国人中止的地方进行的；绝大部分英国的社会主义者尚未意识到，他们才开始发现的大多数问题，德国社会主义者很早以前已彻底讨论过了。"
      }
    ]
  },
  {
    "name": "见识城邦·童年的消逝",
    "author": "尼尔·波兹曼",
    "url": "1e1c307ca9d857c047d33df2a808e557",
    "nums": 1,
    "marks": [
      {
        "time": " 添加于 2019年11月21日星期四 上午6:47:26",
        "address": "您在位置 #536-539的标注",
        "content": "列奥·洛文塔尔（Leo Lowenthal）说道：“自从文艺复兴以来，关于人类本性的普遍哲学是建立在这样的构想之上的：每个个人都是离经叛道者。在很大程度上，个人的存在就在于坚持个性，反对社会的限制和规范要求。”"
      }
    ]
  }
]
```

## txt to json

有了上面的思路之后，我们就可以对 Kindle 的标注文本进行处理。先将 txt 格式的文本转换成 json 结构化的数据。然后再使用这个结构化的 json 进行后续的处理操作。对于文本的处理，选择 Python 比较合适。因为在 Python 中字符串对象有很多操作方法，比如分割、匹配、替换等等，都要比其他语言方便一些；以下就是具体实现的代码：

```python
import re
import sys
import json
from hashlib import md5

# 定义分隔符
DELIMITER = u"==========\n"

# 按照分隔符对所有标注进行分割，并存放在该数组中
all_marks = []

# 按照书籍来对标注进行分组存放
all_books = []


# 定义一个函数用于获取当前书籍在 all_books 列表中的索引
def get_book_index(book_name):
    """get book's index"""
    for i in range(len(all_books)):
        if all_books[i]["name"] == book_name:
            return i
    # 如果书籍并不存在，说明还没有插入该元素，就将该元素插入到最后一个元素
    return -1


# 定义渲染处理标注文本的函数  
def render_clippings(file_name):
    global all_marks
    global all_books

    # 以 utf-8 格式打开标注文件并并将内容读取到 content 变量中
    with open(file_name, "r", encoding="utf-8") as f:
        content = f.read()

    # 对读入的内容去除空行，即将 '\n\n' 替换为 '\n'，方便后续处理
    content = content.replace("\n\n", "\n")

    # 对去除空行的内容以分隔符进行分隔，得到的是一个列表，每个元素就是一个标注
    all_marks = content.split(DELIMITER)
    for i in range(len(all_marks)):
        # 以换行符进行分隔，将每个标注拆分成四个元素
        mark = all_marks[i].split("\n")
        # 如果该标注中元素的数量为 4 说明就是一个正确的标注，否则就是无效的
        if len(mark) == 4:

          	# 对标注的第一个元素，即书名部分进行 md5 计算，用于将它设置为后续的 url 路径，以及 html 文件名
            book_url = md5(mark[0].encode("utf-8")).hexdigest()
            # 去除掉书名中一些特殊的字符，用来拆分出简短的书名
            book_info = re.split(r"[()<>|\[\]（）《》【】｜]\s*", mark[0])
            # 获取书名，一般为第一个元素，目的是为了去除 kinlde 中文商店下载的又长又臭的书名
            book_name = book_info[0] if str(book_info[0]) != "" else (mark[0])
            
            # 获取该书的作者
            book_author = book_info[-2] if len(book_info) > 1 else ""
            
            mark_info = mark[1].split("|")
  					# 获取该书的标记时间和标注位置
            mark_time = mark_info[1]
            mark_address = mark_info[0].strip("- ")
            
            # 获取该标注的正文内容
            mark_content = mark[2]
            
            # 查询该书的列表索引，将该标记插入到该书的 marks 列表中
            book_index = get_book_index(book_name)
            if book_index == -1:
                all_books.append(
                    {
                        "name": book_name,
                        "author": book_author,
                        "url": book_url,
                        "nums": 0,
                        "marks": [],
                    }
                )
            all_books[book_index]["marks"].append(
                {"time": mark_time, "address": mark_address, "content": mark_content}
            )
            # 更新该书的标记数量
            all_books[book_index]["nums"] += 1
    # 使用 lambda 函数以标注数量为 key 对所有书籍进行倒序排序
    all_books.sort(key=lambda x: x["nums"], reverse=True)
    
    # 以下就是将 all_books 列表以 json 格式写入到一个 json 文件中，或许会有一些其他的用途，比如前端展示
    try:
        json_str = json.dumps(all_books, indent=2, ensure_ascii=False)
        with open("clippings.json", "w") as f:
            f.write(json_str)
        return 1
    except:
        return 0

 if __name__ == "__main__":
    file_path = "source.txt" if len(sys.argv) == 1 else sys.argv[1]
    render_clippings(file_path)
```

## json to html

接下来再将上述得到的 json 内容写入到 html 文件中。渲染 html 的方式有两种，一种是通过 jinja2 的模版进行渲染，一种是通过字符串替换拼凑 html 内容。两种各有各的好处，jinjia2 实现起来比较优雅一些，但是会引入一个 jinjia2 的依赖；第二种方式就无任何依赖，适用性回好一些；下面就讲一下使用第二种方式的实现；

- 将 html 内容按照元素的分布进行拆分，定义如下几个几个特殊的变量

```python
HTML_HEAD = """<!DOCTYPE html>
<html>
	<head>
	<meta charset="utf-8" />
	<title> Kindle 读书笔记 </title>
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<link href="../style/css/bootstrap.min.css" rel="stylesheet" type="text/css" />
	<link href="../style/css/bootstrap-theme.min.css" rel="stylesheet" type="text/css" />
	<link href="../style/css/custom.css" rel="stylesheet" type="text/css" />
</head>
<body>
"""

INDEX_TITLE = """
	<div class="container">
		<header class="header col-md-12">
			<div class="page-header">
                <embed src="date.svg" type="image/svg+xml" />
				<h1><small><span class="glyphicon glyphicon-book" aria-hidden="true"></span> Kindle 读书笔记 </small> <span class="badge">更新于 UPDATE </span> <span class="badge"> 共 BOOKS_SUM 本书，SENTENCE_SUM 条笔记</span></h1>
			</div>
		</header>
	<div class="col-md-12">
        <div class="list-group">
"""

BOOK_TITLE = """
	<div class="container">
		<header class="header col-md-12">
			<div class="page-header">
				<h1><small><span class="glyphicon glyphicon-book" aria-hidden="true"></span>BookName</small> <span class="badge"></span></h1>
			</div>
		</header>

        <div class="col-md-2">
			<ul class="nav nav-pills nav-stacked go-back">
				<li role="presentation" class="active text-center">
					<a href="../index.html" style="border-radius: 50%;"><span class="glyphicon glyphicon-backward" aria-hidden="true"></span></a>
				</li>
			</ul>
		</div>
"""

MARK_CONTENT = """
    	<div class="col-md-12">
			<article>
				<div class="panel panel-default">
					<div class="panel-body mk88"><p>SENTENCE_TXT
                    </p></div>
					<div class="panel-footer text-right">
						<span class="label label-primary"><span class="glyphicon glyphicon-tag" aria-hidden="true"></span> 标注</span>
						<span class="label label-default"><span class="glyphicon glyphicon-bookmark" aria-hidden="true"></span>SENTENCE_ADDR</span>
						<span class="label label-default"><span class="glyphicon glyphicon-time" aria-hidden="true"></span>SENTENCE_TIME</span>
					</div>
				</div>
			</article>
        </div>
"""

ITEM_CONTENT = """          <a href="HTML_URL" class="list-group-item"><span class="glyphicon glyphicon-book" aria-hidden="true"></span>HTML_FILE_NAME<span class="glyphicon glyphicon-tag" aria-hidden="true">SENTENCE_COUNT</span></a>
"""

FOOTER_CONTENT = """
        </div>
    </div>
</body>
</html>
"""
```

- 渲染 index.html 文件

```python
def render_index_html():
    with open("index.html", "w", encoding="utf-8") as f:
        f.write(HTML_HEAD.replace("../", ""))
        # 替换书籍的总数量和标注的总数量
        f.write(
            INDEX_TITLE.replace("SENTENCE_SUM", str(len(all_marks)))
            .replace("UPDATE", time.strftime("%Y-%m-%d %H:%M", time.localtime()))
            .replace("BOOKS_SUM", str(len(all_books)))
        )

        # 根据预先定义的标识字符替换每本书籍的书籍名、作者、标注数量、URL
        for book in all_books:
            f.write(
                ITEM_CONTENT.replace("HTML_URL", "books/" + book["url"] + ".html")
                .replace("HTML_FILE_NAME", book["name"] + " [" + book["author"] + "]")
                .replace("SENTENCE_COUNT", str(book["nums"]))
            )
        f.write(FOOTER_CONTENT)
```

- 渲染 book 书籍页面

```python
def render_books_html():
    if os.path.exists("books"):
        shutil.rmtree("books")
    os.mkdir("books")
    for i in range(len(all_books)):
        book_url = all_books[i]["url"]
        book_name = all_books[i]["name"]
        book_author = all_books[i]["author"]
        with open("books/" + book_url + ".html", "w", encoding="utf-8") as f:
            f.write(HTML_HEAD)
            f.write(
                BOOK_TITLE.replace("BookName", book_name + " [" + book_author + "]")
            )
            for j in range(len(all_books[i]["marks"])):
                mark = all_books[i]["marks"][j]
                f.write(
                    MARK_CONTENT.replace("SENTENCE_TXT", mark["content"])
                    .replace("SENTENCE_ADDR", mark["address"])
                    .replace("SENTENCE_TIME", mark["time"])
                )
            f.write(FOOTER_CONTENT)
```

## date to svg

前段时间看到 yihong 大佬的 **[GitHubPoster](https://github.com/yihong0618/GitHubPoster)** 支持了 json 格式的数据，只要提供类似类似如下格式的数据，就可以生成相应的 svg 了。真的是一个很棒的特性，这样我们就可以根据每天标记的数量来生成一个对应的 svg 图了。

```json
{
  "2019-05-28": 1,
  "2019-06-10": 1,
  "2019-07-18": 1,
  "2019-07-23": 1,
  "2019-07-24": 1,
  "2019-07-29": 1,
  "2019-08-12": 1
 }
```

{{% raw %}}

<blockquote class="twitter-tweet"><p lang="zh" dir="ltr">支持了自定义 json 的源数据，生成了某个 tg 现充群的群聊的 poster <a href="https://t.co/nhSe3qlVe0">https://t.co/nhSe3qlVe0</a> <a href="https://t.co/bkijsFDtzC">pic.twitter.com/bkijsFDtzC</a></p>&mdash; yihong0618 (@yihong0618) <a href="https://twitter.com/yihong0618/status/1466275108952051716?ref_src=twsrc%5Etfw">December 2, 2021</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

{{% endraw %}}

- 生成 `date.json` 数据文件

生成一个{日期: 数量} 格式的字典其实挺简单，不过对于 kindle 标注的时间格式需要稍微处理一下，转换成一个标准的时间格式。

```python
def render_date_json():
    all_dates = {}
    for i in range(len(all_marks)):
        mark = all_marks[i].split("\n")
        # 如果一个标注有 4 行说明它就是一个正确的标注
        if len(mark) == 4:
            # 第二行就是标注的时间，以年月日关键字进行分隔，第一个元素就是年，第二个就是月，第三个就是日
            date = re.split(r"[年月日]\s*",mark[1].split("|")[1].split(" ")[2])
            
            # 在 1-9 月前面补充一个 0
            month = date[1] if len(date[1]) == 2 else "0" + date[1]

            # 在 1-9 日前面补充一个 0
            day = date[2] if len(date[2]) == 2 else "0" + date[2]
            
            # 最后拼凑成 2021-12-05 这样的时间格式
            date = date[0] + "-" + month + "-" + day
            
            # 如果当前日期没有在字典中，则将它添加到字典中
            if date not in all_dates:
                all_dates[date] = 0
 
            # 对天数的 value 值进行自增 1
            all_dates[date] += 1
    # 将数据写入 json 文件当中
    try:
        json_str = json.dumps(all_dates, indent=2, ensure_ascii=False)
        with open("date.json", "w") as f:
            f.write(json_str)
        return 1
    except:
        return 0
```

生成好 json 格式的数据之后，接下来我们就使用 GitHubPoster 来生成相应的 svg 文件。由于 GitHubPoster 的依赖项太多，且还没有支持 docker 方式来运行，在本地安装也不是很方便，因此为了方便起见我们将它放在 GitHub action 中运行。这样只要每次更新标注文本的源文件就可以自动更新 html 页面并生成最新的 svg 图片了。

```yaml
---
name: Build kindle note website

on:
  push:
    branches:
      - gh-pages
      - master
jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      
      - name: Set up Python
        uses: actions/setup-python@v1
        with:
          python-version: 3.6

      - name: Install dependencies
        run: |
          # 安装 github_poster 及其依赖
          pip3 install -U github_poster

			  # 生成 html 文件
      - name: Build .html file
        run: python3 kindle.py

       # 生成 svg 文件
      - name: Build svg file
        run: |
          github_poster json --json_file date.json --year 2021 --me kindleReading --background-color '#ffffff'
          mv OUT_FOLDER/json.svg date.svg

      # 设置 commit 信息为 GitHub action bot，并提交 commit 和 push 到 origin 上
      - name: Config git user and user.email and push commit
        run: |
          git config user.name github-actions
          git config user.email 41898282+github-actions[bot]@users.noreply.github.com
          git add .
          git commit -am "Auto build by GitHub Actions $(date)"
          git push origin -f
```

