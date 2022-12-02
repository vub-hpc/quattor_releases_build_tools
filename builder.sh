#!/bin/bash

REPOS_MVN="release aii CAF CCM cdp-listend configuration-modules-core configuration-modules-grid LC ncm-cdispd ncm-ncd ncm-query ncm-lib-blockdevices"
REPOS_ONE_TAG="template-library-core template-library-standard template-library-examples template-library-monitoring"
REPOS_BRANCH_TAG="template-library-os template-library-grid template-library-openstack"
RELEASE=""
BUILD=""
MAXFILES=2048
RELEASE_ROOT=$(dirname $(readlink -f "$0"))
LIBRARY_CORE_DIR=$RELEASE_ROOT/src/template-library-core
GIT_USER_NAME='Stephane GERARD'
GIT_USER_EMAIL='stephane.gerard@vub.be'

if [[ $(ulimit -n) -lt $MAXFILES ]]; then
  echo "INFO: Max open files (ulimit -n) is below $MAXFILES, trying to increase the limit for you."
  ulimit -n 4096

  if [[ $(ulimit -n) -lt $MAXFILES ]]; then
    echo "ABORT: Max open files (ulimit -n) is still below $MAXFILES, releasing components will likely fail. Manually increase the limit and try again."
    exit 2
  fi
fi

if [[ -n "$QUATTOR_TEST_TEMPLATE_LIBRARY_CORE" && -d "$QUATTOR_TEST_TEMPLATE_LIBRARY_CORE" ]]; then
    echo "INFO: QUATTOR_TEST_TEMPLATE_LIBRARY_CORE defined and set to '$QUATTOR_TEST_TEMPLATE_LIBRARY_CORE'"
else
    echo "ABORT: QUATTOR_TEST_TEMPLATE_LIBRARY_CORE is not correctly defined, cannot perform a release without a reference copy of template-library-core."
    exit 2
fi

shopt -s expand_aliases
source maven-illuminate.sh
source ./mvn_test.sh


function echo_warning {
  echo -e "\033[1;33mWARNING\033[0m  $1"
}

function echo_error {
  echo -e "\033[1;31mERROR\033[0m  $1"
}

function echo_success {
  echo -e "\033[1;32mSUCCESS\033[0m  $1"
}

function echo_info {
  echo -e "\033[1;34mINFO\033[0m  $1"
}

function exit_usage {
    echo
    echo "USAGE: builder.sh REPOSITORY BRANCH VERSIONSTRING"
    exit 3
}

function is_in_list () {
    elem=$1
    list=$2

    found=0

    if [[ $list == $elem ]]; then
        found=1
    fi
    if [[ $list =~ ^"$elem " ]]; then
        found=1
    fi
    if [[ $list =~ " $elem"$ ]]; then
        found=1
    fi
    if [[ $list =~ " $elem " ]]; then
        found=1
    fi

    return $found
}

# # Check that HOME/.m2/settings.xml exists -> it contains the passphrase to unlock gpg key
# if [[ ! -f "$HOME/.m2/settings.xml" ]]; then
#     echo_error "Maven personal settings (~/.m2/settings.xml) is missing"
#     exit 2
# fi

# Set git user and mail address
git config --global user.name $GIT_USER_NAME
git config --global user.email $GIT_USER_EMAIL

# Check that dependencies required to perform a release are available
missing_deps=0
for cmd in {gpg,gpg-agent,git,mvn,createrepo,tar,sed}; do
    hash $cmd 2>/dev/null || {
        echo_error "Command '$cmd' is required but could not be found"
        missing_deps=$(($missing_deps + 1))
    }
done
if [[ $missing_deps -gt 0 ]]; then
    echo_error "Aborted due to $missing_deps missing dependencies (see above)"
    exit 2
fi


if [[ -n $1 ]]; then
    REPO=$1
fi

if [[ -n $2 ]]; then
    BRANCH=$2
fi

if [[ -n $3 ]]; then
    VERSION=$3
fi
CLEAN=1

echo "Preparing repositories for release..."
cd $RELEASE_ROOT
mkdir -p src/
cd src/
if [[ -d $REPO ]]; then
    if [ $CLEAN -eq 1 ]; then
        rm -rf $REPO
    fi
fi
git clone -q https://github.com/quattor/$REPO.git
cd $REPO
git checkout -q $BRANCH
prsfic="$RELEASE_ROOT/prs/$REPO"
if [[ -f $prsfic ]]; then
    echo "Fetching and merging the requested PRs..."
    readarray -t prs < $prsfic
    for pr in $prs; do
        git fetch origin refs/pull/$pr/head
        if [ $? -ne 0 ]; then
            echo_error "Failed to fetch PR $pr"
        fi
        git merge FETCH_HEAD --commit -m "merging PR $pr"
        if [ $? -ne 0 ]; then
            echo_error "Failed to merge FETCH_HEAD"
        fi
    done
fi
# Applying patches if they exist (file <repo_name>.patch)
patchfic="$RELEASE_ROOT/$REPO.patch"
if [ -f $patchfic ]; then
    echo "Applying patches..."
    git apply $patchfic
    git add .
    git commit -m 'local patch'
fi
cd ..
echo "Done."
is_in_list $REPO "$REPOS_MVN"
if [[ $? -eq 1 ]]; then
    echo_info "---------------- Building $REPO ----------------"
    cd $REPO
    #mvn_release > "$RELEASE_ROOT/${REPO}_build.log" 2>$1
    mvn_pack > "$RELEASE_ROOT/${REPO}_build.log" 2>$1
    if [[ $? -gt 0 ]]; then
        echo_error "BUILD FAILURE"
        exit 1
    fi
    cd ..
    echo
fi
echo_info "BUILD COMPLETED"
