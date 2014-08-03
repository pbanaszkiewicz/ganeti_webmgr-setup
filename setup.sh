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
# 5. installs GWM dependencies into that virtual environment (all of them will
#    be provided as ``wheel`` binary packages, because GWM users might not be
#    allowed to have ``gcc`` & co. installed)
#
# 6. installs GWM itself into that virtual environment
#
# 7. creates configuration directory near that virtual environment with sane
#    default settings in there and random ``SECRET_KEY``
#
# 8. generates proper WSGI file for the project (that can work with custom
#    directory and virtual environment)

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

# default values
install_directory='./ganeti_webmgr'
base_url="http://ftp.osuosl.org/pub/osl/ganeti-webmgr"

# helper function: display help message
usage() {
echo "Install (or upgrade) fresh Ganeti Web Manager from OSUOSL servers.

Usage:
    $0 -h
    $0 [-d <dir>] [-D <database>] [-N] [-w <address>]
    $0 -u <dir>

Default installation directory:     $install_directory
Default database server:            SQLite
Default remote wheels location:     $base_url

Options:
  -h                            Show this screen.
  -d <install directory>        Specify install directory.
  -D <database server>          Either 'postgresql' or 'mysql' or 'sqlite'.
                                This option will try to install required
                                dependencies for selected database server
                                (unless -N).  If you don't specify it, SQLite
                                will be assumed the default DB.
  -N                            Don't try to install system dependencies.
  -w <wheels (local/remote) directory location>
                                Where wheel packages are stored.  Don't change
                                this value unless you know what you're doing!
  -u <install directory>        Upgrade existing installation. Forces -N.
  -g <branch>                   Install selected GWM branch from the osuosl git
                                repsitory"
    exit 0
}

# helper: architecture and OS recognizing
lsb_release='/usr/bin/lsb_release'
architecture=`uname -m`
os='unknown'

if [ -x "$lsb_release" ]; then
    # we pull in default values, should work for both Debian and Ubuntu
    os=`$lsb_release -s -i | tr "[:upper:]" "[:lower:]"`

    if [ "$OS" == "centos" ]; then
        os_codename=`$lsb_release -s -r | sed -e 's/\..*//'`
    else
        os_codename=`$lsb_release -s -c | tr "[:upper:]" "[:lower:]"`
    fi

elif [ -r "/etc/redhat-release" ]; then
    # it's either RHEL or CentOS, both is fine
    os='centos'

    # instead of codename, we pull in release version ('6.3', '6.4', etc)
    os_codename=`sed s/.*release\ // /etc/redhat-release | sed s/\ .*//`
fi

#------------------------------------------------------------------------------

no_dependencies=0
upgrade=0
database_server='sqlite'
git_version=0

