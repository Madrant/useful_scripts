#!/bin/bash

SCRIPT_VERSION=0.9.8
SCRIPT_REPO_URL=http://rhodecode.localnet/Tools/rebuild

SCRIPT_FOLDER="$(dirname $(readlink -f $0))"
SCRIPT_PATH=`pwd`"/$0"

# Exit on error
set -e

# Pre and Post scripts location
EXT_SCRIPTS="$SCRIPT_FOLDER/_rebuild"

# Variables for 'src' folder path
SRC_FOLDER_NAME="src"
SAVED_PATH=$PATH
SRC_PATH= #Auto located in parent folders

# Additional parameters:
NOCLEAN=0   #do not perform 'make clean' on sources (for test builds)
SILENT=1    #do not show target build output
SHOWCMD=1

# make parameters
CPUS=`cat /proc/cpuinfo | grep processor | wc -l`

# color constants:
DEFAULT="\E[37;47m" # White on black - default
WHITE="\E[30;47m"   # Black on white - headers
RED="\E[37;41;1m"   # White on red   - errors
NONE="\E[0m"        # All attributes off

# Print error
#
# $1 - message to print
print_err() {
    echo -en ${RED}
    echo -n "${1}"
    echo -e  ${NONE}
}

# Print target
#
# $1 - message to print
print_target() {
    echo -en ${WHITE}
    echo -n "${1}"
    echo -e  ${NONE}
}

check_cmd() {
    if ! type $1 1>/dev/null 2>/dev/null
    then
       print_err "Error: Command '$1' not found - please install '$1' and try again"
       exit 1
    fi
}

run_cmd() {
    check_cmd $1

    RUN_CMD_TMP=".cmd.stderr"

    if [ "$SHOWCMD" == "1" ]
    then
        echo "running: $@"
    fi

    if [ "$SILENT" == "1" ]
    then
        "$@" 1>/dev/null 2>$RUN_CMD_TMP && rc=$? || rc=$? && true #do not exit on error
    else
        "$@" && rc=$? || rc=$? && true #do not exit on error
    fi

    if [ "$rc" != 0 ]
    then
        print_err "Error: command '$@' failed"

        if [ -f $RUN_CMD_TMP ]
        then
            cat $RUN_CMD_TMP
            rm -f $RUN_CMD_TMP 1>/dev/null 2>/dev/null
        fi

        exit 1
    fi

    if [ -f $RUN_CMD_TMP ]
    then
        rm -f $RUN_CMD_TMP 1>/dev/null 2>/dev/null
    fi
}

# Check for additional params
#
# $1...$n - additional params to check
parse_params() {
    cmdline_params=( "$@" )
    param_num=1

    for param in "${cmdline_params[@]}"
    do
        next_param_num=$((param_num+1))
        next_param=${!next_param_num}

        if [ "$param" == "noclean" ]
        then
            echo "No 'make clean' will be performed on build"
            NOCLEAN=1
        fi

        if [ "$param" == "verbose" ]
        then
            echo "Verbose mode enabled"
            SILENT=0
        fi

        param_num=$((param_num+1))
    done
}

parse_cmdline() {
    case $1 in
        "help")
            parse_config
            print_help $2
        ;;
        "self-update")
            run_self_update $2 $3 $4 $5 $6
        ;;
        "version")
            echo "Script version: $SCRIPT_VERSION"
        ;;
        "clone")
            parse_config
            clone_all
        ;;
        "update")
            parse_config
            update_all $2 $3 $4
        ;;
        "all")
            # $1 == "all"

            parse_params $2 $3
            parse_config

            target_execute_all

            echo "All target finished"
        ;;
        *)  #default
            if [ -z $1 ]
            then
                print_help
                exit 0
            fi

            parse_params $2 $3
            parse_config

            #call internal function "target_name()"
            target_execute $1 $2 $3 $4
        ;;
    esac
}

