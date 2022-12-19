#/bin/bash

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

# Standalone script which consumes and produces content via pipe (stdin and stdout), but under the hood copies the content
# to files and invokes a command passing them.
#
# Used to make the interface of tools that do not accept pipe compatible with a pipeline (e.g: utilities which uses fseek)
#
# The downside is that content is actually written to /tmp, which is usually mounted in a disk, so it's slower.

INPUT_FILE_PLACE_HOLDER="INPUT_FILE"
OUTPUT_FILE_PLACE_HOLDER="OUTPUT_FILE"

if [ $# -eq 0 -o $# -gt 3 ]; then
    echo "Usage: $0 <command to execute, using \"${INPUT_FILE_PLACE_HOLDER}\" and \"${OUTPUT_FILE_PLACE_HOLDER}\" to mark the content provided by pipe> [<input file extension>] [<output file extension>]"
    exit 1
fi

COMMAND="$1"
INPUT_FILE_EXTENSION="$2"
OUTPUT_FILE_EXTENSION="$3"

INPUT_FILE="$(mktemp)"
if [ "${INPUT_FILE_EXTENSION}" != "" ]; then
    rm ${INPUT_FILE}
    INPUT_FILE="${INPUT_FILE}.${INPUT_FILE_EXTENSION}"
fi

OUTPUT_FILE="$(mktemp)"
if [ "${OUTPUT_FILE_EXTENSION}" != "" ]; then
    rm ${OUTPUT_FILE}
    OUTPUT_FILE="${OUTPUT_FILE}.${OUTPUT_FILE_EXTENSION}"
fi

ADJUSTED_INPUT_FILE=$(echo "${INPUT_FILE}" | sed 's/\//\\\//g')
ADJUSTED_OUTPUT_FILE=$(echo "${OUTPUT_FILE}" | sed 's/\//\\\//g')
ADJUSTED_COMMAND=$(echo "${COMMAND}" | sed 's/'${INPUT_FILE_PLACE_HOLDER}'/'${ADJUSTED_INPUT_FILE}'/g' | sed 's/'${OUTPUT_FILE_PLACE_HOLDER}'/'${ADJUSTED_OUTPUT_FILE}'/g')

cat - >${INPUT_FILE}
eval "${ADJUSTED_COMMAND}" >/dev/null
cat ${OUTPUT_FILE}

rm ${INPUT_FILE}
rm ${OUTPUT_FILE}
