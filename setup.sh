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


### Help text
case "$1" in
    --help|-h)
        echo "Install Ganeti Web Manager.

Usage:
  setup.sh -h | --help
  setup.sh <install directory>

Options:
  -h --help     Show this screen."
        exit 0
    ;;
esac

#------------------------------------------------------------------------------

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
    echo "Unknown distribution!  Cannot install required dependencies!"
    exit 1
fi

echo ""
echo "------------------------------------------------------------------------"
echo "Detected package manager: $package_manager"
echo "Installing system dependencies.  Please enter your password and confirm"
echo "installation."
echo "------------------------------------------------------------------------"

### installing system dependencies
sudo ${package_manager} ${package_manager_cmds} python python-virtualenv

echo ""
echo "------------------------------------------------------------------------"
echo "Creating virtual environment for Python packages"
echo "------------------------------------------------------------------------"

### creating virtual environment
venv='/usr/bin/virtualenv'

# check if user has provided any installation path
if [ "$1" ]; then
    install_directory="$1"
else
    # nothing provided, we create our own directory
    install_directory="./ganeti_webmgr"
fi
${venv} --setuptools --no-site-packages ${install_directory}

### updating pip and setuptools to the newest versions
${install_directory}/bin/pip install --upgrade setuptools pip

echo ""
echo "------------------------------------------------------------------------"
echo "Installing Ganeti Web Manager dependencies"
echo "------------------------------------------------------------------------"
