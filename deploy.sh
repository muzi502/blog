#!/bin/bash
# by: muzi
# use: build and deploy pubic to github and vps
# date: 2019-11-21

set -eo
date=$(TZ=UTC-8 date +"%Y-%m-%d-%H:%M")
hexo_dir=/var/www/hexo
post_dir=${hexo_dir}/source/_posts
public_dir=${hexo_dir}/public
github_dir=/var/www/muzi502.github.io

cd ${post_dir}
rename 's/([12]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])-)//' *.md

cd ${hexo_dir}
rm -rf db.json public/*
hexo g
rm -rf  ${post_dir}
git checkout ${post_dir}
find ${public_dir} -name '*.html' -type f -print0 | xargs -0 sed -i '/^[[:space:]]*$/d'
sed -i '/muzi.disqus.com/d' ${public_dir}/index.html


cp -rf ${public_dir}/* ${github_dir}/
cd /var/www/muzi502.github.io

find . -type f  -name "*.html" | xargs -L1 -P 16 sed -i "s|blog.k8s.li/img/|cdn.jsdelivr.net/gh/muzi502/muzi502.github.io/img/|"

git add .
git commit -am "update ${date}"
git push origin master
