#!/bin/sh

SCRIPT_DIR="$(dirname $(readlink -f $0))"
SRC_ROOT="${SCRIPT_DIR}/../"

# pvs-studio-analyzer parameters
SUPPRESS_FILE="${SCRIPT_DIR}/suppress_bcc2.json"
STRACE_OUT="${SRC_ROOT}/strace_out"

COMPILER="g++"
THREADS=2

# plog-converter parameters
PLOG_DIAG_RULES="GA:1,2,3;OP:1;64:1;CS:1;MISRA:1,2"
PLOG_OUTPUT_FORMAT=tasklist
PLOG_OUTPUT_FILE="${SCRIPT_DIR}/report.tasks"

if [ ! -e "${STRACE_OUT}" ]; then
    pvs-studio-analyzer trace -- make -C "${SRC_ROOT}"
fi

pvs-studio-analyzer analyze -s "${SUPPRESS_FILE}" --compiler "${COMPILER}" -j "${THREADS}"
plog-converter  -a  "${PLOG_DIAG_RULES}"    \
                -t  "${PLOG_OUTPUT_FORMAT}" \
                -o  "${PLOG_OUTPUT_FILE}"   \
                "${SCRIPT_DIR}/PVS-Studio.log"

echo "Analysis done, '${PLOG_OUTPUT_FILE}' contents:"
cat "${PLOG_OUTPUT_FILE}"

rm -f "${STRACE_OUT}"
