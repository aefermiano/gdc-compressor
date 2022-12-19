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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE=""
GDI=""
FILES=""
RULES="default"
INPUT_OUTPUT_FILE=""
OVERWRITE=0

# Dependencies' order matters!
source ${SCRIPT_DIR}/config.sh
source ${SCRIPT_DIR}/utils.sh
source ${SCRIPT_DIR}/gdcformat.sh
source ${SCRIPT_DIR}/gdiparser.sh
source ${SCRIPT_DIR}/rulesprocessor.sh

function show_usage {
    local SCRIPT_NAME=$1

    echo "${SCRIPT_NAME} [-h/--help] [-c/--compress] [-e/--extract] [-l/--list] [-g/--gdi <gdi_file>] [-f/--files <common separated file list] [-r/--rules <custom rule file>] [-o/--overwrite] <input or output file>"
}

function compress {
    if [ "${FILES}" == "" ]; then
        echoerr "No input files found"
        exit 5
    fi

    IFS=","
    for file in ${FILES}; do
        if [ ! -f "${file}" ]; then
            echoerr "File ${file} does not exist"
            exit 14
        fi
    done
    IFS="${DEFAULT_IFS}"

    if [ "${OVERWRITE}" -eq 0 -a -f "${INPUT_OUTPUT_FILE}" ]; then
        echoerr "File ${INPUT_OUTPUT_FILE} already exists. I refuse to overwrite it."
        exit 7
    fi

    >${INPUT_OUTPUT_FILE}

    load_rules

    start_header ${INPUT_OUTPUT_FILE}

    IFS=","
    for file in ${FILES}; do
        IFS="${DEFAULT_IFS}"
        ADJUSTED_HASH_COMMAND=$(replace_tokens_in_command_line "${HASH_COMMAND}" "${file}" "")
        HASH=$(eval ${ADJUSTED_HASH_COMMAND})
        FILE_SIZE=$(stat -c%s "${file}")

        PIPELINE_NAME=$(discover_pipeline_name "${file}")

        check_pipeline_required_tools "${PIPELINE_NAME}"

        COMMAND_LINE=$(generate_compress_pipeline_command_line ${PIPELINE_NAME} "${INPUT_OUTPUT_FILE}")
        COMMAND_LINE=$(replace_tokens_in_command_line "${COMMAND_LINE}" "${file}" ${FILE_SIZE})

        OFFSET=$(stat -c%s "${INPUT_OUTPUT_FILE}")
        echo
        echo "File: ${file}"
        echo "Compress command line: ${COMMAND_LINE}"
        eval ${COMMAND_LINE}

        CURRENT_OUTPUT_FILE=$(stat -c%s "${INPUT_OUTPUT_FILE}")
        local SIZE_OF_COMPRESSED_DATA=$((${CURRENT_OUTPUT_FILE} - ${OFFSET}))

        EXTRACT_COMMAND_LINE=$(generate_extract_pipeline_command_line ${PIPELINE_NAME} ${OFFSET} ${SIZE_OF_COMPRESSED_DATA} "${file}")
        echo "Extract command line: ${EXTRACT_COMMAND_LINE}"
        add_to_header "${file}" "${FILE_SIZE}" "${SIZE_OF_COMPRESSED_DATA}" "${HASH}" "${EXTRACT_COMMAND_LINE}"
        IFS=","
    done
    IFS="${DEFAULT_IFS}"

    finish_header ${INPUT_OUTPUT_FILE}
}

function list {
    if [ ! -f ${INPUT_OUTPUT_FILE} ]; then
        echoerr "File ${INPUT_OUTPUT_FILE} does not exist"
        exit 11
    fi

    validate_file_magic_word

    read_header

    PRINTABLE_TEXT="File;Size (orig);Size (comp);Hash;Extract command"$'\n'";;;;"$'\n'"${HEADER}"
    echo "${PRINTABLE_TEXT}" | column -t -H 4 --table-wrap 5 -s ";"
}

function extract {
    if [ ! -f ${INPUT_OUTPUT_FILE} ]; then
        echoerr "File ${INPUT_OUTPUT_FILE} does not exist"
        exit 12
    fi

    validate_file_magic_word

    read_header

    while IFS= read -r line; do
        IFS="${DEFAULT_IFS}"
        FILE_NAME=$(echo "${line}" | cut -d';' -f 1)
        FILE_SIZE=$(echo "${line}" | cut -d';' -f 2)
        INFORMED_HASH=$(echo "${line}" | cut -d';' -f 4)
        EXTRACT_COMMAND=$(echo "${line}" | cut -d';' -f 5)

        if [ -f "${FILE_NAME}" ]; then
            echoerr "${FILE_NAME} already exists, I won't overwrite it!"
        fi

        ADJUSTED_EXTRACT_COMMAND=$(replace_tokens_in_command_line "${EXTRACT_COMMAND}" "${INPUT_OUTPUT_FILE}" "${FILE_SIZE}")

        echo
        echo "File name: ${FILE_NAME}"
        echo "Command line: ${ADJUSTED_EXTRACT_COMMAND}"

        eval ${ADJUSTED_EXTRACT_COMMAND}

        ADJUSTED_HASH_COMMAND=$(replace_tokens_in_command_line "${HASH_COMMAND}" "${FILE_NAME}" "")
        CALCULATED_HASH=$(eval ${ADJUSTED_HASH_COMMAND})

        if [ "${INFORMED_HASH}" != "${CALCULATED_HASH}" ]; then
            echoerr "Hashes do not match!"
            exit 13
        fi
        IFS=
    done <<<"${HEADER}"
}

if [ $# == 0 ]; then
    show_usage $0
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
    -c | --compress)
        MODE="compress"
        shift
        ;;
    -e | --extract)
        MODE="extract"
        shift
        ;;
    -l | --list)
        MODE="list"
        shift
        ;;
    -g | --gdi)
        GDI=$2
        shift
        shift
        ;;
    -f | --files)
        FILES="$2"
        shift
        shift
        ;;
    -r | --rules)
        RULES=$2
        shift
        shift
        ;;
    -o | --overwrite)
        OVERWRITE=1
        shift
        ;;
    -h | --help)
        show_usage $0
        exit 0
        ;;
    -* | --*)
        echoerr "Unknown option $1"
        show_usage $0
        exit 1
        ;;
    *)
        if [ "${INPUT_OUTPUT_FILE}" == "" ]; then
            INPUT_OUTPUT_FILE=$1
        else
            echoerr "Only one input or output file allowed"
            show_usage $0
            exit 1
        fi
        shift # past argument
        ;;
    esac
done

if [ "${MODE}" == "" ]; then
    echoerr "Mode not specified"
    exit 9
fi

if [ "${GDI}" != "" ]; then
    if [ "${FILES}" != "" ]; then
        echoerr "Specify only one kind of input files, GDI or individual files"
        exit 2
    fi

    FILES="$(get_gdi_files "${GDI}"),${GDI}"
fi

if [ "${INPUT_OUTPUT_FILE}" == "" ]; then
    echoerr "Should specify at least one input or output file"
    exit 4
fi

if [ "${MODE}" == "compress" ]; then
    compress
elif [ "${MODE}" == "extract" ]; then
    extract
elif [ "${MODE}" == "list" ]; then
    list
else
    echoerr "Unknown mode: ${MODE}"
    exit 3
fi
