#!/bin/bash

REBUILD_SCRIPT_NAME=rebuild.sh
REBUILD_SCRIPT_CONFIG_NAME=rebuild.config

set -e

# $1 - script location
# $2 - commit or not (pass 'commit' to commit after update)
# $3...$7 - args for 'hg commit' (example: -u User)

echo "$REBUILD_SCRIPT_NAME update script"

FLD=`pwd`
echo "Current folder is: $FLD"

DST=$1

run_cleanup() {
    echo "Removing $FLD folder"
    cd ..

    #Simple protection from delete anything but /tmp/bla-bla-bla-rebuild_update folder
    if [ `pwd` == "/tmp" ]
    then
        rm -rf $FLD
    fi
}

if [ -z $DST ]
then
    echo "Please set destination folder as '$0 [folder]'"
    exit 0
fi

echo "Target folder is: $DST"

if [ ! -f $DST/$REBUILD_SCRIPT_NAME ]
then
    echo "No '$REBUILD_SCRIPT_NAME' in destination folder $DST - exiting"
    run_cleanup
    exit 0
fi

if [ ! -f $FLD/$REBUILD_SCRIPT_NAME ]
then
    echo "No '$REBUILD_SCRIPT_NAME' in source folder $FLD - exiting"
    run_cleanup
    exit 0
fi

LOCAL_MD5=( `md5sum $DST/$REBUILD_SCRIPT_NAME` )
LAST_MD5=( `md5sum $FLD/$REBUILD_SCRIPT_NAME` )

echo "Local file hash:  "$LOCAL_MD5
echo "Latest file hash: "$LAST_MD5

if [ "$LOCAL_MD5" == "$LAST_MD5" ]
then
    echo "No update needed - local script is the same as in latest revision"
    run_cleanup
    exit 0
fi

echo "Performing script update"
rm -f $DST/$REBUILD_SCRIPT_NAME
cp $FLD/$REBUILD_SCRIPT_NAME $DST/$REBUILD_SCRIPT_NAME

if [ ! -f $DST/$REBUILD_SCRIPT_NAME ]
then
    echo "No '$REBUILD_SCRIPT_NAME' in destintaion folder $FLD - update failed"
    run_cleanup
    exit 1
fi

if [ ! -f $DST/$REBUILD_SCRIPT_CONFIG_NAME ]
then
    cp -f $FLD/$REBUILD_SCRIPT_CONFIG_NAME $DST/$REBUILD_SCRIPT_CONFIG_NAME
fi

echo "Script update completed"
cat $DST/$REBUILD_SCRIPT_NAME | grep "^SCRIPT_VERSION"

run_cleanup

echo "Done! Update procedure completed"

pushd $DST
    if [ "$2" == commit ]
    then
        echo "Commiting ${REBUILD_SCRIPT_NAME}"

        hg sum 1>/dev/null 2>&1 && rc=$? || rc=$? && true #do not exit on error

        if [ "$rc" == 0 ]
        then
            SCRIPT_VERSION=`cat ${REBUILD_SCRIPT_NAME} | grep ^SCRIPT_VERSION | sed s/SCRIPT_VERSION=//g`

            echo hg commit -m "${REBUILD_SCRIPT_NAME}: self-updated to version ${SCRIPT_VERSION}" ${REBUILD_SCRIPT_NAME}
            hg commit -m "${REBUILD_SCRIPT_NAME}: self-updated to version ${SCRIPT_VERSION}" $3 $4 $5 $6 $7 ${REBUILD_SCRIPT_NAME}
        else
            echo "No mercurial repo found: aborting commit process"
            exit 1
        fi

        echo "Commit procedure completed"
    fi
popd
