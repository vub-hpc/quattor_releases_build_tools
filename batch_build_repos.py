#!/usr/bin/env python

import os
from os import listdir
from os.path import isfile, join
import json
import subprocess
import argparse
import re
import string
from time import time

# This script works together with a json file that contains a dictionary
# where each key is the name of the Quattor repositories, and the corresponding
# value is again a dict that specifies the branch and the PRs to be applied during
# the maven-build process. The key 'toversion' gives the version string of the
# the release you want to build.

# Functions

def fix_snapshot_timestamp():

    rootdir = os.getcwd()
    # find the path of directory with RPMs
    tpath = os.path.join(rootdir, 'target')
    regex = '^\d[\d.]*-SNAPSHOT$'
    trpmdir = [join(tpath,d) for d in listdir(tpath) if isdir(join(tpath,d)) and re.match(regex,d)]
    if len(trpmdir) == 0:
        print('No suitable directory found in target!')
        exit(1)
    if len(trpmdir) > 1:
        print('More than one directory with RPMs -> Please make some cleanup!')
        exit(1)
    pkgsdir = trpmdir[0]
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
                                        pkgname = parts[0].strip('\"').strip('\'')
                                        if pkgname in rpmdict:
                                            tostr = rpmdict[pkgname]
                                            newline = re.sub(r'SNAPSHOT[0-9]{14}', tostr, line)
                                            tofix = 1
                                        else:
                                            newline = line
                                    else:
                                        newline = line
                                print(newline)
                                newlines.append(newline)
                            else:
                                newlines.append(line)
                    if tofix:
                        with open(ficpath, 'w') as f:
                            f.writelines(newlines)


# data to initialize tobuid.json file if it does not exist yet
repolist = ['aii', 'CAF', 'CCM', 'cdp-listend', 'configuration-modules-core',
            'configuration-modules-grid', 'LC', 'ncm-cdispd', 'ncm-ncd',
            'ncm-query', 'ncm-lib-blockdevices']
branch_def = 'master'
prs_def = []
toversion_def = '22.10.0-rc2'
data = {}
for repo in repolist:
    data[repo] = {}
    data[repo]['branch'] = branch_def
    data[repo]['prs'] = prs_def
    data[repo]['toversion'] = toversion_def

# generate a timestamp
ts = str(int(time()))

# process arguments
parser = argparse.ArgumentParser()
parser.add_argument('--init', help='Initialize the JSON file', action='store_true')
parser.add_argument('--edit', help='Edit the JSON file', action='store_true')
parser.add_argument('--repo', help='Name of the repo to edit in the JSON')
parser.add_argument('--allrepos', help='To edit all repositories', action='store_true')
parser.add_argument('--branch', help='Branch of the repo in the JSON')
parser.add_argument('--toversion', help='Version string to apply to products of the build process')
parser.add_argument('--addprs', help='To add a comma-seperated list of PRs to the branch in the JSON')
parser.add_argument('--delprs', help='To delete the list of PRs of a branch in the JSON', action='store_true')
parser.add_argument('--display', help='Show the content of the JSON file', action='store_true')
parser.add_argument('--delete', help='Delete a repo in the JSON file', action='store_true')
parser.add_argument('--build', help='Build the repositories', action='store_true')
parser.add_argument('--only', help='Names of the repos to build (comma seperated list)')
parser.add_argument('--ncmcomp', help='If you only want to compile a given ncm-component')
parser.add_argument('--ignore', help='Names of the repos to ignore (comma-seperated list)')
parser.add_argument('--collect', help='To create the repo for RPMs and the template libraries', action='store_true')
parser.add_argument('--upload', help='To copy to the right locations the template libraries and the RPMs', action='store_true')
args = parser.parse_args()

# examples of commands:
#   ./batch_build_repos.py --init
#   ./batch_build_repos.py --edit --repo aii --branch 21.12.0
#   ./batch_build_repos.py --edit --repo aii --delprs
#   ./batch_build_repos.py --edit --allrepos --toversion 22.10.0-rc2
#   ./batch_build_repos.py --delete --repo foobar
#   ./batch_build_repos.py --display
#   ./batch_build_repos.py --build
#   ./batch_build_repos.py --build --ignore foo,bar
#   ./batch_build_repos.py --build --onlyrepo foo,bar
#   ./batch_build_repos.py --build --ncmcomp ncm-opennebula
#   ./batch_build_repos.py --collect
#   ./batch_build_repos.py --upload

# check arguments (dependencies)
if (args.edit or args.init or args.display or args.delete) and (args.build or args.collect or args.upload):
    if args.build and (args.collect or args.upload):
        print("Options --build, --collect and --upload are mutually exclusive!")
        exit(1)
    else:
        print("Options --build or --collect or --upload can't be used with options that changes the json!")
        exit(1)
