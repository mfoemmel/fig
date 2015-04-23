**Problem being solved:** Dealing with differently compiled versions of the same
package.

People have tried using various macro packages for producing Fig packages and
had issues with build droppings and various intermediary artifacts to be
ignored.

**Proposed solution:** Adding variables to Fig (separate from the environment
variables it now supports).  These could be substituted into package
descriptors, retrieve paths, asset paths, environment variable values,
commands, etc.

# Restrictions

## Names

The usual alphanumeric plus underscore.

## Values

Unrestricted, but post-expansion, would need to fit the rules of whatever it
was substituted into, e.g. in package descriptors, the value of a variable
could only contain alphanumerics, underscore, hyphen, or period.

## Scope

Because we'd be using the values of variables in file-scoped statements (assets
and retrieves), these would have to be globally scoped.

## Lifetime

Because these values are going to end up baked into assets, variables values
will be expanded at package publishing time, and variables will thus not exist
in published packages.  Due to this and the minimum version grammar publishing
already in place, published packages will continue to be compatible with people
using paleolithic versions of Fig.


# Syntax

## Definition

Since the term "set" is already used for environment variables and so that we
can mimic other tools "-D" options, I'm thinking we use the term "define" for
Fig variables.  I don't think we're going to need any path variable behavior,
so there's no need for an "add"/"path"/"append" equivalent.

### In package.fig / application.fig:

Pretty obvious, similar to an environment variable statement, but file scoped:

    grammar v3

    define gcc_version=4.9.0
    define pen_colors="red blue black"
    define neopolitan='vanilla chocolate strawberry'
    …

### On the command-line:

Following the usual scheme for options:

    fig --define foo=bar …
    fig -D lib_version=9.3-with_frobnication …


## Reference

Since we've got `command` statements to consider, I want to avoid anything that
is confusable with shell syntax, so leading dollar sign and curly braces as
delimiters are out.  Also with `command` statements, there is what I consider
the confusing "@packagename" expansion to worry about; I want there to be an
actual delimiter.  The at sign already has multiple meanings, so that can't be
used.

Since we've got to worry about glob characters in asset statements, I'm
thinking of going with parentheses as delimiters.  Percent signs seem to be
common with macro/templating systems, so why not go with that as the sigil?

Expansion can be prevented via quoting or escaping the sigil.

Whether a variable is defined on the command-line or in a file shouldn't matter
for expansion.

Fig variable expansion will happen as the first thing in statement
interpretation, which means that at signs in Fig variables that are used in
values of environment variables will be expanded.

### In package.fig / application.fig:

Things that should work fine:

    grammar v3

    define original=y
    define bare=x%(original)z            # Sets bare to "xyz"
    define double_quoted="x%(original)z" # Sets double_quoted to "xyz"
    define single_quoted='x%(original)z' # Sets single_quoted to "x%(original)z"
    define escaped=x\%(original)z        # Sets escaped to "x%(original)z"

    define project_version=1.3.7
    define redhat_version=6.3
    define gcc_version=4.7.1
    define frobnication_provider=thingy/3.7.21beta

    resource mylib.%(project_version).gcc%(gcc_version)/lib/*.{so,dylib}

    retrieve LIBPATH->lib/gcc%(gcc_version)/[package]/

    config default
        override boost/1.51.0.redhat%(redhat_version).gcc%(gcc_version)
        include  %(frobnication_provider)

        set PRODUCT_VERSION=%(project_version)
        add CLASSPATH=@/%(project_version)/lib/product-%(project_version).jar

        command
            echo @ @%(frobnication_provider) %(project_version) '%(something quoted)'
        end
    end

Broken things:

    grammar v3

    define x=%(undefined_variable)  # No shell-like defaulting to the empty
                                    # string.
    define x=%()                    # Syntax error: no variable name.
    define x=% (something)          # Syntax error: space between sigil and
                                    # delimiter.
    define x='% (something)'        # Fine, since this is setting to a literal
                                    # string and not to a reference to another
                                    # variable.
    define x=%(%(something))        # Syntax error: we are not going down the
                                    # symbolic name rabbit hole.

    define foo='blah blah'
    config whatever
        include %(foo)              # "blah blah" is not a valid package
                                    # descriptor.
    end

### On the command-line:

    # Yes, this may be a silly example…
    fig --define package_descriptor=foo/1.2.3:someconfig '%(package_descriptor)'

    # … but I can certainly see something like…
    fig --publish 'mything/1.2.3.gcc%(gcc_version)' --define gcc_version=4.7.1 \
        --append 'LIBPATH=@/lib.gcc%(gcc_version)/' \
        --resource '**/*.gcc%(gcc_version).so'

    fig --define something=whatever --set "EXPANDED=%(something)" \
        --set "UNEXPANDED='%(something)'"
