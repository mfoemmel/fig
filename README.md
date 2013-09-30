Description
===========

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

Full documentation
==================

https://github.com/mfoemmel/fig/wiki

Community
=========

\#fig on irc.freenode.net

[Fig Mailing List](http://groups.google.com/group/fig-user)

Copyright
=========

Copyright (c) 2009-2013 Matthew Foemmel. See LICENSE for details.
