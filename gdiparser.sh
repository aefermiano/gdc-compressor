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

# Very dumb parser
function get_gdi_files {
    local GDI_FILE=$1

    FILES_SEPARATED_BY_NEW_LINE=$(tail -n +2 "${GDI_FILE}" | awk '{print $5}')

    FILES=""
    while IFS= read -r line; do
        if [ "${FILES}" != "" ]; then
            FILES="${FILES},${line}"
        else
            FILES="${line}"
        fi
    done <<<"${FILES_SEPARATED_BY_NEW_LINE}"
    IFS="${DEFAULT_IFS}"

    echo ${FILES}
    return 0
}
