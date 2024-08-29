#!/bin/bash

#GOAL: Upload tagged releases of Quattor template-library-core to a git
#      repo in order to simplify later import into the VUB-HPC Quattor
#      workspace.

urlstart='git@github.com:StephaneGerardVUB'
repo='q_tpl_core_lib'
tag=$(date +%Y%m%d%H%M)
pompath='src/configuration-modules-core/pom.xml'
version=$(grep 'SNAPSHOT' $pompath | sed -e 's/version//g' | sed -e 's/[<>/ ]//g')

[ -d $repo ] && rm -rf $repo
git clone ${urlstart}/${repo}.git
cd $repo
cp -R ../src/template-library-core/* ./
git add -A .
git commit -m"release ${version} tag ${tag}"
git tag -m"release ${version} tag ${tag}" "${version}-${tag}"
git push origin --tags HEAD
