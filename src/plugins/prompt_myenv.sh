# This script manages your python virtual envrionment for you.
#
# Here is what it does:
# - Whenever you 'cd' into a directory it will activate the right
# virtual env for you.
# - If a virtual env was not created, it will automatically create
# one for you.
# - If a virtual env falls out of sync with the 'requirements.txt'
# file which was used to create it then it will be re-created.
# This is done by comparing the md5 checksum of the 'requirements.txt'
# file and a checksum which is stored inside each created virtual
# environment.
# - to recreate the venvs for a bunch for folders activate
# myenv_recreate in each the folders. It *is not* enough to just
# cd into these folders as part of a command line since then
# prompt_myenv will not be activated.
#
# Below are APIs to the general public - do not break them.
#
# How to force creation of a virual env:
# $ myenv_create
# How to recreate a environment if need be:
# $ myenv_recreate
#
# TODO: (this is a the TODO list for myenv until it becomes
# a project on it's own)
# - when i'm inside a git repos ".git" folder myenv still does git
# commands and I get an error since you are not supposed to use these
# git commands when you're in the ".git" folder.
# - the md5 must be make out of the requirements and the python version.
# we once had the myenv configuration file added to requirements
# but this is wrong since there could be many myenv configuration files.
# we just want the python version and the requirements.txt file.
# - do not read the config again if the data of the myenv config files
# did not change (performance enhancement).
# - make a config which controls how myenv decides whether to keep the
# venv or not. This way we can enable to keep the venv active when we
# are within the .myenv directory to any depth.

: "${BASHY_LOG_INFO:?BASHY_LOG_INFO must be set, core/log.sh must be loaded first}"
: "${BASHY_LOG_ERROR:?BASHY_LOG_ERROR must be set, core/log.sh must be loaded first}"
: "${BASHY_LOG_DEBUG:?BASHY_LOG_DEBUG must be set, core/log.sh must be loaded first}"

myenv_conf_file_name=".myenv"
myenv_md5_file_name="md5sum"

function myenv_getconf() {
	assoc_new myenv_conf
	export myenv_conf

	# first read the configuration from the home folder
	export myenv_home_conf_file="${HOME}/${myenv_conf_file_name}"
	if [ -r "${myenv_home_conf_file}" ]
	then
		assoc_config_read myenv_conf "${myenv_home_conf_file}"
	fi

	# next step over it with local configuration
	if [ -r "${myenv_conf_file_name}" ]
	then
		assoc_config_read myenv_conf "${myenv_conf_file_name}"
	fi

	# get all the other parameters from the config
	export myenv_virtual_env_python
	export myenv_virtual_env_name
	export myenv_virtual_env_requirement_files

	# general myenv parameters
	export myenv_virtual_env_auto_create
	export myenv_virtual_env_auto_activate
	export myenv_virtual_env_auto_deactivate

	assoc_get myenv_conf myenv_virtual_env_python "virtual_env_python"
	assoc_get myenv_conf myenv_virtual_env_name "virtual_env_name"
	assoc_get myenv_conf myenv_virtual_env_folder "virtual_env_folder"
	assoc_get myenv_conf myenv_virtual_env_requirement_files "virtual_env_requirement_files"

	assoc_get myenv_conf myenv_virtual_env_auto_create "virtual_env_auto_create"
	assoc_get myenv_conf myenv_virtual_env_auto_activate "virtual_env_auto_activate"
	assoc_get myenv_conf myenv_virtual_env_auto_deactivate "virtual_env_auto_deactivate"

	# calculate variables from other variables

	# turn to array
	read -r -a myenv_virtual_env_requirement_files <<< "${myenv_virtual_env_requirement_files}"
	# set the folder to the virtual env
	if [ -z "${myenv_virtual_env_folder}" ]
	then
		# export myenv_virtual_env_folder="${HOME}/.virtualenvs/${myenv_virtual_env_name}"
		export myenv_virtual_env_folder=".venv/${myenv_virtual_env_name}"
	fi
	# the the python version used (could be used for powerline)
	export myenv_virtual_env_python_version
	python_version_short myenv_virtual_env_python_version "${myenv_virtual_env_python}"
}

function myenv_create_virtualenv() {
	# do not create virtualenv if there are error files
	if [ -f .myenv.virtualenv.errors ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_ERROR}" "not creating virtual env because error file [.myenv.virtualenv.errors] exits"
		return 1
	fi

	# create a virtual env
	bashy_log "prompt_myenv" "${BASHY_LOG_INFO}" "creating new venv in [${myenv_virtual_env_folder}]"
	rm -rf "${myenv_virtual_env_folder}"
	mkdir -p "${myenv_virtual_env_folder}"
	virtualenv --clear --quiet "--python=${myenv_virtual_env_python}" "${myenv_virtual_env_folder}" > .myenv.virtualenv.errors 2>&1
	local code=$?
	if [ "${code}" -ne 0 ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_ERROR}" "could not create virtual env. see errors in .myenv.virtualenv.errors"
		rm -rf "${myenv_virtual_env_folder}"
		return "${code}"
	fi
	rm -f .myenv.virtualenv.errors
	bashy_log "prompt_myenv" "${BASHY_LOG_INFO}" "created virtualenv"
	# shellcheck source=/dev/null
	source "${myenv_virtual_env_folder}/bin/activate"
	MYENV_ENV="yes"
	bashy_log "prompt_myenv" "${BASHY_LOG_INFO}" "entered virtualenv"
	return 0
}

