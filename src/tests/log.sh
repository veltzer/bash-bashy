source src/core/assert.sh
source src/core/log.sh

function testLogSilentByDefault() {
	bashy_log_none
	_bashy_assert_equal "$(bashy_log "test" "${BASHY_LOG_ERROR}" "hidden")" ""
}

function testLogPrintsAtOrBelowLevel() {
	bashy_log_info
	_bashy_assert_equal "$(bashy_log "test" "${BASHY_LOG_ERROR}" "shown")" "bashy: test: ${BASHY_LOG_ERROR} - shown"
	_bashy_assert_equal "$(bashy_log "test" "${BASHY_LOG_INFO}" "shown")" "bashy: test: ${BASHY_LOG_INFO} - shown"
	# debug is above info, so it stays quiet
	_bashy_assert_equal "$(bashy_log "test" "${BASHY_LOG_DEBUG}" "hidden")" ""
	bashy_log_none
}

function testLogUsageOnWrongArity() {
	bashy_log_debug
	local out
	out=$(bashy_log "only one")
	if [[ "${out}" != usage:* ]]
	then
		_bashy_assert_fail
	fi
	bashy_log_none
}
