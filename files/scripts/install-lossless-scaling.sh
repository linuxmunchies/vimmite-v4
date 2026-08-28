#!/usr/bin/env bash
set -euo pipefail

readonly LSFG_VERSION="1.0.0"
readonly LSFG_SHA256="77749bbd5bddd19ea38b090e0cec8912e9285a92b9345429df924dc33cc47786"
readonly LSFG_URL="https://github.com/PancakeTAS/lsfg-vk/releases/download/v${LSFG_VERSION}/lsfg-vk-${LSFG_VERSION}.x86_64.rpm"

lsfg_workdir="$(mktemp -d /tmp/vimmite-lsfg.XXXXXX)"
trap 'rm -rf "${lsfg_workdir}"' EXIT

curl --fail --location --retry 3 --output "${lsfg_workdir}/lsfg-vk.rpm" "${LSFG_URL}"
printf '%s  %s\n' "${LSFG_SHA256}" "${lsfg_workdir}/lsfg-vk.rpm" | sha256sum --check --strict

# Upstream does not sign this RPM. The pinned SHA-256 digest above is the trust
# check, so package signature verification is disabled only for this local file.
dnf5 --assumeyes --nogpgcheck install "${lsfg_workdir}/lsfg-vk.rpm"

