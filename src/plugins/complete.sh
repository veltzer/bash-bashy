# This plugin provides auto complete support to
# programs that use pytconf

function _activate_complete() {
	local -n __var=$1
	local -n __error=$2
	complete -C "pypitools complete" pypitools
	complete -C "pyawskit complete" pyawskit
	complete -C "pycmdtools complete" pycmdtools
	complete -C "pypowerline complete" pypowerline
	complete -C "pygitpub complete" pygitpub
	complete -C "pytsv complete" pytsv
	complete -C "pyscrapers complete" pyscrapers
	complete -C "pyflexebs complete" pyflexebs
	complete -C "pydatacheck complete" pydatacheck
	complete -C "pymultigit complete" pymultigit
	complete -C "pygooglecloud complete" pygooglecloud
	complete -C "pymakehelper complete" pymakehelper
	complete -C "pygcal complete" pygcal
	complete -C "pytubekit complete" pytubekit
	complete -C "pycontacts complete" pycontacts

	# Through the completion cache, so that a shell start does not run all eight
	# tools. A tool that is not installed is skipped, as "source <(...)" used to.
	local tool
	for tool in rsconstruct rsmultigit rscontacts rscalendar rsdedup rsspell rstype rspass
	do
		bashy_completion "${tool}" "${tool}" complete bash || true
	done

	complete -F _rsmultigit mg
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_complete() {
	complete -r pypitools pyawskit pycmdtools pypowerline pygitpub pytsv pyscrapers \
		pyflexebs pydatacheck pymultigit pygooglecloud pymakehelper pygcal pytubekit \
		pycontacts rsconstruct rsmultigit rscontacts rscalendar rsdedup rsspell rstype \
		rspass mg 2> /dev/null
}

register_interactive _activate_complete _deactivate_complete