print_help() {
    if [ "$1" == "all" ]
    then
        echo "Build 'all' sequence targets:"
        printf "    %s\n" "${BUILD_ALL[@]}"

        exit 0
    fi

    echo "$0 - build/rebuild automation script"
    echo
    echo "Usage:"
    echo "$0 [parameters...]"
    echo
    echo "Options:"
    echo "  all         - build all target (see 'help all')"
    echo "  help        - print help"
    echo "  self-update - update script from repository rhodecode.localnet"
    echo "  version     - show script version"
    echo "  clone       - clone  all required sources"
    echo "  update      - update all required sources"
    echo
    echo "Targets:"
    cat $SCRIPT_PATH | grep -e "target_build[A-Za-z0-9._]*[\(][\)]" | \
                       grep -Po "build[A-Za-z0-9._]*" | \
                       sed "s/build_/  /g" || true
    echo
    echo "Target options:"
    echo "  <target> noclean - do not perform sources clean when builduing target"

    exit 0
}

# Self-update rebuild.sh from repository
#
# $1 - custom arg, pass 'commit' to perform auto-commit after update
# $2...$6 - args for 'hg commit'
run_self_update() {
    echo "Running self-update"

    #Check for hg command
    hash hg || ( echo "Please install 'mercurial' package" && exit 1 )

    RAND=( `date | md5sum` )
    TMP=/tmp/$RAND-rebuild-update-tmp

    hg clone $SCRIPT_REPO_URL $TMP || ( echo "Clone $SCRIPT_REPO_URL failed" && exit 1 )

    pushd $TMP
    exec /bin/bash $TMP/update.sh $SCRIPT_FOLDER $1 $2 $3 $4 $5 $6
    popd

    exit 0
}

locate_src_folder() {
    path=$SCRIPT_FOLDER

    while [ ! -d $path/$SRC_FOLDER_NAME ]
    do
        echo "Searching for '$SRC_FOLDER_NAME' folder in $path"

        cd $path/..
        path=`pwd`

        if [ "$path" == "/" ]
        then
            print_err "Search completed: no '$SRC_FOLDER_NAME' folder found"
            print_err "Please prepare a sources folder or link named '$SRC_FOLDER_NAME' in parent directory"
            exit 1
        fi
    done

    SRC_PATH=$path/$SRC_FOLDER_NAME
    echo "Sources folder found: $SRC_PATH"

    cd $SCRIPT_FOLDER
}

# Locate "src" folder path and pass it to rebuild.config
parse_config() {
    locate_src_folder
    export SRC_PATH

    source rebuild.config
}

# Clone required repos from CLONE_ALL URLs array
#
clone_all() {
    pushd $SRC_PATH

    for url in "${CLONE_ALL[@]}"
    do
        echo "Cloning '$url'"

        # Do not exit on error
        hg clone $url || true
    done

    popd
}

