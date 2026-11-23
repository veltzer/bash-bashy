source src/core/python.sh

function test_python_version() {
	a=
	python_version_short a "$(command -v python3 || true)"
	ubuntu_ver=$(lsb_release -r -s)
	if [[ "${ubuntu_ver}" = "23.04" ]]
	then
		_bashy_assert_equal "${a}" 3.11
	fi
	if [[ "${ubuntu_ver}" = "22.10" ]]
	then
		_bashy_assert_equal "${a}" 3.10
	fi
}
