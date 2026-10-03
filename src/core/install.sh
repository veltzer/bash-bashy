# Shared mechanics and reporting for plugin installers.
#
# Every _install_* function used to hand roll the same three messages, which
# drifted over time ("is already installed", "is already up to date",
# "Upgrading foo from [x] to [y]", ...), and to hand roll the download, the
# checksum check and the removal around them. This module keeps all of that in
# one place so every plugin behaves and reports identically.
#
# An installer is always the same shape: parse its arguments, work out the
# latest version, work out the installed one, hand both to bashy_install_check,
# and only then fetch and unpack.
#
#	function _install_gh() {
#		bashy_install_args "$@" || return
#		local release_json
#		bashy_github_release "cli/cli" release_json || return
#		local latest_version
#		latest_version=$(bashy_github_version "${release_json}")
#		local folder
#		folder=$(bashy_install_dir)
#		local executable="${folder}/gh"
#		local installed_version=""
#		if [ -x "${executable}" ]
#		then
#			installed_version=$("${executable}" --version 2>/dev/null | awk '{print $3; exit}')
#		fi
#		if bashy_install_check "gh" "${installed_version}" "${latest_version}"
#		then
#			return
#		fi
#		# ... download, verify and unpack ...
#	}
#
# The helpers below cover the ways a project actually ships: a single binary, an
# archive, a deb package, or a package in apt/npm/pip. The package manager ones
# do no version arithmetic of their own - the package manager already knows what
# is installed, and a second opinion here would only be a worse one.
#
# This module is loaded before download.sh, so it may only call into it from
# inside a function body, never at load time. pathutils.sh loads earlier, so
# _bashy_pathutils_is_in_path is available throughout.

# Where plugins put the single binaries they install. Override in ~/.bashy.config.
if [ -z "${BASHY_INSTALL_DIR+x}" ]
then
	export BASHY_INSTALL_DIR="${HOME}/install/binaries"
fi

# bashy_install_dir
# Echo the install directory, creating it if it is not there yet. Installers used
# to just assume it existed and failed obscurely on a fresh machine when it did not.
function bashy_install_dir() {
	if [ ! -d "${BASHY_INSTALL_DIR}" ]
	then
		mkdir -p "${BASHY_INSTALL_DIR}"
	fi
	echo "${BASHY_INSTALL_DIR}"
}

# bashy_install_args [--force]
# Parse the arguments every installer accepts. An installer calls this first,
# with its own "$@", and returns when it fails: a misspelt option must not
# silently run a plain install. --force means "do the work even when the tool is
# already at the latest version", for a binary that was damaged, a package that
# was half removed, or a release that was republished under the same version.
# The state lives in BASHY_INSTALL_FORCE and is reset on every call, so an
# installer never inherits the flag from the one that ran before it.
function bashy_install_args() {
	BASHY_INSTALL_FORCE=0
	local arg
	for arg in "$@"
	do
		case "${arg}" in
			--force)
				BASHY_INSTALL_FORCE=1
				;;
			*)
				echo "${FUNCNAME[1]}: unknown argument [${arg}], the only option is --force" >&2
				return 1
				;;
		esac
	done
	return 0
}

# bashy_install_forced
# Succeed when the running installer was given --force. For the plugins whose
# "is it there already" check is not a version comparison.
function bashy_install_forced() {
	[ "${BASHY_INSTALL_FORCE:-0}" -eq 1 ]
}

# bashy_install_check <name> <installed_version> <latest_version>
# Report what is about to happen and say whether there is anything to do.
# An empty <installed_version> means the tool is not installed yet.
# Returns 0 if <name> is already at <latest_version> (caller should return),
# 1 if the caller should go on and install. Under --force the up to date case
# says so and still returns 1, so the installer puts the same version back.
function bashy_install_check() {
	local name=$1
	local installed=$2
	local latest=$3
	if [ -z "${latest}" ]
	then
		echo "${name}: could not determine the latest version" >&2
		return 1
	fi
	if [ -z "${installed}" ]
	then
		echo "Installing ${name} ${latest}"
		return 1
	fi
	if [ "${installed}" = "${latest}" ]
	then
		if bashy_install_forced
		then
			echo "${name} ${latest} is already installed (latest), reinstalling"
			return 1
		fi
		echo "${name} ${latest} is already installed (latest)"
		return 0
	fi
	echo "${name} ${installed} is installed, upgrading to ${latest}"
	return 1
}

