# Use an official centos image as a parent image
FROM centos:7

# Set the working directory to install dependencies to /quattor
WORKDIR /quattor

# install library core in /quattor, tests need it
ADD https://codeload.github.com/quattor/template-library-core/tar.gz/master /quattor/template-library-core-master.tar.gz
RUN tar xvfz template-library-core-master.tar.gz

# Install dependencies
RUN yum install -y maven epel-release rpm-build createrepo rpm-sign vim
RUN rpm -U http://yum.quattor.org/devel/quattor-release-1-1.noarch.rpm

# The available version of perl-Test-Quattor is too old for mvnprove.pl to
# work, but this is a quick way of pulling in a lot of required dependencies.
# Surprisingly `which` is not installed by default and panc depends on it.
# libselinux-utils is required for /usr/sbin/selinuxenabled
RUN yum install --nogpgcheck -y perl-Test-Quattor which panc aii-ks ncm-lib-blockdevices \
    ncm-ncd git libselinux-utils sudo perl-Crypt-OpenSSL-X509 \
    perl-Data-Compare perl-Date-Manip perl-File-Touch perl-JSON-Any \
    perl-Net-DNS perl-Net-FreeIPA perl-Net-OpenNebula \
    perl-Net-OpenStack-Client perl-NetAddr-IP perl-REST-Client \
    perl-Set-Scalar perl-Text-Glob perl-Parallel-ForkManager \
    perl-Config-General ncm-metaconfig
#perl-Git-Repository perl-Data-Structure-Util
# Hack around the two missing Perl rpms for ncm-ceph
RUN yum install -y cpanminus gcc
RUN cpanm install Git::Repository Data::Structure::Util

# point library core to where we downloaded it
ENV QUATTOR_TEST_TEMPLATE_LIBRARY_CORE /quattor/template-library-core-master

#only valid in iihe's private network (no public repo for this release)
ADD http://repos.cerberus.os/20230416/quattor_externals-el8/perl-Net-OpenNebula-0.317.0-1.el8.noarch.rpm /quattor/perl-Net-OpenNebula-0.317.0-1.el8.noarch.rpm
RUN yum install -y perl-Net-OpenNebula-0.317.0-1.el8.noarch.rpm

# set workdir to where we'll run the tests
WORKDIR /home
# yum-cleanup-repos.t must be run as a non-root user. It must also resolve
# to a name (nobody) to avoid getpwuid($<) triggering a warning which fails
# the tests.
RUN useradd -u 1000 -d /home bob
USER 1000
ENV HOME /home
