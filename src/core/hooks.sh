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
	if [ -n "${_deactivate}" ]
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
	register_core "${_function}" "$(_bashy_hooks_caller_name)" "${_deactivate}"
}

# register_install <install function>
# Remember the installer of the calling plugin, for bashy_install.
function register_install() {
	local _function=$1
	assoc_set _bashy_assoc_install "$(_bashy_hooks_caller_name)" "${_function}"
}

# register_interactive <activate function> [deactivate function]
# Like register, but only in an interactive shell.
function register_interactive() {
	local _function=$1
	local _deactivate=${2:-}
	if is_interactive
	then
		register_core "${_function}" "$(_bashy_hooks_caller_name)" "${_deactivate}"
	fi
}
