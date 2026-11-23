source src/core/var.sh
source src/core/measure.sh
source src/core/float.sh

function sleep_a_little() {
	sleep 2
}

function test_measure() {
	local diff=
	local result=
	local "error="
	measure diff sleep_a_little result error
	# echo "diff is ${diff}"
	# echo "result is ${result}"
	_bashy_assert_lt "${diff}" 2.1
	_bashy_assert_gt "${diff}" 1.9
}
