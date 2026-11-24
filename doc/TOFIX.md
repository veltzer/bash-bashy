# TOFIX

Findings from a code scan on 2026-10-04.

## Medium

- `src/plugins/minikube.sh:10` - the `if ! cmd; then __var=$?` pattern stores the status of the negated test, which is always 0 inside the `then` branch (`if ! false; then echo $?; fi` prints 0), so a failed completion/source is recorded as success and `bashy_errors` (`src/bashy.sh:271`, `result = 0` means ok) never shows it. The same bug is in `bash_completions_system.sh:9,18`, `bash_it.sh:56`, `eksctl.sh:14`, `fzf.sh:13`, `google_cloud_sdk.sh:10,17`, `kurtosis.sh:9`, `ng.sh:8`, `nvm.sh:11,18`, `oc.sh:10`, `powerline.sh:18`, `pureline.sh:14`, `python_venv.sh:15`, `rvm.sh:15`, `starship.sh:10`, `system_default_bashrc.sh:10` and `virtualenvwrapper.sh:33`; set `__var=1` as `bash_completions_prog.sh:11` does, and add a test for a failing activation.
- `src/plugins/rvm.sh:16` - assigns the message to `_error` (single underscore), a stray global, instead of the `__error` nameref, so the reason is lost; use `__error`.

## Low

- `src/plugins/rvm.sh:10` - exports a hardcoded `RUBY_VERSION="2.3.3"` (a long-EOL Ruby) on every activation with no comment, against the "never hardcode a version" rule in `CLAUDE.md:20`; drop it and let rvm's own default/`.ruby-version` decide, or document why it is pinned.
- `src/plugins/eksctl.sh:15` - error message says `eskctl`; fix the typo.
- `src/plugins/powerline-shell.sh:14` - uses the external `which` (also `pypowerline.sh:16`), forking a process and depending on a non-POSIX tool; use the `command -v` builtin instead.
- `doc/design.txt:28` - says "An installer is a plain bash function with no parameters", but every installer takes `--force` through `bashy_install_args "$@"` (`src/core/install.sh:68`, README "Writing an installer"); update the sentence.