# bashy_install_download <url>
# Report the artifact a plugin is about to fetch, in one consistent format.
function bashy_install_download() {
	echo "download_file is [$1]"
}

# bashy_uninstall_binary <name> [executable path]
# Remove a single binary installed into BASHY_INSTALL_DIR, reporting either way.
# The path defaults to ${BASHY_INSTALL_DIR}/<name>.
function bashy_uninstall_binary() {
	local name=$1
	local executable=${2:-${BASHY_INSTALL_DIR}/$1}
	if [ -f "${executable}" ]
	then
		echo "removing ${executable}"
		rm -f "${executable}"
	else
		echo "no ${name} detected"
	fi
	return 0
}

# bashy_uninstall_directory <name> <directory> [more directories...]
# Remove the directory tree(s) a plugin installed, reporting either way.
# Handy for the plugins that unpack a whole toolchain rather than one binary.
function bashy_uninstall_directory() {
	local name=$1
	shift
	local found=1
	local directory
	for directory in "$@"
	do
		# a plugin may leave both a versioned directory and a symlink to it
		if [ -d "${directory}" ] || [ -L "${directory}" ]
		then
			echo "removing ${directory}"
			rm -rf "${directory}"
			found=0
		fi
	done
	if [ "${found}" -ne 0 ]
	then
		echo "no ${name} detected"
	fi
	return 0
}

# bashy_github_release <owner/repo> [out_var]
# Fetch the json of the latest release of a github project.
# Assigns to out_var when given, otherwise echoes. Returns 1 when the fetch fails.
function bashy_github_release() {
	local repo=$1
	local json
	if ! json=$(curl --fail --silent --location "https://api.github.com/repos/${repo}/releases/latest")
	then
		echo "bashy_github_release: could not fetch the latest release of [${repo}]" >&2
		return 1
	fi
	if [ -n "${2:-}" ]
	then
		local -n __out=$2
		__out="${json}"
	else
		echo "${json}"
	fi
}

# bashy_github_version <release json> [prefix]
# Echo the version of a release, with <prefix> stripped from the tag name.
# The prefix defaults to "v", which is what almost every project tags with.
# The prefix is a literal, not a pattern: biome tags "@biomejs/biome@2.5.15",
# and a prefix with a slash in it broke the sed expression this used to be.
function bashy_github_version() {
	local json=$1
	local prefix=${2-v}
	local tag
	tag=$(echo "${json}" | jq --raw-output '.tag_name')
	echo "${tag#"${prefix}"}"
}

# bashy_github_asset <release json> <jq test regex> [out_var]
# Echo the download url of the one asset of a release matching <jq test regex>.
# Fails when the pattern matches no asset, or more than one - an ambiguous match
# silently produced a multi line url before, which is never what a caller wants.
function bashy_github_asset() {
	local json=$1
	local pattern=$2
	local urls
	urls=$(echo "${json}" | jq --raw-output --arg re "${pattern}" \
		'.assets[].browser_download_url | select(test($re))')
	local count
	count=$(echo "${urls}" | grep --count . || true)
	if [ "${count}" -eq 0 ]
	then
		echo "bashy_github_asset: no asset matches [${pattern}]" >&2
		return 1
	fi
	if [ "${count}" -gt 1 ]
	then
		echo "bashy_github_asset: [${pattern}] matches ${count} assets, expected one:" >&2
		echo "${urls}" >&2
		return 1
	fi
	if [ -n "${3:-}" ]
	then
		local -n __out=$3
		__out="${urls}"
	else
		echo "${urls}"
	fi
}

# bashy_install_extract <archive> <destination folder> [tar/unzip arguments...]
# Unpack <archive> into <destination folder>, then stamp everything it wrote with
# the current time. Both tar and unzip restore the mtime recorded inside the
# archive, which makes a freshly installed file look years old.
function bashy_install_extract() {
	local archive=$1
	local folder=$2
	shift 2
	case "${archive}" in
		*.zip)
			unzip -q -o "${archive}" -d "${folder}" "$@" || return 1
			# unzip has no equivalent of tar --touch, so restamp afterwards
			local member
			for member in "$@"
			do
				touch "${folder}/${member}" 2>/dev/null || true
			done
			;;
		*)
			tar xf "${archive}" -m -C "${folder}" "$@" || return 1
			;;
	esac
}

