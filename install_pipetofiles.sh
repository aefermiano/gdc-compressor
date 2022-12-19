#!/bin/bash

#
# Copyright (C) 2022 Antonio Fermiano
#
# This file is part of gdc-compressor.
#
# gdc-compressor is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# gdc-compressor is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with gdc-compressor. If not, see <https://www.gnu.org/licenses/>.
#

set -e

# Standalone script that installs pipetofiles.sh

function echoerr() {
    echo "$@" 1>&2
}

if [ "$EUID" -ne 0 ]; then
    echoerr "Please run as root"
    exit
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_TO_INSTALL="pipetofiles.sh"
INSTALLATION_FOLDER="/usr/local/bin"

for file in ${FILES_TO_INSTALL}; do
    cp ${SCRIPT_DIR}/${file} ${INSTALLATION_FOLDER}
    chmod +x ${INSTALLATION_FOLDER}/${file}
done
