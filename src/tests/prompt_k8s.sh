source src/core/assert.sh
source src/core/misc.sh
source src/core/hooks.sh
source src/core/log.sh
source src/core/var.sh
source src/core/pathutils.sh
source src/core/git.sh
source src/plugins/prompt_k8s.sh

# the plugin end to end: a repo with a .k8s.conf sets KUBECONFIG while inside
# and takes it away on the way out
function testPromptK8sSetsAndClearsKubeconfig() {
	local repo
	repo=$(mktemp --directory)
	git -c init.defaultBranch=main init --quiet "${repo}"
	mkdir -p "${repo}/sub"
	touch "${repo}/.k8s.conf"
	git_is_inside_flush
	unset KUBECONFIG PROMPT_K8S_CONF
	cd "${repo}/sub" || _bashy_assert_fail
	prompt_k8s
	_bashy_assert_equal "${KUBECONFIG}" "$(realpath "${repo}")/.k8s.conf"
	prompt_k8s
	_bashy_assert_equal "${KUBECONFIG}" "$(realpath "${repo}")/.k8s.conf"
	cd / || _bashy_assert_fail
	prompt_k8s
	if var_is_defined KUBECONFIG
	then
		_bashy_assert_fail
	fi
	rm -rf "${repo}"
}

# a KUBECONFIG the user set by hand outside any repo is not the plugin's to clear
function testPromptK8sLeavesForeignKubeconfigAlone() {
	local dir
	dir=$(mktemp --directory)
	git_is_inside_flush
	unset PROMPT_K8S_CONF
	export KUBECONFIG="/my/own/config"
	cd "${dir}" || _bashy_assert_fail
	prompt_k8s
	_bashy_assert_equal "${KUBECONFIG}" "/my/own/config"
	unset KUBECONFIG
	cd / || _bashy_assert_fail
	rm -rf "${dir}"
}
