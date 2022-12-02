#!/bin/bash

#GOAL: To import a new release of template-library-core
#      in the HPC-VUB Quattor workspace.

repo='q_tpl_core_lib'
giturl="https://github.com/StephaneGerardVUB/${repo}.git"
coreroot="$HOME/git/HPC_quattor/cfg/upstream"

function echo_error {
  echo -e "\033[1;31mERROR\033[0m  $1"
}

[ ! -z $repo ] && [ -d /tmp/$repo ] && rm -rf /tmp/$repo
cd /tmp
git clone $giturl
if [ $? -ne 0 ]; then
    echo_error 'git clone failed!'
    exit 1
fi
cd $repo
taglist=$(git tag)
tagarr=($taglist)
cpt=0
for tag in $taglist; do
    echo "$cpt) $tag"
    ((cpt+=1))
done
echo 'Choose a tag:'
read choice
echo you have chosen ${tagarr[$choice]}
tag=${tagarr[$choice]}
release=$(echo $tag |cut -d'-' -f1)
git checkout tags/$tag
coredest="$coreroot/$release/core"
mkdir -p $coredest
if [ $? -ne 0 ]; then
    echo_error "Could not create $coredest directory!"
    exit 1
fi
cp -R ./* $coredest/
rm -rf /tmp/$repo


