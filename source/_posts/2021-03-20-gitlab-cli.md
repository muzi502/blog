---
title: python-gitlab CLI 使用记录
date: 2021-03-23
updated: 2021-03-20
slug:
categories: 技术
tag:
  - ci
  - gitlab
copyright: true
comment: true
---

## 开倒车 🚗 ？

年后这几周花了两周左右的时间将我司的 GitHub 代码迁移到内部的 Gitlab。影响最大的就是我们产品的发布流水线，需要适配 Gitlab 和内网环境的一些服务。基本上整个产品打包发布的流水线代码全部重写了一遍，可累坏咱了🥺。当时心里还认为代码迁移至 Gitlab 纯属倒车行为😅，不过等到所有的适配修改完毕后忽然发现 Gitlab 真香！

归根结底内网的 Gitlab 网络状况十倍百倍与 GitHub 不止。众所周知在学习**墙国**，GitHub 直连的速度和稳定性差的一批。也正因此之前在 GitHub 上的流水线经常会被网络抖动所干扰，有时侯 fetch 一个 repo 十几二十分钟！迁移到内网 Gitlab 之后，那速度简直飞起！以往最少十几分钟的流水线现在只需要不到五分钟就能完成😂。

于是今天就写篇博客记录一下当时折腾 Gitlab 时收获的一点人生经验👓

> 我今天是作为一个长者给你们讲的，我不是新闻工作者，但是我见得太多了，我有这个必要告诉你们一点人生的经验

## Gitlab

在折腾的过程中使用到的有关 Gitlab 的文档和工具：

