# Code changes

* ~~Make use of Statement#is_environment_variable?().~~
* ~~Change `URL.is_url?()` to match arbitrary RFC-compliant URLs.~~
* Single-quoted command and retrieve statements that could be unparsed to v0 should be.
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
    * ~~In package definition~~
    * ~~On command-line~~
* Command-line
    * ~~command~~
    * ~~`--command-extra-args`~~
* ~~Retrieve statements~~
* ~~Command statement~~
* Fix all "pending" tests.
* ~~Commands, both command statements and from the command-line.  Handling of quoting with `--command-extra-args` is going to be interesting.~~

### Bugs that may involve breakage post v1.0

* Asset statements have lots of issues with URLs.
    * URLs that involve redirects.
    * URLs that aren't simple protocol://host/path/to/asset, e.g. if they've got query parameters.
* Retrieves should turn unescaped "[" that aren't followed by "package]" into errors.

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
* Document quoting, including the command-line option behaviors, e.g. `--resource 'foo'` vs `--resource "'foo'"` `--resource '"foo"'`.
* Redo all the statement descriptions, including quoting behaviors.
* Describe v0 vs v1 grammars.
* ~~Document "looks like a URL".~~
* Describe retrieve behavior in the presence of symlinks.
* Document application configuration (the "Configuration" page in the wiki).
* Document repository locking.
* Document that command statements are only processed in published packages or with `--run-command-statement`.
* Document that exec(2) with a single command-line component goes through the shell, whereas multiple components do not.
* The whole running commands vs. command-line expansion stuff needs reorganizing.

# Paranoia / things to think about

* ~~Check "@" escapes with `--set`/`--append`.~~
* Look into Simplecov CSV outputter for diffing runs.
* Double check where archives are extracted under the influence of a retrieve.
