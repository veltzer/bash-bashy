# hook subsystem of bashy
#
# A plugin registers the function bashy should run to activate it, and may also
# hand over a function that undoes that ("deactivate") and one that installs the
# tool it wraps ("install"). Activation functions run at startup, in registration
# order. The other two are only ever run on demand, through bashy_deactivate and
# bashy_install, so they are kept by plugin name rather than in the run list.

# register_core <activate function> <plugin name> [deactivate function]
function register_core() {
	local _function=$1
	local _name=$2
	local _deactivate=${3:-}
	assoc_assert_key_not_exists _bashy_assoc_function "${_function}"
	_bashy_array_push _bashy_array_function "${_function}"
	assoc_set _bashy_assoc_function "${_function}" "${_name}"
	if [[ -n "${_deactivate}" ]]
	then
		assoc_set _bashy_assoc_deactivate "${_name}" "${_deactivate}"
	fi
}

# the plugin name is the basename of the file that called us, minus its suffix
function _bashy_hooks_caller_name() {
	local _name="${BASH_SOURCE[2]##*/}"
	echo "${_name%.*}"
}

# register <activate function> [deactivate function]
function register() {
	local _function=$1
	local _deactivate=${2:-}
	local _caller
	_caller=$(_bashy_hooks_caller_name)
	register_core "${_function}" "${_caller}" "${_deactivate}"
}

# register_install <install function>
# Remember the installer of the calling plugin, for bashy_install.
function register_install() {
	local _function=$1
	local _caller
	_caller=$(_bashy_hooks_caller_name)
	assoc_set _bashy_assoc_install "${_caller}" "${_function}"
	_bashy_hooks_guard_installer "${_function}"
}

# _bashy_hooks_guard_installer <install function>
# Make a direct call of a registered installer (say "_install_gh" typed at the
# prompt) fail like a run through bashy_install does when the latest version
# cannot be determined. The installer itself cannot report that: its
# "if bashy_install_check ...; then return; fi" returns 0, so the failure is
# only recorded in BASHY_INSTALL_FAILED and read back by bashy_install_run.
# So the installer is moved to _bashy_orig<name> and <name> becomes a thin
# wrapper that runs it through bashy_install_run. This is the one place every
# plugin passes through, so no plugin needs to know. A function that does not
# exist (yet) is left alone, and a function that is already the wrapper (the
# plugin was sourced twice) is not wrapped again. Never exits.
function _bashy_hooks_guard_installer() {
	local _function=$1
	local _body
	_body=$(declare -f "${_function}") || return 0
	if [[ "${_body}" == *"bashy_install_run _bashy_orig${_function} "* ]]
	then
		return 0
	fi
	eval "_bashy_orig${_body}"
	eval "${_function}() { bashy_install_run _bashy_orig${_function} \"\$@\"; }"
}

# register_interactive <activate function> [deactivate function]
# Like register, but only in an interactive shell.
function register_interactive() {
	local _function=$1
	local _deactivate=${2:-}
	if is_interactive
	then
		local _caller
		_caller=$(_bashy_hooks_caller_name)
		register_core "${_function}" "${_caller}" "${_deactivate}"
	fi
}
