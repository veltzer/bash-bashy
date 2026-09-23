source src/core/assert.sh
source src/core/color.sh

function testCechoWrapsTextInColor() {
	local out
	out=$(_bashy_cecho red "hello" 1)
	# the text has to be there, between a colour code and the reset
	_bashy_assert_equal "${out}" $'\033[1;31mhello\033[0m'
}

function testCechoNewlineFlag() {
	# 0 means "end with a newline", anything else means "no newline"
	_bashy_assert_equal "$(_bashy_cecho g "x" 0 | wc -l)" 1
	_bashy_assert_equal "$(_bashy_cecho g "x" 1 | wc -l)" 0
}

function testCechoUnknownColorIsPlain() {
	local out
	out=$(_bashy_cecho nosuchcolor "plain" 1)
	_bashy_assert_equal "${out}" $'nosuchcolorplain\033[0m'
}
