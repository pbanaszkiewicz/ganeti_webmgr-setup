#!/bin/bash

# Copyright (c) 2013 Piotr Banaszkiewicz.
# MIT License, see:
#  https://github.com/pbanaszkiewicz/ganeti_webmgr-setup/blob/master/LICENSE

# This script:
#
# 1. detects user's operating system (Debian or CentOS)
#
# 2. installs system dependencies (Python, ``python-virtualenv``) via user's OS
#    default package managers (``apt`` or ``yum``) [requires ``sudo``]
#
# 3. creates virtual environment in local directory (or in directory specified
#    by user)
#
# 4. installs newest ``pip`` and ``setuptools`` in that virtual environment
#    (they're needed for ``wheel`` packages below)
#
# 5. installs GWM dependencies into that virtual environment (some of them may
#    need to be provided as ``wheel`` binary packages, because GWM users might
#    not be allowed to have ``gcc`` & co. installed)
#
# 6. installs GWM itself into that virtual environment
#
# 7. creates configuration directory near that virtual environment with sane
#    default settings in there
#
# 8. installs GWM tools (ie. ``/usr/bin/gwm*``, like webserver or update
#    utility) that use above configuration directory (for example through
#    environment variable, like Django does with ``DJANGO_SETTINGS_MODULE``)
#
# 9. generates random ``SECRET_KEY`` (with read access only for GWM webserver)
#
# 10. generates proper WSGI file for the project (that can work with custom
#     directory and virtual environment)

# helpers: setting text colors
txtbold=$(tput bold)
txtred=$(tput setaf 1)
txtgreen=$(tput setaf 2)
txtblue=$(tput setaf 4)
txtwhite=$(tput setaf 7)
txtboldred=${txtbold}$(tput setaf 1)
txtboldgreen=${txtbold}$(tput setaf 2)
txtboldblue=$(tput setaf 4)
txtboldwhite=${txtbold}$(tput setaf 7)
txtreset=$(tput sgr0)

# helper function: check if some binary exists and is callable and otherwise
# echo warning
check_if_exists() {
    if [ ! -x $1 ]; then
        echo "${txtboldred}Cannot find $1! It's necessary to complete" \
             "installation.${txtreset}"
        exit 1
    fi
}

# helper function: display help message
usage() {
echo "Install (or upgrade) fresh Ganeti Web Manager from OSUOSL servers.

Usage:
    $0 [-h]
    $0 [-d <dir>] [-N]
    $0 [-u <dir>]

Default installation directory: ./ganeti_webmgr

Options:
  -d <install_directory>       Specify install directory.
  -N                           Don't try to install system dependencies.
  -u <install_directory>       Upgrade existing installation.
  -h                           Show this screen."
    exit 0
}

# helper "function": read computers architecture
architecture=`uname -i`

# TODO: better architecture and OS recognizing

install_directory='./ganeti_webmgr'
no_dependencies=0
update=0

### Runtime arguments and help text
while getopts "hu:d:N" opt; do
    case $opt in
        h)
            usage
            ;;

        u)
            upgrade=1
            install_directory=${OPTARG}
            ;;
        d)
            install_directory=${OPTARG}
            ;;

        N)
            no_dependencies=1
            ;;

        \?)
            # unknown parameter
            exit 2
            ;;
    esac
done

#------------------------------------------------------------------------------

### whether we should try to install system dependencies
if [ $no_dependencies -eq 0 ]; then

    ### detecting if it's Debian or CentOS
    if [ -x '/usr/bin/apt-get' ]; then
        # it's apparently Debian-based system
        package_manager='apt-get'
        package_manager_cmds='install'
        os='debian'

    elif [ -x '/usr/bin/yum' ]; then
        # nah, it's CentOS!
        package_manager='yum'
        package_manager_cmds='install'
        os='centos'

    else
        # unknown Linux distribution
        echo "${txtboldred}Unknown distribution! Cannot install required" \
             "dependencies!"
        echo "Please install on your own:"
        echo "- Python (version 2.6.x or 2.7.x)"
        echo "- python-virtualenv"
        echo "...and run setup:"
        echo " $0 -N ${txtreset}"
        exit 3
    fi

    echo ""
    echo "------------------------------------------------------------------------"
    echo "Detected package manager: $package_manager"
    echo "Installing system dependencies.  ${txtboldblue}Please enter your"
    echo "password and confirm installation.${txtreset}"
    echo "------------------------------------------------------------------------"

    ### installing system dependencies
    sudo="/usr/bin/sudo"
    check_if_exists $sudo

    ${sudo} ${package_manager} ${package_manager_cmds} python python-virtualenv

    # check whether installation succeeded
    if [ ! $? -eq 0 ]; then
        echo "${txtboldred}Something went wrong. Please install these" \
             "required dependencies on your"
        echo "own:"
        echo "- Python (version 2.6.x or 2.7.x)"
        echo "- python-virtualenv"
        echo "and suppress installing them via --no-system-deps option.${txtreset}"
        exit 4
    fi
fi

echo ""
echo "------------------------------------------------------------------------"
echo "Creating virtual environment for Python packages"
echo "------------------------------------------------------------------------"

### creating virtual environment
venv='/usr/bin/virtualenv'
check_if_exists $venv

# installing fresh
if [ -eq $upgrade 0 ]; then
    echo "Installing to: $install_directory"

    ${venv} --setuptools --no-site-packages ${install_directory}
    # check if virtualenv has succeeded
    if [ ! $? -eq 0 ]; then
        echo "${txtboldred}Something went wrong. Could not create virtual" \
             "environment"
        echo "in this path:"
        echo "  ${install_directory}${txtreset}"
        echo "Please create virtual environment manually by using virtualenv" \
             "command."
        exit 5
    fi

# nope! upgrading!
else
    echo "Upgrading: $install_directory"

    # Nothing to do here.  Using pip in a right way handles upgrading
    # automatically.
fi

### updating pip and setuptools to the newest versions
pip=${install_directory}/bin/pip
check_if_exists $pip
${pip} install --upgrade setuptools pip

# check if successfully upgraded pip and setuptools
if [ ! $? -eq 0 ]; then
    echo "${txtboldred}Something went wrong. Could not upgrade pip nor" \
         "setuptools"
    echo "in this virtual environment:"
    echo "  ${install_directory}${txtreset}"
    echo "Please upgrade pip and setuptools manually by issueing this" \
         "command:"
    echo "  ${pip} install --upgrade setuptools pip"
    exit 5
fi

echo ""
echo "------------------------------------------------------------------------"
echo "Installing Ganeti Web Manager and its dependencies"
echo "------------------------------------------------------------------------"

url="http://ftp.osuosl.org/pub/osl/ganeti-webmgr/${os}/${architecture}/"
echo $url
