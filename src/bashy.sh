# The is the main entry point of bashy
#
# Here is the general flow here:
#
# _bashy_load_core - loads core functions under ~/.bashy/core/*.sh
# _bashy_read_plugins - reads which plugins you want loaded
# 	from either ~/.bashy.list or ~/.bashy/bashy.list
# _bashy_load_plugins - loads the plugins you wanted from
# 	~/.bashy/plugins
# 	and
# 	~/.bashy_extra
# _bashy_run_plugins - runs the plugins
#
# Writing bashy plugin:
# - each plugin should be independent and handle just one issue.
# - plugins should not really do anything when sourced, just register
# functions to be called later.
# - order among plugins will be according to their order in bashy.list.
# - plugins are in charge of their own error handling. The plugins are
# run with 'set +e'. The reason is that forcing 'set -e' on all plugins
# is a really bad design descision.

# The core modules are loaded in this order rather than alphabetically, so that a
# module can just call into the ones before it. It goes from the standalone
# building blocks to the modules that build on top of them:
#
#   source                bootstrap, everything else is loaded through it
#   null .. version       standalone, they depend on nothing
#   assoc .. hooks        each one uses modules listed above it
#
# Add a new module wherever its dependencies are already satisfied. Anything not
# named here still gets loaded afterwards, so a forgotten module is not fatal.

# Where bashy lives: the folder holding this file. Everything else (core,
# plugins, bashy.list) is found relative to it, so bashy runs the same from
# ~/.bashy and from a source checkout. Sourced as a bare "bashy.sh" there is no
# slash to strip, which is what the second line is for.
_BASHY_HOME="${BASH_SOURCE[0]%/*}"
if [ "${_BASHY_HOME}" = "${BASH_SOURCE[0]}" ]
then
	_BASHY_HOME="."
fi

bashy_core_order=(
	# standalone building blocks
	null
	assert
	array
	var
	log
	misc
	color
	pathutils
	errexit
	float
	git
	measure
	profile
	version
	install
	completion
	# these use the modules above
	assoc
	check
	python
	download
	hooks
)

function _bashy_load_core() {
	# cannot use _bashy_source_absolute function here since it is still not loaded (bootstrap problem)
	# shellcheck source=/dev/null
	source "${BASH_SOURCE%/*}/core/source.sh"
	local _dir="${BASH_SOURCE%/*}/core"
	# named modules first, in dependency order, then anything left over
	local _ordered=()
	local _module
	for _module in "${bashy_core_order[@]}"; do
		if [ -r "${_dir}/${_module}.sh" ]; then
			_ordered+=("${_dir}/${_module}.sh")
		fi
	done
	local _f
	for _f in "${_dir}"/*.sh; do
		local _base="${_f##*/}"
		_base="${_base%.sh}"
		if [ "${_base}" = "source" ]; then
			continue
		fi
		# array.sh is not loaded yet at this point, so check by hand
		local _known=1
		for _module in "${bashy_core_order[@]}"; do
			if [ "${_module}" = "${_base}" ]; then
				_known=0
				break
			fi
		done
		if [ "${_known}" -ne 0 ]; then
			_ordered+=("${_f}")
		fi
	done
	for f in "${_ordered[@]}"; do
		local _name="${f##*/}"
		_name="${_name%%.*}"
		bashy_core_names+=("${_name}")
		local _result=0
		_bashy_source_absolute "${f}" || _result=1
		bashy_core_res+=("${_result}")
	done
}

