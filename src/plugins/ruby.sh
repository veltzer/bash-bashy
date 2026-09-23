function _activate_ruby() {
	local -n __var=$1
	local -n __error=$2
	GEM_HOME="${HOME}/install/gems"
	GEM_HOME_BIN="${GEM_HOME}/bin"
	if ! checkDirectoryExists "${GEM_HOME}" __var __error; then return; fi
	if ! checkDirectoryExists "${GEM_HOME_BIN}" __var __error; then return; fi
	_bashy_pathutils_add_head PATH "${GEM_HOME_BIN}"
	export GEM_HOME
	__var=0
}

function _install_bundler() {
	# the alternative is "gem install bundler", but the distribution packages
	# bring ruby itself along with it
	bashy_install_apt "bundler" "ruby" "ruby-dev" "ruby-bundler"
}

function _uninstall_bundler() {
	bashy_uninstall_apt "bundler" "ruby" "ruby-dev" "ruby-bundler"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_ruby() {
	_bashy_pathutils_remove PATH "${HOME}/install/gems/bin"
	unset GEM_HOME
}

register _activate_ruby _deactivate_ruby