function myenv_create_pip() {
	# do not do pip if there are error files
	if [ -f .myenv.pip.errors ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_ERROR}" "not creating virtual env because error file [.myenv.pip.errors] exits"
		return 1
	fi

	# install pip requirements
	local file
	for file in "${myenv_virtual_env_requirement_files[@]}"
	do
		pip install --quiet -r "${file}" > .myenv.pip.errors 2>&1
		local code=$?
		if [ "${code}" -ne 0 ]
		then
			bashy_log "prompt_myenv" "${BASHY_LOG_ERROR}" "could not install requirements. see errors in .myenv.pip.errors"
			# rm -rf "${myenv_virtual_env_folder}"
			return "${code}"
		fi
		rm -f .myenv.pip.errors
		bashy_log "prompt_myenv" "${BASHY_LOG_INFO}" "installed requirements [${file}]"
	done
	# no quotes in the next command are a must
	cat "${myenv_virtual_env_requirement_files[@]}" | grep -E -v "^#" | sort | md5sum > "${myenv_virtual_env_folder}/${myenv_md5_file_name}"
	local code=$?
	if [ "${code}" -ne 0 ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_ERROR}" "could not create md5 sum"
		rm -rf "${myenv_virtual_env_folder}"
		return "${code}"
	fi
	return 0
}

function myenv_create() {
	if myenv_create_virtualenv
	then
		myenv_create_pip
	fi
}

function myenv_recreate() {
	if [ ! -d "${myenv_virtual_env_folder}" ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_INFO}" "no virtual env found in [${myenv_virtual_env_folder}], setting up new virtual env"
		if ! myenv_create_virtualenv
		then
			return $?
		fi
	fi
	if [ ! -f "${myenv_virtual_env_folder}/${myenv_md5_file_name}" ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_INFO}" "md5 file is missing, recreating environment"
		if ! myenv_create_pip
		then
			return $?
		fi
	fi
	local a
	a=$(cat "${myenv_virtual_env_requirement_files[@]}" | grep -E -v "^#" | sort | md5sum)
	local b
	b=$(cat "${myenv_virtual_env_folder}/${myenv_md5_file_name}")
	if [ "${a}" != "${b}" ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_INFO}" "md5 is out of sync, installing requirements"
		myenv_create_pip
	fi
}

function myenv_in_virtual_env() {
	[ -n "${VIRTUAL_ENV:-}" ]
}

function myenv_deactivate_real() {
	bashy_log "prompt_myenv" "${BASHY_LOG_DEBUG}" "deactivating virtual env"
	deactivate
	MYENV_ENV=""
}

function myenv_deactivate() {
	if [ -z "${VIRTUAL_ENV:-}" ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_ERROR}" "not in virtual env"
		return
	fi
	myenv_deactivate_real
}

function myenv_deactivate_soft() {
	if [ "${myenv_virtual_env_auto_deactivate}" = 0 ]
	then
		if myenv_in_virtual_env
		then
			myenv_deactivate_real
		fi
	fi
}

function myenv_activate_soft() {
	if [ -z "${VIRTUAL_ENV:-}" ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_INFO}" "activating virtual env"
		if [ -r "${myenv_virtual_env_folder}/bin/activate" ]
		then
			# shellcheck source=/dev/null
			source "${myenv_virtual_env_folder}/bin/activate"
			MYENV_ENV="yes"
		else
			bashy_log "prompt_myenv" "${BASHY_LOG_ERROR}" "cannot activate virtual env at [${myenv_virtual_env_folder}]"
		fi
	fi
}

function myenv_activate() {
	if [ -n "${VIRTUAL_ENV:-}" ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_DEBUG}" "in virtual env"
		return
	fi
	bashy_log "prompt_myenv" "${BASHY_LOG_INFO}" "activating virtual env"
	if [ -r "${myenv_virtual_env_folder}/bin/activate" ]
	then
		# shellcheck source=/dev/null
		source "${myenv_virtual_env_folder}/bin/activate"
		MYENV_ENV="yes"
	else
		bashy_log "prompt_myenv" "${BASHY_LOG_ERROR}" "cannot activate virtual env at [${myenv_virtual_env_folder}]"
	fi
}

function prompt_myenv_inner() {
	myenv_getconf

	# if we are in a virtual env which is not myenv related
	if [ -n "${VIRTUAL_ENV:-}" ] && [ -z "${MYENV_ENV}" ]
	then
		bashy_log "prompt_myenv" "${BASHY_LOG_DEBUG}" "in virtual env which is not myenv related. not doing anything."
		return
	fi

	# if we don't have a .myenv file
	if ! [ -r "${myenv_conf_file_name}" ]
	then
		myenv_deactivate_soft
		return
	fi

	# if we don't have requirement files
	local file
	for file in "${myenv_virtual_env_requirement_files[@]}"
	do
		if ! [ -r "${file}" ]
		then
			myenv_deactivate_soft
			return
		fi
	done

	# if we are in the wrong virtual env, deactivate
	if myenv_in_virtual_env
	then
		if [ "$(readlink -f "${myenv_virtual_env_folder}")" != "${VIRTUAL_ENV:-}" ]
		then
			myenv_deactivate
		fi
	fi
	if [ "${myenv_virtual_env_auto_create}" = 0 ]
	then
		myenv_recreate
	fi
	if [ "${myenv_virtual_env_auto_activate}" = 0 ]
	then
		myenv_activate_soft
	fi
}

function prompt_myenv() {
	prompt_myenv_inner
	if [ -n "${VIRTUAL_ENV:-}" ]
	then
		export myenv_powerline_virtual_env_python_version="${myenv_virtual_env_python_version}"
	else
		unset myenv_powerline_virtual_env_python_version
	fi
}

function _activate_prompt_myenv() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "md5sum" __var __error; then return; fi
	_bashy_prompt_register prompt_myenv
	__var=0
}

register_interactive _activate_prompt_myenv
