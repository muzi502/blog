---
title: 使用 CloudFlare Workers 搭建 telegram 频道镜像站
date: 2020-03-26
updated: 2020-04-21
slug: cloudflare-worker-build-mirror-website
categories: 技术
tag:
  - GFW
  - CloudFlare
  - telegram
copyright: true
comment: true
---

## 更新

-   2020-04-21：推荐食用  [Telegram-Channel-Mirror](https://github.com/idealclover/Telegram-Channel-Mirror) 进行反代 telegram 频道

## 一次偶遇

昨天在咱的 [让图片飞起来 oh-my-webp.sh ！](https://blog.k8s.li/oh-my-webpsh.html) 收到了 [ChrAlpha](https://ichr.me/) 大佬的回复，咱就拜访了一下大佬的博客😂，无意间发现 [Cloudflare Worder 免费搭建镜像站](https://blog.ichr.me/post/cloudflare-worker-build-mirror-website/) 这篇博客。于是呐，咱也想着能不能玩一玩这个 Workers 。虽然之前听说过有用 Workers 做很多好玩的事儿，比如加速网站、代理 Google 镜像站什么的。不过这些对于咱来说不是很刚需就没有折腾。刚好咱的 telegram 电报频道 [RSS Kubernetes](https://t.me/rss_kubernetes) 人也比较多了，为了提高一点影响力，咱就想着能不能把频道的预览界面 [t.me/s/rss_kubernetes](https://t.me/s/rss_kubernetes) 反代到咱域名上。虽然之前尝试使用 nginx 进行反代，但是效果不尽人意，于是当时就弃坑了。在春节的时候咱也看到过有人反代 [2019-nCoV疫情实时播报🅥](https://t.me/nCoV2019) ，比如 [2019ncov.ga](https://2019ncov.ga/)，不过当时那个项目折腾起来也是很麻烦，咱这种菜鸡还是溜了溜了😂。直到今天看到 [Cloudflare Worder 免费搭建镜像站](https://blog.ichr.me/post/cloudflare-worker-build-mirror-website/) 这篇博客后就心血来潮，就搞一搞吧😂

## 劝退~~三~~一连

首先你要有个 Cloudflare 账户，这是必须的。关于 Cloudflare 的注册咱就不多说啦，不过咱倒是建议大家伙把域名的 DNS 解析放到 Cloudflare 上来，好处多多：有把 https 小绿锁、免费的 ~~加速~~ 减速 CDN （墙内）、域名访问统计等等可玩性比较高😋。需要注意的是 Cloudflare 的 Worker 一天 10 万次免费额度，也够咱喝一壶的啦，不用担心不够用。

## 新建 Worker

登录到 [Cloudflare](https://dash.cloudflare.com)的~~大盘~~面板，点击左上角的 `Menu` ----> `Workers` 进入到 Workers 页面。新注册的用户会提示设置一个 `workers.dev` 顶级域名下的二级子域名，这个子域名设置好之后是不可更改的，之后你新创建的 Worker 就会使以这个域名而二级子域名开始的，类似于  `WorkerName.yousetdomain.workers.dev` 。`yousetdomain` 就是你要设置的二级子域名，`WorkerName` 可以自定义，默认是随机生成的。也可以给自己的域名添加一条 CNAME 到 `WorkerName.yousetdomain.workers.dev` ，这样使用自己的域名就可以访问到 `Worker` 了。

设置好二级子域名之后选择 free 套餐计划，然后进入到 Worker 管理界面，创建一个新的 `Worker`  然后在 `Script` 输入框里填入以下代码。**俗话说代码写得好，同行抄到老**，咱的 `worker.js` 代码是参考自 [Workers-Proxy](https://github.com/Siujoeng-Lau/Workers-Proxy) ，不过咱去掉了一些无关紧要的代码，原代码是加入了辨别移动设备适配域名、屏蔽某些 IP 和国家的功能。对于咱的 telegram 频道镜像站来说，这都是多余的，于是就去掉了。

![image-20200326184802562](https://blog.k8s.li/img/20200326184802562.png)

```javascript
// Website you intended to retrieve for users.
const upstream_me = 't.me';
const upstream_org = 'telegram.org';

// Custom pathname for the upstream website.
const upstream_path = '/s/rss_kubernetes';

// Whether to use HTTPS protocol for upstream address.
const https = true;

// Replace texts.
const replace_dict = {
  $upstream: '$custom_domain'
};

addEventListener('fetch', event => {
  event.respondWith(fetchAndApply(event.request));
});

async function fetchAndApply(request) {
  let response = null;
  let url = new URL(request.url);
  let url_hostname = url.hostname;

  if (https == true) {
    url.protocol = 'https:';
  } else {
    url.protocol = 'http:';
  }

  var upstream_domain = upstream_me;

  // Check telegram.org
  let pathname = url.pathname;
  console.log(pathname);
  if (pathname.startsWith('/static')) {
    console.log('here');
    upstream_domain = upstream_org;
    url.pathname = pathname.replace('/static', '');
  } else {
    if (pathname == '/') {
      url.pathname = upstream_path;
    } else {
      url.pathname = upstream_path + url.pathname;
    }
  }

  url.host = upstream_domain;

  let method = request.method;
  let request_headers = request.headers;
  let new_request_headers = new Headers(request_headers);

  new_request_headers.set('Host', url.hostname);
  new_request_headers.set('Referer', url.hostname);

  let original_response = await fetch(url.href, {
    method: method,
    headers: new_request_headers
  });

  let response_headers = original_response.headers;
  let status = original_response.status;

  response = new Response(original_response.body, {
    status,
    headers: response_headers
  });
  let text = await response.text();

  // Modify it.
  let modified = text.replace(
    /telegram.org/g, 'tg.k8s.li/static'
  );

  // Return modified response.
  return new Response(modified, {
    status: response.status,
    statusText: response.statusText,
    headers: response.headers
  });
}
```

需要注意的是，像 `t.me` 域名下的站点，比如我的 `https://t.me/s/rss_kubernetes` ，它的 js 和 css 样式文件是使用的 telegram.org 域名。~~所以我们需要在 `replace_dict` 那里定义好替换的正则表达式，~~将  `https://t.me/s/rss_kubernetes`页面里的  `telegram.org` 同样进行反代才行，这需要为 telegram 建一个单独的 Worker 😑。这也是评论区  [ChrAlpha](https://ichr.me/) 小伙伴提到的办法。

```html
ubuntu@blog:~$ curl https://t.me/s/rss_kubernetes | grep "<script src="
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  141k  100  141k    0     0  85287      0  0:00:01  0:00:01 --:--:-- 85237
    <script src="//telegram.org/js/jquery.min.js"></script>
    <script src="//telegram.org/js/jquery-ui.min.js"></script>
    <script src="//telegram.org/js/widget-frame.js?29"></script>
    <script src="//telegram.org/js/telegram-web.js?8"></script>
```

修改下处代码为，将`https://t.me/s/rss_kubernetes`页面里的  `telegram.org` 同样进行一次反代。这样访问到 `https://t.me/s/rss_kubernetes`页面时，把的 telegram.org 替换为另一个 Worker 的域名，比如我的 `telegram.k8srss.workers.dev`  。不过像频道里的图片、文件、视频等资源 telegram 是使用的 CDN ，而且有好几个域名……这点很僵硬，暂时找不到合适的办法。貌似一个 Worker 只能反代一个域名？如果汝有合适的办法，欢迎与咱交流，咱感激不尽😋

```javascript
let modified = text.replace(/telegram.org/g, "telegram.k8srss.workers.dev")
```

这样再使用 curl 访问测试一下，原来的 telegram.org 已经全部替换成 telegram.k8srss.workers.dev 了😂。现在墙内用户也可以无痛访问啦。在此感谢  [ChrAlpha](https://ichr.me/)  小伙伴😂提出宝贵的建议。

```html
</main>
    <script src="//telegram.k8srss.workers.dev/js/jquery.min.js"></script>
    <script src="//telegram.k8srss.workers.dev/js/jquery-ui.min.js"></script>

    <script src="//telegram.k8srss.workers.dev/js/widget-frame.js?29"></script>
    <script src="//telegram.k8srss.workers.dev/js/telegram-web.js?8"></script>
  
<!-- page generated in 121.26ms -->
```

这个文本替换功能很好玩儿，在 Cloudflare 官方的博客里还有个 demo [introducing-cloudflare-workers](https://cloudflareworkers.com/#c62c6c0002cb236166b794c440870cca:https://blog.cloudflare.com/introducing-cloudflare-workers) 。使用这个功能咱有解锁了一个玩具，稍后再讲😂。

> Here is a worker which performs a site-wide search-and-replace, replacing the word "Worker" with "Minion". [Try it out on this blog post.](https://cloudflareworkers.com/#c62c6c0002cb236166b794c440870cca:https://blog.cloudflare.com/introducing-cloudflare-workers)

~~剽窃~~修改好代码之后点击左下角的 `Save and Deploy` 然后 Preview 看看页面是否显示正常，如果显示正常恭喜你成功啦。

![image-20200326190914520](https://blog.k8s.li/img/20200326190914520.png)

如果你想使用这种办法反代其他频道，只需要把 `const upstream_path = '/s/rss_kubernetes'` 后的  rss_kubernetes 替换为你想要代理的 telegram 频道 username 即可。之所以加上 `upstream_path`  而不反代整个 `t.me` 是为了防止别人滥用，毕竟 10W 次不经薅😂

### 改进

周四晚上睡觉前在推特上发了个推文，向大家请教了一下之前一个 Worker 里只能反代一个域名的问题。第二天 [@Echowxsy](https://twitter.com/Echowxsy) 就回复咱了，而且还特意注册了 CouldFare 账号使用 Workers 帮咱测试了一下。在此非常感谢 [@Echowxsy](https://twitter.com/Echowxsy)  帮咱。按照  [@Echowxsy](https://twitter.com/Echowxsy) 小伙伴所说的：

> 我没用过 CloudFlare，不过我看了一下你的blog，貌似可以用两个upstream实现这个功能。 在modified那里替换为当前worker的地址，然后在后面加上一个不会重复的路径，例如xxx。 然后在fetchAndApply里面判断，如果当前请求的pathname=/xxx，使用upstream2，否则使用upstream1。 理论上是可以实现的。
>
> 就是一个 Workers 可以做很多事情，他实际上就是 Node.js 代码。 然后这里是将 [http://telegram.org/xxxx](https://t.co/wTGzY4U6sD?amp=1) 映射到 [http://tg.k8s.li/static/xxxx](https://t.co/yQwEY2mzCP?amp=1) 。 然后在 Workers 里面判断，如果有 `/static` 则从 [http://telegram.org](https://t.co/VYm4zCfwPr?amp=1) 获取，否则从 [http://t.me](https://t.co/N4Ahg0VLN1?amp=1) 获取。

`此处引用` [@Echowxsy](https://twitter.com/Echowxsy) 的 [推文](https://twitter.com/Echowxsy/status/1243407321989967874)

Woerker 首先我们获取完要反代的 `https://t.me/s/rss_kubernetes ` 页面 html 源码，然后使用 replace 函数把 telegram.org 以及cdn[1-5].telesco.pe 等域名进行替换，替换为 /static 、/cdn[1-5] 等不同的 url 路径。然后将修改后的 html 页面返回给客户端。客户端客户端在请求 `/static`  时 Worker 就会去 [http://telegram.org](https://t.co/VYm4zCfwPr?amp=1) 获取相应的资源返回给用户。这样就实现了一个 Worker 反代多个域名骚操作。修改后的代码如下：

```javascript
const upstream_me = 't.me';
const upstream_org = 'telegram.org';

// Custom pathname for the upstream website.
const upstream_path = '/s/rss_kubernetes';

// Whether to use HTTPS protocol for upstream address.
const https = true;

// Replace texts.
const replace_dict = {
  $upstream: '$custom_domain'
};

addEventListener('fetch', event => {
  event.respondWith(fetchAndApply(event.request));
});

async function fetchAndApply(request) {
  let response = null;
  let url = new URL(request.url);
  let url_hostname = url.hostname;

  if (https == true) {
    url.protocol = 'https:';
  } else {
    url.protocol = 'http:';
  }

  var upstream_domain = upstream_me;

  // Check telegram.org
  let pathname = url.pathname;
  console.log(pathname);
  if (pathname.startsWith('/static')) {
    console.log('here');
    upstream_domain = upstream_org;
    url.pathname = pathname.replace('/static', '');
  } else {
    if (pathname == '/') {
      url.pathname = upstream_path;
    } else {
      url.pathname = upstream_path + url.pathname;
    }
  }

  url.host = upstream_domain;

  let method = request.method;
  let request_headers = request.headers;
  let new_request_headers = new Headers(request_headers);

  new_request_headers.set('Host', url.hostname);
  new_request_headers.set('Referer', url.hostname);

  let original_response = await fetch(url.href, {
    method: method,
    headers: new_request_headers
  });

  let original_response_clone = original_response.clone();
  let response_headers = original_response.headers;
  let new_response_headers = new Headers(response_headers);
  let status = original_response.status;

  response = new Response(original_response_clone.body, {
    status,
    headers: new_response_headers
  });
  let text = await response.text();

  // Modify it.
  let modified = text.replace(/telegram.org/g,'tg.k8s.li/static');

  // Return modified response.
  return new Response(modified, {
    status: response.status,
    statusText: response.statusText,
    headers: response.headers
  });
}
```

## 自定义域名

回到 Workers 的管理页面，点击 `rename` 即可修改 Worker 的三级子域名。不过咱还是不太喜欢 `WorkerName.yousetdomain.workers.dev` 这么长的域名，想使用咱自己的二级子域名访问。

首先回到域名管理的页面，进入到自己域名顶部那一栏里的 `Workers` ，在那里添加相应的路由即可。

![image-20200326191340166](https://blog.k8s.li/img/20200326191340166.png)

点击 `Add Route` ，在 Route 那一栏输入好自己的域名，注意最后的 `/*` 也要加上，然后 Worker 选择刚刚创建的那个即可。接着再添加 `CNAME` 记录到自己的 `WorkerName.yousetdomain.workers.dev` ，这样就能使用自己的域名访问啦😋

![image-20200326191435923](https://blog.k8s.li/img/20200326191435923.png)

## 文本替换

前文提到的文本替换功能帮咱解决了一个小问题。咱友链关注的一个博客 [chanshiyu.com](https://chanshiyu.com/#/) 没有提供 RSS ，他是将博客内容放在 GitHub issue 上，所以只能通过 RSSHUB 来订阅 GitHub 的 issue 来获取博客的更新。但 RSSHUB 获取的是 GitHub issue 的链接而非原博客的链接，于是咱想了想就用 `Worker` 进行替换不得了。

通过 RSSHUB 获取到的 RSS 数据如下：

```xml
<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
<channel>
<title>
<![CDATA[ chanshiyucx/blog Issues ]]>
</title>
<link>https://github.com/chanshiyucx/blog/issues</link>
<atom:link href="http://rsshub.app/github/issue/chanshiyucx/blog" rel="self" type="application/rss+xml"/>
<description>
<![CDATA[
chanshiyucx/blog Issues - Made with love by RSSHub(https://github.com/DIYgod/RSSHub)
]]>
</description>
<generator>RSSHub</generator>
<webMaster>i@diygod.me (DIYgod)</webMaster>
<language>zh-cn</language>
<lastBuildDate>Thu, 26 Mar 2020 11:00:06 GMT</lastBuildDate>
<ttl>60</ttl>
<item>
<title>
<![CDATA[ Telegram 电报机器人 ]]>
</title>
<description>
<![CDATA[
]]>
</description>
<pubDate>Wed, 25 Mar 2020 03:54:04 GMT</pubDate>
<guid isPermaLink="false">https://github.com/chanshiyucx/blog/issues/108</guid>
<link>https://github.com/chanshiyucx/blog/issues/108</link>
```

其中的 `<guid isPermaLink="false">` 和 `<link>` 中的链接 github.com/chanshiyucx/blog/issues/ 替换为 chanshiyu.com/#/post/ 即可。于是还是同样的方法新建一个 Worker，然后修改一下 `worker.js` 的代码就可以啦。

```javascript
// Website you intended to retrieve for users.
const upstream = 'rsshub.app'

// Custom pathname for the upstream website.
const upstream_path = '/github/issue/chanshiyucx/blog'

// Whether to use HTTPS protocol for upstream address.
const https = true

addEventListener('fetch', event => {
    event.respondWith(fetchAndApply(event.request));
})

async function fetchAndApply(request) {

    let response = null;
    let url = new URL(request.url);
    let url_hostname = url.hostname;

    if (https == true) {
        url.protocol = 'https:';
    } else {
        url.protocol = 'http:';
    }

    var upstream_domain = upstream;
    url.host = upstream_domain;
    if (url.pathname == '/') {
        url.pathname = upstream_path;
    } else {
        url.pathname = upstream_path + url.pathname;
    }

    let method = request.method;
    let request_headers = request.headers;
    let new_request_headers = new Headers(request_headers);

    new_request_headers.set('Host', url.hostname);
    new_request_headers.set('Referer', url.hostname);

    let original_response = await fetch(url.href, {
        method: method,
        headers: new_request_headers
    })

    let original_response_clone = original_response.clone();
    let original_text = null;
    let response_headers = original_response.headers;
    let new_response_headers = new Headers(response_headers);
    let status = original_response.status;

    const content_type = new_response_headers.get('content-type');
    if (content_type.includes('text/html') && content_type.includes('UTF-8')) {
        original_text = await replace_response_text(original_response_clone, upstream_domain, url_hostname);
    } else {
        original_text = original_response_clone.body
    }

    response = new Response(original_text, {
        status,
        headers: new_response_headers
    })
    let text = await response.text()

// Modify it.
    let modified = text.replace(/github.com\/chanshiyucx\/blog\/issues\//g, "chanshiyu.com\/#\/post\/")

// Return modified response.
    return new Response(modified, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers
    })
    return response;
}
```

部署好 Worker 之后就可以使用 RSS 来订阅啦😋

![image-20200326193643610](https://blog.k8s.li/img/20200326193643610.png)

## 解锁更多好玩儿的😋

关于 Cloudflare 的 Workers 还有更多好玩的等待你去发现，咱就推荐一下啦：

- [Cloudflare Worker 免费搭建镜像站](https://blog.ichr.me/post/cloudflare-worker-build-mirror-website/)
- [从现在起，任何人都可以在Cloudflare上使用Workers运行JavaScript！](https://blog.cloudflare.com/zh/cloudflare-workers-unleashed-zh/)
- [尽情编写代码吧：改善开发人员使用Cloudflare Workers的体验](https://blog.cloudflare.com/zh/just-write-code-improving-developer-experience-for-cloudflare-workers-zh/)
- [使用 Cloudflare Workers 加速 Google Analytics](https://blog.skk.moe/post/cloudflare-workers-cfga)
- [使用 Backblaze B2 和 Cloudflare Workers 搭建可以自定义域名的免费图床](https://blog.meow.page/2019/09/24/free-personal-image-hosting-with-backblaze-b2-and-cloudflare-workers)
- [使用 Cloudflare Workers 提高 WordPress 速度和效能教學](https://free.com.tw/cloudflare-workers-wordpress/)
- [使用Cloudflare Workers反带P站图片](https://yojigen.tech/archives/post19/)

最后宣传一下咱的 [@rss_kubernetes](https://t.me/rss_kubernetes) 频道，国内用户可以访问 [tg.k8s.li](https://tg.k8s.li)，如果你对 docker 、K8s、云原生等感兴趣，就到咱碗里来吧😂。不订阅咱的频道也可以通过咱的 [tg.k8s.li](https://tg.k8s.li) 镜像站来查看 RSS 推送信息。

![image-20200327003346742](https://blog.k8s.li/img/20200327003346742.png)

GitHub page 又被墙一波，rsshub.app 也被墙掉了。墙越来越高了，这个社会也来越可笑了……不知道未来的互联网会变成什么样子，但我们作为一只屁民能做的就是**不为墙添砖加瓦，不为极权专制独裁暴政唱赞歌**。最后一张自己制作 kindle 电子书时喜欢使用的封面图片送给大家。
