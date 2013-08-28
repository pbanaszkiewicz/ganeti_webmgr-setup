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

8. installs GWM tools (ie. ``/usr/bin/gwm*``, like webserver or update
   utility) that use above configuration directory (for example through
   environment variable, like Django does with ``DJANGO_SETTINGS_MODULE``)

9. generates proper WSGI file for the project (that can work with custom
   directory and virtual environment)

.. _Ganeti Web Manager: http://ganeti-webmgr.readthedocs.org/en/latest/


Necessary GWM changes
---------------------

* GWM will need to be truly PyPI and ``pip`` compliant package (**DONE**)

* it will need to take into account different settings path (as mentioned
  above: via environment variable)

* GWM will need to be easily WSGI-fied, so that a lightweight webserver can
  host it (**DONE**)


Additional enhancements
-----------------------

* ``ganeti-webmgr-tools`` package with webserver and/or some other tools will
  be needed

* we'll need to provide ``wheel`` packages of GWM's binary dependencies (like
  PostgreSQL connection library)

* we'll need to think of sane default settings for GWM
