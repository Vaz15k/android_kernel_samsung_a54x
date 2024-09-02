#!/bin/bash
DIR=`readlink -f .`
PARENT_DIR=`readlink -f ${DIR}/..`

AK3_DIR="$HOME/AnyKernel3"
TC_DIR="$HOME/Prebuilts"
OUT_DIR="$DIR/out"

ARGS="$*"
DEVICE_MODEL="$1"

JOBS=$(nproc --all)
MAKE_PARAMS="-j$JOBS -C $DIR CC=clang LLVM=1 LLVM_IAS=1 CLANG_TRIPLE=llvm- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-"

devicecheck() {
    if [ "$DEVICE_MODEL" == "SM-A546E" ]; then
        DEVICE_NAME="SM-A546E"
        DEFCONFIG=s5e8835-a54xnsxx_defconfig
    elif [ "$DEVICE_MODEL" == "SM-A546B" ]; then
        DEVICE_NAME="SM-A546B"
        DEFCONFIG=s5e8835-a54xnaxx_defconfig
    else
        echo "- Config not found"
        exit
    fi
}

toolchain() {
	BT_DIR="$TC_DIR/build-tools"
	CL_DIR="$TC_DIR/gl-clang/clang-r536225"
	GAS_DIR="$TC_DIR/gas"

	export PATH=$CL_DIR/bin:$PATH
	export PATH=$BT_DIR/path/linux-x86:$PATH
	export PATH=$GAS_DIR/linux-x86:$PATH
}

ksu() {
    # Check if KSU flag is provided
    if [[ "$ARGS" == *"--ksu"* ]]; then
        KSU="true"
        CONFIG_KSU=y
    else
        KSU="false"
    fi

    # Check the value of KSU
    if [ "$KSU" == "true" ]; then
        ZIP_NAME="Squeak_KSU_"$DEVICE_NAME"_"$(date +'%Y-%m-%d')""
		rm -fr $OUT_DIR
        if [ -d "KernelSU" ]; then
            echo "KernelSU exists"
        else
            echo "KernelSU not found !"
            echo "Fetching ...."
            curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
        fi
    elif [ "$KSU" == "false" ]; then
        echo "KSU disabled"
        ZIP_NAME="Squeak_"$DEVICE_NAME"_"$(date +'%Y-%m-%d')""
        if [ -d "KernelSU" ]; then
            rm -rf drivers/kernelsu
            rm -rf KernelSU
            git reset HEAD --hard
        fi
    fi
}

anykernel3() {
	if [ -d $AK3_DIR ]; then
		cd $AK3_DIR
		git reset HEAD --hard
		rm -fr Squeak* Image
		cd $DIR
	else 
	    git clone --branch a54x https://github.com/Vaz15k/AnyKernel3.git $AK3_DIR
	    cd $DIR
	fi
}

makezipfile() {
    cp $OUT_DIR/arch/arm64/boot/Image $AK3_DIR
    cd $AK3_DIR
    zip -r9 $ZIP_NAME . -x '*.git*' '*patch*' '*ramdisk*' 'README.md' '*modules*'
}

export PLATFORM_VERSION=14
export ANDROID_MAJOR_VERSION=u
export DEPMOD=depmod

echo "Starting Building ..."
devicecheck
ksu
toolchain
make $MAKE_PARAMS $DEFCONFIG
make $MAKE_PARAMS
anykernel3
makezipfile
