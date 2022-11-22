#!/usr/bin/env python

import os
import json
import subprocess
import argparse
from time import time

# This script works together with a json file that contains a dictionary
# where each key is the name of the Quattor repositories, and the corresponding
# value is again a dict that specifies the branch and the PRs to be applied during
# the maven-build process. The key 'toversion' gives the version string of the
# the release you want to build.

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
parser.add_argument('--ignore', help='Names of the repos to ignore (comma-seperated list)')
args = parser.parse_args()

# examples of commands:
#   ./night_build_repo.py --init
#   ./night_build_repo.py --edit --repo aii --branch 21.12.0
#   ./night_build_repo.py --edit --repo aii --delprs
#   ./night_build_repo.py --edit --allrepos --toversion 22.10.0-rc2
#   ./night_build_repo.py --delete --repo foobar
#   ./night_build_repo.py --display
#   ./night_build_repo.py --build
#   ./night_build_repo.py --build --ignore foo,bar
#   ./night_build_repo.py --build --onlyrepo foo,bar

# check arguments (dependencies)
if args.edit:
    test = 0
    if args.repo and args.allrepos:
        print("Options --repo and --allrepos are mutually exclusive!")
        exit(1)
    if args.repo or args.allrepos:
        if args.branch or args.addprs or args.delprs:
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

# if we reach this point, either the user wants to build
# or there is nothing to do
if not args.build:
    print("Please specify what you want to do with options!")
    print("If you want to build the repositories, provide --build option.")
    exit(1)

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
        result = subprocess.Popen(cmd, shell=True)
        opt = result.communicate()[0]
        if opt:
            f.write(opt + "\n\n")
        exitcode = result.returncode
        if exitcode == 0:
            f.write('DONE')
        else:
            f.write('FAILED')