### Runtime arguments and help text
while getopts "hu:d:D:Nw:g:" opt; do
    case $opt in
        h)
            usage
            ;;

        u)
            upgrade=1
            install_directory="$OPTARG"
            no_dependencies=1
            ;;

        d)
            install_directory="$OPTARG"
            ;;

        D)
            database="$OPTARG"
            echo "$database" | grep -e '^postgres' -i 1>/dev/null
            if [ $? -eq 0 ]; then
                database_server='postgresql'
            fi
            echo "$database" | grep -e '^mysql' -i 1>/dev/null
            if [ $? -eq 0 ]; then
                database_server='mysql'
            fi
            ;;

        N)
            no_dependencies=1
            ;;

        w)
            base_url="$OPTARG"
            ;;
        g)
            git_version=1
            git_branch="$OPTARG"
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

    case $os in
        debian)
            package_manager='apt-get'
            package_manager_cmds='install'
            check_if_exists "/usr/bin/$package_manager"
            ;;

        ubuntu)
            package_manager='apt-get'
            package_manager_cmds='install'
            check_if_exists "/usr/bin/$package_manager"
            ;;

        centos)
            package_manager='yum'
            package_manager_cmds='install'
            check_if_exists "/usr/bin/$package_manager"
            ;;

        unknown)
            # unknown Linux distribution
            echo "${txtboldred}Unknown distribution! Cannot install required" \
                 "dependencies!"
            echo "Please install on your own:"
            echo "- Python (version 2.6.x or 2.7.x)"
            echo "- python-virtualenv"
            echo "...and run setup suppressing installation of required deps:"
            echo "  $0 -N ${txtreset}"
            exit 3
            ;;
    esac

    echo ""
    echo "------------------------------------------------------------------------"
    echo "Detected package manager: $package_manager"
    echo "Installing system dependencies.  ${txtboldblue}Please enter your"
    echo "password and confirm installation.${txtreset}"
    echo "------------------------------------------------------------------------"

    ### installing system dependencies
    sudo="/usr/bin/sudo"
    check_if_exists "$sudo"

    # debian based && postgresql
    if [ \( "$os" == "ubuntu" -o "$os" == "debian" \) -a "$database_server" == "postgresql" ]; then
        database_requirements='libpq5'

    # debian based && mysql
    elif [ \( "$os" == "ubuntu" -o "$os" == "debian" \) -a "$database_server" == "mysql" ]; then
        database_requirements='libmysqlclient18'

    # RHEL based && postgresql
    elif [ \( "$os" == "centos" \) -a "$database_server" == "postgresql" ]; then
        database_requirements='postgresql-libs'

    # RHEL based && mysql
    elif [ \( "$os" == "centos" \) -a "$database_server" == "mysql" ]; then
        database_requirements='mysql-libs'
    fi

    ${sudo} ${package_manager} ${package_manager_cmds} python \
        python-virtualenv ${database_requirements}

    # check whether installation succeeded
    if [ ! $? -eq 0 ]; then
        echo "${txtboldred}Something went wrong. Please install these" \
             "required dependencies on your"
        echo "own:"
        echo "- Python (version 2.6.x or 2.7.x)"
        echo "- python-virtualenv"
        if [ ! -n $database_requirements ]; then
            echo "- $database_requirements"
        fi
        echo "and suppress installing them via -N runtime argument.${txtreset}"
        exit 4
    fi
fi

echo ""
echo "------------------------------------------------------------------------"
echo "Creating virtual environment for Python packages"
echo "------------------------------------------------------------------------"

### creating virtual environment
venv='/usr/bin/virtualenv'
check_if_exists "$venv"

# installing fresh
if [ $upgrade -eq 0 ]; then
    echo "Installing to: $install_directory"

    ${venv} --setuptools --no-site-packages "$install_directory"
    # check if virtualenv has succeeded
    if [ ! $? -eq 0 ]; then
        echo "${txtboldred}Something went wrong. Could not create virtual" \
             "environment"
        echo "in this path:"
        echo "  $install_directory${txtreset}"
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

### updating pip and setuptools to the newest versions, installing wheel
pip="$install_directory/bin/pip"
check_if_exists "$pip"
${pip} install --upgrade setuptools pip wheel

# check if successfully upgraded pip and setuptools
if [ ! $? -eq 0 ]; then
    echo "${txtboldred}Something went wrong. Could not upgrade pip nor" \
         "setuptools"
    echo "in this virtual environment:"
    echo "  $install_directory${txtreset}"
    echo "Please upgrade pip and setuptools manually by issuing this" \
         "command:"
    echo "  ${pip} install --upgrade setuptools pip"
    exit 5
fi

echo ""
echo "------------------------------------------------------------------------"
echo "Installing Ganeti Web Manager and its dependencies"
echo "------------------------------------------------------------------------"


git='/usr/bin/git'
check_if_exists "$git"

if [ "$git_version" -eq 1 ]; then
    pip_args="-e git://git.osuosl.org/gitolite/ganeti/ganeti_webmgr/@${git_branch}#egg=ganeti_webmgr"
