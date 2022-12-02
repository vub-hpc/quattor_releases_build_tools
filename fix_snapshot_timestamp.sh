#!/bin/bash

rootdir=$(dirname $(readlink -f "$0"))
pkgsdir="${rootdir}/target/21.12.1-SNAPSHOT"
tplaiirootdir="${rootdir}/src/template-library-core/quattor/aii"
tplncmrootdir="${rootdir}/src/template-library-core/components"
pkgslst=$(ls "$pkgsdir/" |grep -e '\.rpm$' )
for pkg in $pkgslst; do
    if [[ $pkg =~ ^aii- ]] || [[ $pkg =~ ^ncm- ]];then
        str1=$(echo $pkg|cut -d'-' -f1)
        str2=$(echo $pkg|cut -d'-' -f2)
        pkgname="$str1-$str2"
        echo $pkgname
        timestamp=$(echo $pkg|sed -E 's/.*SNAPSHOT([0-9]+).*/\1/')
        ficlist=()
        if [[ $str1 == 'aii' ]]; then
            ficlist=$(egrep -l -R -e 'SNAPSHOT[0-9]{14}' ${tplaiirootdir}/${str2}/*)
        fi
        if [[ $str1 == 'ncm' ]];then
            ficlist=$(egrep -l -R -e 'SNAPSHOT[0-9]{14}' ${tplncmrootdir}/${str2}/*)
        fi
        for fic in $ficlist; do
            sed -E -i "s/SNAPSHOT[0-9]{14}/SNAPSHOT${timestamp}/g" $fic
        done
    fi
done
