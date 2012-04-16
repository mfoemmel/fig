Description
===========

## Short version

Fig is a package management tool with both install time and run time behavior;
by the use of environment variables defined within a Fig package file, at run
time your code does not need to know precisely where resources are installed.

Fig is similar to a lot of other package/dependency-management tools. In
particular, it steals a lot of ideas from Apache Ivy and Debian APT. However,
unlike Ivy, Fig is meant to be lightweight (no XML, no JVM startup time),
language agnostic (Java doesn't get preferential treatment), and work with
executables as well as libraries. And unlike APT, Fig is cross platform and
project-oriented.

## Long version

Fig is a utility for configuring environments and managing dependencies across
a team of developers.

An "environment" in fig is a set of environment variables.  A "package" is a
collection of files, along with some metadata describing which environment
variables should be modified when the package is included.  For instance, each
dependency may prepend its corresponding jar to CLASSPATH.  The metadata may
also list that package's lower-level Fig package dependencies.

Fig recursively builds an environment consisting of package dependencies
(typically specified via command-line options or a package.fig file), each of
which as noted above may have its own dependencies, and optionally executes a
shell command in that environment.  The caller's environment is not affected.

Developers can use package.fig files to specify the list of dependencies to use
for different tasks. This file will typically be versioned along with the rest
of the source files, ensuring that all developers on a team are using the same
environments.

Packages exist in two places: a "local" repository cache in the user's home
directory-- also called the fig-home --and a "remote" repository on a shared
server. Fig will automatically download packages from the remote repository and
install them in the fig-home as needed.  Fig does not contact the remote
repository unless it needs to.  The default fig-home is `$HOME/.fighome`, but
may be changed by setting the `$FIG_HOME` environment variable.

Command-line Usage
==================

Fig recognizes the following options:

## Flags

    -g, --get VARIABLE               print value of environment variable VARIABLE
        --list-local, --list         list packages in $FIG_HOME
        --list-configs               list configurations
        --list-dependencies          list package dependencies, recursively
        --list-variables             list all variables defined/used by package and its dependencies
        --list-remote                list packages in remote repo
        --list-tree                  for listings, output a tree instead of a list
        --list-all-configs           for listings, follow all configurations of the base package
        --clean                      remove package from $FIG_HOME
        --publish                    install package in $FIG_HOME and in remote repo
        --publish-local              install package only in $FIG_HOME
    -c, --config CONFIG              apply configuration CONFIG, default is "default"
        --file FILE                  read Fig file FILE. Use '-' for stdin. See also --no-file
        --no-file                    ignore package.fig file in current directory
    -p, --append VARIABLE=VALUE      append (actually, prepend) VALUE to PATH-like environment variable VARIABLE
    -i, --include DESCRIPTOR         include package/version:config specified in DESCRIPTOR in environment
    -s, --set VARIABLE=VALUE         set environment variable VARIABLE to VALUE
        --archive PATH               include PATH archive in package (when using --publish)
        --resource PATH              include PATH resource in package (when using --publish)
    -u, --update                     check remote repo for updates and download to $FIG_HOME as necessary
    -m, --update-if-missing          check remote repo for updates only if package missing from $FIG_HOME
    -l, --login                      login to remote repo as a non-anonymous user
        --force                      force-overwrite existing version of a package to the remote repo
        --figrc PATH                 add PATH to configuration used for Fig
        --no-figrc                   ignore ~/.figrc
        --log-config PATH            use PATH file as configuration for Log4r
        --log-level LEVEL            set logging level to LEVEL
                                       (off, fatal, error, warn, info, debug, all)
        --suppress-warning-include-statement-missing-version
                                     don't complain about "include package" without a version
    -?, -h, --help                   display this help text
    -v, --version                    print Fig version
        --                           end of Fig options; anything after this is used as a command to run
        --command-extra-args         end of Fig options; anything after this is appended to the end of a
                                     "command" statement in a "config" block.

Some of these options may also be expressed as statements in a package.fig
file.  For instance, `--append`, `--archive`, `--resource`, `include`.

## Environment Variables Influencing Fig's Behavior

    FIG_REMOTE_URL      Required for operations involving the remote repository.
    FIG_HOME            Optional - Location of local repo cache. Defaults to $HOME/.fighome.

    FIG_REMOTE_LOGIN    Required for --login, unless $HOME/.netrc is configured.
    FIG_REMOTE_USER     Required for --login, unless $HOME/.netrc is configured.
    FIG_FTP_THREADS     Optional - Size of FTP session pool. Defaults to 16.

## Commands affected by environment variables

### `--list-remote`

When using the `--list-remote` command against an FTP server, Fig uses a pool
of FTP sessions to improve performance. By default it opens 16 connections, but
that number can be overridden by setting the `FIG_FTP_THREADS` environment
variable.

### `--login`

If the `--login` option is supplied, Fig will look for credentials.  If
environment variables `FIG_REMOTE_USER` and/or `FIG_REMOTE_PASSWORD` are
defined, Fig will use them instead of prompting the user.  If ~/.netrc exists,
with an entry corresponding to the host parsed from `FIG_REMOTE_URL`, that
entry will take precedence over `FIG_REMOTE_USER` and `FIG_REMOTE_PASSWORD`.
If sufficient credentials are still not found, Fig will prompt for whatever is
still missing, and use the accumulated credentials to authenticate against the
remote server.  Even if both environment variables are defined, Fig will only
use them if `--login` is given.

Usage
=====

## Overview

Like other package management tools, Fig requires a file describing the
contents and dependencies of a given package.  You then publish a package to a
repository, which can simply be local or additionally a remote one.  There is
no explicit installation; you just use the package from another.  Unlike other
tools, you don't specify where (other than via the `FIG_HOME` environment
variable) or how an installed set of packages are structured.

