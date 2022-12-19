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

# Map (unordered) that mirrors the rule file, meaning key = wildcard, value = pipeline name.
declare -A RULES_MAP
# List (ordered) containing the wildcards.
declare -a RULES_WILDCARDS

function load_rules {
    local RULES_PATH="${SCRIPT_DIR}/rules/${RULES}"

    if [ ! -f "${RULES_PATH}" ]; then
        echoerr "Rules file not found."
        exit 6
    fi

    local i=0
    for line in $(grep -v '$\s*#' ${RULES_PATH}); do
        WILDCARD="$(echo $line | cut -d\; -f 1)"
        PIPELINE="$(echo $line | cut -d\; -f 2)"

        RULES_MAP[${WILDCARD}]="${PIPELINE}"
        RULES_WILDCARDS[$i]="${WILDCARD}"

        i=$((i + 1))
    done
}

function generate_compress_pipeline_command_line {
    local PIPELINE_NAME=$1
    local OUTPUT_FILE=$2

    local COMMAND_LINE=""

    local i="0"
    while read line; do
        if [ "$(echo $line | grep '^compress;')" == "" ]; then
            continue
        fi

        if [ "$i" -eq "1" ]; then
            COMMAND_LINE="${COMMAND_LINE} | ${PROGRESS_COMMAND}"
        fi

        APP_NAME=$(echo $line | cut -d';' -f 2)
        ARGUMENTS=$(echo $line | cut -d';' -f 3)

        if [ "$i" -ge 1 ]; then
            COMMAND_LINE="${COMMAND_LINE} | "
        fi

        COMMAND_LINE="${COMMAND_LINE}${APP_NAME} ${ARGUMENTS}"

        i=$((i + 1))
    done <"${SCRIPT_DIR}/pipelines/${PIPELINE_NAME}"

    if [ "$i" -eq 1 ]; then
        COMMAND_LINE="${COMMAND_LINE} | ${PROGRESS_COMMAND}"
    fi

    COMMAND_LINE="${COMMAND_LINE} >> ${OUTPUT_FILE}"

    echo ${COMMAND_LINE}
}

function generate_extract_pipeline_command_line {
    local PIPELINE_NAME=$1
    local OFFSET=$2
    local SIZE=$3
    local OUTPUT_FILE=$4

    local COMMAND_LINE="dd if=_FILE_NAME_ bs=2M iflag=skip_bytes,count_bytes skip=${OFFSET} count=${SIZE} status=none"

    while read line; do
        if [ "$(echo $line | grep '^extract;')" == "" ]; then
            continue
        fi

        APP_NAME=$(echo $line | cut -d';' -f 2)
        ARGUMENTS=$(echo $line | cut -d';' -f 3)

        COMMAND_LINE="${COMMAND_LINE} | ${APP_NAME} ${ARGUMENTS}"

    done <"${SCRIPT_DIR}/pipelines/${PIPELINE_NAME}"

    COMMAND_LINE="${COMMAND_LINE} | ${PROGRESS_COMMAND} > '${OUTPUT_FILE}'"

    echo ${COMMAND_LINE}
}

function discover_pipeline_name {
    local INPUT_FILE_NAME="$1"

    for wildcard in "${RULES_WILDCARDS[@]}"; do
        if [ "$(find "${INPUT_FILE_NAME}" -name "${wildcard}")" ]; then
            echo "${RULES_MAP[${wildcard}]}"
            return 0
        fi
    done

    echoerr "No pipeline found for file ${INPUT_FILE_NAME}"
    exit 8
}

function check_pipeline_required_tools {
    while read line; do
        if [ "${line}" == "" ]; then
            continue
        fi
        PIPELINE_COMMAND="$(echo $line | cut -d";" -f 2)"
        set +e
        hash "${PIPELINE_COMMAND}"
        if [ $? -ne 0 ]; then
            echoerr "Command \"${PIPELINE_COMMAND}\" not installed."
            exit 15
        fi
        set -e
    done <"${SCRIPT_DIR}/pipelines/${PIPELINE_NAME}"
}
