#!/bin/bash
# by: muzi
# use: build and deploy pubic to github and vps
# date: 2019-11-21

set -eo pipefail
INPUT=$1
INPUT=${INPUT:=deploy}
PICS_URL="https://p.k8s.li"
DATA=$(TZ=UTC-8 date +"%Y-%m-%d-%H:%M")
WORKDIR=$(cd $(dirname "${BASH_SOURCE}") && pwd -P)
POST_DIR=${WORKDIR}/source/_posts
PUBLIC_DIR=${WORKDIR}/public
PUBLIC_REPO_DIR=/var/www/muzi502.github.io

make_public() {
    cd ${POST_DIR}
    rename 's/([12]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])-)//' *.md
    cd ${WORKDIR}
    rm -rf db.json public/*
    hexo clean && hexo g
    rm -rf  ${POST_DIR}
    git checkout ${POST_DIR}
    find ${PUBLIC_DIR} -name '*.html' -type f -print0 | xargs -0 sed -i '/^[[:space:]]*$/d'
    sed -i '/muzi.disqus.com/d' ${PUBLIC_DIR}/index.html
}

push_public() {
    cp -rf ${PUBLIC_DIR}/* ${PUBLIC_REPO_DIR}
    cd ${PUBLIC_REPO_DIR}
    # find . -type f  -name "*.html" | xargs -L1 -P 16 sed -i "s|p.k8s.li|cdn.jsdelivr.net/gh/muzi502/pics|"
    git add .
    git commit -am "chore(*): update post ${DATA}"
    git push origin master -f
}

fix_pics_url() {
    find ${POST_DIR} -type f -name "*.md" | xargs -L1 -P 16 sed -i -e "s#./img/#${PICS_URL}/#g;s#img/#${PICS_URL}/#g"
}

push_post() {
    fix_pics_url
    git commit -am "chore(*): update post pics url"
    git push origin master -f
}
case $INPUT in
    deploy )
        make_public
        push_public
    ;;
    push )
        push_post
    ;;
esac