In order to use the contents of one package from another, you define
environment variables with in a package definition that will have portions
substituted with locations from a given depended upon package.

## Package definition

The definition of a package for Fig is done using a file (by default
"package.fig") with a simple language.  Comments consist of an octothorpe ("#")
though end of line.  At the top level of a file, you can put "archive",
"resource", or "retrieve" statement and "config" blocks.  At this level, order
of statements is not significant.  A "config" block can contain "set", path,
"include" and "command" statements; order of statements within "config" blocks
is significant.  "config" blocks are not nestable.

A simple (nonsensical) example "package.fig" file that contains one of each
kind of statement:

    archive path/somefile.tar.gz
    resource foo/*.jar
    retrieve LOCATION_VARIABLE->some-relative-path/[package]
    config default
        set VARIABLE=value
        add CLASSPATH=foo.jar
        include dependency/1.2.3 override indirect-dependency/4.5.6
        command "echo foo"
    end

### Package contents

You tell Fig what to include in your package using "resource" and "archive"
statements.  These two kinds of statements behave identically except that the
contents of the files referenced by "archive" statements are extracted upon
installation.  Thus, given a package.fig file containing the statements

    archive path/somefile.tar.gz
    resource foo/*.jar

the bundled up package will contain all of the jar files in the `foo/`
subdirectory of the current directory and the `somefile.tar.gz` archive.  When
package is installed, the jar files will be in a `foo` subdirectory of the
package directory and the `somefile.tar.gz` contents will be extracted.

If multiple archives contain the same file, one version will end up overwriting
the other.  There are no guarantees as to which version of a file will be the
last one written.

#### Caveat

In the current repository format, archives in a package are stored in a single
flat directory.  This means that if the last component of the path for an
"archive" statement or a URL for a "resource" statement are not unique, you
will run into problems.  In a package.fig file containing:

    archive a-path/somefile.tar.gz
    archive another-path/somefile.tar.gz
    archive http://example/some/path/somefile.tar.gz
    resource ftp://whatever/foo/bar/somefile.tar.gz

all of the files would end up clobbering each other.  Fig actually checks for
this situation and will prevent publishing such a package, but it's something
you need to look out for.  Note that local "resource"s with different paths are
fine:

    resource something/somefile.tgz
    resource wherever/somefile.tgz

### Where to put the contents of a depended upon package

Done via a "retrieve" statement.

### Declaring dependencies

Done via an "include" statement.

### Specifying runtime environment

"set" and path statements.  A path statement is specified as "add", "append",
or "path"; all are synonymous.

### Default commands

If a command to run is not given on the `fig` command-line, the command in a
"command" statement is executed.

## Publishing


## Installing/Updating


## Runtime use


Examples
========

Fig lets you configure environments three different ways:

* From the command line
* From a "package.fig" file in the current directory
* From packages included indirectly via one of the previous two methods

## Command Line

To get started, let's define an environment variable via the command line and
execute a command in the new environment. We'll set the "GREETING" variable to
"Hello", then run a command that uses that variable:

    $ fig -s GREETING=Hello -- echo '$GREETING, World'
    Hello, World

Also note that when running Fig, the original environment isn't affected:

     $ echo $GREETING
     <nothing>

Fig also lets you append environment variables using the system-specified path
separator (e.g. colon on Unix, semicolon on windows). This is useful for adding
directories to the PATH, LD_LIBRARY_PATH, CLASSPATH, etc. For example, let's
create a "bin" directory, add a shell script to it, then include it in the
PATH:

    $ mkdir bin
    $ echo 'echo $GREETING, World' > bin/hello
    $ chmod +x bin/hello
    $ fig -s GREETING=Hello -p PATH=bin -- hello
    Hello, World

## Fig Files

You can also specify environment modifiers in files. Fig looks for a file
called "package.fig" in the current directory and automatically processes it.

This "package.fig" file implements the previous example:

    config default
      set GREETING=Hello
      append PATH=@/bin
    end

Then we can just run:

    $ fig -- hello
    Hello, World

NOTE: The '@' symbol in a given package.fig file (or in a published
dependency's .fig file) represents the full path to that file's directory.  The
above example would still work if we just used "bin", but later on when we
publish our project to the shared repository we'll definitely need the '@',
since the project directories will live in the Fig-home rather than under our
current directory).

A single Fig file may have multiple configurations:

    config default
      set GREETING=Hello
      append PATH=@/bin
    end

    config french
      set GREETING=Bonjour
      append PATH=@/bin
    end

## Config Sections

Configurations other than "default" can be specified using the "-c" option:

    $ fig -c french -- hello
    Bonjour, World

The statements from one config section can be incorporated into another config
section via an `include` statement:

    config default
      include :spanish
    end

    config spanish
      set GREETING="Buenas Dias"
      append PATH=@/bin
    end

Note that config statements cannot be nested within a Fig file.  I.e. the
following is _invalid_:

    config foo
      config bar
      end
    end

## Packages

Let's share our little script with the rest of the team by bundling it into a
package and publishing it. First, point the `FIG_REMOTE_URL` environment
variable to the remote repository. If you just want to play around with Fig,
you can have it point to a local directory:

    $ export FIG_REMOTE_URL=file://$(pwd)/remote

Before we publish our package, we'll need to tell Fig which files we want to
include. We do this by using the "resource" statement in our "package.fig"
file:

    resource bin/hello

    config default...

Now we can share the package with the rest of the team by using the `--publish`
option:

    $ fig --publish hello/1.0.0

Once the package has been published, we can include it in other environments
with the `-i` or `--include` option.  (For the purpose of this example, let's
first move the "package.fig" file out of the way, so that it doesn't confuse
Fig or us.) The "hello/1.0.0" string represents the name of the package and the
version number.

    $ mv package.fig package.bak
    $ fig -u -i hello/1.0.0 -- hello
    ...downloading files...
    Hello, World

The `-u` (or `--update`) option tells Fig to check the remote repository for
packages if they aren't already installed locally (Fig will never make any
network connections unless this option is specified). Once the packages are
downloaded, we can run the same command without the `-u` option:

    $ fig -i hello/1.0.0 -- hello
    Hello, World

When including a package, you can specify a particular configuration by
appending it to the package name using a colon:

    $ fig -i hello/1.0.0:french -- hello
    Bonjour, World

## Retrieves

By default, the resources associated with a package live in the Fig home
directory, which defaults to "$HOME/.fighome". This doesn't always play nicely
with IDE's however, so Fig provides a "retrieve" statement to copy resources
from the repository to the current directory.

For example, let's create a package that contains a library for the "foo"
programming language. Define a "package.fig" file:

    config default
      append FOOPATH=@/lib/hello.foo
    end

Then:

    $ mkdir lib
    $ echo "print 'hello'" > lib/hello.foo
    $ fig --publish hello-lib/3.2.1

Create a new "package.fig" file (first moving to a different directory or
deleting the "package.fig" we just used for publishing):

    retrieve FOOPATH->lib/[package]
    config default
      include hello-lib/3.2.1
    end

Upon a `fig --update`, each resource in FOOPATH will be copied into
lib/[package], where [package] resolves to the resource's package name (minus
the version).

     $ fig -u
     ...downloading...
     ...retrieving...
     $ cat lib/hello-lib/hello.foo
     print 'hello'

Fig Configuration
=================

Need a description of `.figrc` here.

Package Statement Descriptions
==============================

One point of frequent confusion revolves around which statements are concerned
with publishing packages, and which are for downloading packages and otherwise
modifying the Fig environment.  The same Fig file can contain both publish
(e.g., `append`, `resource`) and download (e.g., `include`) statements, but you
may not want to use the same dependency file for both publishing a package and
specifying that same package's dependencies, since for example its "build-time"
dependencies may differ from its "include-time" dependencies.  Multiple config
sections may be helpful in organizing these concerns.

## `add`

Specifies a value to be prepended to a `PATH`-like environment variable, e.g.
`CLASSPATH` for Java.  Does not include the delimiter within the variable, just
the component value.

### Syntax

    config something
        add VARIABLE=value
    end

No whitespace is allowed around the equals sign.  The value cannot be empty.
No whitespace, semicolons, colons, double quotes, less-than signs, greater-than
signs, or pipe symbols are allowed in the value.  At sign ("@") and retrieve
variable substitution is done on the value.

## `append`

Synonym for `add`.  Note that, despite the name, the value will be prepended,
not appended.  (At the present time, there is no way to actually append a value
to a path variable.)

## `archive`

Specifies an archive file (either a local path or a URL) that is supposed to be
incorporated into the package.  This is different from a `resource` in that the
contents will be extracted as part of installation.  Also unlike a `resource`,
if the value is a local path, no file globbing will be performed.

### Syntax

    archive URL
    archive local/path

## `command`

Specifies a default command to be run for a given `config` when no command is
given on the command-line.

    config default
      command "echo Hello there."
    end

Cannot be specified outside of a `config` statement.  There may not be multiple
commands within a given `config`.

You can use the `--command-extra-args` option to add parameters to the command.
For example, given the above package declaration, if you were to run `fig
--command-extra-args It is a nice day.`, you would get "Hello there. It is a
nice day." as output.

### Syntax

    config something
      command "command-line"
    end

The command-line must be specified in double quotes and cannot contain double
quotes.

Package names preceded by at signs ("@") will be expanded to the base
directory of that package.  For example, given

    config something
      command "echo blah@foo/whatever"
    end

the "@foo" will be replaced with the directory where Fig has the foo package
stored.

Due to Fig internals, the command-line will be split on whitespace and
reassembled with single spaces, so you can't get a whitespace character into
your program.

## `config`

A grouping of statements that specifies what is to be done.  There must either
be a configuration named "default" or you will always have to specify a
configuration on the command-line.

### Syntax

    config something
      set ...
      add ...
      include ...
      command ...
    end

May not be nested.  If you wish to incorporate the effects of one configuration
into another, use an `include` statement.

## `include`

Can be used in two ways: to affect configurations and to declare package
dependencies.

### Pull one configuration into another

You can get the effects of one configuration in another by using the name of
the other configuration preceded by a colon:

    config a
      include :b
    end

    config b
      ...
    end

### Declare a package dependency

States that one package should be installed prior to the current one; can
specify a configuration in the other package.

    config default
      include somepackage/1.2.3:some_non_default_configuration
    end

Dependency version conflicts can be resolved by using `override` clauses.

Say you've got a "base-dependency" package.  Then, in the `package.fig` for
"middle-dependency-a" you have

    config default
      include base-dependency/1.2.3
    end

And in the `package.fig` for "middle-dependency-b" you have

    config default
      include base-dependency/3.2.1
    end

Finally, in the `package.fig` for the package you're working on you've got

    config default
      include middle-dependency-a
      include middle-dependency-b
    end

This will produce a conflicting requirement on "base-dependency".  Resolve this
by either matching the version of one dependency to another:

    config default
      include middle-dependency-a override base-dependency/3.2.1
      include middle-dependency-b
    end

Or specify the same version to both:

    config default
      include middle-dependency-a override base-dependency/2.2.2
      include middle-dependency-b override base-dependency/2.2.2
    end

Multiple `override` clauses can be specified in a single `include` statement.

### Syntax

    config something
      include package-descriptor [override package/version [...]]
    end

## `path`

Synonym for `add`.

## `resource`

Specifies either a URL or a local path (that will have file globbing performed
on it) that is supposed to be incorporated into the package.  This is different
from an `archive` in that the contents will not be extracted as part of
installation.  If the value is a local path, then file globbing will be
performed on it, allowing you to do things like include all jar files below a
directory, e.g. "`resource jars/**/*.jar`".

### Syntax

    resource URL
    resource local/path

## `retrieve`

Specifies where, relative to the current directory, to copy files from packages
when an environment variable is modified.

### Syntax

    retrieve VARIABLE->some/path

Note that there is no whitespace allowed around the "`->`".

### Reason for existence

Fig would prefer to keep the files for all dependencies in the local repository
and have your code find the actual locations via environment variables.  The
reason that this kind of statement exists is to support tools that manage their
own runtime environments, e.g. IDEs.  If you have no need for such programs,
then you don't need this kind of statement.  If you are in such a situation,
you will need to point your program configuration to the correct locations
within your project directory and you will want to periodically do:

    cd base/directory/for/project
    fig --update

### Conditions in which statement will be processed

For a retrieve to do anything, the environment variable that it refers to must
be manipulated in a way that requires variable expansion.

If nothing uses the environment variable indicated by the statement, the
statement will have no effect.  So, given a package.fig like

    retrieve CLASSPATH->some/path/to/copy/jar/files/to
    config default
      set FOO=BAR
      add WHATEVER=some/path
    end

no copying will happen because no manipulation of the CLASSPATH environment
variable is done.

Even if the variable is referenced, the statement will have no effect if the
variable doesn't require any expansion, which is always the case within a
package with no prerequisites, e.g.

    # Not going to do any copying here, either.
    retrieve CLASSPATH->some/path/to/copy/jar/files/to
    config default
      set CLASSPATH=whatever
    end

The simplest form of a retrieve that will actually execute something looks like
the following.  You need to have a prerequisite package that manipulates the
variable in a way that requires expansion:

    config default
      add CLASSPATH=@/some.jar
    end

And then you need to depend upon that:

    retrieve CLASSPATH->from-dependent
    config default
      include prerequisite/1
    end

Also, only retrieve statements in the base package (whether the package.fig in
the current directory or from a package descriptor specified on the command
line) will have any effect.  So, if you have a package "prerequisite" with the
following

    retrieve CLASSPATH->from-prerequisite
    config default
      set CLASSPATH=@/whatever
    end

and a package.fig in the current directory like

    config default
      include prerequisite/1
    end

then no copying will take place despite the CLASSPATH variable being set.

### Other

Substitution of the string "[package]" is done.

## `set`

Specifies the value of an environment variable.  Unlike `add`/`append`/`path`,
this is the complete value.

### Syntax

    config something
      set VARIABLE=value
    end

No whitespace is allowed around the equals sign.  The value can be empty.  No
whitespace is allowed in the value.  At sign ("@") and retrieve variable
substitution is done on the value.

Querying Fig Net Effects
========================

If you've got a long chain of dependencies of packages, it can be challenging
to figure out the full effects of it.  There are a number of commands for just
figuring out what's going on.

## `--list-dependencies`

This will give you the total set of packages you're pulling in.

For example, if you have package A which depends upon packages B and C
which both depend upon package D, running

    fig --list-dependencies A/1.2.3

will give you

    B/2.3.4
    C/3.4.5
    D/4.5.6

If there are no dependencies and stdout is connected to a terminal you'll get:

    fig --list-dependencies package-with-no-dependencies/1.2.3

    <no dependencies>

However, if stdout is not connected to a terminal:

    fig --list-dependencies package-with-no-dependencies/1.2.3 | cat

    [no output]

## `--list-variables`

This gives you the environment variables and their values that Fig
adds/overrides from the environment variables inherited by the invoking program
(e.g. shell, `cron`, etc.).

Say you've got package A that looks like

    config default
        set FOO=from_a
        set BAR=from_a

        include B/1.2.3
    end

and package B that looks like

    config default
        set BAR=from_b
    end

then running

    fig --list-variables A/1.2.3

will give you

    BAR=from_b
    FOO=from_a

Note that the output of `--list-variables` _only_ includes variables that Fig
actually changes.  If you want to see the net environment produced by Fig, do
something like this:

    fig ... -- printenv | sort

## Delving deeper

The following apply to both `--list-dependencies` and `--list-variables`.

### `--list-all-configs`, a.k.a. "What's everything I can possibly get?"

Unlike the default behavior which will only look at a single base
configuration, this option will cause Fig to follow all of the dependencies
using all the configurations in the package descriptor or the package.fig file.
This will not follow all configurations in all depended upon packages, only the
ones reachable by one of the configurations in the starting package.

For a simple package.fig file like

    config default
        set FOO=bing
        set BAR=bang

        include blah/1.2.3
    end

    config nondefault
        set BAR=bong
        set BAZ=beng
    end

and package "blah" like

    config default
        FROM_B_DEFAULT=x
    end

    config nondefault
        FROM_B_NONDEFAULT=x
    end

running

    fig --list-variables --list-all-configs

will give you

    BAR
    BAZ
    FOO
    FROM_B_DEFAULT

i.e. all of the variables that can be set via any dependency path starting with
a configuration in the base package.  You only get variable names and not
values because walking a single path through all dependencies cannot be done.

Similarly, using `fig --list-dependencies --list-all-configs` with a
package.fig containing

    config default
        include foo/1.2.3
    end

    config nondefault
        include foo/4.5.6
    end

will emit

    foo/1.2.3
    foo/4.5.6

### `--list-tree`, a.k.a. "Hey, where'd that come from?"

Following the example from `--list-dependencies` above, if you additionally
specify `--list-tree`, you'll get a nested dependency tree:

    fig --list-dependencies --list-tree A/1.2.3

    A/1.2.3
        B/2.3.4
            D/4.5.6
        C/3.4.5
            D/4.5.6

If you don't specify a package descriptor, but you've got a package.fig
file in the current directory with the same dependencies as package A
above, you'll get

    fig --list-dependencies --list-tree

    <unpublished>
        B/2.3.4
            D/4.5.6
        C/3.4.5
            D/4.5.6

For `--list-variables`, if you have package A

    config default
        set A1=blah
        set A2=blah

        include C/1.2.3
        include B/1.2.3
    end

package B

    config default
        set B1=blah
        set B2=blah
    end

and package C

    config default
        set C1=blah
        set C2=blah
    end

and you run `fig --list-variables --list-tree A/1.2.3`, you'll get

    A/1.2.3
    |   A1 = blah
    |   A2 = blah
    '---C/1.2.3
    |       C1 = blah
    |       C2 = blah
    '---B/1.2.3
            B1 = blah
            B2 = blah

You can tell the difference between a `set` statement and a
`add`/`append`/`path` statement by the output indicating the behavior of the
latter kind of statement.  E.g. for a package.fig

    config default
        set    FOO=bing
        append BAR=bong
    end

running `fig --list-variables --list-tree` will get you

    <unpublished>
        BAR = bong:$BAR
        FOO = bing

as a `add`, `append`, or `path` statement will prepend the value to the
existing value of the variable.

Installation and Development
============================

## Installation

    gem install fig

*NOTE*: When installing Fig on Windows you must first have installed the
Development Kit available from http://rubyinstaller.org/downloads. Instructions
for installation of the Development Kit are available at
https://github.com/oneclick/rubyinstaller/wiki/Development-Kit.

## Building the gem

    rake build

## Building a gem for ruby 1.8.7 on Windows

You can no longer use the rakefile to produce this specific gem. You will need
to create a fig.gemspec file manually. Use the list of gem dependencies found
in the rakefile as a guide. There are two specific gems that need to be
depended on: json v 1.4.2 and libarchive-static-ruby186. Also, the spec.files
should specificly list all the source files, pathed from the base directory
of the project.

Community
=========

\#fig on irc.freenode.net

[Fig Mailing List](http://groups.google.com/group/fig-user)

Copyright
=========

Copyright (c) 2009-2012 Matthew Foemmel. See LICENSE for details.