# bashy_install_binary <name> <url> [executable path]
# Install a single executable fetched from <url> into BASHY_INSTALL_DIR.
# The download goes through the cache, so the bytes are never chmod'ed in place -
# the cached copy stays a plain file and a copy of it becomes the executable.
# The path defaults to ${BASHY_INSTALL_DIR}/<name>.
function bashy_install_binary() {
	local name=$1
	local url=$2
	local executable=${3:-$(bashy_install_dir)/${name}}
	bashy_install_download "${url}"
	local binary
	bashy_download "${url}" binary || return 1
	rm -f "${executable}"
	cp "${binary}" "${executable}"
	chmod +x "${executable}"
	return 0
}

# bashy_install_deb <name> <url>
# Download a .deb through the cache and install it with dpkg, falling back to
# apt-get to pull in dependencies dpkg alone cannot resolve.
function bashy_install_deb() {
	local name=$1
	local url=$2
	echo "Installing ${name} from a deb package"
	bashy_install_download "${url}"
	local deb
	bashy_download "${url}" deb || return 1
	sudo dpkg --install "${deb}" || sudo apt-get install --fix-broken --assume-yes
	return 0
}

# bashy_install_marker <folder> <name> [version]
# Echo the path of the file recording which version of <name> is installed in
# <folder>, and write <version> into it when one is given. Some projects ship an
# artifact that cannot report its own version (an AppImage, a rolling download),
# so the installer has to remember what it put there.
function bashy_install_marker() {
	local folder=$1
	local name=$2
	local marker="${folder}/.${name}_version"
	if [ -n "${3:-}" ]
	then
		echo "$3" > "${marker}"
	fi
	echo "${marker}"
}

# bashy_install_marker_version <folder> <name> <executable>
# Echo the version recorded by bashy_install_marker, but only when <executable>
# is really there - a marker left behind by a removed binary must not read as
# "installed".
function bashy_install_marker_version() {
	local folder=$1
	local name=$2
	local executable=$3
	local marker="${folder}/.${name}_version"
	if [ -x "${executable}" ] && [ -f "${marker}" ]
	then
		cat "${marker}"
	fi
}

# _bashy_apt_update
# Run apt-get update at most once per session, to avoid running it repeatedly
# during a bashy_upgrade. Plugins that modify apt sources should unset
# _BASHY_APT_UPDATED to force a fresh update.
function _bashy_apt_update() {
	if [ -z "${_BASHY_APT_UPDATED:-}" ]
	then
		sudo apt-get update
		export _BASHY_APT_UPDATED=1
	fi
}

