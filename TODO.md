* Put spaces into filenames in all the tests.
* Test quoting of asset command-line options.
* Whack wiki asset descriptions.
* Test actual asset globbing/non-globbing of disk files.
* Test that having a # in a value requires v1 grammar.
* Test that v0 grammar results in unquoted "resources.tar.gz" and v1 grammar quotes it.
* Document "looks like a URL".
* Check "@" escapes with `--set`/`--append`.
* Document that command statements are only processed in published packages.
* Double check where archives are extracted under the influence of a retrieve.
* Look into Simplecov CSV outputter for diffing runs.
* Document repository locking.
* Repository class coverage doesn't seem to be hitting resources with URLs.
* Get all the tests' `$PWD` out of `spec/runtime-work` and into `spec/runtime-work/userhome` so that we're properly testing paths to things.  Too many of the tests are counting on files being in `$HOME`.
* Rename not_found_error to something like url_not_found_error
* Clarify "URLs" that are either file-or-URL or proper URLs.
* Make use of Statement#is_environment_variable?.
* Retrieve statements should validate its path the same way that path statements do.
