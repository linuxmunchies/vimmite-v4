#!/usr/bin/env bash
set -euo pipefail

readonly NERD_FONTS_VERSION="3.5.1"
readonly FONT_ROOT="/usr/share/fonts/vimmite/nerd-fonts"

fonts_workdir="$(mktemp -d /tmp/vimmite-fonts.XXXXXX)"
trap 'rm -rf "${fonts_workdir}"' EXIT

install_font() {
    local font_name="$1"
    local font_sha256="$2"
    local archive_path="${fonts_workdir}/${font_name}.zip"
    local destination="${FONT_ROOT}/${font_name}"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/${font_name}.zip"

    curl --fail --location --retry 3 --output "${archive_path}" "${font_url}"
    printf '%s  %s\n' "${font_sha256}" "${archive_path}" | sha256sum --check --strict

    install -d -m 0755 "${destination}"
    unzip -q "${archive_path}" '*.ttf' -d "${destination}"
    find "${destination}" -type f -exec chmod 0644 {} +
}

install_font "FiraCode" "239395baf60c89b2eaf4862b6b09db0ef95605cd3e8eef51c00345822a81a665"
install_font "JetBrainsMono" "fab782a66f7d3019da64f6572db9fc5d3a4bcb19f9fa13e2d8a62e3693d6396e"

fc-cache --force