if args.edit:
    test = 0
    if args.repo and args.allrepos:
        print("Options --repo and --allrepos are mutually exclusive!")
        exit(1)
    if args.repo or args.allrepos:
        if args.branch or args.addprs or args.delprs or args.toversion:
            test = 1
        else:
            print("Missing branch (--branch) OR comma-seperated list of PRs (--addprs) OR --delpars flag")
            exit(1)
    else:
        print("With --edit flag, you must specify a repo with --repo or all with --allrepos")
        exit(1)
if args.delete:
    if not args.repo:
        print("Please specify the repo (--repo) you want to delete!")
        exit(1)

# initialize if asked to
if args.init:
    with open('tobuild.json', 'w') as f:
        json.dump(data, f)
    exit()

# load json into a dict
repos = {}
try:
    f = open('tobuild.json', 'r')
except IOError:
    print("Cannot open 'tobuild.json'. Use this command with --init flag to create this file.")
    exit(1)
else:
    repos = json.load(f)

# display content of json file if asked to
if args.display:
    for key1, value1 in repos.items():
        print(key1 + ':')
        for key2, value2 in value1.items():
            print("  " + key2 + ': ' + str(value2))
    exit()


# edit json if aksed to
if args.edit:
    if args.allrepos:
        if args.toversion:
            for repo in repos.keys():
                repos[repo]['toversion'] = args.toversion
        if args.branch:
            for repo in repos.keys():
                repos[repo]['branch'] = args.branch
    else:
        if not args.repo in repos:
            repos[args.repo] = {}
            repos[args.repo]['branch'] = branch_def
            repos[args.repo]['prs'] = prs_def
            repos[args.repo]['toversion'] = toversion_def
        if args.branch:
            repos[args.repo]['branch'] = args.branch
        if args.addprs:
            repos[args.repo]['prs'] += args.addprs.split(',')
        if args.delprs:
            repos[args.repo]['prs'] = []
    with open('tobuild.json', 'w') as f:
        json.dump(repos, f)
    exit()

# delete a repo if asked to
if args.delete:
    if not args.repo in repos:
        print("Repo '" + args.repo + "' does not exist!")
        exit(1)
    del repos[args.repo]
    with open('tobuild.json', 'w') as f:
        json.dump(repos, f)
    exit()


# building the repos (results: RPMs and PAN templates)
if args.build:

    # check arguments: options --ignore and --only are mutually exclusive
    if args.ignore and args.only:
        print("Options --ignore and --only are mutually exclusive!")
        exit(1)

    # create the empty logfile for output of build processes
    logfilename = 'build_' + ts + '.log'
    with open(logfilename, 'w'): pass

    # update of the lists of PRs (files named after the repo, used by builder.sh)
    prspath = 'prs'
    if not os.path.isdir(prspath):
        os.mkdir(prspath)
    for repo in repos.keys():
        prs_str = ''
        prs = repos[repo]['prs']
        for pr in prs:
            prs_str = prs_str + str(pr) + ' '
        namefic = os.path.join(prspath, repo)
        with open(namefic, 'w') as f:
            prs_str = prs_str[:-1]
            f.write(prs_str)

    # build the repos
    with open(logfilename, 'a') as f:
        # build list of repos to build
        repolst = []
        if args.only:
            repolst = args.only.split(',')
        elif args.ignore:
            repostoignore = args.ignore.split(',')
            repolst = [repo for repo in repos.keys() if repo not in repostoignore]
        else:
            repolst = repos.keys()

        for repo in repolst:
            f.write("\n" + repo + "\n\n")
            cmd = "./builder.sh " + repo + " " + repos[repo]['branch'] + " " + repos[repo]['toversion']
            if args.ncmcomp:
                cmd = cmd + " " + args.ncmcomp
            result = subprocess.Popen(cmd, shell=True)
            opt = result.communicate()[0]
            if opt:
                f.write(opt + "\n\n")
            exitcode = result.returncode
            if exitcode == 0:
                f.write('DONE')
            else:
                f.write('FAILED')

# collecting things to create the repo with the RPMs and the tpl libraries
if args.collect:
    cmd = "./collector.sh"
    result = subprocess.Popen(cmd, shell=True)
    opt = result.communicate()[0]
    if opt:
        print(opt)
    exitcode = result.returncode
    if exitcode == 0:
        print('DONE')
    else:
        print('FAILED')

# save the RPMs and the template library 'core'
if args.upload:
    # first fix any discrepency in snapshot timestamp
    fix_snapshot_timestamp()
    # this script will create a tag and push it to a git repo
    cmd = "./upload_tpllibcore.sh"
    result = subprocess.Popen(cmd, shell=True)
    opt = result.communicate()[0]
    if opt:
        print(opt)
    exitcode = result.returncode
    if exitcode == 0:
        print('DONE')
    else:
        print('FAILED')
    #TODO: copy the RPMs to the proper location...
