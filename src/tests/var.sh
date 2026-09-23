source src/core/assert.sh
source src/core/var.sh

function testSetByName() {
	local b=5
	var_set_by_name b 6
	_bashy_assert_equal "${b}" 6
}

function in_function() {
	local c=5
	var_set_by_name c 6
	_bashy_assert_equal "${c}" 6
}

function testInFunction() {
	in_function
}

function testSetByNameKeepsQuotes() {
	local v=""
	# the eval based version broke on a single quote and expanded a dollar
	var_set_by_name v "it's \$HOME \`x\`"
	_bashy_assert_equal "${v}" "it's \$HOME \`x\`"
}

function testDefinedPATH() {
	if ! var_is_defined PATH
	then
		assertFail
	fi
}

function testNotDefined() {
	if var_is_defined PATHY
	then
		assertFail
	fi
}
