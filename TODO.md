# Code changes

* ~~Make use of Statement#is_environment_variable?().~~
* ~~Change `URL.is_url?()` to match arbitrary RFC-compliant URLs.~~
* Bad URLs (FIG_REMOTE_URL, asset paths) will result in ugly stack traces; need to turn these into reasonable error messages.
* Retrieve statements should validate their paths the same way that path statements do.
* Produce nice error messages when packages contain file names that Windows can't deal with.
* Periodically `ack '\bTODO:'` and fix what we can.

## v1.0

Whitespace/quoting stuff in order to have a working command line.  It is currently possible to publish packages using `--set`/`--append`/`--resource`/`--archive` that can't be parsed.

* ~~Need to adjust v0 grammar to allow characters in file names that are not allowed by Windows.~~
* ~~Multiple places directly instantiate Unparser::V0.  Need to have a central place to determine unparse grammar.~~
* Asset statements
    * ~~In package definition~~
    * ~~On command-line~~
* Environment variable statements
    * In package definition
    * On command-line
* Fix all "pending" tests.
* Quoting of retrieves: post 1.0? Although... this really should work along with environment variable statements.  Need to figure out escaping of "[package]".
* Commands need to be specified as individual components, i.e. if we get a command with four arguments, even if they contain whitespace, then the command should receive four arguments.

### Bugs that may involve breakage post v1.0

* Asset statements have lots of issues with URLs.
    * URLs that involve redirects.
    * URLs that aren't simple protocol://host/path/to/asset, e.g. if they've got query parameters.

# Tests

* Put spaces into filenames in all the tests.  Can't do this until environment variable statements can handle whitespace.
* Test actual asset globbing/non-globbing of disk files
    * Including those with special characters.
    * Test effects of escapes.
* Test that v0 grammar results in double-quoted "resources.tar.gz" and v1 grammar single quotes it.
* Get all the tests' `$PWD` out of `spec/runtime-work` and into `spec/runtime-work/userhome` so that we're properly testing paths to things.  Too many of the tests are counting on files being in `$HOME`.
* Resource statements in published packages, particularly pointing to URLs. Resource statements containing URLs won't exist in any newly published packages, but they do in old ones.
* ~~Should be able to read a v1 package.fig with a resource with "#" in it and then publish using v0.~~
* ~~Serious testing of which grammar version stuff gets unparsed into.~~

# Documentation

* Clarify "URLs" that are either file-or-URL or proper URLs.
* Whack wiki asset descriptions, including quoting behaviors.
* ~~Document "looks like a URL".~~
* Describe retrieve behavior in the presence of symlinks.
* Document repository locking.
* Document that command statements are only processed in published packages or with `--run-command-statement`.
* Document quoting, including the command-line option behaviors, e.g. `--resource 'foo'` vs `--resource "'foo'"` `--resource '"foo"'`.

# Paranoia / things to think about

* Check "@" escapes with `--set`/`--append`.
* Look into Simplecov CSV outputter for diffing runs.
* Double check where archives are extracted under the influence of a retrieve.
