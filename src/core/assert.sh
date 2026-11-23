ASSERT_FAILED_CODE=128

function _bashy_assert_equal() {
	local a=$1
	local b=$2
	if [[ "${a}" != "${b}" ]]
	then
		echo "assertion failed ! [ ${a} = ${b} ]"
		exit "${ASSERT_FAILED_CODE}"
	fi
}

function _bashy_assert_not_equal() {
	local a=$1
	local b=$2
	if [[ "${a}" = "${b}" ]]
	then
		echo "assertion failed [ ${a} = ${b} ]"
		exit "${ASSERT_FAILED_CODE}"
	fi
}

function _bashy_assert_ok() {
	:
}

function _bashy_assert_fail() {
	echo "assertion failed"
	exit "${ASSERT_FAILED_CODE}"
}
