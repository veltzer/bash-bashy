function _activate_proxy() {
	local -n __var=$1
	local -n __error=$2
	if "${PROXY_ENABLED}"
	then
		proxy_enable
	fi
	__var=0
}

function proxy_disable() {
	export -n http_proxy
	export -n https_proxy
	export -n no_proxy
}

function proxy_enable() {
	export http_proxy="${PROXY_HTTP}"
	export https_proxy="${PROXY_HTTPS}"
	export no_proxy="${PROXY_NO}"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_proxy() {
	proxy_disable
}

register _activate_proxy _deactivate_proxy
