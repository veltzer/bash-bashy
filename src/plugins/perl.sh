function _activate_perl() {
	local -n __var=$1
	local -n __error=$2
	PERL_LOCAL="${HOME}/install/perl"
	if ! checkDirectoryExists "${PERL_LOCAL}" __var __error; then return; fi
	export PERL5LIB
	_bashy_pathutils_add_tail PERL5LIB "${PERL_LOCAL}"
	# local perl installation with perl -MCPAN
	# the absense of double quotes in the next line is important
	export PERL_LOCAL_LIB_ROOT="${HOME}/install/perl5"
	export PERL_MB_OPT="--install_base ${PERL_LOCAL_LIB_ROOT}"
	export PERL_MM_OPT="INSTALL_BASE=${PERL_LOCAL_LIB_ROOT}"
	_bashy_pathutils_add_tail PERL5LIB "${PERL_LOCAL_LIB_ROOT}/lib/perl5/i686-linux-gnu-thread-multi-64int"
	_bashy_pathutils_add_tail PERL5LIB "${PERL_LOCAL_LIB_ROOT}/lib/perl5"
	_bashy_pathutils_add_tail PATH "${PERL_LOCAL_LIB_ROOT}/bin"
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_perl() {
	_bashy_pathutils_remove PATH "${HOME}/install/perl5/bin"
	unset PERL5LIB PERL_LOCAL_LIB_ROOT PERL_MB_OPT PERL_MM_OPT
}

register _activate_perl _deactivate_perl