- [Gitlab workflow](https://about.gitlab.com/topics/version-control/what-is-gitlab-workflow/)：了解一下 Gitlab 的工作流，不同于 GitHub 的 PR，在 Gitlab 中使用的是 MR 的方式；
- [Gitlab API](https://docs.gitlab.com/ee/api/README.html)：Gitlab API 的官方文档，了解它在使用下下面这些工具时候会得心应手。
- [python-gitlab](https://python-gitlab.readthedocs.io/en/stable/api-objects.html) API client：使用 Python 实现的 Gitlab API client，用它来完成一些特定需求工具的开发，比如根据 tag 或者 branch获取 repo 中指定的文件或目录；
- [python-gitlab](https://python-gitlab.readthedocs.io/) CLI：基于 [python-gitlab](https://python-gitlab.readthedocs.io/en/stable/api-objects.html) API client 封装成的命令行工具，因为是 CLI 工具所以可以很方便地集成在一些流水线的脚本中；
- [go-gitlab](https://github.com/xanzy/go-gitlab) API client：使用 Golang 实现的 Gitlab API client。由于发布流水线中的一个阶段就是根据一个 list 来收集其他 repo 中的特定文件和目录，使用的工具是 golang 写的，为了减少代码修改量就使用了 go-gitlab 而不是 python-gitlab。

## [Gitlab workflow](https://about.gitlab.com/topics/version-control/what-is-gitlab-workflow/)

### PR

在 GitHub 上我们一般使用 PR 的方式来完成代码合并工作，流程如下：

- 成员 Fork 原始仓库，将 Fork 出来的仓库 clone 到本地
- 在本地创建新分支，并基于新分支进行修改和提交，推送新分支到 Fork 的仓库
- 基于 Fork 仓库中的新分支向原始仓库的目标分支发起 Pull Request
- 在 PR 的评论中 @ 审查者，请求 review 修改
- 审查者收到请求邮件，审查代码，并在建议处直接做出评论
- 提交者根据建议，继续提交改动，并对意见作出回应
- 审查者无异议后，在 PR 的评论中 @ 管理员，请求合入代码，管理员接受 PR，代码合入主分支

### MR

但是到了 Gitlab 之后我们就使用 MR 的方式来完成代码合并工作，流程如下：

- 成员 Clone 原始仓库到本地，基于要修改的分支，创建新的分支
- 本地修改和提交，推送新分支到原始仓库
- 在原始仓库中基于新分支向目标保护分支发起 Merge Request
- 审核者 review 代码，管理员 Merge 代码

相比来讲 MR 和方式更适合团队内部的协作开发，PR 的方式适合开源项目的协作开发。

## [Gitlab](https://docs.gitlab.com/ee/api/README.html) API

> The main GitLab API is a [REST](http://spec.openapis.org/oas/v3.0.3) API. Because of this, the documentation in this section assumes that you’re familiar with REST concepts.

参照官方文档 [API resources](https://docs.gitlab.com/ee/api/api_resources.html) 可知，共有 Projects 、Groups、Standalone 这三种 API 分组。

- Projects： 对应的就是与 repo 相关的 API ，比如 tag、commit、branch 、MR、Issue 这一类型；
- Groups： 对应类似于 GitHub 上的 Organizations，一般来讲公司里的 repo 都会按照团队来划分组织，同一团队里的 repo 会放在 gitlab 同一个 Groups  下，而不是以个人为单位存放 repo；
- Standalone：则是除了 Projects 和 Groups 之外的 API 资源，如 user

而我们多数情况下使用的是 Projects 相关的 API，通过它来对 repo 进行增删改查。简单介绍完 Gitlab API 类型之后，本文会介绍几种使用 Gitlab API 的工具。在使用这些工具的过程中，如果遇到一些错误可以通过 [Status codes](https://docs.gitlab.com/ee/api/README.html#status-codes) API 返回状态码来排查问题。

## [python-gitlab](https://python-gitlab.readthedocs.io/) CLI

这是一个使用 [python-gitlab](https://python-gitlab.readthedocs.io/en/stable/api-objects.html) API client 封装好的 gitlab 命令行工具，可以使用它来完成绝大多数 Gitlab API 所支持的操作。因为之前的流水线中有很多操作是访问的 GitHub，比如提交 PR、获取 repo tag、查看 PR labels 等，都是写在 Jenkinsfile 调用各种脚本和工具来完成的。 切换到了 Gitlab，自然也需要一个工具来完成上述操作了。那么 python-gitlab CLI 这个工具无疑是不二之选，甚至比之前的工具更方便。因为迄今为止还没有见到过 GitHub 能有像 python-gitlab 这样的工具。总之，对于使用 Gitlab 的人来讲，要对 repo 完成一些自动化处理的工作，强烈推荐使用这个 CLI 工具，它可以很方便地集成在流水线中。

### 安装

python-gitlab CLI 依赖 Python 2.7 或者 3.4+，2021 年啦，就不要使用 Python2.7 啦😊。本地安装好 python3 和 pip3 后使用如下命令安装即可。

```bash
# 在这里使用清华的 pypi 源来加速安装，毕竟是墙🧱国
$ sudo pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple requests PyYAML python-gitlab
```

由于使用这个工具的场景大多数是在 Jenkins 所创建的 slave pod 中执行的，所以也可以构建一个 docker 镜像， `Dockerfile` 如下

```dockerfile
FROM debian:buster
RUN apt update \
    && apt install -y --no-install-recommends \
        git \
        python3 \
        python3-pip \
        jq \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple requests PyYAML python-gitlab

COPY python-gitlab.cfg /etc/python-gitlab.cfg
```

### 配置

Gitlab CLI 工具需要使用一个 `python-gitlab.cfg` 配置文件用于连接 Gitlab 服务器以及完成一些鉴权认证，配置文件格式为 `ini` 如下：

```ini
[global]
default = gitlab.com
ssl_verify = true
timeout = 5
per_page = 100
api_version = 4

[gitlab.com]
url = https://gitlab.com
private_token = xxxxxxxxx
```

- 全局的连接参数

| Option        | Possible values   | Description                                                  |
| ------------- | ----------------- | ------------------------------------------------------------ |
| `ssl_verify`  | `True` 或 `False` | 是否开启 SSL 加密验证                                        |
| `timeout`     | 证书              | 连接超时时间                                                 |
| `api_version` | `4`               | API 的版本，默认为 4 即可，参考 [API V3 to API V4](https://docs.gitlab.com/ee/api/v3_to_v4.html) |
| `per_page`    | 1 ～ 100          | 每次返回的元素数量，Gitlab 的最大限制为 100。可以通过 `--all` 参数获取所有的元素 |

- 自定义 GitLab server 参数

| Option          | Description                                                  |
| --------------- | ------------------------------------------------------------ |
| `url`           | GitLab server 的 URL                                         |
| `private_token` | 通过访问 gitlab 服务器的 [-/profile/personal_access_tokens](https://gitlab.com/-/profile/personal_access_tokens) 来生成 token |
| `oauth_token`   |                                                              |
| `job_token`     |                                                              |
| `api_version`   | API 的版本，默认为 4 即可，也可以不用定义，使用全局参数      |
| `http_username` | Gitlab 用户名，不推荐使用它来连接 Gitlab 服务器              |
| `http_password` | Gitlab 密码，不推荐使用它来连接 Gitlab 服务器                |

将文件保存在 `~/.python-gitlab.cfg` 或者 `/etc/python-gitlab.cfg` ，也可以使用环境变量 `PYTHON_GITLAB_CFG` 或者 `--config-file` 执行配置文件的路径，为了省事儿还是将它放到 `~/.python-gitlab.cfg` 下。

配置完成之后，可以使用 `gitlab current-user get` 命令测试连接是否正常，如果有返回值且正确的用户名说明配置成功了。

```bash
$ gitlab current-user get
username: muzi502
```

### 基本使用

gitlab 命令行工具主要是对 Gitlab 服务器上的各种对象如：user, project, file, repo, mr, tag, commit 等进行增删改查(get、list、create、delete、update)。使用的命令行格式方式如下：

```bash
$ gitlab <option> [object] [action] <option>
```

一般来讲只需要 4 种参数：

- 第一个参数是紧接着 gitlab 命令后面的参数，它是 gitlab 命令行的输出参数和配置参数，如 `-o `参数指定输出结果的格式；`-f` 参数将输出结果存放到文件中; `-g` 参数执行连接哪个 Gitlab 服务器。

- 第二个参数则是用来指定所要操作的对象，比如 project-merge-request，project-tag 等，所支持的对象有很多，基本上涵盖了所有 Gitlab API 所支持的操作对象，如下：

```json
$ gitlab -h
usage: gitlab [-h] [--version] [-v] [-d] [-c CONFIG_FILE] [-g GITLAB] [-o {json,legacy,yaml}] [-f FIELDS]
{application,application-appearance,application-settings,audit-event,broadcast-message,current-user,current-user-email,current-user-gp-gkey,current-user-key,current-user-status,deploy-key,deploy-token,dockerfile,event,feature,geo-node,gitignore,gitlabciyml,group,group-access-request,group-badge,group-board,group-board-list,group-cluster,group-custom-attribute,group-deploy-token,group-epic,group-epic-issue,group-epic-resource-label-event,group-export,group-import,group-issue,group-label,group-member,group-merge-request,group-milestone,group-notification-settings,group-package,group-project,group-runner,group-subgroup,group-variable,hook,issue,l-da-pgroup,license,merge-request,namespace,notification-settings,pages-domain,project,project-access-request,project-additional-statistics,project-approval,project-approval-rule,project-badge,project-board,project-board-list,project-branch,project-cluster,project-commit,project-commit-comment,project-commit-discussion,project-commit-discussion-note,project-commit-status,project-custom-attribute,project-deploy-token,project-deployment,project-environment,project-event,project-export,project-file,project-fork,project-hook,project-import,project-issue,project-issue-award-emoji,project-issue-discussion,project-issue-discussion-note,project-issue-link,project-issue-note,project-issue-note-award-emoji,project-issue-resource-label-event,project-issue-resource-milestone-event,project-issues-statistics,project-job,project-key,project-label,project-member,project-merge-request,project-merge-request-approval,project-merge-request-approval-rule,project-merge-request-award-emoji,project-merge-request-diff,project-merge-request-discussion,project-merge-request-discussion-note,project-merge-request-note,project-merge-request-note-award-emoji,project-merge-request-resource-label-event,project-merge-request-resource-milestone-event,project-milestone,project-note,project-notification-settings,project-package,project-pages-domain,project-pipeline,project-pipeline-bridge,project-pipeline-job,project-pipeline-schedule,project-pipeline-schedule-variable,project-pipeline-variable,project-protected-branch,project-protected-tag,project-push-rules,project-registry-repository,project-registry-tag,project-release,project-remote-mirror,project-runner,project-service,project-snippet,project-snippet-award-emoji,project-snippet-discussion,project-snippet-discussion-note,project-snippet-note,project-snippet-note-award-emoji,project-tag,project-trigger,project-user,project-variable,project-wiki,runner,runner-job,snippet,todo,user,user-activities,user-custom-attribute,user-email,user-event,user-gp-gkey,user-impersonation-token,user-key,user-membership,user-project,user-status,variable}
```

- 第三个参数则是 action 参数，即用于指定对所操作的对象进行何种操作，一般来讲都会支持增删改查操作（get, list, create, update, delete）

```bash
$ gitlab project-tag
usage: gitlab project-tag [-h] {list,get,create,delete,set-release-description} ...
```

- 第三个参数则是 object + action 所依赖的参数，比如指定 project id

```bash
$ gitlab project-tag list
usage: gitlab project-tag list --project-id PROJECT_ID [--page PAGE] [--per-page PER_PAGE] [--all]
gitlab project-tag list: error: the following arguments are required: --project-id
```

- Project-ID：是 gitlab 上唯一表示该 repo 的 ID，可分为两种，一种是 `group/project` 的形式，其中 `/` 要转译成 `%2F` 如：`muzi502%2Fkubespray`；另一种则是数字的形式，在该 repo 的 web 页面上可以看到，推荐使用第二种。

  ![image-20210319085926423](https://p.k8s.li/image-20210319085926423.png)

```bash
# 也可以使用gitlab 命令获取 repo 的 id
$ gitlab project get --id muzi502%2Fkubespray
id: 25099880
path: kubespray
```

- 在流水线中可以根据 token 获取用户的用户名和邮箱，用于配置流水线中的 repo git 信息，避免因为 CLA 无法通过。

```shell
gitlab -o json current-user get | jq '.id'
git config --global user.email $(gitlab -o json current-user get | jq -r '.email')
git config --global user.name $(gitlab -o json current-user get | jq -r '.username')
```

### project

- 获取 repo ssh url  地址

由于 Jenkins 流水线中 clone 的 repo url 是使用 token+ https 的方式，在流水线中如果要 push 代码到 repo 需要修改为 ssh 的方式，可使用如下方式根据 project id 来获取该 repo 的 ssh url。

```bash
$ gitlab -o json  project get --id ${PROJECT_ID} | jq -r '.ssh_url_to_repo'
$ git remote remove origin
$ git remote add origin $(gitlab -o json  project get --id ${PROJECT_ID} | jq -r '.ssh_url_to_repo')
```

### file

对于 repo 中文件的操作使用 project-file

```bash
$ gitlab project-file
usage: gitlab project-file [-h] {get,create,update,delete,raw,blame} ...
```

- 获取文件，通过 `project-file` 对象的 get 操作

```bash
$ gitlab -o json project-file get --project-id ${PROJECT_ID} --file-path .gitignore --ref master  | jq '.'
{
  "file_name": ".gitignore",
  "file_path": ".gitignore",
  "size": 1208,
  "encoding": "base64",
  "content_sha256": "91f1d50ba3a4f79f96d9371afc70b389f75dfb2ac5190b8fb01051aa8679fd04",
  "ref": "master",
  "blob_id": "b09ca9d3b101034c7e34430177c1d64738df5fbb",
  "commit_id": "a9c97e5253c455546c2c7fdd794147eeb9b8ab7a",
  "last_commit_id": "4ffc106c58fc5865b6d72a52365e25b8c268d4d8",
  "content": "LnZhZ3JhbnQKKi5yZXRyeQoqKi92YWdyYW50X2Fuc2libGVfaW52ZW50b3J5CiouaW1sCnRlbXAKLmlkZWEKLnRveAouY2FjaGUKKi5iYWsKKi50ZnN0YXRlCioudGZzdGF0ZS5iYWNrdXAKLnRlcnJhZm9ybS8KY29udHJpYi90ZXJyYWZvcm0vYXdzL2NyZWRlbnRpYWxzLnRmdmFycwovc3NoLWJhc3Rpb24uY29uZgoqKi8qLnN3W3Bvbl0KKn4KdmFncmFudC8KcGx1Z2lucy9taXRvZ2VuCgojIEFuc2libGUgaW52ZW50b3J5CmludmVudG9yeS8qCiFpbnZlbnRvcnkvbG9jYWwKIWludmVudG9yeS9zYW1wbGUKaW52ZW50b3J5LyovYXJ0aWZhY3RzLwoKIyBCeXRlLWNvbXBpbGVkIC8gb3B0aW1pemVkIC8gRExMIGZpbGVzCl9fcHljYWNoZV9fLwoqLnB5W2NvZF0KKiRweS5jbGFzcwoKIyBEaXN0cmlidXRpb24gLyBwYWNrYWdpbmcKLlB5dGhvbgplbnYvCmJ1aWxkLwpjcmVkZW50aWFscy8KZGV2ZWxvcC1lZ2dzLwpkaXN0Lwpkb3dubG9hZHMvCmVnZ3MvCi5lZ2dzLwpwYXJ0cy8Kc2Rpc3QvCnZhci8KKi5lZ2ctaW5mby8KLmluc3RhbGxlZC5jZmcKKi5lZ2cKCiMgUHlJbnN0YWxsZXIKIyAgVXN1YWxseSB0aGVzZSBmaWxlcyBhcmUgd3JpdHRlbiBieSBhIHB5dGhvbiBzY3JpcHQgZnJvbSBhIHRlbXBsYXRlCiMgIGJlZm9yZSBQeUluc3RhbGxlciBidWlsZHMgdGhlIGV4ZSwgc28gYXMgdG8gaW5qZWN0IGRhdGUvb3RoZXIgaW5mb3MgaW50byBpdC4KKi5tYW5pZmVzdAoqLnNwZWMKCiMgSW5zdGFsbGVyIGxvZ3MKcGlwLWxvZy50eHQKcGlwLWRlbGV0ZS10aGlzLWRpcmVjdG9yeS50eHQKCiMgVW5pdCB0ZXN0IC8gY292ZXJhZ2UgcmVwb3J0cwpodG1sY292LwoudG94LwouY292ZXJhZ2UKLmNvdmVyYWdlLioKLmNhY2hlCm5vc2V0ZXN0cy54bWwKY292ZXJhZ2UueG1sCiosY292ZXIKLmh5cG90aGVzaXMvCgojIFRyYW5zbGF0aW9ucwoqLm1vCioucG90CgojIERqYW5nbyBzdHVmZjoKKi5sb2cKbG9jYWxfc2V0dGluZ3MucHkKCiMgRmxhc2sgc3R1ZmY6Cmluc3RhbmNlLwoud2ViYXNzZXRzLWNhY2hlCgojIFNjcmFweSBzdHVmZjoKLnNjcmFweQoKIyBTcGhpbnggZG9jdW1lbnRhdGlvbgpkb2NzL19idWlsZC8KCiMgUHlCdWlsZGVyCnRhcmdldC8KCiMgSVB5dGhvbiBOb3RlYm9vawouaXB5bmJfY2hlY2twb2ludHMKCiMgcHllbnYKLnB5dGhvbi12ZXJzaW9uCgojIGRvdGVudgouZW52CgojIHZpcnR1YWxlbnYKdmVudi8KRU5WLwo="
}

# 文件内容是 base64 编码的，需要使用 base64 解码才能获取原始的内容。
$ gitlab -g gitlab -o json project-file get --project-id 25099880 --file-path .gitignore --ref master  | jq -r '.content' | base64 -d
.vagrant
*.retry
**/vagrant_ansible_inventory
*.iml
temp
.idea
.tox
…………
```

- 通过 project-file 的 raw 方法可以获取文件的原始内容，无须 base64 解码

```bash
$ gitlab project-file get --project-id ${PROJECT_ID} --file-path .gitignore --ref master
```

- 创建文件，对文件的增删改都是通过提交 commit 来完成的，因此需要指定所要操作的分支以及 commit-message 的信息。另外如果操作的文件是 master 分支获取其他保护分支，要确保当前用户有写入的权限，不然会提示如下错误：

  ```bash
  gitlab project-file update
  Impossible to update object (400: You are not allowed to push into this branch)
  ```

之前在 GitHub 上有一套 CI 并不能适用于 Gitlab，因此需要为所有的分支创建 CI 流水线，用于检查代码是否符合规范，可以通过如下方法批量量地向所有分支创建文件。

```bash
ID=123456
BRANCHS=$(gitlab -o json project-branch list --project-id ${ID} --all | jq -r ".[].name")
for branch in ${BRANCHS}; do
	gitlab project-file create --project-id ${ID} --file-path .gitlab-ci.yml --branch ${branch} --content @.gitlab-ci.yml --commit-message "feat(gitlab-ci): add gitlab-ci.yml for ci"
done
```

- 更新文件

比如批量更新所有分支的 `Makefile` 中 `github.com` 为 `gitlab.com`

```bash
ID=123456
BRANCHS=$(gitlab -o json project-branch list --project-id ${ID} --all | jq -r ".[].name")
for branch in ${BRANCHS}; do
    rm -f Makefile Makefile-
    gitlab project-file raw --project-id ${ID} --file-path Makefile --ref ${branch} > Makefile
    sed -i- "s|github.com/muzi502|gitlab.com/muzi502" Makefile
    gitlab project-file update --project-id ${ID} --file-path Makefile --branch ${branch} --content @Makefile \
    --commit-message "chore(Makefile): update repo url in Makefile for migrate gitlab"
done
```

- 删除文件

```bash
$ gitlab project-file delete --project-id ${PROJECT_ID} --file-path .gitignore --ref master \
--commit-message "test delete file"
```

### MR

- 创建 MR，指定 source branch 和 target branch 以及 mr 的 title 这三个参数。前面最好加上 -o json 参数用户获取 mr 的 iid，可通过此 iid 来对这个 mr 进行增删改查。

```bash
$ gitlab -o json project-merge-request create --project-id ${PROJECT_ID} --source-branch --target-branch ${BASE_BRANCH} --title "${MR_TITLE}"
```

通过 -o json 参数会返回此 mr 的信息，其中 `iid` 就是该 mr 在此 repo 中的唯一标示

```json
$ gitlab -g gitlab -o json project-merge-request create --project-id 25099880 --source-branch release-2.14 --target-branch  master --title "mr create test"
{
  "id": 92872102,
  "iid": 1,
  "project_id": 25099880,
  "title": "mr create test",
  "description": null,
  "state": "opened",
  "created_at": "2021-03-21T12:42:52.893Z",
  "updated_at": "2021-03-21T12:42:52.893Z",
  "merged_by": null,
  "merged_at": null,
  "closed_by": null,
  "closed_at": null,
  "target_branch": "master",
  "source_branch": "release-2.14",
  "user_notes_count": 0,
  "upvotes": 0,
  "downvotes": 0,
  "author": {
    "id": 5599205,
    "name": "muzi502",
    "username": "muzi502",
    "state": "active",
    "avatar_url": "https://secure.gravatar.com/avatar/f91578ffea9a538eedd8fbaf3007289b?s=80&d=identicon",
    "web_url": "https://gitlab.com/muzi502"
  }
```

- 合并 MR

```bash
$ gitlab project-merge-request merge --project-id ${PROJECT_ID} --iid @mr_iid
```

- 查看 MR 状态

```bash
$ gitlab -o json project-merge-request get --project-id ${PROJECT_ID} --iid @mr_iid | jq -r ".state"
```

- 集成在 Jenkinsfile  中完成创建 MR、合并 MR、检查 MR

调用用它的时候只需要传入 SOURCE_BRANCH, TARGET_BRANCH, MR_TITLE 这三个参数即可。

```bash
def makeMR(SOURCE_BRANCH, TARGET_BRANCH, MR_TITLE) {
    container("debian") {
        sh """
        gitlab -o json project-merge-request create --project-id ${PROJECT_ID}  --title \"${MR_TITLE}\" \
        --source-branch ${SOURCE_BRANCH} --target-branch ${TARGET_BRANCH} > mr_info.json

        jq -r '.iid' mr_info.json > mr_iid
        jq -r '.web_url' mr_info.json > mr_url
        """
    }
}

def checkMR() {
    container("debian") {
        retry(120) {
        sh """
        if [ ! -s mr_iid ]; then exit 0; else sleep 60s; fi
        gitlab -o json project-merge-request get --project-id ${PROJECT_ID} --iid @mr_iid | jq -r ".labels[]" | grep 'approve'
        """
        }
    }
}

def mergeMR(){
    container("debian") {
        retry(10){
        sh """
        if [ ! -s mr_iid ]; then exit 0; else sleep 60s; fi
        if gitlab project-merge-request merge --project-id ${PROJECT_ID} --iid @mr_iid; then sleep 10s; fi
        gitlab -o json project-merge-request get --project-id ${PROJECT_ID} --iid @mr_iid | jq -r ".state" | grep 'merged'
        """
        }
    }
}
```

### Tag

- 列出 repo tag

在这里还是推荐使用 git tag 的方式获取 repo tag ，因为 Gitlab API 的限制，每次请求最多只能返回 100 个值，可以加上 `--all` 参数来返回所有的值。

```bash
$ gitlab -o json project-tag list --project-id ${ID} | jq -r '.[].name'
$ gitlab -o json project-tag list --project-id ${ID} --all | jq -r '.[].name'
```

- 创建 tag

```bash
$ gitlab project-tag create --project-id ${ID} --tag-name v1.0.0-rc.2 --ref master
```

- 删除 tag

upstream 上的 repo tag 只能通过在 Gitlab 上删除，在本地 repo 下是无法删除的，因此可以使用如下命令删除  Gitlab repo tag，注意：受保护的 repo tag 如果没有权限的话是无法删除的。

```bash
$ gitlab project-tag delete --project-id ${ID} --tag-name v1.0.0-rc.2
```

- 创建受保护的 repo tag

由于我们流水线任务依赖于 repo tag 来做版本的对于，因此需要保护每一个 repo tag，但有特殊情况下又要覆盖 repo tag，所以受保护的 repo tag 目前还没有找到合适的方法，只能先手动创建了，等到需要删除的时候再删除它。可以使用如下命令批量创建受保护的 repo tag。

```bash
$ git tag | xargs -L1 -I {} gitlab project-protected-tag create --project-id ${ID} --name {}
```

## Lint 流水线

迁移到了 Gitlab 之后原有的流水线在内网的 Gitlab 上也就无法使用了，为了减少维护成本就使用了 Gitlab 自带的 CI 。我所维护的 repo 使用 Gitlab CI 只是做一些 lint 的检查内容，因此 CI 配置起来也特别简单。如 kubespray 的 CI 配置：

- `.gitlab-ci.yml`

```yaml
---
lint:
  image: 'quay.io/kubespray/kubespray:v2.15.0'
  script:
    - chmod -R o-w .
    - make lint
  tags:
    - shared
```

- 使用 gitlab CLI 工具给所有分支添加 `.gitlab-ci.yml` 文件

```bash
ID=123456
BRANCHS=$(gitlab -o json project-branch list --project-id ${ID} --all | jq -r ".[].name")
for branch in ${BRANCHS}; do
	gitlab project-file create --project-id ${ID} --file-path .gitlab-ci.yml --branch ${branch} --content @.gitlab-ci.yml --commit-message "feat(gitlab-ci): add gitlab-ci.yml for ci"
done
```

## 其他

- repo 迁移

由于内部的 Gitlab 不支持导入 git url 的方式，所以只能手动地将 GitHub 上的 repo clone 到本地再 push 到 Gitlab 上。使用 git clone 的方式本地只会有一个 master 分支，要把 GitHub 上 repo 的所有分支都 track 一遍，然后再 push 到 Gitlab 上。

```bash
# 使用 git clone 下来的 repo 默认为 master 分支
$ git clone git@gitlab.com/muzi502/kubespray.git
# track 出 origin 上的所有分支
$ git branch -r | grep -v '\->' | while read remote; do git branch --track "${remote#origin/}" "$remote"; done
$ git fetch --all
$ git pull --all
$ git remote remove origin
$ git remote add origin git@gitlab/gitlab502/kubespray.git
$ git push origin --all
```

## 参考

- [How to fetch all Git branches](https://stackoverflow.com/questions/10312521/how-to-fetch-all-git-branches)
- [GitLab 工作流](https://yixinglu.gitlab.io/gitlab-workflow.html)
- [python-gitlab](https://python-gitlab.readthedocs.io/)
- [Gitlab API Docs](https://docs.gitlab.com/ee/api/README.html)
- [go-gitlab](https://github.com/xanzy/go-gitlab)
- [谈谈 Git 存储原理及相关实现](https://mp.weixin.qq.com/s/x5PHNn87OYCSpYE_hb8I2A)
- [Git解密——认识Git引用](https://morningspace.github.io/tech/inside-git-3/)
- [GitLab CI/CD 介绍和使用](https://blinkfox.github.io/2018/11/22/ruan-jian-gong-ju/devops/gitlab-ci-jie-shao-he-shi-yong/)
