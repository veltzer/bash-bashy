# a set of bash functions to help with color printing

function _bashy_cecho() {
	local color=$1
	local text=$2
	local newline=$3
	local code="\033["
	case "$1" in
		black | bk) color="${code}0;30m";;
		red | r) color="${code}1;31m";;
		green | g) color="${code}1;32m";;
		yellow | y) color="${code}1;33m";;
		blue | b) color="${code}1;34m";;
		purple | p) color="${code}1;35m";;
		cyan | c) color="${code}1;36m";;
		gray | gr) color="${code}0;37m";;
		*) ;; # any other name is used as given
	esac
	local text="${color}${text}${code}0m"
	if [[ "${newline}" = 0 ]]
	then
		echo -e "${text}"
	else
		echo -en "${text}"
	fi
}