# Update required repos from CLONE_ALL URLs array
#
# $1, $2, $3 - update params
update_all() {
    pushd $SRC_PATH

    for url in "${CLONE_ALL[@]}"
    do
        # remove 'http://' from url
        url_noproto=${url:7}
        target_path=${url_noproto#*/}
        target_dir=${target_path##*/}

        if [ ! -d $target_dir ]
        then
            echo "Repo not cloned: [$url]"
            run_cmd hg clone $url
        fi

        pushd $target_dir 1>/dev/null

        echo "Checking '$target_dir'"

        if hg outgoing > /dev/null 2>&1
        then
            print_err "Warning! Outgoing changes in '$target_dir'"
            exit 1
        fi

        # 'hg incoming' is 2x faster
        if hg incoming > /dev/null 2>&1
        then
            echo "Updating repo: '$target_dir'"
            run_cmd hg pull
            run_cmd hg update $1 $2 $3
        fi

        popd 1>/dev/null # $target_dir
    done

    popd # $SRC_PATH
}

# Check target for existance
#
# $1 - target name
target_check() {
    if ! cat $SCRIPT_PATH | grep "target_build_$1()" > /dev/null
    then
        print_err "Target not found: '$1'"
        exit 1
    fi
}

# Execute target 'all' with pre- and post- build scripts
#
# none
target_execute_all() {
    PRE_SCRIPT=$EXT_SCRIPTS/all-pre
    POST_SCRIPT=$EXT_SCRIPTS/all-post

    date
    print_target "Executing target 'all'"

    # Check for pre-build script
    if [ -f $PRE_SCRIPT ]
    then
        print_target "Executing pre-build script: '$PRE_SCRIPT'"
        run_cmd $PRE_SCRIPT
    else
        echo "No pre-build script: '$PRE_SCRIPT'"
    fi

    # Execute target
    for t in "${BUILD_ALL[@]}"
    do
        target_execute $t
    done

    date
    print_target "Finished target: 'all'"

    # Check for post-build script
    if [ -f $POST_SCRIPT ]
    then
        print_target "Executing post-build script: '$POST_SCRIPT'"
        run_cmd $POST_SCRIPT
    else
        echo "No post-build script: '$POST_SCRIPT'"
    fi
}

# Execute target_build_<name>
#
# $1 - target name
# $2, $3, $4 - target params
target_execute() {
    PRE_SCRIPT=$EXT_SCRIPTS/$1-pre
    POST_SCRIPT=$EXT_SCRIPTS/$1-post

    # Check if target exists
    target_check $1

    # Check for pre-build script
    if [ -f $PRE_SCRIPT ]
    then
        print_target "Executing pre-build script: '$PRE_SCRIPT'"
        run_cmd $PRE_SCRIPT
    else
        echo "No pre-build script: '$PRE_SCRIPT'"
    fi

    # Execute target
    date
    print_target "Executing target '$1'"

    target_build_$1 $2 $3 $4

    date
    print_target "Finished target: '$1'"

    # Check for post-build script
    if [ -f $POST_SCRIPT ]
    then
        print_target "Executing post-build script: '$POST_SCRIPT'"
        run_cmd $POST_SCRIPT
    else
        echo "No post-build script: '$POST_SCRIPT'"
    fi
}

eldk_prepare() {
    [ -z ELDK_BIN_PATH ]   && (print_err "var ELDK_BIN_PATH is not set in rebuild.config"   && exit 1)
    [ -z ELDK_PREFIX ]     && (print_err "var ELDK_PREFIX is not set in rebuild.config"     && exit 1)
    [ -z ELDK_SETUP_ENV ]  && (print_err "var ELDK_SETUP_ENV is not set in rebuild.config"  && exit 1)
    [ -z ELDK_GCC_FOLDER ] && (print_err "var ELDK_GCC_FOLDER is not set in rebuild.config" && exit 1)

    source $ELDK_SETUP_ENV
    unset LDFLAGS #eldk workaround

    if [ ! -L $ELDK_BIN_PATH"/"$ELDK_PREFIX"gcc" ]
    then
        echo "Link does note exists - preparing toolchain"

        LN_CMD="sudo ln -fs"
        FOLDER=$ELDK_GCC_FOLDER

        pushd $ELDK_BIN_PATH

        $LN_CMD $FOLDER/$ELDK_PREFIX"addr2line" $ELDK_PREFIX"addr2line"
        $LN_CMD $FOLDER/$ELDK_PREFIX"ar"        $ELDK_PREFIX"ar"
        $LN_CMD $FOLDER/$ELDK_PREFIX"as"        $ELDK_PREFIX"as"
        $LN_CMD $FOLDER/$ELDK_PREFIX"c++filt"   $ELDK_PREFIX"c++filt"
        $LN_CMD $FOLDER/$ELDK_PREFIX"cpp"       $ELDK_PREFIX"cpp"
        $LN_CMD $FOLDER/$ELDK_PREFIX"elfedit"   $ELDK_PREFIX"elfedit"
        $LN_CMD $FOLDER/$ELDK_PREFIX"embedspu"  $ELDK_PREFIX"embedspu"
        $LN_CMD $FOLDER/$ELDK_PREFIX"g++"       $ELDK_PREFIX"g++"
        $LN_CMD $FOLDER/$ELDK_PREFIX"gcc"       $ELDK_PREFIX"gcc"
        $LN_CMD $FOLDER/$ELDK_PREFIX"gdb"       $ELDK_PREFIX"gdb"
        $LN_CMD $FOLDER/$ELDK_PREFIX"gprof"     $ELDK_PREFIX"gprof"
        $LN_CMD $FOLDER/$ELDK_PREFIX"ld"        $ELDK_PREFIX"ld"
        $LN_CMD $FOLDER/$ELDK_PREFIX"nm"        $ELDK_PREFIX"nm"
        $LN_CMD $FOLDER/$ELDK_PREFIX"objcopy"   $ELDK_PREFIX"objcopy"
        $LN_CMD $FOLDER/$ELDK_PREFIX"objdump"   $ELDK_PREFIX"objdump"
        $LN_CMD $FOLDER/$ELDK_PREFIX"ranlib"    $ELDK_PREFIX"ranlib"
        $LN_CMD $FOLDER/$ELDK_PREFIX"readelf"   $ELDK_PREFIX"readelf"
        $LN_CMD $FOLDER/$ELDK_PREFIX"size"      $ELDK_PREFIX"size"
        $LN_CMD $FOLDER/$ELDK_PREFIX"strings"   $ELDK_PREFIX"strings"
        $LN_CMD $FOLDER/$ELDK_PREFIX"strip"     $ELDK_PREFIX"strip"

        popd
    fi
}

#kernel 2.6.37+
target_build_kernel() {
    eldk_prepare

    check_cmd bc
    check_cmd gawk

    pushd $KERNEL_PATH

    if [ ! $NOCLEAN == 1 ]
    then
        run_cmd make ARCH=$ARCH clean
    fi

    run_cmd make -j $CPUS ARCH=$ARCH $KERNEL_CONFIG
    run_cmd make -j $CPUS ARCH=$ARCH LOCALVERSION= uImage

    rc=$?

    if [ $rc != 0 ]
    then
        print_err "Kernel build failed - make returns non-zero exit code"
        exit 1
    fi

    if [ ! -f arch/$ARCH/boot/uImage ]
    then
        print_err "Kernel build failed - no uImage found"
        exit 1
    fi

    cp arch/$ARCH/boot/uImage $SCRIPT_FOLDER/bin

    popd
}

#kernel 2.6.32 + backports
target_build_kernel_old() {
    eldk_prepare

    check_cmd bc
    check_cmd gawk

    pushd $KERNEL_V2_PATH

    if [ ! $NOCLEAN == 1 ]
    then
        run_cmd make ARCH=$ARCH clean
    fi

    cp $SCRIPT_FOLDER/../kernel/.config $KERNEL_V2_PATH
    run_cmd make -j $CPUS ARCH=$ARCH LOCALVERSION= uImage

    rc=$?

    if [ $rc != 0 ]
    then
        echo "Kernel build failed - make returns non-zero exit code"
        print_err 1
    fi

    if [ ! -f arch/$ARCH/boot/uImage ]
    then
        print_err "Kernel build failed - no uImage found"
        exit 1
    fi

    cp arch/$ARCH/boot/uImage $SCRIPT_FOLDER/bin

    popd
}

#dtb
target_build_dtb() {
    pushd $SCRIPT_FOLDER

    DTC=`which dtc || true` # 'true' is used to avoid silent exit on error

    if [ -f $KERNEL_PATH/scripts/dtc/dtc ]
    then
        DTC=$KERNEL_PATH/scripts/dtc/dtc
    fi

    if [ -f $KERNEL_V2_PATH/scripts/dtc/dtc ]
    then
        DTC=$KERNEL_V2_PATH/scripts/dtc/dtc
    fi

    run_cmd $DTC -I dts -O dtb -o bin/xilinx.dtb ../dtb/xilinx.dts

    rc=$?

    if [ $rc != 0 ]
    then
        print_err "Device-tree build failed - dtc returns non-zero exit code"
        exit 1
    fi

    popd
}

#u-boot
target_build_uboot() {
    eldk_prepare

    check_cmd make

    if [ -f ../u-boot/xparameters.h ] && [ ! -z $UBOOT_XPAR_PATH ]
    then
        echo "Updating xparameters.h"
        cp ../u-boot/xparameters.h $UBOOT_PATH/$UBOOT_XPAR_PATH/xparameters.h
    fi

    pushd $UBOOT_PATH

    if [ ! $NOCLEAN == 1 ]
    then
        run_cmd make ARCH=$ARCH mrproper
    fi

    run_cmd make -j $CPUS ARCH=$ARCH $UBOOT_CONFIG
    run_cmd make -j $CPUS

    rc=$?

    if [ $rc != 0 ]
    then
        print_err "U-boot build failed - make returns non-zero exit code"
        exit 1
    fi

    if [ ! -f u-boot.bin ]
    then
        print_err "U-boot build failed - no u-boot.bin found"
        exit 1
    fi

    cp u-boot.bin $SCRIPT_FOLDER/bin

    popd
}

#U-boot env
target_build_uboot_env() {
    pushd $SCRIPT_FOLDER

    $UBOOT_PATH/tools/mkenvimage $UBOOT_ENV_ENDIANESS -p $UBOOT_ENV_PADDING \
                                 -s $UBOOT_ENV_SIZE -o bin/$UBOOT_ENV_BIN ../u-boot/$UBOOT_ENV_TXT
    rc=$?

    if [ $rc != 0 ]
    then
        print_err "Env build failed - dtc returns non-zero exit code"
        exit 1
    fi

    popd
}

#buildroot
target_build_rootfs() {
    eldk_prepare

    check_cmd make
    check_cmd gcc
    check_cmd g++
    check_cmd patch
    check_cmd gzip
    check_cmd unzip
    check_cmd rsync

    PATH=$SAVED_PATH
    echo "PATH="$PATH

    pushd $BUILDROOT_PATH

    cp $BUILDROOT_CONFIG_1 .defconfig
    run_cmd make defconfig

    if [ ! $NOCLEAN == 1 ]
    then
        run_cmd make clean
    fi

    run_cmd make -j $CPUS

    cp $BUILDROOT_CONFIG_2 .defconfig
    run_cmd make defconfig
    run_cmd make -j $CPUS

    if [ "$BUILDROOT_OUTPUT_IMAGE" = "uramdisk" ]
    then
        if [ -f $UBOOT_PATH/tools/mkimage ]
        then
            MKIMAGE=$UBOOT_PATH/tools/mkimage
        fi

        if hash mkimage
        then
            MKIMAGE=mkimage
        fi

        if [ -z $MKIMAGE ]
        then
            print_err "mkimage tool not found - install u-boot-tools or build U-boot first"
            exit 1
        fi

        echo "$MKIMAGE -A arm -O linux -T ramdisk -C gzip -d rootfs.ext2.gz uramdisk"
        run_cmd $MKIMAGE -A arm -O linux -T ramdisk -C gzip -d output/images/rootfs.ext2.gz output/images/uramdisk
    fi

    if [ ! -f output/images/$BUILDROOT_OUTPUT_IMAGE ]
    then
        print_err "Rootfs build failed - no $BUILDROOT_OUTPUT_IMAGE found"
        exit 1
    fi

    cp output/images/$BUILDROOT_OUTPUT_IMAGE $SCRIPT_FOLDER/bin

    if [ ! -z $BUILDROOT_TAR_IMAGE ]
    then
        if [ -f output/images/$BUILDROOT_TAR_IMAGE ]
        then
            cp output/images/$BUILDROOT_TAR_IMAGE $SCRIPT_FOLDER/bin
            gzip -f $SCRIPT_FOLDER/bin/$BUILDROOT_TAR_IMAGE
        else
            echo "No $BUILDROOT_TAR_IMAGE file found"
        fi
    fi

    popd
}

# Start script here
echo "Script version: '${SCRIPT_VERSION}'"
echo "Current folder: '${SCRIPT_FOLDER}'"
echo

if [ ! -d "$SCRIPT_FOLDER/bin" ]
then
    echo "Creating 'bin' folder: '$SCRIPT_FOLDER/bin'"
    mkdir -p "$SCRIPT_FOLDER/bin"
fi

parse_cmdline $@
