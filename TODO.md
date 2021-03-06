# Code changes

* Detect

    ```
    config build
        include :build
    end
    ```

* Retrieve statements should validate their paths the same way that path statements do.
* Fix bits of code that that work around pre-Ruby v2 versions.  (Run "`ack -Q 1.9.3`".)
* Produce nice error messages when packages contain file names that Windows can't deal with.
* Periodically `ack '\bTODO:'` and fix what we can.

### Bugs that may involve breakage post v1.0

* Asset statements have lots of issues with URLs.
    * URLs that involve redirects.
    * URLs that aren't simple protocol://host/path/to/asset, e.g. if they've got query parameters.

# Tests

* Test actual asset globbing/non-globbing of disk files
    * Including those with special characters.
    * Test effects of escapes.

# Documentation

* Describe retrieve behavior in the presence of symlinks.

# Paranoia / things to think about

* Look into Simplecov CSV outputter for diffing runs.
* Double check where archives are extracted under the influence of a retrieve.
