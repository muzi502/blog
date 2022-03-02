---
title: Code it is trivial 写代码是微不足道的
date: 2019-03-03
updated:
categories: 互联网
slug:
tag:
copyright: true
comment: true
---

本文转载至 stack overflow 创始人 Jeff Atwood 的 [Code: It's Trivial](https://blog.codinghorror.com/code-its-trivial/)
背景是：当时 stack overflow 刚成立不久，而且使用的技术是 Windows server 及.net，就有特别多的人喷 stack overflow 技术垃圾，声称花一个周末的时间就能开发出像 stack overflow 一样的网站。 Jeff Atwood 于是写这篇文章怼回去，仔细看看 hack news 上的评论挺有意思的。[hack news 的链接在这](https://news.ycombinator.com/item?id=678501) 。还有当时的 [droxbox](https://news.ycombinator.com/item?id=8863) 和 [Airbnb](https://news.ycombinator.com/item?id=426120) 也被喷的狗血淋头。十年多过去了，喷他们的人只留下了一个 ID，而被喷的人留下了一个伟大的网站。

---

Remember that Stack Overflow thing we've been working on? Some commenters on a recent Hacker News article questioned the pricing of Stack Exchange -- essentially, a hosted Stack Overflow:
Seems really pricey for a relatively simple software like this. Someone write an open source alternative? it looks like something that can be thrown together in a weekend.
Ah, yes, the stereotypical programmer response to most projects: it's trivial! I could write that in a week!*
It's even easier than that. Open source alternatives to Stack Overflow already exist, so you've got a head start. Gentlemen, start your compilers! Er, I mean, interpreters!
No, I don't take this claim seriously. Not enough to write a response. And fortunately for me, now I don't need to, because Benjamin Pollack -- one of the few people outside our core team who has access to the Stack Overflow source code -- already wrote a response. Even if I had written a response, I doubt it would have been half as well written as Benjamin's.
Developers think cloning a site like StackOverflow is easy for the same reason that open-source software remains such a horrible pain in the ass to use. When you put a developer in front of StackOverflow, they don't really see StackOverflow. What they actually see is this:

```sql
create table QUESTION (ID identity primary key,
TITLE varchar(255),
BODY text,
UPVOTES integer not null default 0,
DOWNVOTES integer not null default 0,
USER integer references USER(ID));
create table RESPONSE (ID identity primary key,
BODY text,
UPVOTES integer not null default 0,
DOWNVOTES integer not null default 0,
QUESTION integer references QUESTION(ID))
```

If you then tell a developer to replicate StackOverflow, what goes into his head are the above two SQL tables and enough HTML to display them without formatting, and that really is completely doable in a weekend. The smarter ones will realize that they need to implement login and logout, and comments, and that the votes need to be tied to a user, but that's still totally doable in a weekend; it's just a couple more tables in a SQL back-end, and the HTML to show their contents. Use a framework like Django, and you even get basic users and comments for free.
But that's not what StackOverflow is about. Regardless of what your feelings may be on StackOverflow in general, most visitors seem to agree that the user experience is smooth, from start to finish. They feel that they're interacting with a polished product. Even if I didn'tknow better, I would guess that very little of what actually makes StackOverflow a continuing success has to do with the database schema--and having had a chance to read through StackOverflow's source code, I know how little really does. There is a tremendous amount of spit and polish that goes into making a major website highly usable. A developer, asked how hard something will be to clone, simply does not think about the polish, because the polish is incidental to the implementation.
I have zero doubt that given enough time, open source clones will begin to approximate what we've created with Stack Overflow. It's as inevitable as evolution itself. Well, depending on what time scale you're willing to look at. With a smart, motivated team of closed-source dinosaurs, it is indeed possible to outrun those teeny tiny open-source mammals. For now, anyway. Let's say we're those speedy, clever Velociraptor types of dinosaurs -- those are cool, right?
Despite Benjamin's well reasoned protests, the source code to Stack Overflow is, in fact, actually, kind of ... well, trivial. Although there is starting to be quite a lot of it, as we've been beating on this stuff for almost a year now. That doesn't mean our source code is good, by any means; as usual, we make crappy software, with bugs. But every day, our tiny little three person team of speedy-but-doomed Velociraptors starts out with the same goal. Not to write the best Stack Overflow code possible, but to create the best Stack Overflow experience possible. That's our mission: make Stack Overflow better, in some small way, than it was the day before. We don't always succeed, but we try very, very hard not to suck -- and more importantly, we keep plugging away at it, day after day.
Building a better Stack Overflow experience does involve writing code and building cool features. But more often, it's anything but:

1. synthesizing cleaner, saner HTML markup
2. optimizing our pages for speed and load time efficiency
3. simplifying or improving our site layout, CSS, and graphics
4. responding to support and feedback emails
5. writing a blog post explaining some aspect of the site engine or philosophy
6. being customers of our own sites, asking our own programming questions and sysadmin questions
7. interacting with the community on our dedicated meta-discussion site to help gauge what we should be working on, and where the rough edges are that need polishing
8. electing community moderators and building moderation tools so the community can police and regulate itself as it scales
9. producing Creative Commons dumps of our user-contributed questions and answers
10. coming up with schemes for responsible advertising so we can all make a living
11. producing the Stack Overflow podcast with Joel
12. helping set up logistics for the Stack Overflow DevDays conferences
13. setting up the next site in the trilogy, and figuring out where we go next As programmers, as much as we might want to believe thatlots_of_awesome_code = success;

---

There's nothing particularly magical about the production of source code. In fact, writing code is a tiny proportion of what makes most businesses successful.
Code is meaningless if nobody knows about your product. Code is meaningless if the IRS comes and throws you in jail because you didn't do your taxes. Code is meaningless if you get sued because you didn't bother having a software license created by a lawyer.
Writing code is trivial. And fun. And something I continue to love doing. But if you really want your code to be successful, you'll stop coding long enough to do all that other, even more trivial stuff around the code that's necessary to make it successful.

* Although, to be fair, I really could write Twitter in a week. It's so ridiculously simple! Come on!
