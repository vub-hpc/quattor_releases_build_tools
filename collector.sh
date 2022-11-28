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

# Update the Quattor version used by template-library-examples (SCDB-based) to the one being released
update_examples () {
    tag=$1
    cd template-library-examples
    sed -i -e "s%quattor/[0-Z\.\_\-]\+\s%quattor/$tag %" $(find clusters -name cluster.build.properties)
    git commit -a -m "Update Quattor version used by examples to ${tag}"
    cd ..
}

# Remove all current configuration module related templates.
# To be used before starting the update: after the updated
# only the obsolete configuration modules will be missing.
clean_templates() {
    rm -Rf ${LIBRARY_CORE_DIR}/components/*
}

# Commit to template-library-core the removal of obsolete configuration modules
remove_obsolete_components () {
    cd ${LIBRARY_CORE_DIR}
    #FIXME: ideally should check that there is only deleted files left
    git add -A .
    git commit -m 'Remove obsolete components'
    cd ..
}

# Update the templates related to configuration modules.
# This has to be called for every repository containing configuration modules.
publish_templates() {
    echo_info "Publishing Component Templates"
    type=$1
    tag=$2
    cd configuration-modules-$1
    git checkout $tag
    mvn_compile
    # ugly hack
    if [ -d ncm-metaconfig ]; then
        cd ncm-metaconfig
        mvn_test
        cd ..
    fi
    components_root=${LIBRARY_CORE_DIR}/components
    metaconfig_root=${LIBRARY_CORE_DIR}/metaconfig
    mkdir -p ${components_root}
    mkdir -p ${metaconfig_root}
    cp -r ncm-*/target/pan/components/* ${components_root}
    cp -r ncm-metaconfig/target/pan/metaconfig/* ${metaconfig_root}
    git checkout master
    cd ${LIBRARY_CORE_DIR}
    git add .
    git commit -m "Component templates (${type}) for tag ${tag}"
    cd ..
}

# Update templates related to AII and its plugins.
# Existing AII templates are removed before the update so
# that obsolete templates are removed.
publish_aii() {
    echo_info "Publishing AII Templates"
    tag="$1"
    dest_root="${LIBRARY_CORE_DIR}/quattor/aii"

    # It's better to do a rm before copying, in case a template has been suppressed.
    # For aii-core, don't delete subdirectory as some are files not coming from somewhere else...
    rm ${dest_root}/*.pan

    (
        cd aii || return
        git checkout "aii-$tag"
        mvn_compile

        # Copy dedicated AII templates
        cp -r aii-core/target/pan/quattor/aii/* "${dest_root}"

        # Copy AII component templates
        for aii_component in dhcp ks pxelinux; do
            rm -Rf "${dest_root:?}/${aii_component}"
            cp -r "aii-${aii_component}/target/pan/quattor/aii/${aii_component}" "${dest_root}"
        done
        git checkout master
    )

    (
        cd configuration-modules-core || return
        git checkout "configuration-modules-core-$tag"
        mvn_compile
        # Copy shared AII/core component templates
        for component in freeipa opennebula; do
            rm -Rf "${dest_root:?}/${component}"
            cp -r "ncm-${component}/target/pan/quattor/aii/${component}" "${dest_root}"
        done
        git checkout master
    )

    cd "${LIBRARY_CORE_DIR}" || return
    git add -A .
    git commit -m "AII templates for tag $tag"
    cd ..
}

# Build the template version.pan appropriate for the version
update_version_file() {
    release_major=$1
    if [ -z "$(echo $release_major | egrep 'rc[0-9]*$')" ]
    then
      release_minor="-1"
    else
      release_minor="_1"
    fi
    version_template=quattor/client/version.pan
    cd ${LIBRARY_CORE_DIR}

    cat > ${version_template} <<EOF
template quattor/client/version;

variable QUATTOR_RELEASE ?= '${release_major}';
variable QUATTOR_REPOSITORY_RELEASE ?= QUATTOR_RELEASE;
variable QUATTOR_PACKAGES_VERSION ?= QUATTOR_REPOSITORY_RELEASE + '${release_minor}';
EOF

    git add .
    git commit -m "Update Quattor version file for ${release_major}"
    cd -
}


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
    echo "USAGE: collector.sh VERSION_STRING"
    exit 3
}

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

# # Process arguments
# if [[ -n $1 ]]; then
#     VERSION=$1
# else
#     echo_error "Version not provided"
#     exit_usage
# fi
VERSION='21.12.1-SNAPSHOT'

# # launch gpg-agent
# gpg-agent --daemon

# Set git user and mail address
git config --global user.name $GIT_USER_NAME
git config --global user.email $GIT_USER_EMAIL

# if gpg-agent; then
#     if gpg --yes --sign $0; then

        echo_info "Cloning the rest of repositories"
        cd src/
        for r in $REPOS_ONE_TAG $REPOS_BRANCH_TAG; do
            if [[ ! -d $r ]]; then
                git clone -q https://github.com/quattor/$r.git
            fi
        done
        cd ..

        cd $RELEASE_ROOT
        mkdir -p target/

        echo_info "Collecting RPMs"
        mkdir -p target/$VERSION
        find src/ -type f -name \*.rpm | grep /target/rpm/ | xargs -I @ cp @ target/$VERSION/

        cd target/

        #echo_info "Signing RPMs"
        #rpmsign --addsign $VERSION/*.rpm

        echo_info "Creating repository"
        createrepo -s sha $VERSION/

        #echo_info "Signing repository"
        #gpg --detach-sign --armor $VERSION/repodata/repomd.xml

        echo_info "Creating repository tarball"
        tar -cjf quattor-$VERSION.tar.bz2 $VERSION/
        echo_info "Repository tarball built: target/quattor-$VERSION.tar.bz2"

        echo_success "---------------- YUM repositories complete ----------------"

        cd $RELEASE_ROOT/src

        echo_info "---------------- Updating template-library-core  ----------------"
        clean_templates
        echo_info "    Updating configuration module templates..."
        publish_templates "core" "configuration-modules-core-$VERSION" && echo_info "    Published core configuration module templates"
        publish_templates "grid" "configuration-modules-grid-$VERSION" && echo_info "    Published grid configuration module templates"

        echo_info "    Remove templates for obsolete components..."
        remove_obsolete_components

        echo_info "    Updating AII templates..."
        publish_aii "$VERSION" &&  echo_info "    AII templates successfully updated"

        echo_info "    Updating Quattor version template..."
        update_version_file "$VERSION" && echo_info "    Quattor version template sucessfully updated"

        echo_info "Updating examples"
        update_examples $VERSION


        echo_success "---------------- Update of template-library-core successfully completed ----------------"

        echo_success "RELEASE COMPLETED"
#     fi
# fi
