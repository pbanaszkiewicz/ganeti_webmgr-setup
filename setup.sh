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
# 5. installs GWM dependencies into that virtual environment (some of them might
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


# setting text colors
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


### Runtime arguments and help text
nodependencies=0
case "$1" in
    --help|-h)
        echo "Install Ganeti Web Manager (by default: to 'ganeti_webmgr' directory).

Usage: setup.sh [--option] <install directory>

Default installation directory: ./ganeti_webmgr

Options:
  --no-system-deps   Don't try to install system dependencies.
  -h --help          Show this screen."
        exit 0
    ;;

    --no-system-deps)
        nodependencies=1
    ;;
esac

#------------------------------------------------------------------------------

### whether we should try to install system dependencies
if [ $nodependencies -eq 0 ]; then

    ### detecting if it's Debian or CentOS
    if [ -f '/usr/bin/apt-get' ]; then
        # it's apparently Debian-based system
        package_manager='apt-get'
        package_manager_cmds='install'
        os='debian'

    elif [ -f '/usr/bin/yum' ]; then
        # nah, it's CentOS!
        package_manager='yum'
        package_manager_cmds='install'
        os='centos'

    else
        # unknown Linux distribution
        echo "${txtboldred}Unknown distribution! Cannot install required dependencies!"
        echo "Please install on your own:"
        echo "- Python (version 2.6.x or 2.7.x)"
        echo "- python-virtualenv"
        echo "...and run setup:"
        echo " $0 --no-system-deps $1 ${txtreset}"
        exit 1
    fi

    echo ""
    echo "------------------------------------------------------------------------"
    echo "Detected package manager: $package_manager"
    echo "Installing system dependencies.  ${txtboldblue}Please enter your password and confirm"
    echo "installation.${txtreset}"
    echo "------------------------------------------------------------------------"

    ### installing system dependencies
    sudo ${package_manager} ${package_manager_cmds} python python-virtualenv

    # check whether installation succeeded
    if [ ! $? -eq 0 ]; then
        echo "${txtboldred}Something went wrong. Please install these required dependencies on your"
        echo "own:"
        echo "- Python (version 2.6.x or 2.7.x)"
        echo "- python-virtualenv"
        echo "and suppress installing them via --no-system-deps option. ${txtreset}"
        exit 2
    fi
fi

echo ""
echo "------------------------------------------------------------------------"
echo "Creating virtual environment for Python packages"
echo "------------------------------------------------------------------------"

### creating virtual environment
venv='/usr/bin/virtualenv'

# check if user has provided any installation path
if [ "$2" ]; then
    install_directory="$2"
elif [ "$1" != "--no-system-deps" ]; then
    install_directory="$1"
else
    # nothing provided, we create our own directory
    install_directory="./ganeti_webmgr"
fi

echo 'Installing to: $install_directory'

${venv} --setuptools --no-site-packages ${install_directory}

### updating pip and setuptools to the newest versions
${install_directory}/bin/pip install --upgrade setuptools pip

echo ""
echo "------------------------------------------------------------------------"
echo "Installing Ganeti Web Manager dependencies"
echo "------------------------------------------------------------------------"