else
    # WARNING: watch out for double slashes when concatenating these strings!
    url="$base_url/$os/$os_codename/$architecture/"
    pip_args="--find-link="$url" ganeti_webmgr"
fi

${pip} install --upgrade --use-wheel ${pip_args}

if [ ! $? -eq 0 ]; then
    echo "${txtboldred}Something went wrong. Could not install GWM nor its" \
         "dependencies"
    echo "in this virtual environment:"
    echo "  $install_directory${txtreset}"
    echo "Please check if you have internet access and consult with official" \
         "GWM documentation:"
    echo "  http://ganeti-webmgr.readthedocs.org/en/latest/"
    exit 6
fi

# install dependencies for database
if [ "$database_server" != "sqlite" ]; then
    case $database_server in
        postgresql)
            ${pip} install --upgrade --use-wheel --find-link="$url" psycopg2
            ;;
        mysql)
            ${pip} install --upgrade --use-wheel --find-link="$url" MySQL-python
            ;;
    esac

    if [ ! $? -eq 0 ]; then
        echo "${txtboldred}Something went wrong. Could not install database" \
            "dependencies"
        echo "in this virtual environment:"
        echo "  $install_directory${txtreset}"
        echo "Please check if you have internet access and consult with official" \
             "GWM documentation:"
        echo "  http://ganeti-webmgr.readthedocs.org/en/latest/"
        exit 7
    fi
fi


### default configuration

# TODO: alternatively get a tarball from GitHub and unzip it

# clone pbanaszkiewicz's repo
config_repo='https://github.com/pbanaszkiewicz/ganeti_webmgr-config.git'

${git} clone "$config_repo" "$install_directory/config"
if [ ! $? -eq 0 ]; then
    echo "${txtboldred}Something went wrong. Could not download configuration"\
        "files"
    echo "from this Git repository:"
    echo "  $config_repo${txtreset}"
    echo "Please check if you have internet access, git installed and consult"\
         "with official GWM documentation:"
    echo "  http://ganeti-webmgr.readthedocs.org/en/latest/"
    exit 8
fi

/bin/mv "$install_directory/config/gwm-manage.py" "$install_directory/bin/"

# readlink provides us with absolute path to specified directory
config_path=`/bin/readlink -m "$install_directory/config"`
if [ $? -eq 0 ]; then
    # if we used readlink, let's change hardcoded path in gwm-manage.py
    /bin/sed -i "s;../config;$config_path;" \
             "$install_directory/bin/gwm-manage.py"
fi

# install noVNC

# TODO: use fixed commit or stable version

# clone kanaka's repo
novnc_repo="https://github.com/kanaka/noVNC.git"

# make sure src dir exists
mkdir -p "${install_directory}/src"

${git} clone "$novnc_repo" "$install_directory/src/noVNC"
if [ ! $? -eq 0 ]; then
    echo "${txtboldred}Something went wrong. Could not install noVNC"
    echo "from this Git repository:"
    echo "  $config_repo${txtreset}"
    echo "Please check if you have internet access, git installed and consult"\
         "with official GWM documentation:"
    echo "  http://ganeti-webmgr.readthedocs.org/en/latest/"
    exit 9
fi

# if using GWM git version copy noVNC directly to src directory
if [ "$git_version" -eq 1 ]; then
    cp -r "${install_directory}/src/noVNC" "${install_directory}/src/ganeti-webmgr/ganeti_webmgr/static/novnc"
else
    cp -r "${install_directory}/src/noVNC" "${install_directory}/lib/python2*/ganeti-webmgr/ganeti_webmgr/static/novnc"
fi

### generating secrets
# secret_path="$install_directory/.secrets/"
# dd if=/dev/urandom bs=32 count=1 | base64 > "$secret_path/SECRET_KEY.txt"
# dd if=/dev/urandom bs=32 count=1 | base64 > "$secret_path/MGR_API_KEY.txt"
