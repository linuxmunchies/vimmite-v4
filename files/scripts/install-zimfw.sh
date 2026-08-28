#!/usr/bin/env bash
set -euo pipefail

readonly ZIMFW_VERSION="1.20.1"
readonly ZIMFW_SHA256="730f7a86f7aac9c87b137e85ecf0ebec19530ab6af065289bcd0d60cb13d8689"
readonly ZIMFW_URL="https://github.com/zimfw/zimfw/releases/download/v${ZIMFW_VERSION}/zimfw.zsh"
readonly ZIMFW_DESTINATION="/usr/share/vimmite/zim/zimfw.zsh"
readonly ZIM_SKEL="/usr/share/vimmite/zim/skel"

zimfw_workdir="$(mktemp -d /tmp/vimmite-zimfw.XXXXXX)"
trap 'rm -rf "${zimfw_workdir}"' EXIT

curl --fail --location --retry 3 --output "${zimfw_workdir}/zimfw.zsh" "${ZIMFW_URL}"
printf '%s  %s\n' "${ZIMFW_SHA256}" "${zimfw_workdir}/zimfw.zsh" | sha256sum --check --strict

install -d -m 0755 "$(dirname "${ZIMFW_DESTINATION}")"
install -m 0644 "${zimfw_workdir}/zimfw.zsh" "${ZIMFW_DESTINATION}"

# Resolve Zim and its configured modules while composing the image. New users
# receive a complete, offline-ready setup rather than cloning plugins during
# their first login.
install -d -m 0755 "${ZIM_SKEL}" "${ZIM_SKEL}/.zim" /etc/skel
install -m 0644 /usr/share/vimmite/zim/zimrc "${ZIM_SKEL}/.zimrc"
install -m 0644 /usr/share/vimmite/zim/zshrc "${ZIM_SKEL}/.zshrc"
ZIM_HOME="${ZIM_SKEL}/.zim" \
ZIM_CONFIG_FILE="${ZIM_SKEL}/.zimrc" \
  zsh -c 'source /usr/share/vimmite/zim/zimfw.zsh install'

# zimfw's generated initializer contains the build-time absolute ZIM_HOME.
# Let each account regenerate it from the already downloaded module tree.
rm -f "${ZIM_SKEL}/.zim/init.zsh" "${ZIM_SKEL}/.zim/login_init.zsh"

cp -a "${ZIM_SKEL}/.zim" /etc/skel/.zim
install -m 0644 "${ZIM_SKEL}/.zimrc" /etc/skel/.zimrc
install -m 0644 "${ZIM_SKEL}/.zshrc" /etc/skel/.zshrc

# Fedora's account tools and installer consume this default for newly created
# users. Existing accounts remain opt-in through `ujust setup-zsh true`.
sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd
