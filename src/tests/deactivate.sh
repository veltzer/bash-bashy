source src/core/assert.sh
source src/core/misc.sh
source src/core/hooks.sh

# Every deactivate function a plugin names on its register line has to exist in
# that same file, or bashy_deactivate would fail with "command not found".
function testRegisteredDeactivatesAreDefined() {
	local missing=0
	local file line deactivate
	local -a lines
	for file in src/plugins/*.sh
	do
		# the register lines first, then the lookups, so the file is not read
		# twice at once
		readarray -t lines < <(grep -E '^register' "${file}")
		for line in "${lines[@]}"
		do
			[[ "${line}" =~ ^register(_interactive)?\ +[^\ ]+\ +([^\ ]+) ]] || continue
			deactivate="${BASH_REMATCH[2]}"
			if ! grep -q "^function ${deactivate}()" "${file}"
			then
				echo "${file}: registers [${deactivate}] but does not define it"
				missing=1
			fi
		done
	done
	_bashy_assert_equal "${missing}" 0
}

# and the other way round: a deactivate function that is defined but never handed
# to register is unreachable through bashy_deactivate
function testDefinedDeactivatesAreRegistered() {
	local missing=0
	local file deactivate
	local -a defined
	for file in src/plugins/*.sh
	do
		readarray -t defined < <(sed -n 's/^function \(_deactivate_[a-z0-9_]*\)().*/\1/p' "${file}")
		for deactivate in "${defined[@]}"
		do
			if ! grep -qE "^register(_interactive)? +[^ ]+ +${deactivate}$" "${file}"
			then
				echo "${file}: defines [${deactivate}] but does not register it"
				missing=1
			fi
		done
	done
	_bashy_assert_equal "${missing}" 0
}

# one plugin end to end: aliases come and go
function testCarefulAliasesDeactivate() {
	source src/plugins/careful_aliases.sh
	# shellcheck disable=SC2034 # filled by name through the namerefs
	local result="" error=""
	_activate_careful_aliases result error
	alias rm > /dev/null 2>&1 || _bashy_assert_fail
	_deactivate_careful_aliases
	if alias rm > /dev/null 2>&1
	then
		_bashy_assert_fail
	fi
	return 0
}
