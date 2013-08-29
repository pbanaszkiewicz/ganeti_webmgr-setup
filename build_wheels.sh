#!/bin/bash

# Copyright (c) 2013 Piotr Banaszkiewicz.
# MIT License, see:
#  https://github.com/pbanaszkiewicz/ganeti_webmgr-setup/blob/master/LICENSE

# This script builds Python wheel packages to the specified directory from
# within a virtual environment

# default paths
env_dir='./venv/'
gwm_dir='./gwm/'
wheels_dir='./wheels/'

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
echo "Build Ganeti Web Manager dependencies as wheel packages.

Usage:
    $0 [-h]
    $0 [-e <dir>] [-g <dir>] [-w <dir>]

Default virtual environment path:   ${env_dir}
Default GWM clone path:             ${gwm_dir}
Default wheels output directory:    ${wheels_dir}

Wheels are put in subfolders in this pattern:
    ${wheels_dir}/{distribution}/{version}/{architecture}/

Options:
  -e <environment dir>      Specify virtual environment path. This gets erased
                            on every runtime.
  -g <GWM dir>              Where to clone GWM. If this path exists, GWM is not
                            cloned and existing copy is used instead.
  -w <wheels dir>           Where to put built wheel packages.
  -h                        Show this screen."
    exit 0
}

# helper: architecture and OS recognizing
lsb_release='/usr/bin/lsb_release'
architecture=`uname -i`
os='unknown'

if [ -x $lsb_release ]; then
    # we pull in default values, should work for both Debian and Ubuntu
    os=`$lsb_release -s -i | tr "[:upper:]" "[:lower:]"`

    if [ "$OS" == "centos" ]; then
        os_codename=`$lsb_release -s -r | sed -e 's/\..*//'`
    else
        os_codename=`$lsb_release -s -c | tr "[:upper:]" "[:lower:]"`
    fi

elif [ -r "/etc/redhat-release" ]; then
    # it's either RHEL or CentOS, which is fine
    os='centos'

    # instead of codename, we pull in release version ('6.3', '6.4', etc)
    os_codename=`sed s/.*release\ // /etc/redhat-release | sed s/\ .*//`
fi

#------------------------------------------------------------------------------

### Runtime arguments and help text
while getopts "he:g:w:" opt; do
    case $opt in
        h)
            usage
            ;;

        e)
            env_dir=${OPTARG}
            ;;
        g)
            gwm_dir=${OPTARG}
            ;;

        w)
            wheels_dir=${OPTARG}
            ;;

        \?)
            # unknown parameter
            exit 2
            ;;
    esac
done

check_if_exists "/bin/rm"
check_if_exists "/usr/bin/virtualenv"
check_if_exists "/usr/bin/git"

# remove venv
/bin/rm "${env_dir}" -r 2>/dev/null

# create venv
/usr/bin/virtualenv --setuptools --no-site-packages "${env_dir}"
if [ ! $? -eq 0 ]; then
    echo "${txtboldred}Something went wrong. Could not create virtual" \
         "environment"
    echo "in this path:"
    echo "  ${env_dir}${txtreset}"
    exit 3
fi

# update pip, setuptools and wheel
pip="${env_dir}/bin/pip"
check_if_exists "${pip}"
${pip} install --upgrade setuptools pip wheel
if [ ! $? -eq 0 ]; then
    echo "${txtboldred}Something went wrong. Could not install setuptools," \
         "pip or wheel"
    echo "in this virtual environment:"
    echo "  ${env_dir}${txtreset}"
    exit 4
fi

# clone gwm if it doesn't exist
if [ ! -d "{$gwm_dir}" ]; then
    gwm_address='git://git.osuosl.org/gitolite/ganeti/ganeti_webmgr'
    /usr/bin/git clone "${gwm_address}" "${gwm_dir}"

    if [ ! $? -eq 0 ]; then
        echo "${txtboldred}Something went wrong. Could clone GWM repository."
        echo "Check if repository address is correct:"
        echo "  ${gwm_address}${txtreset}"
        exit 5
    fi
fi

# install gwm into venv, put wheels to the wheel dir
wheel_path="${wheels_dir}/${os}/${os_codename}/${architecture}"
${pip} wheel --log=./pip.log --wheel-dir="${wheel_path}" "${gwm_dir}"
if [ ! $? -eq 0 ]; then
    echo "${txtboldred}Something went wrong. Could not create wheel" \
         "packages."
    echo "Check out pip log to see more:"
    echo "  ./pip.log${txtreset}"
    exit 6
fi

# remove venv
/bin/rm "${env_dir}" -r
