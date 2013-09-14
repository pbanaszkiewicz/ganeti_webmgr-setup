Ganeti Web Manager installation files
=====================================

Installation files for `Ganeti Web Manager`_.  Mainly a ``setup.sh`` (bash
script) that:

1. detects user's operating system (Ubuntu, Debian or CentOS, 32b or 64b)

2. installs system dependencies (Python, ``python-virtualenv``) via user's OS
   default package managers (``apt`` or ``yum``) [requires ``sudo``]

3. creates virtual environment in local directory (or in directory specified
   by user)

4. installs newest ``pip`` and ``setuptools`` in that virtual environment
   (they're needed for ``wheel`` packages below)

5. installs GWM dependencies into that virtual environment (all of them will
   be provided as ``wheel`` binary packages, because GWM users might not be
   allowed to have ``gcc`` & co. installed)

6. installs GWM itself into that virtual environment

7. creates configuration directory near that virtual environment with sane
   default settings in there and random ``SECRET_KEY``

8. generates proper WSGI file for the project (that can work with custom
   directory and virtual environment)

.. _Ganeti Web Manager: http://ganeti-webmgr.readthedocs.org/en/latest/


Necessary GWM changes
---------------------

* GWM will need to be truly PyPI and ``pip`` compliant package (**DONE**)

* it will need to take into account different settings path (via environment
  variable)

* GWM will need to be easily WSGI-fied, so that a lightweight webserver can
  host it (**DONE**)


Additional enhancements
-----------------------

* we'll need to provide ``wheel`` packages of GWM's binary dependencies (like
  PostgreSQL connection library) (**DONE**)

* we'll need to think of sane default settings for GWM


Server scripts
==============

For building GWM dependencies I created a script called ``build_wheels.sh``.
The script's flow goes like this:

1. detect server's Linux distribution and version, and architecture

2. install missing building dependencies (some development files for
   PostgreSQL, MySQL and Python)

3. remove existing virtual environment (used for building Python packages)

4. recreate virtual environment, update it's packages (``setuptools``,
   ``pip``, ``wheel``) to the newest versions

5. get fresh GWM (or use existing one)

6. package GWM and all it's dependencies + ``psycopg2`` (for PostgreSQL) +
   ``MySQL-python`` (for, guess, MySQL)

7. put those packages (called *wheels*) to specific directory (the path is
   determined by OS and architecture, so for my system it'd be
   ``ubuntu/raring/x86_64/packages.whl``).
