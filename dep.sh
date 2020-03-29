#!/bin/bash
#################################################################################
# MIT License
# 
# Copyright (c) 2020 Jia Lihong
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#################################################################################
#
# Usage: $(basename $0) [OPTION]... DIRECTORY
# Scan and visualize C/C++ source file dependencies.
# 
# Options:
#   -h              show help
#   -e              show extern dependencies
#   -o FILENAME     specify the output png name, default is "dep.png"
#

err() {
    echo "ERROR: $*" >&2
    exit 1
}

display_help() {
    echo "Usage: $(basename "$0") [OPTION]... DIRECTORY"
    echo "Scan and visualize C/C++ source file dependencies."
    echo ""
    echo "Options:"
    echo "  -h              show help"
    echo "  -e              show extern dependencies"
    echo "  -o FILENAME     specify the output png name, default is \"dep.png\""
    echo ""
}

contains() {
    local result="false"
    local grep_result
    grep_result="$(echo "$1" | grep "^$2$")"
    if [ -n "${grep_result}" ]; then
        result="true"
    fi
    echo "${result}"
}

check_dot() {
    if ! type "dot" >/dev/null 2>&1; then
        err "graphviz is not installed"
    fi
}

main() {
    DISPLAY_HELP="false"
    SHOW_EXTERN="false"
    OUTPUT_NAME="dep.png"

    while getopts "eho:" opt
    do
        case "$opt" in
        e) SHOW_EXTERN="true" ;;
        h) DISPLAY_HELP="true" ;;
        o) OUTPUT_NAME="${OPTARG}" ;;
        *) echo "Unknown option $opt"; exit 1 ;;
        esac
    done

    readonly DISPLAY_HELP
    readonly SHOW_EXTERN
    readonly OUTPUT_NAME

    if [[ "${DISPLAY_HELP}" == "true" ]]; then
        display_help
        exit 0
    fi

    check_dot

    shift $(( OPTIND - 1))

    if [ -n "$1" ]; then
        readonly DIR="$1"
    else
        echo "Missing directory"
        display_help
        exit 1
    fi

    readonly NEWLINE=$'\n'

    echo "SHOW_EXTERN: ${SHOW_EXTERN}"
    echo "OUTPUT_NAME: ${OUTPUT_NAME}"
    echo "DIR = ${DIR}"

    readonly FILEPATH_LIST="$(find "${DIR}" -regex ".*\.\(h\|hxx\|hpp\|hh\|c\|cxx\|cpp\|cc\)")"
    readonly FILENAME_LIST="$(echo "${FILEPATH_LIST}" | awk -F'/' '{print $NF}')"
    readonly FILE_NUM="$(echo "${FILEPATH_LIST}" | wc -l)"

    extern_list=""
    dep_inner_list=""
    dep_extern_list=""

    echo "FILE_NUM = ${FILE_NUM}"

    i=0
    for filepath in ${FILEPATH_LIST}; do
        i="$(( "$i" + 1 ))"
        echo -n "[$i/${FILE_NUM}] Scanning ${filepath} ... "

        filename="$(echo "${filepath}" | awk -F'/' '{print $NF}')"
        include_list="$(cpp -fpreprocessed "${filepath}" | sed -ne 's/^\s*#include\s*<\(.*\)>\s*$/\1/p; s/^\s*#include\s*\"\(.*\)\"\s*$/\1/p')"

        for include_path in ${include_list}; do
            include_name="$(echo "${include_path}" | awk -F'/' '{print $NF}')"

            if [[ "$(contains "${FILENAME_LIST}" "${include_name}")" == "false" ]]; then
                dep_extern_list="${dep_extern_list}${NEWLINE}\"${filename}\" -> \"${include_name}\""
                if [[ "$(contains "${extern_list}" "${include_name}")" == "false" ]]; then
                    extern_list="${extern_list}${NEWLINE}${include_name}"
                fi
            else
                dep_inner_list="${dep_inner_list}${NEWLINE}\"${filename}\" -> \"${include_name}\""
            fi
        done
        echo "done"
    done

    IFS=$'\n'

    echo -n "Generating .dot file ... "
    dot_result="digraph dep {"

    for filename in ${FILENAME_LIST}; do
        if [[ -n "${filename}" ]]; then
            dot_result="${dot_result}${NEWLINE}\"${filename}\";"
        fi
    done
    for dep in ${dep_inner_list}; do
        dot_result="${dot_result}${NEWLINE}${dep};"
    done

    if [[ "${SHOW_EXTERN}" == "true" ]]; then
        for filename in ${extern_list}; do
            if [[ -n "${filename}" ]]; then
                dot_result="${dot_result}${NEWLINE}\"${filename}\" [color=red];"
            fi
        done
        for dep in ${dep_extern_list}; do
            dot_result="${dot_result}${NEWLINE}${dep};"
        done
    fi

    dot_result="${dot_result}${NEWLINE}}"

    echo "done"

    readonly TEMP_DOT="$(mktemp)"
    echo -n "Writing .dot file ... "
    echo "${dot_result}" > "${TEMP_DOT}"
    echo "done"

    echo -n "Generating .png file ... "
    dot -o "${OUTPUT_NAME}" -Tpng "${TEMP_DOT}"
    echo "done"
}

main "$@"