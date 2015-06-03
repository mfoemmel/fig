- `sftp:` URLs are subject to https://github.com/net-ssh/net-sftp/issues/27.
- Packages containing symlinks fail to install on Windows.  libarchive doesn't corectly report them as symlinks.
- Bad values in `FIG_HOME` and `FIG_REMOTE_URL` produce nasty errors.
- The internal storage for home directory layouts in v2 format don't take the
  value of `FIG_REMOTE_URL` into account, meaning that, if you switch
  `FIG_REMOTE_URL` without also switching `FIG_HOME`, "fun" things can happen.
- URLs with query parameters or involve redirects are untested.
- Repository locking doesn't happen on Windows.
