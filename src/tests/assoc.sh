source src/core/assert.sh
source src/core/null.sh
source src/core/assoc.sh

function testAssoc() {
	assoc_new conf
	assoc_config_read conf "data/test.conf"
	# assoc_print conf
	local len=
	assoc_len conf len
	_bashy_assert_equal "${len}" 2
	a=
	assoc_get conf a "a"
	_bashy_assert_equal "${a}" "a_value"
	b=
	assoc_get conf b "b"
	_bashy_assert_equal "${b}" "b_value"
	local "c="
	assoc_get conf c "c"
	if ! _bashy_null_var_is_null c
	then
		assertFail
	fi
}