function _bashy_read_plugins_filename() {
	local filename=$1
	local line plugin enabled
	while read -r line; do
		if [[ "${line}" =~ ^#.* ]]; then
			continue
		fi
		if [[ "${line}" =~ ^[[:space:]]*$ ]]; then
			continue
		fi
		if [[ "${line}" =~ ^-.* ]]; then
			plugin="${line:1}"
			enabled=0
		else
			plugin="${line}"
			enabled=1
		fi
		_bashy_array_push bashy_array_plugin "${plugin}"
		assoc_set bashy_assoc_enabled "${plugin}" "${enabled}"
		# read returns false on a final line that has no trailing newline, which silently
		# dropped the last plugin of a hand edited list. Appending a newline to the
		# stream costs nothing and makes the last line arrive like any other.
	done < <(
		cat "${filename}"
		echo
	)
}

function _bashy_read_plugins() {
	local filename="${_BASHY_HOME}/bashy.list"
	_bashy_read_plugins_filename "${filename}"
	filename="${HOME}/.bashy.list"
	if [ -f "${filename}" ]; then
		_bashy_read_plugins_filename "${filename}"
	fi
}

function _bashy_load_plugins() {
	local plugin current_filename
	for plugin in "${bashy_array_plugin[@]}"; do
		current_filename="${_BASHY_HOME}/plugins/${plugin}.sh"
		if [[ -r "${current_filename}" ]]; then
			assoc_set bashy_assoc_found "${plugin}" 1
			assoc_set bashy_assoc_filename "${plugin}" "${current_filename}"
		else
			current_filename="${HOME}/.bashy_extra/${plugin}.sh"
			if [[ -r "${current_filename}" ]]; then
				assoc_set bashy_assoc_found "${plugin}" 1
				assoc_set bashy_assoc_filename "${plugin}" "${current_filename}"
			else
				assoc_set bashy_assoc_found "${plugin}" 0
				continue
			fi
		fi
		bashy_log "core/bashy" "${BASHY_LOG_DEBUG}" "loading [${plugin}]"
		_bashy_source_absolute "${current_filename}"
		assoc_set bashy_assoc_source "${plugin}" "$?"
	done
}

function _bashy_load_config() {
	local bashy_config="${HOME}/.bashy.config"
	if [ -f "${bashy_config}" ]; then
		# cannot use _bashy_source_absolute function here since it is still not loaded
		# shellcheck source=/dev/null
		source "${bashy_config}"
	fi
}

function _bashy_run_plugins() {
	local function
	for function in "${_bashy_array_function[@]}"; do
		local plugin
		assoc_get _bashy_assoc_function plugin "${function}"
		local enabled
		assoc_get bashy_assoc_enabled enabled "${plugin}"
		if [[ "${enabled}" = 0 ]]; then
			bashy_log "core/bashy" "${BASHY_LOG_DEBUG}" "${plugin} disabled"
			continue
		fi
		bashy_log "core/bashy" "${BASHY_LOG_DEBUG}" "running function [${function}]"
		if is_step; then
			read -rn 1
		fi
		if is_profile; then
			local result=
			local error=""
			local _diff=
			measure _diff "${function}" result error
			assoc_set bashy_assoc_result "${plugin}" "${result}"
			assoc_set bashy_assoc_error "${plugin}" "${error}"
			assoc_set bashy_assoc_diff "${plugin}" "${_diff}"
		else
			local result=
			local error=""
			"${function}" result error
			assoc_set bashy_assoc_result "${plugin}" "${result}"
			assoc_set bashy_assoc_error "${plugin}" "${error}"
			assoc_set bashy_assoc_diff "${plugin}" "NO_PROFILE"
		fi
	done
}

function bashy_status_core() {
	local i name res
	((i = 0))
	for name in "${bashy_core_names[@]}"; do
		_bashy_cecho gr "${name}" 1
		res="${bashy_core_res[${i}]}"
		if [ "${res}" = 0 ]; then
			_bashy_cecho g "\tOK" 0
		else
			_bashy_cecho r "\tERROR" 0
		fi
		((i++))
	done | column -t
}

# show status of plugins and their init success.
# this is different than file status since if a file
# failed to load it may not have installed any plugin
# handlers which may have succeeded in initializing
# or not
function bashy_status_plugins() {
	local plugin
	for plugin in "${bashy_array_plugin[@]}"; do
		_bashy_cecho gr "${plugin}" 1
		local enabled
		assoc_get bashy_assoc_enabled enabled "${plugin}"
		if [[ "${enabled}" = 1 ]]; then
			_bashy_cecho g "\tEN" 1
		else
			_bashy_cecho y "\tDI" 1
		fi
		local found
		assoc_get bashy_assoc_found found "${plugin}"
		if [[ "${found}" = 1 ]]; then
			_bashy_cecho g "\tFOUND_OK" 1
		else
			_bashy_cecho r "\tFOUND_ERROR" 1
			continue
		fi
		# local filename
		# assoc_get bashy_assoc_filename filename "${plugin}"
		# if [[ $filename = 0 ]]
		# then
		# 	_bashy_cecho r "\tNO_FILENAME" 1
		# else
		# 	_bashy_cecho gr "\t${filename}" 1
		# fi
		if [[ "${enabled}" = 1 ]]; then
			local source
			assoc_get bashy_assoc_source source "${plugin}"
			if [[ "${source}" = 0 ]]; then
				_bashy_cecho g "\tLOAD_OK" 1
			else
				_bashy_cecho r "\tLOAD_ERROR" 1
			fi
			local result
			assoc_get bashy_assoc_result result "${plugin}"
			if [[ "${result}" = 0 ]]; then
				_bashy_cecho g "\tRESULT_OK" 1
			else
				_bashy_cecho r "\tRESULT_ERROR" 1
			fi
			if is_profile; then
				local _diff
				assoc_get bashy_assoc_diff _diff "${plugin}"
				printf "\t%s\n" "${_diff}"
			else
				echo
			fi
		else
			_bashy_cecho y "\tNOT_LOADED" 1
			_bashy_cecho y "\tNO_RESULT" 1
			_bashy_cecho y "\tNO_TIME" 0
		fi
	done | column -t
}

function bashy_errors() {
	local i plugin
	((i = 0))
	for plugin in "${bashy_array_plugin[@]}"; do
		local enabled
		assoc_get bashy_assoc_enabled enabled "${plugin}"
		if [[ "${enabled}" = 0 ]]; then
			bashy_log "core/bashy" "${BASHY_LOG_DEBUG}" "${plugin} disabled"
			continue
		fi
		local result
		assoc_get bashy_assoc_result result "${plugin}"
		if [[ "${result}" = 0 ]]; then
			bashy_log "core/bashy" "${BASHY_LOG_DEBUG}" "${plugin} succeeded"
			continue
		fi
		local error
		assoc_get bashy_assoc_error error "${plugin}"
		_bashy_cecho r "${plugin} - [${error}]\n" 1
		((i++))
	done
}

function bashy_internal_print() {
	_bashy_array_print bashy_array_plugin
}

function bashy_off() {
	if [ -f "${HOME}/.bashy.disable" ]; then
		echo "bashy is already off"
	else
		touch "${HOME}/.bashy.disable"
		echo "turned bashy off"
	fi
}

function bashy_on() {
	if [ -f "${HOME}/.bashy.disable" ]; then
		rm "${HOME}/.bashy.disable"
		echo "turned bashy on"
	else
		echo "bashy is already on"
	fi
}

function bashy_version() {
	echo "${BASHY_VERSION_STR}"
}

# bashy_check_deployment [source checkout]
# Compare the running bashy against a checkout of the repository and say what
# differs. A deployment that has drifted from the source is otherwise invisible:
# everything keeps working, just not with the code you think you are running.
#
# The argument is the root of the checkout, the folder holding src/ and
# scripts/. Without one the usual places are tried.
function bashy_check_deployment() {
	local source_dir=${1:-}
	if [ -z "${source_dir}" ]
	then
		local candidate
		for candidate in "${REPOS_FOLDER:-${HOME}/git}/bash-bashy" "${REPOS_FOLDER:-${HOME}/git}/veltzer/bash-bashy" "${HOME}/bash-bashy"
		do
			if [ -r "${candidate}/src/bashy.sh" ]
			then
				source_dir="${candidate}"
				break
			fi
		done
	fi
	if [ -z "${source_dir}" ] || [ ! -r "${source_dir}/src/bashy.sh" ]
	then
		echo "no bashy checkout found, pass one: bashy_check_deployment <checkout>"
		return 1
	fi
	local src="${source_dir}/src"
	echo "comparing [${_BASHY_HOME}] against [${src}]"
	local source_version
	source_version=$(sed -n 's/^export BASHY_VERSION_STR="\(.*\)"/\1/p' "${src}/core/version.sh" 2>/dev/null)
	if [ -n "${source_version}" ] && [ "${source_version}" != "${BASHY_VERSION_STR}" ]
	then
		echo "  version: running ${BASHY_VERSION_STR}, source ${source_version}"
	fi
	local differing
	differing=$(
		diff --recursive --brief "${src}/core" "${_BASHY_HOME}/core" 2>&1
		diff --recursive --brief "${src}/plugins" "${_BASHY_HOME}/plugins" 2>&1
		diff --brief "${src}/bashy.sh" "${_BASHY_HOME}/bashy.sh" 2>&1
		diff --brief "${src}/bashy.list" "${_BASHY_HOME}/bashy.list" 2>&1
	)
	if [ -z "${differing}" ]
	then
		echo "  up to date"
		return 0
	fi
	printf '  %s\n' "${differing}"
	echo "  run ${source_dir}/scripts/install_in_home.sh to update"
	return 1
}

# bashy_install <plugin>
# Run the installer a plugin registered with register_install.
function bashy_install() {
	local plugin=$1
	local installer
	assoc_get _bashy_assoc_install installer "${plugin}"
	if _bashy_null_is_null "${installer}"
	then
		echo "no installer registered for [${plugin}]"
		return 1
	fi
	"${installer}"
}

# bashy_deactivate <plugin>
# Run the deactivate function a plugin registered alongside its activate one.
function bashy_deactivate() {
	local plugin=$1
	local deactivate
	assoc_get _bashy_assoc_deactivate deactivate "${plugin}"
	if _bashy_null_is_null "${deactivate}"
	then
		echo "[${plugin}] has no deactivate function"
		return 1
	fi
	"${deactivate}"
}

function _bashy_init() {
	_bashy_load_config
	if [ -f "${HOME}/.bashy.disable" ]; then
		return
	fi
	declare -ga bashy_core_names
	declare -ga bashy_core_res
	_bashy_load_core
	declare -ga _bashy_array_function
	assoc_new _bashy_assoc_function
	assoc_new _bashy_assoc_deactivate
	assoc_new _bashy_assoc_install
	declare -ga bashy_array_plugin
	assoc_new bashy_assoc_found
	assoc_new bashy_assoc_filename
	assoc_new bashy_assoc_source
	assoc_new bashy_assoc_result
	assoc_new bashy_assoc_error
	assoc_new bashy_assoc_diff
	assoc_new bashy_assoc_enabled
	bashy_log "core/bashy" "${BASHY_LOG_DEBUG}" "bashy_starting"
	_bashy_read_plugins
	_bashy_load_plugins
	_bashy_run_plugins
	bashy_log "core/bashy" "${BASHY_LOG_DEBUG}" "bashy_ending"
	# bashy_errors
}

# now run _bashy_init
# we don't want to force the user to do anything more than source ~/.bashy/bashy.sh
# in his ~/.bashrc, so we do this automatically
_bashy_init
