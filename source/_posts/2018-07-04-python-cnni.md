---
title: 一个简单的 python 爬虫
date: 2018-07-20
updated:
categories: 技术
slug:
tag:
copyright: true
comment: true
---

```python
import re
import requests
def input_url(i):
    if i == 0:
        url = "http://www.cnnic.net.cn/hlwfzyj/hlwxzbg/index" + ".htm"
    else:
        url = "http://www.cnnic.net.cn/hlwfzyj/hlwxzbg/index_" + str(i) + ".htm"
    res = requests.get(url)
    urls = re.findall("<a href=\'./(.*?).pdf\'.*?target=\"_blank\">", res.content.decode("utf-8") , re.M)
    for m in range(0, len(urls)):
        dome = "http://www.cnnic.net.cn/hlwfzyj/hlwxzbg/"
        html = urls[m]
        urls[m] = dome + html + ".pdf"
    return urls
```

```python
if __name__ == '__main__':
    file = open("pdf.json", "w")
    for i in range(0,7):
        pdf = input_url(i)
        for i in pdf:
                file.write(i)
                file.write("\n")
    file.close()
```
