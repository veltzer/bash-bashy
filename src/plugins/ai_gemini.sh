# Install the latest stable Gemini CLI.
# https://geminicli.com/docs/get-started/installation/
function _install_gemini() {
	bashy_install_npm "gemini" "@google/gemini-cli@latest"
}

function _uninstall_gemini() {
	bashy_uninstall_npm "gemini" "@google/gemini-cli"
}
