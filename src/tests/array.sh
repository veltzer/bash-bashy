source src/core/array.sh

# created by _bashy_array_new inside the tests; declared here so the linter knows
declare -ga arr

function testSetLen() {
	_bashy_array_new my_array
	_bashy_array_set my_array 2 4
	len=
	_bashy_array_length my_array len
	_bashy_assert_equal "${len}" 1
}

function testSetPop() {
	_bashy_array_new arr2
	_bashy_array_set arr2 0 a
	_bashy_array_set arr2 1 b
	_bashy_array_set arr2 2 c
	d=5
	_bashy_array_pop arr2 d
	_bashy_assert_equal "${d}" c
	_bashy_array_pop arr2 d
	_bashy_assert_equal "${d}" b
	_bashy_array_pop arr2 d
	_bashy_assert_equal "${d}" a
}

function testPushPop() {
	_bashy_array_new arr
	_bashy_array_push arr a
	_bashy_array_push arr b
	_bashy_array_push arr c
	elem=5
	_bashy_array_pop arr elem
	_bashy_assert_equal "${elem}" c
	_bashy_array_pop arr elem
	_bashy_assert_equal "${elem}" b
	_bashy_array_pop arr elem
	_bashy_assert_equal "${elem}" a
}

function testRemove() {
	_bashy_array_new arr
	_bashy_array_push arr a
	_bashy_array_push arr b
	_bashy_array_push arr c
	_bashy_array_remove arr b
	# the length has to shrink, popping alone passed even when nothing was removed
	_bashy_assert_equal "${#arr[@]}" 2
	_bashy_array_pop arr elem
	_bashy_assert_equal "${elem}" c
	_bashy_array_pop arr elem
	_bashy_assert_equal "${elem}" a
}

function testRemoveLastElement() {
	_bashy_array_new arr
	_bashy_array_push arr only
	_bashy_array_remove arr only
	_bashy_assert_equal "${#arr[@]}" 0
}

function testRemoveAbsentValue() {
	_bashy_array_new arr
	_bashy_array_push arr keep
	_bashy_array_remove arr missing
	_bashy_assert_equal "${#arr[@]}" 1
	_bashy_assert_equal "${arr[0]}" keep
}

function testRemoveKeepsWhitespace() {
	_bashy_array_new arr
	_bashy_array_push arr "two words"
	_bashy_array_push arr other
	_bashy_array_remove arr other
	_bashy_assert_equal "${#arr[@]}" 1
	_bashy_assert_equal "${arr[0]}" "two words"
}

function testFind() {
	_bashy_array_new arr
	_bashy_array_push arr a
	_bashy_array_push arr b
	_bashy_array_push arr c
	location=0
	_bashy_array_find arr b location
	_bashy_assert_equal "${location}" 1
}
