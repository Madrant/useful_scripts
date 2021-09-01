#!/bin/bash

# A script to generate version.h based on mercurial commit history

SCRIPT_DIR="$(dirname $(readlink -f $0))"

versionh="${SCRIPT_DIR}/../version.h"

# Create version header file
echo -n "" > "${versionh}"

# Generate version header
echo "#ifndef VERSION_H"  >> "${versionh}"
echo "#define VERSION_H"  >> "${versionh}"
echo ""  >> "${versionh}"

# Go to script location directory
pushd "${SCRIPT_DIR}" > /dev/null

# Get current branch, revision number and hash
current_branch=$(hg branch)
in_branch_revision_number=$(hg log --template "." | wc -m)
current_revision_number=$(hg id -r . --num)
revision_hash=$(hg id | cut -f1 -d' ')
date_time=$(date +%d-%m-%Y'_'%H:%M)

# popd back
popd > /dev/null

# Check gathered strings
if [ -z "${current_branch}" ]; then
    current_branch="branch_unknown"
fi

if [ -z "${in_branch_revision_number}" ]; then
    in_branch_revision_number="revision_unknown"
fi

if [ -z "${revision_hash}" ]; then
    revision_hash="hash_unknown"
fi

# Generate version string
version="${current_branch}-${current_revision_number}(${revision_hash})-(${date_time})"
echo "${version}"

# Save version string
echo "// Version explained: <branch>.<revision number>(<revision hash>).(<datetime as ddmmYHM>)" >> "${versionh}"
echo "#define CPS_APP_CURRENT_VERSION \"${version}\"" >> "${versionh}"

# Close header file
echo ""  >> "${versionh}"
echo "#endif // VERSION_H" >> "${versionh}"
