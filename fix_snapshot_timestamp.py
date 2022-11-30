#!/usr/bin/env python

import os
import re
import string
from os import listdir
from os.path import isfile, join

rootdir = os.getcwd()
pkgsdir = '%s/target/21.12.1-SNAPSHOT'%(rootdir)
tplaiirootdir = '%s/src/template-library-core/quattor/aii'%(rootdir)
tplncmrootdir = '%s/src/template-library-core/components'%(rootdir)

# build a dictionary with packages (key: pkg name, value: timestamp)
rpmslist = [f for f in listdir(pkgsdir) if isfile(join(pkgsdir, f)) and re.match('.*\.rpm$', f)]
rpmdict = {}
for rpm in rpmslist:
    parts = rpm.split('-')
    pkgname = ''
    snapts = ''
    for part in parts:
        if re.match('^SNAPSHOT', part):
            pieces = part.split('.')
            snapts = pieces[0]
            break
        if not re.match('^[0-9]', part):
            if pkgname == '':
                pkgname = part
            else:
                pkgname = pkgname + '-' + part
    rpmdict[pkgname] = snapts
#print(rpmdict)

# fix the aii and ncm-components templates
dirlist = [tplaiirootdir, tplncmrootdir]
for dir in dirlist:
    for root, dirs, files in os.walk(dir):
        for fic in files:
            if fic.endswith('.pan') or fic.endswith('.tpl'):
                ficpath = os.path.join(root, fic)
                print(ficpath)
                tofix = 0
                with open(ficpath) as f:
                    lines = f.readlines()
                    newlines = []
                    for line in lines:
                        if re.match('^#.*SNAPSHOT[0-9]{14}.*', line):
                            lineparts = line.split(',')
                            soft = lineparts[0][2:]
                            pkgname = 'aii-' + soft
                            if pkgname in rpmdict:
                                lineparts[2] = ' ' + rpmdict['aii-' + soft]
                                tofix = 1
                            newline = ','.join(lineparts)
                            newlines.append(newline)
                        elif re.match('.*pkg_repl\s*\(', line):
                            print(line)
                            found = re.findall('pkg_repl\s*\((.*)\)', line)
                            if found:
                                parts = found[0].split(',')
                                if len(parts) > 1:
                                    tostr = rpmdict[parts[0].strip('\"')]
                                    newline = re.sub(r'SNAPSHOT[0-9]{14}', tostr, line)
                                    tofix = 1
                                else:
                                    newline = line
                            print(newline)
                            newlines.append(newline)
                        else:
                            newlines.append(line)
                if tofix:
                    with open(ficpath, 'w') as f:
                        f.writelines(newlines)
