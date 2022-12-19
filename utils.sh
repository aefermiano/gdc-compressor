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

DEFAULT_IFS="${IFS}"

function echoerr() {
    echo "$@" 1>&2
}

function replace_tokens_in_command_line {
    COMMAND_LINE=$1
    FILE_NAME=$2
    FILE_SIZE=$3

    echo ${COMMAND_LINE} |
        sed 's/_FILE_NAME_/'"'${FILE_NAME}'"'/g' |
        sed 's/_FILE_SIZE_/'"${FILE_SIZE}"'/g' |
        sed 's/_XZ_DICTIONARY_SIZE_/'"${XZ_DICTIONARY_SIZE}"'/g' |
        sed 's/_XZ_MEMORY_LIMIT_/'"${XZ_MEMORY_LIMIT}"'/g' |
        sed 's/_XZ_THREADS_/'"${XZ_THREADS}"'/g'
}
