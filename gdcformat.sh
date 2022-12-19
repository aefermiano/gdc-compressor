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

HEADER=""

function start_header {
    DESTINATION_FILE=$1

    echo -n "GDC " >${DESTINATION_FILE}
    echo -n "0000000000000000" >>${DESTINATION_FILE}

    HEADER=""
}

function add_to_header {
    local FILE_NAME=$1
    local FILE_SIZE_UNCOMPRESSED=$2
    local FILE_SIZE_COMPRESSED=$3
    local HASH=$4
    local DECOMPRESS_STRING=$5

    local NEW_LINE="${FILE_NAME};${FILE_SIZE_UNCOMPRESSED};${FILE_SIZE_COMPRESSED};${HASH};${DECOMPRESS_STRING}"
    if [ "${HEADER}" == "" ]; then
        HEADER="${NEW_LINE}"
    else
        HEADER="${HEADER}"$'\n'"${NEW_LINE}"
    fi
}

function finish_header {
    local DESTINATION_FILE=$1

    OFFSET=$(stat -c%s "${DESTINATION_FILE}")

    printf '%016X' ${OFFSET} | dd of=${DESTINATION_FILE} oflag=seek_bytes seek=4 conv=notrunc status=none

    echo -n "${HEADER}" >>${DESTINATION_FILE}
}

function validate_file_magic_word {
    CHECK=$(dd if=${INPUT_OUTPUT_FILE} iflag=count_bytes count=4 status=none)
    if [ "${CHECK}" != "GDC " ]; then
        echoerr "Error validating file ${INPUT_OUTPUT_FILE}"
        exit 10
    fi
}

function read_header {
    OFFSET=$(dd if=${INPUT_OUTPUT_FILE} iflag=count_bytes,skip_bytes skip=4 count=16 status=none)
    OFFSET=$((0x${OFFSET}))

    HEADER=$(dd if=${INPUT_OUTPUT_FILE} iflag=skip_bytes skip=${OFFSET} status=none)
}