# _bashy_apt_installed <package>
# Succeed when dpkg has <package> fully installed.
function _bashy_apt_installed() {
	dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# bashy_install_apt <name> <package...>
# Install distribution packages, reporting in the standard format. When every
# package is already installed nothing runs at all, not even apt-get update: a
# bashy_upgrade must not cost a sudo prompt and an index refresh for each of
# the twenty plugins that are already in place. There is no version comparison
# beyond that on purpose: apt already knows what the archive offers, and
# duplicating that check would only be a slower, worse version of what
# "apt install" does by itself, so when anything is missing the whole list goes
# to apt and it moves the rest forward if it has something newer. Under --force
# a fully installed list is reinstalled instead of skipped.
function bashy_install_apt() {
	local name=$1
	shift
	local package
	local missing=()
	for package in "$@"
	do
		if ! _bashy_apt_installed "${package}"
		then
			missing+=("${package}")
		fi
	done
	local options=()
	if [ "${#missing[@]}" -eq 0 ]
	then
		if ! bashy_install_forced
		then
			echo "${name} is already installed via apt [$*]"
			return 0
		fi
		echo "Reinstalling ${name} via apt [$*]"
		options+=("--reinstall")
	else
		echo "Installing ${name} via apt [$*]"
	fi
	_bashy_apt_update
	sudo DEBIAN_FRONTEND=noninteractive apt-get install "${options[@]}" --assume-yes "$@"
}

# bashy_uninstall_apt <name> <package...>
# Remove distribution packages, reporting either way.
function bashy_uninstall_apt() {
	local name=$1
	shift
	local package
	local found=1
	for package in "$@"
	do
		if _bashy_apt_installed "${package}"
		then
			found=0
		fi
	done
	if [ "${found}" -ne 0 ]
	then
		echo "no ${name} detected"
		return 0
	fi
	echo "removing ${name} via apt [$*]"
	sudo DEBIAN_FRONTEND=noninteractive apt-get purge --assume-yes "$@"
}

# bashy_install_npm <name> <package...>
# Install global npm packages, reporting in the standard format. npm resolves
# "latest" itself, which is why nothing is pinned here. Under --force npm is
# told to reinstall rather than keep what is already there.
function bashy_install_npm() {
	local name=$1
	shift
	if ! _bashy_pathutils_is_in_path "npm"
	then
		echo "${name}: npm not found - install node first" >&2
		return 1
	fi
	local options=()
	if bashy_install_forced
	then
		options+=("--force")
	fi
	echo "Installing ${name} via npm [$*]"
	npm install --global "${options[@]}" "$@"
}

# bashy_uninstall_npm <name> <package...>
# Remove global npm packages, reporting either way.
function bashy_uninstall_npm() {
	local name=$1
	shift
	if ! _bashy_pathutils_is_in_path "npm"
	then
		echo "no ${name} detected"
		return 0
	fi
	echo "removing ${name} via npm [$*]"
	npm uninstall --global "$@"
}

# bashy_install_pip <name> <package...>
# Install python packages, reporting in the standard format. Under --force pip
# reinstalls the packages even when they are already at the latest version.
function bashy_install_pip() {
	local name=$1
	shift
	if ! _bashy_pathutils_is_in_path "pip"
	then
		echo "${name}: pip not found - install python first" >&2
		return 1
	fi
	local options=()
	if bashy_install_forced
	then
		options+=("--force-reinstall")
	fi
	echo "Installing ${name} via pip [$*]"
	pip install --upgrade "${options[@]}" "$@"
}

# bashy_uninstall_pip <name> <package...>
# Remove python packages, reporting either way.
function bashy_uninstall_pip() {
	local name=$1
	shift
	if ! _bashy_pathutils_is_in_path "pip"
	then
		echo "no ${name} detected"
		return 0
	fi
	echo "removing ${name} via pip [$*]"
	pip uninstall --yes "$@"
}

# bashy_install_git <name> <url> <folder> [git arguments...]
# Install by cloning a repository, reporting in the standard format. The previous
# clone is removed first: a project installed this way carries no version we can
# compare, so the only way to be current is to take it again.
function bashy_install_git() {
	local name=$1
	local url=$2
	local folder=$3
	shift 3
	echo "Installing ${name} by cloning [${url}] into [${folder}]"
	rm -rf "${folder}"
	git clone "$@" "${url}" "${folder}"
}

# bashy_install_brew <name> <formula...>
# Install homebrew formulae, reporting in the standard format. "brew install"
# already upgrades a formula that is out of date, so there is no version
# arithmetic to do here either. Under --force "brew reinstall" is used, which
# is how brew puts back a formula that is already current.
function bashy_install_brew() {
	local name=$1
	shift
	if ! _bashy_pathutils_is_in_path "brew"
	then
		echo "${name}: brew not found - install brew first" >&2
		return 1
	fi
	if bashy_install_forced
	then
		echo "Reinstalling ${name} via brew [$*]"
		brew reinstall "$@"
		return
	fi
	echo "Installing ${name} via brew [$*]"
	brew install "$@"
}

# bashy_uninstall_brew <name> <formula...>
# Remove homebrew formulae, reporting either way.
function bashy_uninstall_brew() {
	local name=$1
	shift
	if ! _bashy_pathutils_is_in_path "brew"
	then
		echo "no ${name} detected"
		return 0
	fi
	echo "removing ${name} via brew [$*]"
	brew uninstall "$@"
}

# bashy_install_gh_extension <name> <owner/repo>
# Install a gh(1) extension, reporting in the standard format. gh refuses to
# install an extension that is already there, and --force is its way of saying
# "install it, upgrade it, or leave it alone if it is already the latest".
function bashy_install_gh_extension() {
	local name=$1
	local extension=$2
	if ! _bashy_pathutils_is_in_path "gh"
	then
		echo "${name}: gh not found - install gh first" >&2
		return 1
	fi
	echo "Installing ${name} via a gh extension [${extension}]"
	gh extension install --force "${extension}"
}

# bashy_uninstall_gh_extension <name> <extension>
# Remove a gh(1) extension, reporting either way.
function bashy_uninstall_gh_extension() {
	local name=$1
	local extension=$2
	if ! _bashy_pathutils_is_in_path "gh"
	then
		echo "no ${name} detected"
		return 0
	fi
	echo "removing ${name} via a gh extension [${extension}]"
	gh extension remove "${extension}"
}
