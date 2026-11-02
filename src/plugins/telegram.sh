# This is a plugin for Telegram Desktop, installed from the official binary
# distribution (the linux tarball attached to every tdesktop github release).
# https://desktop.telegram.org
# https://github.com/telegramdesktop/tdesktop/releases
#
# The tarball holds a single "Telegram" folder with two executables, Telegram
# and Updater. It is unpacked whole into TELEGRAM_FOLDER and Telegram is linked
# into BASHY_INSTALL_DIR. The Updater is kept, so Telegram can keep updating
# itself between runs of the installer, the same as an install done by hand.
# Every time it starts, Telegram writes its own desktop entry into
# ~/.local/share/applications and its icon into ~/.local/share/icons. Until that
# first start the menu has nothing to start it from, so the installer writes a
# stand in entry, see _telegram_desktop.

# Where _install_telegram_tar unpacks to.
TELEGRAM_FOLDER="${HOME}/install/telegram"

function _activate_telegram() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

function _install_telegram() {
	bashy_install_via _install_telegram_tar "$@"
}

function _uninstall_telegram() {
	_uninstall_telegram_tar
}

function _install_telegram_tar() {
	bashy_install_args "$@" || return
	case "$(uname -m)" in
		x86_64|amd64) ;;
		*)
			echo "telegram: the binary distribution is x86_64 only, not [$(uname -m)]" >&2
			return 1
			;;
	esac
	local release_json
	bashy_github_release "telegramdesktop/tdesktop" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder="${TELEGRAM_FOLDER}"
	local executable="${folder}/Telegram"
	# Telegram has no command line option that prints its version without
	# starting the gui, so the installer records what it put there.
	local installed_version
	installed_version=$(bashy_install_marker_version "${folder}" "telegram" "${executable}")
	if bashy_install_check "telegram" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# the release also carries the windows and mac installers and a source
	# tarball, so anchor on the linux setup asset to match exactly one
	local pattern="td-setup-linux-x64-[^/]*\\.tar\\.xz$"
	local download_file
	bashy_github_asset "${release_json}" "${pattern}" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	# the project publishes no checksums file, but github records the sha256 of
	# every release asset in the release json
	local digest
	digest=$(echo "${release_json}" | jq --raw-output --arg url "${download_file}" \
		'.assets[] | select(.browser_download_url == $url) | .digest // empty')
	digest="${digest#sha256:}"
	if [ -z "${digest}" ]
	then
		echo "telegram: the release json has no sha256 digest for [${download_file}]" >&2
		return 1
	fi
	bashy_verify_sha256 "${tar}" "${digest}" || return
	local parent="${folder%/*}"
	mkdir -p "${parent}" || return
	local tmp_dir
	tmp_dir=$(mktemp --directory "${parent}/.telegram.XXXXXX") || return
	# the tarball's single top level folder is "Telegram"
	if ! bashy_install_extract "${tar}" "${tmp_dir}" --strip-components=1 \
		|| [ ! -x "${tmp_dir}/Telegram" ] || [ ! -x "${tmp_dir}/Updater" ]
	then
		echo "telegram: could not extract a complete Telegram folder" >&2
		rm -rf "${tmp_dir}"
		return 1
	fi
	# mktemp makes the folder private, give it the usual permissions
	if ! chmod 755 "${tmp_dir}" || ! rm -rf "${folder}" || ! mv "${tmp_dir}" "${folder}"
	then
		rm -rf "${tmp_dir}"
		return 1
	fi
	bashy_install_marker "${folder}" "telegram" "${latest_version}" > /dev/null
	ln --symbolic --force --no-dereference "${executable}" "$(bashy_install_dir)/telegram"
	_telegram_desktop "${executable}" "$(echo "${release_json}" | jq --raw-output '.tag_name')"
}

# _telegram_desktop <executable> <release tag>
# Write a desktop entry for <executable> and the icon it names, so Telegram is in
# the menu before it was ever started. Telegram names its own entry
# org.telegram.desktop._<md5 of its path>, and when it writes that entry it
# deletes telegram.desktop as a leftover of older versions. Under that name the
# stand in is replaced on the first start instead of showing up twice. The icon
# goes where Telegram puts its own, under the name its entry uses, and comes from
# the source tree of the same release, since the tarball has none outside the
# binary. A missing icon only costs the menu its picture, so it does not fail
# the install.
function _telegram_desktop() {
	local executable=$1
	local tag=$2
	local icons="${HOME}/.local/share/icons/hicolor/256x256/apps"
	local icon_url="https://raw.githubusercontent.com/telegramdesktop/tdesktop/${tag}/Telegram/Resources/art/logo_256.png"
	local icon
	if mkdir -p "${icons}" && bashy_download "${icon_url}" icon
	then
		cp "${icon}" "${icons}/org.telegram.desktop.png"
	else
		echo "telegram: could not fetch the icon, the menu entry will have none" >&2
	fi
	local applications="${HOME}/.local/share/applications"
	mkdir -p "${applications}" || return
	# the entry Telegram writes, lib/xdg/org.telegram.desktop.desktop in its
	# source tree, minus DBusActivatable, which needs the dbus service file
	# Telegram also only writes when it starts
	cat > "${applications}/telegram.desktop" << EOF
[Desktop Entry]
Name=Telegram
Comment=New era of messaging
TryExec=${executable}
Exec=${executable} -- %U
Icon=org.telegram.desktop
Terminal=false
StartupWMClass=TelegramDesktop
Type=Application
Categories=Chat;Network;InstantMessaging;Qt;
MimeType=x-scheme-handler/tg;x-scheme-handler/tonsite;x-scheme-handler/ton;
Keywords=tg;chat;im;messaging;messenger;sms;tdesktop;
Actions=quit;
SingleMainWindow=true

[Desktop Action quit]
Exec=${executable} -quit
Name=Quit Telegram
Icon=application-exit
EOF
	if _bashy_pathutils_is_in_path "update-desktop-database"
	then
		update-desktop-database "${applications}"
	fi
}

function _uninstall_telegram_tar() {
	local link="${BASHY_INSTALL_DIR}/telegram"
	# only remove the link if it is ours
	if [ -L "${link}" ] && [ "$(readlink "${link}")" = "${TELEGRAM_FOLDER}/Telegram" ]
	then
		echo "removing ${link}"
		rm -f "${link}"
	fi
	# the account data lives in ~/.local/share/TelegramDesktop and is left alone
	bashy_uninstall_directory "telegram" "${TELEGRAM_FOLDER}"
	# the stand in entry, or the one Telegram wrote over it, both of which run
	# the executable just removed
	local applications="${HOME}/.local/share/applications"
	local entry
	for entry in "${applications}/telegram.desktop" "${applications}"/org.telegram.desktop._*.desktop
	do
		if [ -f "${entry}" ] && grep --quiet --fixed-strings "${TELEGRAM_FOLDER}/Telegram" "${entry}"
		then
			echo "removing ${entry}"
			rm -f "${entry}"
		fi
	done
}

register_interactive _activate_telegram
register_install _install_telegram
