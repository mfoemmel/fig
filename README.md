Description
===========

Fig is a utility for dynamically assembling an environment from a set of packages. Shell commands can then be executed in that package, after which the environment goes away. The caller's environment is never affected.

If fig, an "environment" is just a set of environment variables. A "package" is a collection of files, plus some metadata describing how the environment should be modified when the package is included. For example, a package containing an executable might specify that its "bin" directory be appended to the PATH environment variable. A package containing a Java library might specify that its jar files should be added to the CLASSPATH. Etc.

Packages exist in two places: a "local" repository in the user's home directory, and a "remote" repository that is shared by a team. Fig will automatically download packages from the remote repository and install them in the local repository, when needed. In this sense, fig is a lot like other dependency management tools such as Apache Ivy and Debian APT. Unlike those tools, however, fig is meant to be lightweight, platform agnostic, and language agnostic.

Installation
============

Fig can be installed via rubygems. The gems are hosted at [Gemcutter](http://gemcutter.org), so you'll need to set that up first:

    $ gem install gemcutter
    $ gem tumble

Then you can install fig:

     $ gem install fig

Usage
=====

Fig recognizes the following options (not all are implemented yet):

### Flags ###

    -d, --debug   Print debug info
        --force   Download/install packages from remote repository, even if up-to-date
    -u, --update  Download/install packages from remote repository, if out-of-date
    -n, --no      Automatically answer "n" for any prompt (batch mode)
    -y, --yes     Automatically answer "y" for any prompt (batch mode)


### Environment Modifiers ###

The following otpions modify the environment generated by fig:

    -i, --include DESCRIPTOR  Include package in environment (recursive)
    -p, --append  VAR=VALUE   Append value to environment variable using platform-specific separator
    -s, --set     VAR=VALUE   Set environment variable

### Environment Commands ###

The following commands will be run in the environment created by fig:

    -b, --bash                Print bash commands so user's environment can be updated (usually used with 'eval')
    -g, --get     VARIABLE    Get value of environment variable
    -x, --execute DESCRIPTOR  Execute command associated with specified configuration

    -- COMMAND [ARGS...]      Execute arbitrary shell command

### Other Commands ###

Fig also supports the following options, which don't require a fig environment. Any modifiers will be ignored:

    -?, -h, --help   Display this help text
    --publish        Upload package to the remote repository (also installs in local repository)
    --publish-local  Install package in local repository only
    --list           List the packages installed in local repository   

Community
=========

\#fig on irc.freenode.net

[Fig Mailing List](http://groups.google.com/group/fig-user)

Copyright
=========

Copyright (c) 2009 Matthew Foemmel. See LICENSE for details.
